# CLAUDE-CRON — Windows Autostart Removal
$ErrorActionPreference = "Stop"

Write-Host "🕹️  CLAUDE-CRON — Windows Autostart Removal" -ForegroundColor Green
Write-Host ""

$TaskName = "ClaudeCron"

try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "✅ Autostart removed." -ForegroundColor Green
} catch {
    Write-Host "Task not found — nothing to remove." -ForegroundColor Yellow
}

Write-Host "   Your jobs and data are preserved in ~/claude-cron/data/"
