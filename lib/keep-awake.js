const { spawn } = require('node:child_process');
const { IS_WIN } = require('./config');

let psProcess = null;

// Spawn a single long-lived PowerShell process that calls SetThreadExecutionState
// in a loop every 30s. This avoids flashing a new window on each call.
// ES_CONTINUOUS (0x80000000) | ES_SYSTEM_REQUIRED (0x00000001) = prevent sleep

const PS_KEEP_AWAKE_SCRIPT = `
Add-Type -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);' -Name KeepAwake -Namespace Win32
while ($true) {
  [Win32.KeepAwake]::SetThreadExecutionState(0x80000001) | Out-Null
  Start-Sleep -Seconds 30
}
`;

const PS_RESET_SCRIPT = `
Add-Type -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);' -Name KeepAwake2 -Namespace Win32
[Win32.KeepAwake2]::SetThreadExecutionState(0x80000000) | Out-Null
`;

function start() {
  if (!IS_WIN || psProcess) return;

  psProcess = spawn('powershell', ['-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command', PS_KEEP_AWAKE_SCRIPT], {
    stdio: 'ignore',
    windowsHide: true,
  });

  psProcess.on('error', () => {});
  psProcess.on('exit', () => { psProcess = null; });

  console.log('[keep-awake] Windows sleep blocked');
}

function stop() {
  if (!psProcess) return;

  psProcess.kill();
  psProcess = null;

  // Reset: ES_CONTINUOUS only (allow sleep again)
  try {
    const reset = spawn('powershell', ['-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command', PS_RESET_SCRIPT], {
      stdio: 'ignore',
      windowsHide: true,
    });
    reset.on('error', () => {});
  } catch {}

  console.log('[keep-awake] Windows sleep unblocked');
}

module.exports = { start, stop };
