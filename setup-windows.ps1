# ============================================
#  CLAUDE-CRON — Windows Setup
#  Dashboard + proxy do VPS
# ============================================
#
#  Uruchom: powershell -ExecutionPolicy Bypass -File setup-windows.ps1
#

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# === Helper functions ===

function Write-Info($msg)  { Write-Host "[info] " -ForegroundColor Cyan -NoNewline; Write-Host $msg }
function Write-Ok($msg)    { Write-Host "[ok] " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Write-Warn($msg)  { Write-Host "[warn] " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Fail($msg)  { Write-Host "[error] " -ForegroundColor Red -NoNewline; Write-Host $msg; exit 1 }

$RepoDir = $PSScriptRoot

Write-Host ""
Write-Host "  CLAUDE-CRON — Windows Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Ten skrypt konfiguruje lokalny dashboard claude-cron"
Write-Host "  i podlacza go do Twojego VPS-a (ktory dziala 24/7)."
Write-Host ""
Write-Host "  Mozna tez uzyc bez VPS-a (tylko lokalnie)." -ForegroundColor DarkGray
Write-Host ""

# ============ PREFLIGHT ============

Write-Info "Sprawdzam wymagania..."

# Node.js
try {
    $nodeCmd = Get-Command node -ErrorAction Stop
    $nodeVersion = (node -v) -replace '^v', ''
    $nodeMajor = [int]($nodeVersion.Split('.')[0])
    if ($nodeMajor -lt 18) {
        Write-Fail "Wymagany Node.js 18+, znaleziono v$nodeVersion"
    }
    Write-Ok "Node.js v$nodeVersion"
} catch {
    Write-Fail 'Node.js nie znaleziony. Zainstaluj z https://nodejs.org (18+)'
}

# npm
try {
    $npmVersion = (npm -v 2>$null)
    Write-Ok "npm $npmVersion"
} catch {
    Write-Fail "npm nie znaleziony"
}

# Claude CLI
$claudeInPath = $false
try {
    $null = Get-Command claude -ErrorAction Stop
    Write-Ok "Claude CLI znaleziony"
    $claudeInPath = $true
} catch {
    $localBin = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
    if (Test-Path $localBin) {
        Write-Warn "Claude CLI znaleziony w $localBin, ale NIE jest w PATH!"
        Write-Warn "Dodaj do PATH:"
        Write-Host ""
        $binDir = Join-Path $env:USERPROFILE ".local\bin"
        $pathCmd = '[Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";' + $binDir + '", "User")'
        Write-Host "  $pathCmd" -ForegroundColor Cyan
        Write-Host ""
    } else {
        Write-Warn "Claude CLI nie znaleziony!"
        Write-Warn "Zainstaluj: npm install -g @anthropic-ai/claude-code"
        Write-Warn "Joby nie beda dzialac bez niego. Setup kontynuuje."
        Write-Host ""
    }
}

# npm install
Write-Host ""
Write-Info "Instaluje zaleznosci..."
Set-Location $RepoDir
try {
    $npmOutput = npm install --production 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw $npmOutput }
    Write-Ok "Zaleznosci zainstalowane"
} catch {
    $errMsg = $_.Exception.Message + $npmOutput
    if ($errMsg -match 'node-gyp|MSBuild|cl\.exe|gyp ERR') {
        Write-Host ""
        Write-Host "[error] npm install nie powiodl sie — brak Visual Studio Build Tools." -ForegroundColor Red
        Write-Host ""
        Write-Host "  Zainstaluj Build Tools:" -ForegroundColor Yellow
        Write-Host "  1. Pobierz: https://visualstudio.microsoft.com/visual-cpp-build-tools/" -ForegroundColor Cyan
        Write-Host "  2. Zaznacz 'Desktop development with C++'" -ForegroundColor Cyan
        Write-Host "  3. Zainstaluj i uruchom setup ponownie" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Alternatywnie:" -ForegroundColor Yellow
        Write-Host "  npm install --global windows-build-tools" -ForegroundColor Cyan
        Write-Host ""
        exit 1
    }
    Write-Fail "npm install nie powiodl sie: $errMsg"
}

New-Item -ItemType Directory -Path "$RepoDir\data" -Force | Out-Null
Write-Ok "Katalog data gotowy"

# ============ STEP 1: VPS CONNECTION ============

Write-Host ""
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host "  KROK 1/4 — Polaczenie z VPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Claude-cron na VPS dziala 24/7 i odpala joby wg harmonogramu."
Write-Host "  Ten dashboard podlacza sie do niego przez Tailscale."
Write-Host ""
Write-Host "  Podaj Tailscale IP Twojego VPS-a (np. 100.x.x.x)." -ForegroundColor DarkGray
Write-Host "  Znajdziesz go na VPS: tailscale ip -4" -ForegroundColor DarkGray
Write-Host "  Puste = pomin (tryb tylko lokalny)" -ForegroundColor DarkGray
Write-Host ""

$VpsHost = Read-Host "  Tailscale IP VPS-a"
$VpsUrl = ""

if ($VpsHost) {
    $VpsHost = $VpsHost.Trim()
    $VpsPortInput = Read-Host "  Port VPS [7777]"
    $VpsPort = if ($VpsPortInput) { $VpsPortInput.Trim() } else { "7777" }
    $VpsUrl = "http://${VpsHost}:${VpsPort}"

    [Environment]::SetEnvironmentVariable('CLAUDE_CRON_VPS_URL', $VpsUrl, 'User')
    $env:CLAUDE_CRON_VPS_URL = $VpsUrl
    Write-Ok "VPS: $VpsUrl"
} else {
    Write-Info "Tryb tylko lokalny — joby dzialaja gdy komputer nie spi"
}

# ============ STEP 2: WORKSPACE ============

Write-Host ""
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host "  KROK 2/4 — Workspace" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Folder, w ktorym Claude CLI wykonuje joby (np. Twoj vault Obsidian)."
Write-Host ""

$defaultWorkspace = $env:USERPROFILE
$WorkspaceInput = Read-Host "  Sciezka do workspace [$defaultWorkspace]"
$Workspace = if ($WorkspaceInput) { $WorkspaceInput.Trim().Trim('"').Trim("'") } else { $defaultWorkspace }

# Resolve path (validates existence)
try {
    $Workspace = (Resolve-Path $Workspace -ErrorAction Stop).Path
} catch {
    Write-Fail "Folder nie istnieje: $WorkspaceInput"
}

[Environment]::SetEnvironmentVariable('CLAUDE_CRON_WORKSPACE', $Workspace, 'User')
$env:CLAUDE_CRON_WORKSPACE = $Workspace
Write-Ok "Workspace: $Workspace"

# ============ STEP 3: AUTOSTART HOOK ============

Write-Host ""
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host "  KROK 3/4 — Autostart" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Serwer claude-cron moze startowac automatycznie"
Write-Host "  przy kazdym uruchomieniu Claude Code."
Write-Host ""

$InstallHook = Read-Host "  Zainstalowac autostart? [Y/n]"
if (-not $InstallHook) { $InstallHook = "Y" }

$HookInstalled = $false

if ($InstallHook -match '^[Yy]$') {
    # 1. Create hooks directory
    $HooksDir = Join-Path $env:USERPROFILE ".claude\hooks"
    New-Item -ItemType Directory -Path $HooksDir -Force | Out-Null

    # 2. Write hook JS file
    $HookFile = Join-Path $HooksDir "claude-cron-autostart.js"
    $CronDirJs = $RepoDir.Replace('\', '/')

    $hookContent = @"
const http = require('http');
const { spawn } = require('child_process');

const CRON_DIR = '$CronDirJs';

const req = http.get('http://localhost:7777/api/status', { timeout: 1000 }, () => {
  process.exit(0);
});

req.on('error', () => {
  const child = spawn('node', ['server.js'], {
    cwd: CRON_DIR,
    detached: true,
    stdio: 'ignore',
  });
  child.unref();

  // Caffeinate — keep Mac awake while claude-cron is alive
  if (process.platform === 'darwin') {
    spawn('caffeinate', ['-w', String(child.pid)], {
      detached: true,
      stdio: 'ignore',
    }).unref();
  }

  console.log('Claude-Cron started in background (localhost:7777)');
  process.exit(0);
});

req.on('timeout', () => {
  req.destroy();
});
"@

    Set-Content -Path $HookFile -Value $hookContent -Encoding UTF8
    Write-Ok "Hook: $HookFile"

    # 3. Register hook in settings.json
    $SettingsFile = Join-Path $env:USERPROFILE ".claude\settings.json"
    $hookCmd = "node `"$($HookFile.Replace('\', '/'))`""

    if (Test-Path $SettingsFile) {
        try {
            $settings = Get-Content $SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Write-Warn "Nie mozna odczytac settings.json — tworzenie nowego"
            $settings = [PSCustomObject]@{}
        }
    } else {
        $settings = [PSCustomObject]@{}
    }

    # Ensure hooks object exists
    if (-not (Get-Member -InputObject $settings -Name 'hooks' -MemberType NoteProperty)) {
        $settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{})
    }

    # Ensure UserPromptSubmit array exists
    if (-not (Get-Member -InputObject $settings.hooks -Name 'UserPromptSubmit' -MemberType NoteProperty)) {
        $settings.hooks | Add-Member -NotePropertyName 'UserPromptSubmit' -NotePropertyValue @()
    }

    # Check if already registered
    $existing = @($settings.hooks.UserPromptSubmit) | Where-Object { $_.command -like '*claude-cron-autostart*' }

    if (-not $existing) {
        $entry = [PSCustomObject]@{ type = 'command'; command = $hookCmd }
        $settings.hooks.UserPromptSubmit = @(@($settings.hooks.UserPromptSubmit) + $entry)
        $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
        Write-Ok "Hook zarejestrowany w settings.json"
    } else {
        Write-Ok "Hook juz zarejestrowany w settings.json"
    }

    $HookInstalled = $true
} else {
    Write-Info "Pominieto autostart"
}

# ============ STEP 4: DISCORD ============

Write-Host ""
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host "  KROK 4/4 — Powiadomienia Discord" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Opcjonalne — po zakonczeniu joba dostaniesz wynik na Discorda." -ForegroundColor DarkGray
Write-Host "  Puste = pomin" -ForegroundColor DarkGray
Write-Host ""

$DiscordUrl = Read-Host "  Discord webhook URL"

if ($DiscordUrl) {
    $DiscordUrl = $DiscordUrl.Trim()
    [Environment]::SetEnvironmentVariable('DISCORD_WEBHOOK_URL', $DiscordUrl, 'User')
    $env:DISCORD_WEBHOOK_URL = $DiscordUrl
    Write-Ok "Discord webhook zapisany"
} else {
    Write-Info "Pominieto Discord"
}

# ============ DONE ============

Write-Host ""
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host "  Gotowe!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Repo:       " -NoNewline; Write-Host $RepoDir -ForegroundColor Cyan
Write-Host "  Workspace:  " -NoNewline; Write-Host $Workspace -ForegroundColor Cyan
Write-Host "  Dashboard:  " -NoNewline; Write-Host "http://localhost:7777" -ForegroundColor Cyan
if ($VpsUrl) {
    Write-Host "  VPS:        " -NoNewline; Write-Host $VpsUrl -ForegroundColor Cyan
}
Write-Host ""
Write-Host "  Nastepne kroki:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Otwórz nowy terminal (zmienne zaczna dzialac)"
Write-Host ""
Write-Host "  2. Uruchom serwer:"
Write-Host "     cd $RepoDir; node server.js" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. Otworz dashboard:"
Write-Host "     http://localhost:7777" -ForegroundColor Cyan
Write-Host ""
if ($HookInstalled) {
    Write-Host "  Przy kolejnych sesjach Claude Code serwer startuje automatycznie." -ForegroundColor DarkGray
    Write-Host ""
}
