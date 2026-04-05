const { execSync } = require('node:child_process');
const { IS_WIN } = require('./config');

let intervalId = null;

// Call SetThreadExecutionState via PowerShell one-liner (no window, no loop)
// ES_CONTINUOUS (0x80000000) | ES_SYSTEM_REQUIRED (0x00000001) = prevent sleep
// Must be refreshed periodically — Windows resets after ~60s of inactivity
function ping() {
  try {
    execSync(
      'powershell -NoProfile -NonInteractive -Command "Add-Type -MemberDefinition \'[DllImport(\\\"kernel32.dll\\\")] public static extern uint SetThreadExecutionState(uint esFlags);\' -Name W -Namespace K -PassThru | ForEach-Object { $_.SetThreadExecutionState(0x80000001) }" ',
      { stdio: 'ignore', windowsHide: true }
    );
  } catch {}
}

function start() {
  if (!IS_WIN || intervalId) return;

  ping();
  intervalId = setInterval(ping, 30000);

  console.log('[keep-awake] Windows sleep blocked');
}

function stop() {
  if (!intervalId) return;

  clearInterval(intervalId);
  intervalId = null;

  // Reset: ES_CONTINUOUS only (allow sleep again)
  try {
    execSync(
      'powershell -NoProfile -NonInteractive -Command "Add-Type -MemberDefinition \'[DllImport(\\\"kernel32.dll\\\")] public static extern uint SetThreadExecutionState(uint esFlags);\' -Name W2 -Namespace K2 -PassThru | ForEach-Object { $_.SetThreadExecutionState(0x80000000) }" ',
      { stdio: 'ignore', windowsHide: true }
    );
  } catch {}

  console.log('[keep-awake] Windows sleep unblocked');
}

module.exports = { start, stop };
