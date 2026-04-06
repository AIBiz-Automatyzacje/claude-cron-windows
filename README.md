# Claude-Cron (Windows)

Automatyczny scheduler dla [Claude Code](https://claude.ai/code) na Windows. Ustawiasz co i kiedy ma sie odpalic — Claude robi reszte. Dashboard w stylu retro arcade do zarzadzania wszystkim.

## Co to robi?

- **Harmonogram** — Claude odpala Twoje skille/prompty o wybranej godzinie (codziennie, co X godzin, w wybrane dni)
- **Webhoki** — zewnetrzne serwisy (Make, n8n, Zapier) moga triggerowac joby przez link
- **Dashboard** — przegladarka, `localhost:7777`, zarzadzasz jobami, widzisz historie, przegladasz skille
- **VPS 24/7** — joby leca non-stop na serwerze, nawet gdy spisz
- **Powiadomienia Discord** — wynik joba laduje na Twojego Discorda

---

## Czego potrzebujesz?

1. **Node.js 18+** — [pobierz tutaj](https://nodejs.org)
2. **Visual Studio Build Tools** — wymagane przez `better-sqlite3` ([pobierz tutaj](https://visualstudio.microsoft.com/visual-cpp-build-tools/) — zaznacz "Desktop development with C++")
3. **Claude Code** zainstalowany i zalogowany — w terminalu: `npm install -g @anthropic-ai/claude-code`, potem `claude` zeby sie zalogowac
4. **Tailscale** (opcjonalnie) — jesli chcesz polaczyc sie z VPS-em ([pobierz tutaj](https://tailscale.com/download))
5. **Serwer VPS** z Linuxem (opcjonalnie) — jesli chcesz joby 24/7

---

## Instalacja na Windows — krok po kroku

### Opcja A: Tylko lokalnie (bez VPS-a)

Joby dzialaja tylko gdy komputer nie spi. Najprostrza opcja na start.

#### Krok 1 — Pobierz repo

Otworz PowerShell, przejdz do folderu gdzie chcesz trzymac projekt i wklej:

```powershell
git clone https://github.com/AIBiz-Automatyzacje/claude-cron-windows.git
cd claude-cron-windows
```

#### Krok 2 — Uruchom setup

```powershell
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

Setup pyta o 4 rzeczy:

| Krok | Co wpisac |
|------|-----------|
| **1. Tailscale IP VPS-a** | Zostaw puste — Enter (tryb lokalny) |
| **2. Workspace** | Sciezka do folderu roboczego, np. Twoj vault Obsidian. Domyslnie: folder uzytkownika |
| **3. Autostart** | `Y` — serwer startuje automatycznie z Claude Code |
| **4. Discord** | URL webhooka albo puste — Enter |

#### Krok 3 — Otworz nowy terminal

Zmienne srodowiskowe zaczna dzialac dopiero po otworzeniu nowego terminala.

#### Krok 4 — Uruchom serwer

```powershell
cd $env:USERPROFILE\claude-cron-windows
node server.js
```

> Jesli zainstalowales autostart — przy kolejnych sesjach Claude Code serwer startuje automatycznie. Nie musisz tego robic recznie.

#### Krok 5 — Sprawdz czy dziala

Otworz przegladarke: [http://localhost:7777](http://localhost:7777)

---

### Opcja B: Windows + VPS (pelna wersja)

Windows sluzy jako dashboard, a VPS wykonuje joby 24/7.

#### Krok 1 — Zainstaluj na VPS-ie

Polacz sie z VPS-em przez SSH:

```bash
ssh root@TWOJE_IP_SERWERA
```

Zainstaluj wymagane narzedzia i uruchom installer:

```bash
apt update && apt install -y git curl
git clone https://github.com/AIBiz-Automatyzacje/claude-cron.git /tmp/claude-cron-install
sudo bash /tmp/claude-cron-install/scripts/install-vps.sh
```

Installer pyta o:

| Pytanie | Co wpisac |
|---------|-----------|
| **Log in to Claude CLI** | `Y` — zaloguj sie w przegladarce, potem `/exit` i `exit` |
| **Sciezka do workspace** | Np. `/home/claude/vault` |
| **Port** | Enter (domyslny 7777) |
| **Discord webhook** | URL webhooka albo puste — Enter |
| **Timezone** | Enter (domyslnie Europe/Warsaw) |
| **Tailscale Funnel** | `Y` jesli chcesz webhoki |

Na koncu installer pokaze **Tailscale IP** — zapisz je! Jesli nie widzisz:

```bash
tailscale ip -4
```

#### Krok 2 — Zainstaluj na Windows

Otworz PowerShell:

```powershell
git clone https://github.com/AIBiz-Automatyzacje/claude-cron-windows.git $env:USERPROFILE\claude-cron-windows
cd $env:USERPROFILE\claude-cron-windows
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

Tym razem w kroku 1 wklej **Tailscale IP** z VPS-a.

#### Krok 3 — Sprawdz polaczenie

Otworz [http://localhost:7777](http://localhost:7777) i kliknij **VPS** na gorze dashboardu. Jesli widzisz dane z serwera — dziala.

---

## Jak korzystac z dashboardu

Dashboard ma 3 zakladki:

### JOBS — Twoje zadania

Kliknij **+ NEW JOB** i ustaw:

- **Nazwa** — jak chcesz nazwac joba
- **Skill** — wybierz z listy (Project, User, Plugin)
- **Harmonogram** — codziennie, dni robocze, co X godzin, itp.
- **Prompt** — dodatkowe instrukcje dla Claude'a (opcjonalne)
- **Discord** — zaznacz jesli chcesz powiadomienie

Kazdy job ma przyciski: (uruchom teraz), (wlacz/wylacz), (edytuj), (usun).

### HISTORY — Historia uruchomien

Kliknij dowolny wpis zeby zobaczyc co Claude zrobil — pelny output z narzedziami, czasem i kosztem.

### SKILLS — Dostepne skille

Przegladaj wszystkie skille z filtrami: Project, User, Plugin.

---

## Webhoki — triggerowanie z zewnatrz

1. W dashboardzie edytuj joba
2. Na dole znajdz sekcje **WEBHOOK**
3. Kliknij **GENERATE WEBHOOK URL**
4. Skopiuj URL i wklej go w zewnetrznym serwisie (Make, n8n, Zapier)

### Wysylanie danych do joba

Webhook akceptuje **POST z JSON body**. Cala zawartosc body trafia do Claude jako `webhook_payload` i mozesz sie do niej odwolac w prompcie joba.

Przyklad — wyslanie hasla i tekstu:

```bash
curl -X POST "https://twoj-funnel.ts.net/webhook/<token>" \
  -H "Content-Type: application/json" \
  -d '{"haslo":"widzew","tekst":"Witaj swiecie"}'
```

Odpowiedz serwera:
```json
{"ok":true,"run_id":3,"job_name":"Test"}
```

W Make / n8n / Zapier ustaw:
- **Method**: POST
- **Headers**: `Content-Type: application/json`
- **Body**: JSON z dowolnymi polami

> Uwaga: query string (`?haslo=widzew`) **nie jest obslugiwany** — uzyj body.

### Wymagania

Webhoki dzialaja tylko jesli na VPS-ie wlaczyles **Tailscale Funnel**. Jesli nie, mozesz wlaczyc pozniej:

```bash
sudo tailscale funnel --bg 7777
```

---

## Przydatne komendy

### Na Windows

| Co chcesz zrobic | Komenda |
|------------------|---------|
| Uruchomic recznie | `cd $env:USERPROFILE\claude-cron-windows; node server.js` |
| Otworzyc dashboard | [http://localhost:7777](http://localhost:7777) w przegladarce |
| Sprawdzic co zajmuje port | `netstat -ano \| findstr :7777` |
| Uruchomic na innym porcie | `$env:CLAUDE_CRON_PORT=7778; node server.js` |

### Na VPS-ie (przez SSH)

| Co chcesz zrobic | Komenda |
|------------------|---------|
| Sprawdzic czy dziala | `systemctl status claude-cron` |
| Zobaczyc logi na zywo | `journalctl -u claude-cron -f` |
| Zrestartowac serwis | `systemctl restart claude-cron` |
| Zaktualizowac kod | `su - claude -c 'cd ~/claude-cron && git pull'` + `systemctl restart claude-cron` |
| Sprawdzic Tailscale IP | `tailscale ip -4` |

---

## Rozwiazywanie problemow

### npm install nie dziala (node-gyp / MSBuild error)

Potrzebujesz Visual Studio Build Tools:

1. Pobierz: https://visualstudio.microsoft.com/visual-cpp-build-tools/
2. Zaznacz **Desktop development with C++**
3. Zainstaluj i uruchom `npm install` ponownie

Alternatywnie:
```powershell
npm install --global windows-build-tools
```

### Dashboard nie wczytuje danych z VPS-a

Sprawdz czy Tailscale dziala na obu urzadzeniach. Na Windows otworz Tailscale i sprawdz czy VPS jest widoczny.

### Joby sie nie odpalaja na VPS-ie

Sprawdz logi:
```bash
journalctl -u claude-cron -n 30
```

Najczestsza przyczyna: Claude CLI nie jest zalogowany:
```bash
su - claude
claude
# przejdz logowanie w przegladarce
exit
sudo systemctl restart claude-cron
```

### Joby odpalaja sie o zlej godzinie (VPS)

```bash
timedatectl
timedatectl set-timezone Europe/Warsaw
sudo systemctl restart claude-cron
```

### Port 7777 jest zajety

```powershell
netstat -ano | findstr :7777
```

Uruchom na innym porcie:
```powershell
$env:CLAUDE_CRON_PORT = 7778
node server.js
```

---

## Odinstalowanie

### Usun autostart hook z Claude Code

Otworz plik `~/.claude/settings.json` i usun wpis `claude-cron-autostart` z sekcji `hooks.UserPromptSubmit`.

### Usun zmienne srodowiskowe

```powershell
[Environment]::SetEnvironmentVariable('CLAUDE_CRON_WORKSPACE', $null, 'User')
[Environment]::SetEnvironmentVariable('CLAUDE_CRON_VPS_URL', $null, 'User')
[Environment]::SetEnvironmentVariable('DISCORD_WEBHOOK_URL', $null, 'User')
```

### Usun pliki

```powershell
Remove-Item -Recurse -Force $env:USERPROFILE\claude-cron-windows
```

Dane (historia jobow, baza SQLite) sa w folderze `data/` wewnatrz repo — usuwane razem z nim.
