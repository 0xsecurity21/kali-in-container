#!/usr/bin/env bash
# Centralized, intentionally small package set for the workstation image.
set -Eeuo pipefail

install_xrdp="${1:-0}"
case "$install_xrdp" in 0|1) ;; *) echo "INSTALL_XRDP must be 0 or 1" >&2; exit 2;; esac

# Base utilities
base_packages=(
  ca-certificates curl wget git sudo zsh vim-tiny less file jq unzip zip tar
  tree procps lsof iproute2 iputils-ping net-tools dnsutils netcat-openbsd
  socat tzdata supervisor openssh-server vim
)
# Development tools
development_packages=(
  python3 python3-pip python3-venv pipx nodejs npm golang-go build-essential
  pkg-config
)
# Network and VPN utilities
network_packages=(openvpn traceroute tcpdump)
# Common, ARM64-compatible assessment tools. Wordlist packages are deliberately absent.
pentest_packages=(
  nmap ffuf gobuster sqlmap nikto whatweb enum4linux-ng smbclient
  impacket-scripts hydra john hashcat
)
optional_desktop_packages=(xrdp xorgxrdp xfce4 xfce4-terminal dbus dbus-x11)

apt-get update
apt-get install -y --no-install-recommends \
  "${base_packages[@]}" \
  "${development_packages[@]}" \
  "${network_packages[@]}" \
  "${pentest_packages[@]}"
if [[ "$install_xrdp" == "1" ]]; then
  apt-get install -y --no-install-recommends "${optional_desktop_packages[@]}"
fi
apt-get clean
rm -rf /var/lib/apt/lists/*
