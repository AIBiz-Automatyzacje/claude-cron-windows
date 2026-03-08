# CLAUDE-CRON — Windows Autostart Setup
$ErrorActionPreference = "Stop"

Write-Host "🕹️  CLAUDE-CRON — Windows Autostart Setup" -ForegroundColor Green
Write-Host ""

$ProjectDir = Join-Path $env:USERPROFILE "claude-cron"
$NodePath = (Get-Command node).Source
$ServerPath = Join-Path $ProjectDir "server.js"
$TaskName = "ClaudeCron"

# Remove existing task if present
try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false 2>$null
} catch {}

# Create task
$Action = New-ScheduledTaskAction -Execute $NodePath -Argument $ServerPath -WorkingDirectory $ProjectDir
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "Claude Code skill scheduler"

Write-Host "✅ Installed! Server starts automatically on login." -ForegroundColor Green
Write-Host "   Open http://localhost:7777"
