const { spawn } = require('node:child_process');
const path = require('node:path');
const { IS_WIN } = require('./config');

let awakeProc = null;

// PowerShell inline script that calls SetThreadExecutionState in a loop.
// ES_CONTINUOUS (0x80000000) | ES_SYSTEM_REQUIRED (0x00000001) = prevent sleep
// Loop refreshes every 30s (Windows resets the flag after ~60s of inactivity)
const PS_SCRIPT = [
  '$sig = Add-Type -Name Win32 -Namespace KeepAwake -PassThru -MemberDefinition @"',
  '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);',
  '"@;',
  'while ($true) {',
  '  $sig::SetThreadExecutionState(0x80000001) | Out-Null;',
  '  Start-Sleep -Seconds 30',
  '}',
].join(' ');

function start() {
  if (!IS_WIN || awakeProc) return;

  awakeProc = spawn('powershell', ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', PS_SCRIPT], {
    detached: true,
    stdio: 'ignore',
  });
  awakeProc.unref();

  console.log('[keep-awake] Windows sleep blocked (pid=' + awakeProc.pid + ')');
}

function stop() {
  if (!awakeProc) return;

  try { process.kill(awakeProc.pid); } catch {}
  awakeProc = null;
  console.log('[keep-awake] Windows sleep unblocked');
}

module.exports = { start, stop };
