#!/usr/bin/env bash
set -Eeuo pipefail

# Use the standard ~/.zshrc. Older images exported ZDOTDIR; do not let it
# bypass Kali's default startup file for the persisted kali account.
unset ZDOTDIR

user="${KALI_USER:-kali}"
for flag in ENABLE_SSH ENABLE_XRDP ENABLE_POSTGRESQL ENABLE_REDIS; do
  value="${!flag:-0}"
  [[ "$value" == "0" || "$value" == "1" ]] || { echo "$flag must be 0 or 1" >&2; exit 2; }
done
id "$user" >/dev/null 2>&1 || { echo "User '$user' does not exist" >&2; exit 1; }

home_dir="$(getent passwd "$user" | cut -d: -f6)"
required=("$home_dir" /workspace /opt/custom-tools /root/vpns /usr/share/wordlists)
for path in "${required[@]}"; do
  [[ -d "$path" ]] || { echo "Missing required mount/directory: $path" >&2; exit 1; }
done

# Adjust mount roots only, never recursively modify user data.
for path in "$home_dir" /workspace /opt/custom-tools; do
  if [[ "$(stat -c '%u' "$path")" == "0" ]]; then
    chown "$user:$(id -gn "$user")" "$path" 2>/dev/null || \
      echo "WARNING: cannot adjust ownership of $path; verify KALI_UID/KALI_GID." >&2
  fi
done

# A bind-mounted home can be empty after recreation. Seed a non-interactive
# startup file so zsh never falls back to zsh-newuser-install.
if [[ ! -e "$home_dir/.zshrc" ]]; then
  if [[ -f /etc/skel/.zshrc ]]; then
    cp /etc/skel/.zshrc "$home_dir/.zshrc"
  else
    printf '%s\n' '# Kali workstation zsh startup file.' > "$home_dir/.zshrc"
  fi
  cat >> "$home_dir/.zshrc" <<EOF

# Persistent workstation customizations.
if [ -f "$home_dir/.config/zsh/zshrc" ]; then
    . "$home_dir/.config/zsh/zshrc"
fi
EOF
  chown "$user:$(id -gn "$user")" "$home_dir/.zshrc" 2>/dev/null || true
fi

runtime_config=/run/supervisord-workstation.conf
cp /etc/supervisor/conf.d/workstation.conf "$runtime_config"
# The service manager remains root for SSH/XRDP, but the user's command does not.
sed -i "/^\[program:main\]/a user=${user}" "$runtime_config"
printf '#!/usr/bin/env bash\nexec ' > /run/workstation-main
printf '%q ' "$@" >> /run/workstation-main
printf '\n' >> /run/workstation-main
chmod 0755 /run/workstation-main

if [[ "${ENABLE_SSH:-1}" == "1" ]]; then
  sed -i "s/^AllowUsers .*/AllowUsers ${user}/" /etc/ssh/sshd_config.d/workstation.conf
  /usr/local/libexec/configure-ssh
  cat >> "$runtime_config" <<'EOF'

[program:sshd]
command=/usr/sbin/sshd -D -e
priority=10
autostart=true
autorestart=true
startsecs=1
stopasgroup=true
killasgroup=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0
EOF
fi

if [[ "${ENABLE_XRDP:-0}" == "1" ]]; then
  /usr/local/libexec/configure-xrdp
  cat >> "$runtime_config" <<'EOF'

[program:xrdp-sesman]
command=/usr/sbin/xrdp-sesman --nodaemon
priority=20
autostart=true
autorestart=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0

[program:xrdp]
command=/usr/sbin/xrdp --nodaemon
priority=21
autostart=true
autorestart=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0
EOF
fi

[[ "${ENABLE_POSTGRESQL:-0}" == "1" ]] && echo "PostgreSQL requested: use the compose 'postgres' profile service."
[[ "${ENABLE_REDIS:-0}" == "1" ]] && echo "Redis requested: use the compose 'redis' profile service."
printf 'Kali workstation ready: user=%s workspace=%s ssh=%s xrdp=%s\n' \
  "$user" "$home_dir" "${ENABLE_SSH:-1}" "${ENABLE_XRDP:-0}"
exec /usr/bin/supervisord -c "$runtime_config"
