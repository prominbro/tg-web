#!/usr/bin/env bash
set -euo pipefail

R='\033[0;31m' G='\033[0;32m' Y='\033[0;33m' C='\033[0;36m' W='\033[1;37m' D='\033[0m'
ok()   { echo -e "${G}[✓]${D} $*"; }
info() { echo -e "${C}[i]${D} $*"; }
warn() { echo -e "${Y}[!]${D} $*"; }

[[ "${EUID}" -ne 0 ]] && { echo -e "${R}Запусти от root${D}"; exit 1; }

echo -e "
${W}╔══════════════════════════════════════════════════════════╗
║${W}     tproxy-deploy — удаление всех компонентов           ${W}║
╚══════════════════════════════════════════════════════════╝${D}
"

read -rp "Точно удалить всё? [y/N]: " CONFIRM
[[ "${CONFIRM,,}" != "y" ]] && { echo "Отмена."; exit 0; }

# ─── Stop services ──────────────────────────────────────────────────────
info "Останавливаю сервисы..."
systemctl stop tproxy-server.service mtproxy.service tproxy-firewall.service refresh-mtproxy-config.timer 2>/dev/null || true
systemctl disable tproxy-server.service mtproxy.service tproxy-firewall.service refresh-mtproxy-config.timer 2>/dev/null || true
ok "Сервисы остановлены"

# ─── Remove systemd units ──────────────────────────────────────────────
info "Удаляю systemd юниты..."
rm -f /etc/systemd/system/tproxy-server.service
rm -f /etc/systemd/system/mtproxy.service
rm -f /etc/systemd/system/tproxy-firewall.service
rm -f /etc/systemd/system/refresh-mtproxy-config.service
rm -f /etc/systemd/system/refresh-mtproxy-config.timer
systemctl daemon-reload
ok "Systemd юниты удалены"

# ─── Remove configs ────────────────────────────────────────────────────
info "Удаляю конфиги..."
rm -rf /etc/tproxy-server
rm -rf /etc/mtproxy
ok "Конфиги удалены"

# ─── Remove binaries ───────────────────────────────────────────────────
info "Удаляю бинарники..."
rm -f /usr/local/bin/tproxy-server
rm -f /usr/local/sbin/refresh-mtproxy-config
rm -rf /opt/MTProxy
ok "Бинарники удалены"

# ─── Remove site ───────────────────────────────────────────────────────
info "Удаляю сайт..."
rm -rf /srv/tproxy-site
ok "Сайт удалён"

# ─── Remove nginx vhost ────────────────────────────────────────────────
info "Удаляю nginx vhost..."
for conf in /etc/nginx/conf.d/*.conf; do
  if grep -q "tproxy" "$conf" 2>/dev/null; then
    rm -f "$conf"
    echo "  Удалён: $conf"
  fi
done
nginx -t 2>/dev/null && systemctl reload nginx
ok "Nginx конфиги удалены"

# ─── Remove nftables table ─────────────────────────────────────────────
info "Удаляю nftables..."
nft delete table inet tproxy_backend 2>/dev/null || true
ok "Nftables таблица удалена"

# ─── Remove mtproxy user ──────────────────────────────────────────────
info "Удаляю пользователя mtproxy..."
userdel mtproxy 2>/dev/null || true
ok "Пользователь mtproxy удалён"

# ─── Remove certs ──────────────────────────────────────────────────────
info "Удаляю SSL сертификаты..."
if command -v certbot &>/dev/null; then
  certbot delete --non-interactive 2>/dev/null || true
fi
ok "Сертификаты удалены"

# ─── Remove workdir ────────────────────────────────────────────────────
info "Удаляю рабочую директорию..."
rm -rf /root/tproxy-work
ok "Рабочая директория удалена"

echo ""
echo -e "${G}══════════════════════════════════════════════════════════${D}"
echo -e "${G}  Всё удалено!${D}"
echo -e "${G}══════════════════════════════════════════════════════════${D}"
