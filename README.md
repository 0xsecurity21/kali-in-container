# Kali Workstation

A disposable, native-ARM64 Kali Rolling workstation for Docker Desktop on macOS. Lab files, tools, VPN profiles, wordlists, and user configuration stay on the host under this repository; the image contains no wordlist collection.

## Prerequisites

- Docker Desktop with Apple Silicon enabled and file sharing for this repository
- Docker Compose v2
- An SSH public key (never add a private key here)
- Docker Desktop support for `/dev/net/tun` when using OpenVPN

## Install

```bash
git clone <repository-url> AgenticOffensive
cd AgenticOffensive
cp .env.example .env                 # do not overwrite an existing .env
mkdir -p home/{Documents,tools,vpns,wordlists}
# The default host key is ~/.ssh/id_ed25519.pub. Set SSH_PUBLIC_KEY_PATH in
# .env if you use another public-key file.
mkdir -p home/wordlists/{dirb,dirbuster,metasploit,SecLists}
docker compose up -d --build
```

If this checkout already has `.env`, reconcile its values with `.env.example` rather than replacing it. Old variables such as `ENABLE_RDP` and `INSTALL_RDP` are not used; use `ENABLE_XRDP` and `INSTALL_XRDP`.

## Configuration

Copy `.env.example` for documented safe defaults. `KALI_UID` and `KALI_GID` should match the intended container-side owner of bind-mounted files. Changes to `INSTALL_XRDP` or user IDs require `docker compose build --no-cache`; runtime service flags only require recreation.

| Variable                             | Purpose                                              |
| ------------------------------------ | ---------------------------------------------------- |
| `ENABLE_SSH`                         | Start key-only SSH (default `1`)                     |
| `ENABLE_XRDP` / `INSTALL_XRDP`       | Start/build optional XFCE + XRDP (both must be `1`)  |
| `ENABLE_POSTGRESQL` / `ENABLE_REDIS` | Documents intent to use the matching Compose profile |
| `SSH_PORT` / `XRDP_PORT`             | Localhost host ports                                 |

For XRDP, add a strong `RDP_PASSWORD` only to your ignored `.env`; it is required when XRDP starts and is never shown in `.env.example`.

## Daily use

```bash
# Start or rebuild, then verify health.
docker compose up -d --build
docker compose ps
docker compose logs -f kali

# Open an interactive non-root Kali shell. The working directory is /home/kali.
# `-u kali` matters: Docker Compose exec otherwise uses root.
docker compose exec -u kali kali zsh

# Connect with your existing host private key.
ssh kali@localhost -p 2222

# Stop containers without deleting persistent bind mounts or database volumes.
docker compose down
docker compose down -v              # also removes optional PostgreSQL/Redis data only
```

Ports bind to `127.0.0.1`, not all host interfaces. SSH reads the selected host public key (default: `~/.ssh/id_ed25519.pub`); password and root login are disabled. Only that public key is mounted—private keys never enter the container.

Open in VS Code with **Dev Containers: Reopen in Container**. It reuses the `kali` Compose service and opens the persistent user home, `/home/kali`. Lab documents are at `/home/kali/Documents`; `/workspace` remains a compatibility mount for that same directory.

Inside the container, verify the environment with:

```bash
id
pwd                         # /home/kali
echo "$WORKSPACE"           # /home/kali
workstation-healthcheck
command -v nmap ffuf openvpn
```

Zsh loads Kali's standard `~/.zshrc` first, then sources the persistent workstation configuration at `~/.config/zsh/zshrc`. Container startup seeds `~/.zshrc` if it is absent, preventing the `zsh-newuser-install` prompt after recreation. Zsh supports prefix history search: type a prefix such as `docker`, then press **Up** for the previous matching command or **Down** for the next one.

## Persistent paths

| Host path         | Container path                          | Mode       |
| ----------------- | --------------------------------------- | ---------- |
| `home/`           | `/home/kali`                            | read/write |
| `home/Documents/` | `/home/kali/Documents` and `/workspace` | read/write |
| `home/tools/`     | `/opt/custom-tools`                     | read/write |
| `home/vpns/`      | `/root/vpns`                            | read-only  |
| `home/wordlists/` | `/usr/share/wordlists`                  | read-only  |

Put executable custom programs in `home/tools/bin`; it is on `PATH` as `/opt/custom-tools/bin`. The `home/.local/bin` helpers provide `vpn-connect`, `htb`, `lab-init`, and `update-tools`.

## VPN and wordlists

Place profiles below `home/vpns/`, for example `home/vpns/htb/profile.ovpn`, then run inside the container:

```bash
vpn-connect htb/profile.ovpn
# or: sudo openvpn --config /root/vpns/htb/profile.ovpn
```

The container has only `NET_ADMIN` and the TUN device—never privileged mode. Docker Desktop networking remains NAT; host networking and macvlan are deliberately not enabled. For isolated application labs, attach services to the declared internal `lab` network in a separate Compose override.

Prepare the Kali-compatible host layout without downloading or installing any container packages:

```bash
./scripts/prepare-wordlists.sh
```

It creates the Kali-style directories `dirb`, `dirbuster`, `fern-wifi`, `legion`, `metasploit`, `seclists`, and `wfuzz`. `SecLists` is a compatibility symlink to the lowercase Kali-style `seclists` path. Populate the expected files (`dnsmap.txt`, `fasttrack.txt`, `john.lst`, `nmap.lst`, `rockyou.txt.gz`, `sqlmap.txt`, and `wifite.txt`) only with data you intentionally obtain.

For example:

```bash
git clone --depth 1 https://github.com/danielmiessler/SecLists.git home/wordlists/seclists
# Put a legally obtained rockyou.txt or rockyou.txt.gz in home/wordlists/
```

Expected paths are `/usr/share/wordlists/seclists` (also available as `SecLists`) and, when provided, `/usr/share/wordlists/rockyou.txt`. No wordlists are downloaded during image build or container startup.

## Optional services and desktop

PostgreSQL and Redis run separately and are not exposed to the host:

```bash
docker compose --profile postgres up -d
docker compose --profile redis up -d
```

Enable XRDP by setting `INSTALL_XRDP=1`, `ENABLE_XRDP=1`, and a strong `RDP_PASSWORD` in `.env`, then rebuild. Connect an RDP client to `localhost:${XRDP_PORT}`. Keep XRDP disabled unless needed.

## Troubleshooting and reset

```bash
docker compose config                 # validate resolved Compose config
docker compose exec kali workstation-healthcheck
docker compose exec kali id && docker compose exec kali uname -m
docker compose logs kali
```

If the bind-mounted workspace is unwritable, align `KALI_UID`/`KALI_GID` and rebuild. The entrypoint only adjusts mount-root ownership and never recursively changes host files. On Docker Desktop, verify file sharing and TUN support if OpenVPN fails.

To rebuild the disposable image, use `docker compose down && docker compose up -d --build`. Do **not** delete `home/` or your ignored `.env` unless you intend to discard that host data.

<!-- ssh -D 2024 -f -C -q -N kali@localhost -p 2222 -->
<!-- echo "10.129.67.117 management.htb" | sudo tee -a /etc/hosts -->
