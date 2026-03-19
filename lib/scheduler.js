const { Cron } = require('croner');
const db = require('./db');
const executor = require('./executor');
const { HEARTBEAT_INTERVAL_MS } = require('./config');

const activeJobs = new Map(); // jobId -> Cron instance
let queueProcessing = false;
let heartbeatInterval = null;

// === Queue ===

async function processQueue() {
  if (queueProcessing) return;
  queueProcessing = true;

  try {
    while (true) {
      if (executor.isRunning()) break;

      const queued = db.getQueuedRuns();
      if (queued.length === 0) break;

      const run = queued[0];
      const job = db.getJob(run.job_id);

      await executor.executeRun(run);

      // Retry on failure if retries remain
      if (run.status === 'failed' && job && job.max_retries > 0) {
        const failedRuns = db.getRuns({ job_id: run.job_id, limit: job.max_retries + 1 })
          .filter(r => r.status === 'failed');

        if (failedRuns.length <= job.max_retries) {
          db.createRun({ job_id: run.job_id, trigger_type: 'retry' });
        }
      }
    }
  } finally {
    queueProcessing = false;
  }
}

function enqueueJob(jobId, triggerType = 'scheduled') {
  const run = db.createRun({ job_id: jobId, trigger_type: triggerType });
  processQueue();
  return run;
}

// === Cron scheduling ===

function scheduleJob(job) {
  // Remove existing if re-scheduling
  unscheduleJob(job.id);

  if (!job.enabled || !job.cron_expr) return;

  try {
    const cronJob = new Cron(job.cron_expr, { timezone: Intl.DateTimeFormat().resolvedOptions().timeZone }, () => {
      enqueueJob(job.id, 'scheduled');
    });

    activeJobs.set(job.id, cronJob);
  } catch (err) {
    console.error(`[scheduler] Invalid cron for job ${job.id} "${job.name}": ${err.message}`);
  }
}

function unscheduleJob(jobId) {
  const existing = activeJobs.get(jobId);
  if (existing) {
    existing.stop();
    activeJobs.delete(jobId);
  }
}

function getNextRun(jobId) {
  const cronJob = activeJobs.get(jobId);
  if (!cronJob) return null;
  const next = cronJob.nextRun();
  return next ? next.toISOString() : null;
}

// === Missed job detection ===

function detectMissedJobs() {
  const lastActive = db.getState('last_active_at');
  if (!lastActive) return;

  const lastDate = new Date(lastActive);
  const now = new Date();
  const jobs = db.getAllJobs().filter(j => j.enabled && j.run_on_wake);

  for (const job of jobs) {
    try {
      const cron = new Cron(job.cron_expr);
      // nextRun(fromDate) returns the next scheduled time after fromDate
      const nextFromLast = cron.nextRun(lastDate);
      if (nextFromLast && nextFromLast < now) {
        console.log(`[scheduler] Missed job detected: "${job.name}" — enqueueing`);
        enqueueJob(job.id, 'wake');
      }
    } catch {
      // Skip invalid cron
    }
  }
}

// === Heartbeat ===

function startHeartbeat() {
  db.setState('last_active_at', new Date().toISOString());
  heartbeatInterval = setInterval(() => {
    db.setState('last_active_at', new Date().toISOString());
  }, HEARTBEAT_INTERVAL_MS);
}

function stopHeartbeat() {
  if (heartbeatInterval) {
    clearInterval(heartbeatInterval);
    heartbeatInterval = null;
  }
}

// === Init ===

function start() {
  // Detect missed jobs from downtime
  detectMissedJobs();

  // Schedule all enabled jobs
  const jobs = db.getAllJobs();
  for (const job of jobs) {
    scheduleJob(job);
  }

  startHeartbeat();
  console.log(`[scheduler] Started with ${activeJobs.size} active jobs`);
}

function stop() {
  for (const [id] of activeJobs) {
    unscheduleJob(id);
  }
  stopHeartbeat();
}

function rescheduleAll() {
  for (const [id] of activeJobs) {
    unscheduleJob(id);
  }
  const jobs = db.getAllJobs();
  for (const job of jobs) {
    scheduleJob(job);
  }
}

module.exports = {
  start,
  stop,
  scheduleJob,
  unscheduleJob,
  enqueueJob,
  getNextRun,
  rescheduleAll,
  processQueue,
};
