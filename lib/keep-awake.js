const { spawn, execSync } = require('node:child_process');
const { writeFileSync, unlinkSync } = require('node:fs');
const { join } = require('node:path');
const { IS_WIN } = require('./config');
const { DATA_DIR } = require('./config');

let psProcess = null;
let vbsPath = null;

// Prevent Windows sleep using SetThreadExecutionState.
// PowerShell spawn always flashes a console window on Windows,
// so we wrap it in a .vbs script and run via wscript (no window at all).

const PS_SCRIPT = `
Add-Type -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);' -Name KeepAwake -Namespace Win32
while ($true) {
  [Win32.KeepAwake]::SetThreadExecutionState(0x80000001) | Out-Null
  Start-Sleep -Seconds 30
}
`;

function start() {
  if (!IS_WIN || psProcess) return;

  try {
    // Write PowerShell script to temp file
    const ps1Path = join(DATA_DIR, 'keep-awake.ps1');
    writeFileSync(ps1Path, PS_SCRIPT, 'utf8');

    // Write VBS wrapper that launches PowerShell completely hidden
    vbsPath = join(DATA_DIR, 'keep-awake.vbs');
    const vbs = `Set objShell = CreateObject("WScript.Shell")\nobjShell.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & Replace(WScript.ScriptFullName, "keep-awake.vbs", "keep-awake.ps1") & """", 0, False`;
    writeFileSync(vbsPath, vbs, 'utf8');

    // wscript is a GUI host — spawns zero console windows
    psProcess = spawn('wscript', [vbsPath], {
      stdio: 'ignore',
      windowsHide: true,
      detached: true,
    });
    psProcess.unref();
    psProcess.on('error', () => {});

    console.log('[keep-awake] Windows sleep blocked');
  } catch (err) {
    console.log('[keep-awake] Failed to start:', err.message);
  }
}

function stop() {
  if (!psProcess) return;

  // Kill all PowerShell processes spawned by our script
  try {
    execSync('taskkill /IM powershell.exe /F /FI "WINDOWTITLE eq keep-awake"', { stdio: 'ignore', windowsHide: true });
  } catch {}

  try { psProcess.kill(); } catch {}
  psProcess = null;

  // Reset: allow sleep again
  try {
    const resetVbs = join(DATA_DIR, 'keep-awake-reset.vbs');
    const resetPs1 = join(DATA_DIR, 'keep-awake-reset.ps1');
    writeFileSync(resetPs1, `Add-Type -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);' -Name KeepAwake2 -Namespace Win32\n[Win32.KeepAwake2]::SetThreadExecutionState(0x80000000) | Out-Null`, 'utf8');
    writeFileSync(resetVbs, `Set objShell = CreateObject("WScript.Shell")\nobjShell.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & Replace(WScript.ScriptFullName, "keep-awake-reset.vbs", "keep-awake-reset.ps1") & """", 0, False`, 'utf8');
    spawn('wscript', [resetVbs], { stdio: 'ignore', windowsHide: true });
  } catch {}

  // Cleanup temp files
  try { unlinkSync(join(DATA_DIR, 'keep-awake.ps1')); } catch {}
  try { unlinkSync(join(DATA_DIR, 'keep-awake.vbs')); } catch {}

  console.log('[keep-awake] Windows sleep unblocked');
}

module.exports = { start, stop };
