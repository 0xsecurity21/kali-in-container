#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v xrdp >/dev/null 2>&1; then
  echo "XRDP is enabled but absent. Rebuild with INSTALL_XRDP=1." >&2
  exit 1
fi

[[ -n "${RDP_PASSWORD:-}" ]] || { echo "XRDP requires RDP_PASSWORD in .env" >&2; exit 1; }
echo "${KALI_USER:-kali}:${RDP_PASSWORD}" | chpasswd

# XRDP needs an X session; this is deliberately configured only in the optional build.
cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
exec dbus-launch --exit-with-session startxfce4
EOF
chmod 0755 /etc/xrdp/startwm.sh
mkdir -p /run/dbus /run/xrdp /var/run/xrdp/sockdir
chown xrdp:xrdp /run/xrdp /var/run/xrdp/sockdir
