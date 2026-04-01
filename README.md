# 🕹️ Claude-Cron

Automatyczny scheduler dla [Claude Code](https://claude.ai/code). Ustawiasz co i kiedy ma się odpalić — Claude robi resztę. Dashboard w stylu retro arcade do zarządzania wszystkim.

## Co to robi?

- **Harmonogram** — Claude odpala Twoje skille/prompty o wybranej godzinie (codziennie, co X godzin, w wybrane dni)
- **Webhoki** — zewnętrzne serwisy (Make, n8n, Zapier) mogą triggerować joby przez link
- **Dashboard** — przeglądarka, `localhost:7777`, zarządzasz jobami, widzisz historię, przeglądasz skille
- **VPS 24/7** — joby lecą non-stop na serwerze, nawet gdy śpisz
- **Powiadomienia Discord** — wynik joba ląduje na Twojego Discorda

---

## Czego potrzebujesz?

Zanim zaczniesz, upewnij się że masz:

1. **Serwer VPS** z Linuxem (np. Hostinger, DigitalOcean) — tu będą lecieć joby 24/7
2. **Tailscale** zainstalowany na VPS i na Macu — to prywatna sieć łącząca Twoje urządzenia ([pobierz tutaj](https://tailscale.com/download))
3. **Node.js 18+** na Macu — [pobierz tutaj](https://nodejs.org)
4. **Claude Code** zainstalowany i zalogowany — w terminalu: `npm install -g @anthropic-ai/claude-code`, potem `claude` żeby się zalogować

---

## Instalacja — krok po kroku

> Najpierw instalujesz na VPS (serwer), potem na Macu (dashboard).
>
> *Nie masz VPS-a?* Przejdź do [Instalacja bez VPS-a](#instalacja-bez-vps-a).

### Zanim zaczniesz

Claude-cron potrzebuje **folderu roboczego** na VPS-ie — to miejsce, w którym Claude będzie wykonywał zadania. Zazwyczaj to Twój vault Obsidian.

Jeśli masz już vault na VPS-ie, sprawdź jak się nazywa folder:
```bash
ls /home/claude/
```
Zapisz tę ścieżkę — przyda się za chwilę.

Jeśli nie masz jeszcze folderu — installer go utworzy.

---

### Krok 1 — Instalacja na VPS

Otwórz terminal i połącz się z VPS-em:

```bash
ssh root@TWOJE_IP_SERWERA
```

> **Gdzie znaleźć IP serwera?** W panelu hostingu (np. Hostinger → VPS → IPv4).

Najpierw zainstaluj wymagane narzędzia (na świeżym VPS-ie nie ma ich domyślnie):

```bash
apt update && apt install -y git curl
```

Potem wklej te dwie komendy:

```bash
git clone https://github.com/AIBiz-Automatyzacje/claude-cron.git /tmp/claude-cron-install
sudo bash /tmp/claude-cron-install/scripts/install-vps.sh
```

Installer zrobi wszystko automatycznie. Po drodze zapyta Cię o kilka rzeczy:

| Pytanie | Co wpisać |
|---------|-----------|
| **Log in to Claude CLI** | Wpisz `Y`, przejdź logowanie w przeglądarce, potem `exit` |
| **Ścieżka do workspace** | Ścieżka do Twojego folderu roboczego, np. `/home/claude/vault` |
| **Port** | Zostaw domyślny — Enter |
| **Discord webhook** | URL webhooka z Discorda, albo puste — Enter |
| **Timezone** | Zostaw domyślny (Europe/Warsaw) — Enter |
| **Tailscale Funnel** | `Y` jeśli chcesz webhoki, `N` jeśli nie wiesz co to |

**Na końcu installer pokaże Tailscale IP** — zapisz je! Potrzebujesz go w kroku 2.

Jeśli nie widzisz IP, wpisz na VPS-ie:
```bash
tailscale ip -4
```

Przykład: `100.86.100.113`

---

### Krok 2 — Instalacja na Macu

Otwórz terminal na swoim Macu i wklej:

```bash
git clone https://github.com/AIBiz-Automatyzacje/claude-cron.git ~/claude-cron
cd ~/claude-cron
bash setup.sh
```

Setup pyta o 4 rzeczy po kolei:

| Krok | Co wpisać |
|------|-----------|
| **1. Tailscale IP VPS-a** | Wklej IP z kroku 1, np. `100.86.100.113` |
| **2. Workspace** | Przeciągnij folder z Findera do terminala i naciśnij Enter |
| **3. Autostart** | `Y` — serwer startuje automatycznie z Claude Code |
| **4. Discord** | URL webhooka albo puste — Enter |

Po zakończeniu wklej to w terminalu:

```bash
source ~/.zshrc
```

---

### Krok 3 — Sprawdź czy działa

Otwórz przeglądarkę i wejdź na:

```
http://localhost:7777
```

Powinieneś zobaczyć dashboard z przełącznikiem **LOCAL / VPS** na górze:

- **LOCAL** (zielony) — joby lecą na Twoim Macu
- **VPS** (magenta) — joby lecą na serwerze 24/7

Kliknij **VPS** i sprawdź czy się łączy. Jeśli widzisz dane z serwera — wszystko działa! 🎉

---

## Instalacja bez VPS-a

Jeśli nie masz serwera i chcesz używać tylko lokalnie:

```bash
git clone https://github.com/AIBiz-Automatyzacje/claude-cron.git ~/claude-cron
cd ~/claude-cron
bash setup.sh
```

W kroku 1 (Tailscale IP) zostaw puste i naciśnij Enter. Reszta tak samo.

**Uwaga:** bez VPS-a joby działają tylko kiedy Mac nie śpi. Jak zamkniesz klapę — joby się nie odpalą.

---

## Jak korzystać z dashboardu

Dashboard ma 3 zakładki:

### JOBS — Twoje zadania

Tu tworzysz i zarządzasz jobami. Kliknij **+ NEW JOB** i ustaw:

- **Nazwa** — jak chcesz nazwać joba
- **Skill** — wybierz z listy (pogrupowane: Project, User, Plugin)
- **Harmonogram** — codziennie, dni robocze, co X godzin, itp.
- **Prompt** — dodatkowe instrukcje dla Claude'a (opcjonalne)
- **Discord** — zaznacz jeśli chcesz powiadomienie na Discorda

Każdy job ma przyciski: ▶ (uruchom teraz), ⏻ (włącz/wyłącz), ✎ (edytuj), ✕ (usuń).

### HISTORY — Historia uruchomień

Kliknij dowolny wpis żeby zobaczyć co Claude zrobił — pełny output z narzędziami, czasem i kosztem.

### SKILLS — Dostępne skille

Przeglądaj wszystkie skille z filtrami:
- **📁 Project** — skille z Twojego workspace'u
- **👤 User** — Twoje globalne skille
- **🔌 Plugin** — skille z zainstalowanych pluginów

---

## Webhoki — triggerowanie z zewnątrz

Chcesz żeby Make, n8n albo inny serwis odpalał joba? Potrzebujesz webhooka.

### Jak to ustawić

1. W dashboardzie edytuj joba (✎)
2. Na dole znajdź sekcję **WEBHOOK**
3. Kliknij **🔗 GENERATE WEBHOOK URL**
4. Skopiuj URL (📋) i wklej go w zewnętrznym serwisie

Zewnętrzny serwis wysyła POST na ten URL → claude-cron odpala joba → Claude wykonuje zadanie.

### Ważne

Webhoki działają tylko jeśli podczas instalacji VPS-a włączyłeś **Tailscale Funnel** (`Y` na pytanie o Funnel). Jeśli wtedy wybrałeś `N`, możesz włączyć go później na VPS-ie:

```bash
sudo tailscale funnel --bg 7777
```

---

## Przydatne komendy

### Na VPS-ie (przez SSH)

| Co chcesz zrobić | Komenda |
|------------------|---------|
| Sprawdzić czy działa | `systemctl status claude-cron` |
| Zobaczyć logi na żywo | `journalctl -u claude-cron -f` |
| Zrestartować serwis | `systemctl restart claude-cron` |
| Zaktualizować kod | `su - claude -c 'cd ~/claude-cron && git pull'` a potem `systemctl restart claude-cron` |
| Sprawdzić Tailscale IP | `tailscale ip -4` |

### Na Macu

| Co chcesz zrobić | Komenda |
|------------------|---------|
| Uruchomić ręcznie | `cd ~/claude-cron && node server.js` |
| Otworzyć dashboard | `http://localhost:7777` w przeglądarce |

> Jeśli zainstalowałeś autostart — serwer startuje sam przy każdym uruchomieniu Claude Code. Nie musisz nic robić.

---

## Rozwiązywanie problemów

### Dashboard nie wczytuje danych z VPS-a

Sprawdź czy Tailscale działa na obu urządzeniach. Na Macu:
```bash
tailscale status
```
Powinieneś widzieć swój VPS na liście.

### Joby się nie odpalają na VPS-ie

Sprawdź logi:
```bash
journalctl -u claude-cron -n 30
```

Najczęstsza przyczyna: Claude CLI nie jest zalogowany. Napraw tak:
```bash
su - claude
claude
# przejdź logowanie w przeglądarce
exit
sudo systemctl restart claude-cron
```

### Joby odpalają się o złej godzinie

Serwer może mieć inną strefę czasową. Sprawdź i popraw:
```bash
timedatectl
timedatectl set-timezone Europe/Warsaw
sudo systemctl restart claude-cron
```

### Serwer na Macu nie startuje (port zajęty)

Znaczy że coś już działa na porcie 7777. Sprawdź co:
```bash
lsof -i :7777
```

Możesz uruchomić na innym porcie:
```bash
CLAUDE_CRON_PORT=7778 node server.js
```
