const { spawn } = require('node:child_process');
const { CLAUDE_BIN, WORKSPACE_DIR, MAX_LOG_SIZE } = require('./config');
const db = require('./db');

let currentProcess = null;
let currentRunId = null;

function truncate(str, max) {
  if (!str || str.length <= max) return str || '';
  return str.slice(-max); // Keep the tail (most recent output)
}

function executeRun(run) {
  return new Promise((resolve) => {
    const job = db.getJob(run.job_id);
    if (!job) {
      db.updateRun(run.id, { status: 'failed', error_msg: 'Job not found', finished_at: new Date().toISOString() });
      return resolve();
    }

    currentRunId = run.id;

    // Build prompt: /skillname (if set) + arguments
    let prompt = '';
    if (job.skill_name && job.skill_name.trim()) {
      prompt = `/${job.skill_name}`;
    }
    if (job.arguments && job.arguments.trim()) {
      prompt += (prompt ? ' ' : '') + job.arguments.trim();
    }
    if (!prompt) {
      db.updateRun(run.id, { status: 'failed', error_msg: 'No skill or prompt defined', finished_at: new Date().toISOString() });
      return resolve();
    }

    const args = ['--dangerously-skip-permissions', '-p', prompt];

    db.updateRun(run.id, {
      status: 'running',
      started_at: new Date().toISOString(),
    });

    let stdout = '';
    let stderr = '';
    let killed = false;
    let timedOut = false;

    const proc = spawn(CLAUDE_BIN, args, {
      cwd: WORKSPACE_DIR,
      env: { ...process.env, CLAUDECODE: undefined },
      stdio: ['ignore', 'pipe', 'pipe'],
      shell: process.platform === 'win32',
    });

    currentProcess = proc;

    // Timeout
    const timeoutId = setTimeout(() => {
      timedOut = true;
      proc.kill('SIGTERM');
      setTimeout(() => {
        try { proc.kill('SIGKILL'); } catch {}
      }, 5000);
    }, job.timeout_ms);

    proc.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });

    proc.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });

    proc.on('close', (code) => {
      clearTimeout(timeoutId);
      currentProcess = null;
      currentRunId = null;

      const status = timedOut ? 'timeout' : killed ? 'killed' : code === 0 ? 'success' : 'failed';

      db.updateRun(run.id, {
        status,
        finished_at: new Date().toISOString(),
        exit_code: code,
        stdout: truncate(stdout, MAX_LOG_SIZE),
        stderr: truncate(stderr, MAX_LOG_SIZE),
        error_msg: timedOut ? 'Timeout exceeded' : killed ? 'Killed by user' : '',
      });

      resolve();
    });

    proc.on('error', (err) => {
      clearTimeout(timeoutId);
      currentProcess = null;
      currentRunId = null;

      db.updateRun(run.id, {
        status: 'failed',
        finished_at: new Date().toISOString(),
        error_msg: err.message,
      });

      resolve();
    });
  });
}

function killCurrent() {
  if (!currentProcess) return false;
  currentProcess.kill('SIGTERM');
  setTimeout(() => {
    if (currentProcess && !currentProcess.killed) {
      currentProcess.kill('SIGKILL');
    }
  }, 5000);

  if (currentRunId) {
    db.updateRun(currentRunId, {
      status: 'killed',
      finished_at: new Date().toISOString(),
      error_msg: 'Killed by user',
    });
  }
  return true;
}

function getCurrentRunId() {
  return currentRunId;
}

function isRunning() {
  return currentProcess !== null;
}

module.exports = { executeRun, killCurrent, getCurrentRunId, isRunning };
