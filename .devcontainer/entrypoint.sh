#!/usr/bin/env bash
set -Eeuo pipefail

echo "[agentic] Starting Kali services..."

KALI_USER="${KALI_USER:-kali}"

# Validate user
if ! id "$KALI_USER" >/dev/null 2>&1; then
    echo "[agentic] ERROR: User '$KALI_USER' does not exist."
    exit 1
fi

KALI_HOME="$(getent passwd "$KALI_USER" | cut -d: -f6)"
KALI_GROUP="$(id -gn "$KALI_USER")"

# Bind-mounted dirs are created root-owned by Docker; hand them to the user.
for dir in /workspace "$KALI_HOME/tools" "$KALI_HOME/wordlists"; do
    [[ -d "$dir" ]] && chown "$KALI_USER:$KALI_GROUP" "$dir" 2>/dev/null || true
done

# ------------------------------------------------------------
# SSH
# ------------------------------------------------------------
mkdir -p /run/sshd
ssh-keygen -A

if [[ -f /run/authorized_keys ]]; then
    install -d -m 700 \
        -o "$KALI_USER" \
        -g "$KALI_GROUP" \
        "$KALI_HOME/.ssh"

    install -m 600 \
        -o "$KALI_USER" \
        -g "$KALI_GROUP" \
        /run/authorized_keys \
        "$KALI_HOME/.ssh/authorized_keys"

    echo "[agentic] SSH public key installed."
elif [[ -d /run/authorized_keys ]]; then
    echo "[agentic] WARNING: /run/authorized_keys is a directory."
    echo "[agentic] WARNING: host file .ssh/authorized_keys is probably missing."
else
    echo "[agentic] WARNING: No authorized_keys mounted."
fi

/usr/sbin/sshd

echo "[agentic] SSH server started on port 22."

# ------------------------------------------------------------
# RDP
# ------------------------------------------------------------
if [[ "${ENABLE_RDP:-0}" == "1" ]]; then

    if command -v xrdp >/dev/null 2>&1; then

        # xrdp authenticates through PAM, so the user needs a password.
        if [[ -n "${RDP_PASSWORD:-}" ]]; then
            echo "${KALI_USER}:${RDP_PASSWORD}" | chpasswd
            echo "[agentic] RDP password set for '${KALI_USER}'."
        else
            echo "[agentic] WARNING: RDP_PASSWORD is empty; RDP login will fail."
        fi

        mkdir -p /run/dbus /var/run/xrdp/sockdir
        chown xrdp:xrdp /var/run/xrdp/sockdir 2>/dev/null || true
        chmod 0755 /var/run/xrdp /var/run/xrdp/sockdir

        dbus-uuidgen --ensure 2>/dev/null || true
        dbus-daemon --system --fork || true

        if ! pgrep -x xrdp-sesman >/dev/null; then
            /usr/sbin/xrdp-sesman
        fi
        if ! pgrep -x xrdp >/dev/null; then
            /usr/sbin/xrdp
        fi

        echo "[agentic] XRDP server started on port 3389."

    else
        echo "[agentic] WARNING: XRDP is not installed (rebuild with INSTALL_RDP=1)."
    fi
fi

echo "[agentic] Environment ready."

exec "$@"
