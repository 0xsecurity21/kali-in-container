#!/usr/bin/env bash
set -Eeuo pipefail

user="${KALI_USER:-kali}"
if ! id "$user" >/dev/null 2>&1; then
  echo "SSH configuration failed: user '$user' does not exist" >&2
  exit 1
fi

mkdir -p /run/sshd
# Host keys live on a bind mount so recreated containers keep the same
# fingerprint and clients do not trip host-key-change warnings.
hostkey_dir=/etc/ssh/hostkeys
mkdir -p "$hostkey_dir"
chmod 0755 "$hostkey_dir"

for type in ed25519 ecdsa rsa; do
  key="$hostkey_dir/ssh_host_${type}_key"
  if [[ ! -s "$key" ]]; then
    rm -f "$key" "$key.pub"
    ssh-keygen -q -t "$type" -N '' -f "$key"
  fi
  chmod 0600 "$key"
  chmod 0644 "$key.pub"
done

# The bind mount is intentionally read-only; do not copy keys into persisted home.
if [[ ! -f /etc/ssh/authorized_keys ]]; then
  echo "WARNING: no authorized_keys file is mounted; SSH will accept no logins." >&2
elif [[ ! -s /etc/ssh/authorized_keys ]]; then
  echo "WARNING: authorized_keys is empty; SSH will accept no logins." >&2
fi

# Validate the final server configuration before supervisor starts sshd.
/usr/sbin/sshd -t
