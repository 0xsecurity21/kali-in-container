#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v xrdp >/dev/null 2>&1; then
  echo "XRDP is enabled but absent. Rebuild with INSTALL_XRDP=1." >&2
  exit 1
fi

if ! command -v startxfce4 >/dev/null 2>&1; then
  echo "XRDP is enabled but XFCE is absent. Rebuild with INSTALL_XRDP=1." >&2
  exit 1
fi

[[ -n "${RDP_PASSWORD:-}" || -n "${KALI_PASSWORD:-}" ]] || { echo "XRDP requires RDP_PASSWORD (or KALI_PASSWORD) in .env" >&2; exit 1; }
echo "${KALI_USER:-kali}:${RDP_PASSWORD:-${KALI_PASSWORD}}" | chpasswd

# xrdp reads its TLS key through the ssl-cert group.
getent group ssl-cert >/dev/null || groupadd --system ssl-cert
usermod -aG ssl-cert xrdp

# XFCE session for xrdp
cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG
fi
exec dbus-launch --exit-with-session startxfce4
EOF
chmod 0755 /etc/xrdp/startwm.sh

mkdir -p /run/dbus /run/xrdp /var/run/xrdp/sockdir
chown xrdp:xrdp /run/xrdp /var/run/xrdp/sockdir
chmod 0755 /run/xrdp /var/run/xrdp/sockdir

# System bus; the desktop session also starts its own session bus.
dbus-uuidgen --ensure 2>/dev/null || true
if [[ ! -S /run/dbus/system_bus_socket ]]; then
  dbus-daemon --system --fork
fi
