#!/usr/bin/env bash
set -Eeuo pipefail

required=(/home/"${KALI_USER:-kali}" /workspace /opt/custom-tools /root/vpns /usr/share/wordlists)
for path in "${required[@]}"; do
  [[ -d "$path" ]] || { echo "Missing required directory: $path" >&2; exit 1; }
done

if [[ "${ENABLE_SSH:-1}" == "1" ]]; then
  pgrep -x sshd >/dev/null || { echo "sshd is not running" >&2; exit 1; }
fi
if [[ "${ENABLE_XRDP:-0}" == "1" ]]; then
  pgrep -x xrdp >/dev/null || { echo "xrdp is not running" >&2; exit 1; }
fi
