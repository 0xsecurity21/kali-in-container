#!/usr/bin/env bash
# Centralized, intentionally small package set for the workstation image.
# Group switches come from .env; every group defaults to the smallest usable set.
set -Eeuo pipefail

install_xrdp="${1:-0}"
install_pentest="${2:-1}"
install_dev="${3:-0}"
install_proxy="${4:-1}"

for pair in "INSTALL_XRDP:$install_xrdp" "INSTALL_PENTEST:$install_pentest" \
            "INSTALL_DEV:$install_dev" "INSTALL_PROXY:$install_proxy"; do
  case "${pair#*:}" in
    0|1) ;;
    *) echo "${pair%%:*} must be 0 or 1" >&2; exit 2 ;;
  esac
done

# Always present: connectivity, SSH, process supervision, Python runtime.
base_packages=(
  ca-certificates curl wget git sudo zsh vim-tiny vim less file jq unzip zip tar
  tree procps lsof iproute2 iputils-ping net-tools dnsutils netcat-openbsd
  socat tzdata supervisor openssh-server python3
)
# Development toolchain. Off by default; most tools install with pipx or npm.
development_packages=(
  build-essential pkg-config python3-pip python3-venv pipx nodejs npm golang-go
)
# Network and VPN utilities.
network_packages=(openvpn traceroute tcpdump)
# VPN-routed proxy client. proxy_dns is enabled in /etc/proxychains4.conf.
proxy_packages=(proxychains4)
# Common, ARM64-compatible assessment tools. Wordlist packages are deliberately absent.
pentest_packages=(
  nmap ffuf gobuster feroxbuster sqlmap nikto whatweb enum4linux-ng smbclient
  impacket-scripts hydra john hashcat krb5-user ldap-utils
)

optional_desktop_packages=(xrdp xorgxrdp xfce4 xfce4-terminal dbus dbus-x11)

groups=("${base_packages[@]}" "${network_packages[@]}")
[[ "$install_proxy" == "1" ]] && groups+=("${proxy_packages[@]}")
[[ "$install_pentest" == "1" ]] && groups+=("${pentest_packages[@]}")
[[ "$install_dev" == "1" ]] && groups+=("${development_packages[@]}")
[[ "$install_xrdp" == "1" ]] && groups+=("${optional_desktop_packages[@]}")

apt-get update
apt-get install -y --no-install-recommends "${groups[@]}"
apt-get clean
rm -rf /var/lib/apt/lists/*
