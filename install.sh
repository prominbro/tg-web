#!/usr/bin/env bash
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[0;33m' B='\033[0;34m'
C='\033[0;36m' M='\033[0;35m' W='\033[1;37m' D='\033[0m'
ok()   { echo -e "${G}[✓]${D} $*"; }
fail() { echo -e "${R}[✗]${D} $*"; exit 1; }
info() { echo -e "${C}[i]${D} $*"; }
ask()  { echo -e "${W}$1${D}"; }

# ─── Repo URL (change to your fork) ─────────────────────────────────────
REPO_URL="${TPROXY_REPO:-https://github.com/prominbro/tg-web}"

# ─── Detect source ──────────────────────────────────────────────────────
# If sites/ directory exists next to this script — we're in a cloned repo.
# Otherwise download the repo as a tarball.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/sites/_shared" ]]; then
  DEPLOY_DIR="$SCRIPT_DIR"
else
  info "Скачиваю tproxy-deploy..."
  TEMP_DIR="$(mktemp -d /tmp/tproxy-deploy.XXXXXX)"
  trap 'rm -rf "$TEMP_DIR"' EXIT
  curl -sL "${REPO_URL}/archive/refs/heads/main.tar.gz" | tar -xz -C "$TEMP_DIR" --strip-components=1
  DEPLOY_DIR="$TEMP_DIR"
  ok "Репозиторий скачан"
fi

# ─── Root check ──────────────────────────────────────────────────────────
[[ "${EUID}" -ne 0 ]] && fail "Запусти от root: sudo bash install.sh"

# ─── Banner ──────────────────────────────────────────────────────────────
echo -e "
${B}╔══════════════════════════════════════════════════════════╗
║${W}     tproxy-deploy — автоинсталлятор WEB-прокси для     ${B}║
║${W}          Telegram с красивыми сайтами                   ${B}║
╚══════════════════════════════════════════════════════════╝${D}
"

# ─── Site selection ──────────────────────────────────────────────────────
ask "Выберите сайт для деплоя:"
echo -e "  ${C}1${D}) История ВКонтакте"
echo -e "  ${C}2${D}) История Telegram"
echo -e "  ${C}3${D}) История Instagram"
echo -e "  ${C}4${D}) История YouTube"
echo -e "  ${C}5${D}) История Одноклассников"
echo -e "  ${C}6${D}) О кошках"
echo -e "  ${C}7${D}) О собаках"
echo -e "  ${C}8${D}) О белых песцах"
echo -e "  ${C}9${D}) О музыке"
echo -e "  ${C}10${D}) О программировании"
echo ""
read -rp "Номер [1-10]: " SITE_NUM
SITE_NUM="${SITE_NUM:-1}"

declare -A SITES=(
  [1]="vk"
  [2]="telegram"
  [3]="instagram"
  [4]="youtube"
  [5]="odnoklassniki"
  [6]="cats"
  [7]="dogs"
  [8]="foxes"
  [9]="music"
  [10]="coding"
)
SITE_KEY="${SITES[$SITE_NUM]:-vk}"

# ─── Domain & email ─────────────────────────────────────────────────────
read -rp "Домен (например proxy.example.com): " DOMAIN
[[ -z "$DOMAIN" ]] && fail "Домен не может быть пустым"
read -rp "Email для сертификата: " EMAIL
[[ -z "$EMAIL" ]] && fail "Email не может быть пустым"

# ─── Transport mode ─────────────────────────────────────────────────────
ask "Режим транспорта:"
echo -e "  ${C}1${D}) https        — самый незаметный (по умолчанию)"
echo -e "  ${C}2${D}) https-lanes  — изолированные потоки по HTTP"
echo -e "  ${C}3${D}) websocket    — быстрый, один WS на все потоки"
echo -e "  ${C}4${D}) ws-lanes     — максимальная производительность"
echo ""
read -rp "Режим [1-4]: " MODE_NUM
MODE_NUM="${MODE_NUM:-1}"

declare -A MODES=(
  [1]="https"
  [2]="https-lanes"
  [3]="websocket"
  [4]="websocket-lanes"
)
CARRIER="${MODES[$MODE_NUM]:-https}"

# ─── Confirm ────────────────────────────────────────────────────────────
echo ""
echo -e "${W}═══ Конфигурация ═══${D}"
echo -e "  Сайт:       ${C}${SITE_KEY}${D}"
echo -e "  Домен:      ${C}${DOMAIN}${D}"
echo -e "  Email:      ${C}${EMAIL}${D}"
echo -e "  Транспорт:  ${C}${CARRIER}${D}"
echo ""
read -rp "Продолжить? [Y/n]: " CONFIRM
[[ "${CONFIRM,,}" == "n" ]] && exit 0

# ─── Install dependencies ───────────────────────────────────────────────
info "Устанавливаю зависимости..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  curl git build-essential libssl-dev zlib1g-dev \
  ca-certificates nftables certbot python3-certbot-nginx >/dev/null 2>&1
ok "Зависимости установлены"

# ─── Go check ───────────────────────────────────────────────────────────
if ! command -v go &>/dev/null; then
  info "Устанавливаю Go..."
  GO_VER="1.23.1"
  curl -sL "https://go.dev/dl/go${GO_VER}.linux-amd64.tar.gz" | tar -C /usr/local -xzf -
  echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile.d/go.sh
  export PATH=$PATH:/usr/local/go/bin
  ok "Go ${GO_VER} установлен"
else
  ok "Go уже стоит: $(go version)"
fi

# ─── Clone repo ─────────────────────────────────────────────────────────
WORKDIR="/root/tproxy-work"
mkdir -p "$WORKDIR"
if [[ -d "$WORKDIR/tproxy-server/.git" ]]; then
  info "Репозиторий уже есть, обновляю..."
  git -C "$WORKDIR/tproxy-server" pull --quiet 2>/dev/null || true
else
  info "Клонирую tproxy-server..."
  git clone --depth 1 https://github.com/telegramdesktop/tproxy-server.git "$WORKDIR/tproxy-server" --quiet
fi
ok "Репозиторий готов"

# ─── Build relay ────────────────────────────────────────────────────────
info "Собираю tproxy-server (это займёт 1-3 минуты)..."
cd "$WORKDIR/tproxy-server"
echo -ne "${C}  → тесты...${D}"
go test ./... 2>/dev/null && echo -e " ${G}✓${D}" || echo -e " ${Y}⚠${D}"
echo -ne "${C}  → сборка бинарника...${D}"
go build -trimpath -o tproxy-server ./cmd/tproxy-server && echo -e " ${G}✓${D}" || fail "Ошибка сборки"
install -m 0755 tproxy-server /usr/local/bin/tproxy-server
ok "Релей собран и установлен"

# ─── Build MTProxy ──────────────────────────────────────────────────────
info "Собираю официальный MTProxy (это займёт 2-5 минут)..."
cd "$WORKDIR/tproxy-server"
echo -ne "${C}  → компиляция...${D}"
bash deploy/install-mtproxy.sh 2>&1 | tail -1 && echo -e " ${G}✓${D}" || fail "Ошибка сборки MTProxy"
ok "MTProxy собран"

# ─── Generate secrets ───────────────────────────────────────────────────
info "Генерирую секреты..."
SECRET=$(openssl rand -hex 16)
ok "Секрет сгенерирован"

# ─── Create tproxy user ────────────────────────────────────────────────
id tproxy &>/dev/null || useradd --system --home /nonexistent --shell /usr/sbin/nologin tproxy

# ─── Install configs ───────────────────────────────────────────────────
info "Создаю конфиги..."
mkdir -p /etc/tproxy-server

cat > /etc/tproxy-server/config.json <<CONF
{
  "public_hostname": "${DOMAIN}",
  "listen": "127.0.0.1:8080",
  "admin_listen": "127.0.0.1:8081",
  "public_dir": "/srv/tproxy-site",
  "profiles_file": "/run/credentials/tproxy-server.service/profiles.json",
  "enable_pprof": false,
  "limits": {
    "max_header_bytes": 16384,
    "max_body_bytes": 2097152,
    "max_frame_payload": 1048576,
    "carrier_batch_bytes": 2097152,
    "max_streams_per_session": 128,
    "max_closed_stream_ids": 4096,
    "max_pending_per_session": 33554432,
    "max_pending_global": 536870912,
    "max_pending_items_per_session": 16384,
    "max_pending_items_global": 262144,
    "max_sessions_per_ip": 0,
    "max_sessions_global": 128,
    "max_streams_global": 4096,
    "max_backend_dials_in_flight": 256,
    "new_sessions_per_minute": 600,
    "new_sessions_burst": 128,
    "new_streams_per_minute": 6000,
    "new_streams_burst": 512,
    "max_bootstraps_per_ip": 0,
    "max_bootstraps_global": 512,
    "new_bootstraps_per_minute": 1200,
    "new_bootstraps_burst": 256,
    "max_profiles": 32
  },
  "timeouts": {
    "backend_dial": "5s",
    "long_poll": "25s",
    "reconnect_grace": "2m",
    "bootstrap_lifetime": "2m",
    "read_header": "10s",
    "idle": "75s",
    "shutdown": "15s"
  }
}
CONF

cat > /etc/tproxy-server/profiles.json <<PROF
{
  "profiles": [
    {
      "name": "default",
      "secret": "${SECRET}",
      "backend": "127.0.0.1:9067",
      "carrier_mode": "${CARRIER}"
    }
  ]
}
PROF

cat > /etc/tproxy-server/firewall.nft <<FIRE
table inet tproxy_backend {
  chain local_backend {
    type filter hook input priority -10; policy accept;
    iifname != "lo" tcp dport { 9067, 8888 } drop
  }
}
FIRE

chown root:tproxy /etc/tproxy-server/config.json
chmod 0440 /etc/tproxy-server/config.json
chown root:root /etc/tproxy-server/profiles.json
chmod 0400 /etc/tproxy-server/profiles.json
ok "Конфиги созданы"

# ─── MTProxy config ─────────────────────────────────────────────────────
cat > /etc/mtproxy/mtproxy.env <<MTEOF
MTPROXY_WORKERS=1
MTPROXY_MAX_CONNECTIONS=4096
MTEOF
chown root:mtproxy /etc/mtproxy/mtproxy.env
chmod 0640 /etc/mtproxy/mtproxy.env

# ─── Systemd units ──────────────────────────────────────────────────────
info "Устанавливаю systemd юниты..."

sed "s/-H 2398/-H 9067/" "$WORKDIR/tproxy-server/deploy/mtproxy.service" \
  > /etc/systemd/system/mtproxy.service

cat > /etc/systemd/system/tproxy-server.service <<TSVC
[Unit]
Description=Browser HTTPS transport relay
After=network-online.target mtproxy.service tproxy-firewall.service
Wants=network-online.target mtproxy.service
Requires=tproxy-firewall.service

[Service]
Type=simple
User=tproxy
Group=tproxy
LoadCredential=profiles.json:/etc/tproxy-server/profiles.json
ExecStart=/usr/local/bin/tproxy-server -config /etc/tproxy-server/config.json
Restart=on-failure
RestartSec=3s
TimeoutStopSec=20s
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateDevices=true
PrivateTmp=true
ProtectClock=true
ProtectControlGroups=true
ProtectHome=true
ProtectHostname=true
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectProc=invisible
ProtectSystem=strict
ProcSubset=pid
ReadOnlyPaths=-/srv/tproxy-site
RestrictAddressFamilies=AF_INET AF_INET6
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true
CapabilityBoundingSet=
IPAddressDeny=any
IPAddressAllow=localhost
SystemCallArchitectures=native
SystemCallFilter=@system-service
UMask=0077

[Install]
WantedBy=multi-user.target
TSVC

install -m 0644 "$WORKDIR/tproxy-server/deploy/tproxy-firewall.service" /etc/systemd/system/
install -m 0644 "$WORKDIR/tproxy-server/deploy/refresh-mtproxy-config.service" /etc/systemd/system/
install -m 0644 "$WORKDIR/tproxy-server/deploy/refresh-mtproxy-config.timer" /etc/systemd/system/
install -m 0755 "$WORKDIR/tproxy-server/deploy/refresh-mtproxy-config.sh" /usr/local/sbin/refresh-mtproxy-config
ok "Systemd юниты установлены"

# ─── Deploy site ────────────────────────────────────────────────────────
info "Деплою сайт: ${SITE_KEY}..."
SITE_SRC="${DEPLOY_DIR}/sites/${SITE_KEY}"
SITE_SHARED="${DEPLOY_DIR}/sites/_shared"

if [[ ! -d "$SITE_SRC" ]]; then
  fail "Директория сайта не найдена: ${SITE_SRC}"
fi

mkdir -p /srv/tproxy-site
cp -r "$SITE_SHARED"/. /srv/tproxy-site/
cp -r "$SITE_SRC"/. /srv/tproxy-site/
chmod -R a+rX /srv/tproxy-site
ok "Сайт скопирован в /srv/tproxy-site"

# ─── Start services ─────────────────────────────────────────────────────
info "Запускаю сервисы..."
systemctl daemon-reload
systemctl enable --now tproxy-firewall.service mtproxy.service tproxy-server.service refresh-mtproxy-config.timer 2>/dev/null
sleep 5

if systemctl is-active --quiet tproxy-server; then
  ok "Сервисы запущены"
else
  warn "Проверю логи..."
  journalctl -u tproxy-server -n 5 --no-pager
  fail "Ошибка запуска. Проверь: journalctl -u tproxy-server -n 20"
fi

# ─── Nginx vhost ────────────────────────────────────────────────────────
info "Настраиваю nginx..."
VHOST_CONF="/etc/nginx/conf.d/${DOMAIN}.conf"

cat > "$VHOST_CONF" <<NGINX
map \$http_upgrade \$tproxy_connection_upgrade {
    default upgrade;
    ""      close;
}

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    access_log off;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$tproxy_connection_upgrade;
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 75s;
        client_max_body_size 4m;
    }
}
NGINX

if nginx -t 2>/dev/null; then
  systemctl reload nginx
  ok "Nginx настроен"
else
  fail "Ошибка конфигурации nginx"
fi

# ─── SSL cert ───────────────────────────────────────────────────────────
info "Получаю SSL-сертификат..."
if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --redirect -m "$EMAIL" 2>/dev/null; then
  ok "Сертификат получен и установлен"
else
  echo -e "${Y}[!]${D} Certbot не смог получить сертификат. Возможные причины:"
  echo -e "    - DNS A-запись ${DOMAIN} не указывает на этот сервер"
  echo -e "    - Порты 80/443 заняты другим сервисом"
  echo -e "    Попробуй вручную: certbot --nginx -d ${DOMAIN}"
fi

# ─── Verify ─────────────────────────────────────────────────────────────
echo ""
echo -e "${W}══════════════════════════════════════════════════════════${D}"
echo -e "${G}  Установка завершена!${D}"
echo -e "${W}══════════════════════════════════════════════════════════${D}"
echo ""
echo -e "  Сайт:        ${C}https://${DOMAIN}${D}"
echo -e "  Секрет:      ${C}${SECRET}${D}"
echo -e "  Транспорт:   ${C}${CARRIER}${D}"
echo ""
echo -e "  ${W}Ссылка для клиента:${D}"
echo -e "  ${G}https://t.me/webproxy?server=${DOMAIN}&secret=${SECRET}${D}"
echo ""
echo -e "  ${W}Метрики:${D}"
echo -e "  curl http://127.0.0.1:8081/metrics | grep bytes"
echo ""
echo -e "  ${W}Логи:${D}"
echo -e "  journalctl -u tproxy-server -f"
echo ""
echo -e "  ${W}Обновить сайт:${D}"
echo -e "  cp -r ~/tproxy-deploy/sites/${SITE_KEY}/. /srv/tproxy-site/"
echo -e "  systemctl restart tproxy-server"
echo ""
