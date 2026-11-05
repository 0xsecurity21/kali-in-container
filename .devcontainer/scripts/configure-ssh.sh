#!/usr/bin/env bash
set -Eeuo pipefail

user="${KALI_USER:-kali}"
if ! id "$user" >/dev/null 2>&1; then
  echo "SSH configuration failed: user '$user' does not exist" >&2
  exit 1
fi

mkdir -p /run/sshd
ssh-keygen -A
# The bind mount is intentionally read-only; do not copy keys into persisted home.
if [[ ! -f /etc/ssh/authorized_keys ]]; then
  echo "WARNING: no authorized_keys file is mounted; SSH will accept no logins." >&2
elif [[ ! -s /etc/ssh/authorized_keys ]]; then
  echo "WARNING: authorized_keys is empty; SSH will accept no logins." >&2
fi

# Validate the final server configuration before supervisor starts sshd.
/usr/sbin/sshd -t
