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

## Reproduce the full setup

Run these from the repository root. Everything below was executed and verified on Docker Desktop 4.99.0 (arm64) with Kali Rolling.

### 1. Build and start

```bash
cp .env.example .env            # skip if .env already exists
docker compose up -d --build
docker compose ps               # wait for "healthy"
```

The build takes the package groups from `.env`: `INSTALL_PENTEST=1`, `INSTALL_PROXY=1`, `INSTALL_DEV=0`, `INSTALL_XRDP=1`. Change a flag, then rebuild with `docker compose build --no-cache`.

### 2. Verify identity and services

```bash
docker compose exec -T kali bash -lc 'hostname; uname -m; command -v nmap ffuf proxychains4 openvpn; workstation-healthcheck'
docker compose exec -u kali kali id
ssh -p 2222 -o BatchMode=yes kali@localhost 'whoami; pwd'   # expect: kali, /home/kali
nc -z 127.0.0.1 3389 && echo rdp-listening                  # only with ENABLE_XRDP=1
```

`hostname` comes from `KALI_HOSTNAME`, the user from `KALI_USER`, the architecture from `X_ARCH`. `docker compose exec` without `-u` runs as root by design; use `-u kali` for user work.

### 3. Connect the HTB VPN

Profiles and credentials are not in the repository. Copy yours into the ignored host directory first:

```bash
mkdir -p home/vpns/htb
cp ~/Downloads/<profile>.ovpn home/vpns/htb/
```

```bash
docker compose exec -u kali kali vpn-connect htb/<profile>.ovpn
docker compose exec kali sh -c 'ip -brief addr show tun0; ip route | grep tun0'
```

`vpn-connect` lives in `home/.local/bin`, lists available profiles when the name is wrong, and logs to `/tmp/openvpn.log`. Without the helper:

```bash
docker compose exec -T kali bash -lc 'sudo openvpn --config /root/vpns/htb/<profile>.ovpn \
  --daemon --log /tmp/openvpn.log --writepid /tmp/openvpn.pid'
```

Expected: `tun0` with a `10.10.x.x/23` address and `10.129.0.0/16 via 10.10.14.1 dev tun0`. Profile files stay read-only under `home/vpns/`; the container never writes to them. If `tun0` never appears, read `/tmp/openvpn.log` and confirm `/dev/net/tun` exists in the container.

### 4. Confirm target reachability

```bash
docker compose exec -T kali bash -lc '
  ping -c 2 10.129.68.82
  sudo nmap -Pn -n -p 22,80 10.129.68.82'
```

Expected for this lab target: 0% packet loss, `22/tcp open ssh`, `80/tcp open http`.

### 5. Expose the VPN to macOS over SOCKS

```bash
ssh -fN -D 1080 -p 2222 -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 kali@localhost
lsof -nP -iTCP:1080 -sTCP:LISTEN        # expect 127.0.0.1:1080
```

The listener is loopback-only. Verify the chain, then the lack of a direct route:

```bash
curl -x socks5h://127.0.0.1:1080 -o /dev/null -w '%{http_code}\n' http://10.129.68.82/   # 301
curl -m 5 -o /dev/null -w '%{http_code}\n' http://10.129.68.82/                            # 000
```

`socks5h` resolves names on the container side, `socks5` resolves locally. Burp configuration is in [Burp Suite on the host](#burp-suite-on-the-host-against-vpn-only-targets).

### 6. Pin VPN-only hostnames

HTB free labs push no DNS server, so `.htb` names do not resolve. Pin them inside the container:

```bash
docker compose exec kali sh -c 'echo "10.129.68.82 paperwork.htb" | sudo tee -a /etc/hosts'
curl -x socks5h://127.0.0.1:1080 -o /dev/null -w '%{http_code}\n' http://paperwork.htb/   # 200
```

The entry disappears when the container is recreated. Keep the current list in a file under `home/Documents/` and re-apply it after each `up`.

### 7. Open the folder in VS Code (optional)

If the server CDN is blocked, seed the server first, then **Dev Containers: Reopen in Container**:

```bash
.devcontainer/scripts/seed-vscode-server.sh ~/Downloads/vscode-server-linux-arm64.tar.gz
```

See [VS Code Dev Container server download](#vs-code-dev-container-server-download).

### 8. Stop and restart

```bash
docker compose down                 # keeps home/, VPN profiles, wordlists
docker compose up -d                # VPN and the SOCKS tunnel must be restarted
pkill -f 'ssh -fN -D 1080'
```

Nothing under `home/` or the ignored `.env` is deleted by `down`. Use `docker compose down -v` only when you also want to drop the optional PostgreSQL/Redis volumes.


## Configuration

Everything is driven by `.env`. Copy `.env.example` for documented safe defaults.

| Variable                                    | Purpose                                                     |
| ------------------------------------------- | ----------------------------------------------------------- |
| `CONTAINER_NAME` / `KALI_HOSTNAME`          | Compose container name and in-container hostname             |
| `KALI_USER` / `KALI_UID` / `KALI_GID`       | Login name and uid/gid; a rename needs a free `KALI_UID`     |
| `KALI_PASSWORD`                             | Optional console/RDP password; SSH stays key-only            |
| `X_ARCH`                                    | `arm64` (native) or `amd64` (emulated x86)                   |
| `SSH_PORT` / `XRDP_PORT`                    | Localhost host ports                                         |
| `ENABLE_SSH` / `ENABLE_XRDP`                | Runtime services                                             |
| `INSTALL_XRDP`                              | Builds XFCE + XRDP into the image                            |
| `INSTALL_PENTEST`                           | nmap, ffuf, sqlmap, impacket, hydra, john, hashcat, Kerberos  |
| `INSTALL_DEV`                               | build-essential, Go, Node, pipx, venv (large, off by default) |
| `INSTALL_PROXY`                             | proxychains4 with DNS-over-proxy                             |
| `ENABLE_POSTGRESQL` / `ENABLE_REDIS`        | Documents intent to use the matching Compose profile         |

`KALI_UID`/`KALI_GID` must match the owner Docker Desktop presents for `./home` (uid `1000` by default). `INSTALL_*`, `X_ARCH`, and the identity variables require `docker compose build --no-cache`; runtime flags only require recreation.

Image size comes from the `INSTALL_*` flags. Defaults build a base workstation; enable `INSTALL_DEV=1` only when a tool needs a compiler, and disable `INSTALL_PENTEST` when you only need SSH plus custom tools.

For XRDP, add a strong `RDP_PASSWORD` only to your ignored `.env`; it is required when XRDP starts and is never shown in `.env.example`. When it is empty, `KALI_PASSWORD` is used.


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

Put executable custom programs in `home/tools/bin`; it is on `PATH` as `/opt/custom-tools/bin`. `home/.local/bin` holds `vpn-connect`, which starts an OpenVPN profile from the read-only VPN mount.

## VPN and wordlists

Place profiles below `home/vpns/`, for example `home/vpns/htb/profile.ovpn`, then run inside the container:

```bash
vpn-connect htb/profile.ovpn
# equivalent: sudo openvpn --config /root/vpns/htb/profile.ovpn --daemon --log /tmp/openvpn.log
ls /root/vpns/htb/      # list available profiles
```

The container has only `NET_ADMIN` and the TUN device—never privileged mode. Docker Desktop networking remains NAT; host networking and macvlan are deliberately not enabled. For isolated application labs, attach services to the declared internal `lab` network in a separate Compose override.

### proxychains4

`/etc/proxychains4.conf` is the checked-in `.devcontainer/config/proxychains4.conf`: `strict_chain`, `proxy_dns`, `socks5 127.0.0.1 1080`. It only routes a tool that cannot use `tun0` itself, and it needs a SOCKS listener reachable from inside the container on that address. Tools run inside the container already reach `10.x` through `tun0`, so most of the time no proxy is involved.

The working direction for host applications is the opposite: the listener runs on macOS and forwards into the container. See the Burp section below.


Prepare the Kali-compatible host layout without downloading or installing any container packages:

```bash
mkdir -p home/wordlists/{dirb,dirbuster,metasploit,seclists,wfuzz}
ln -sfn seclists home/wordlists/SecLists
```

Kali expects the lowercase `seclists` directory; `SecLists` is a compatibility symlink. Populate the expected files (`dnsmap.txt`, `fasttrack.txt`, `john.lst`, `nmap.lst`, `rockyou.txt.gz`, `sqlmap.txt`, and `wifite.txt`) only with data you intentionally obtain.

For example:

```bash
git clone --depth 1 https://github.com/danielmiessler/SecLists.git home/wordlists/seclists
# Put a legally obtained rockyou.txt or rockyou.txt.gz in home/wordlists/
```

Expected paths are `/usr/share/wordlists/seclists` (also available as `SecLists`) and, when provided, `/usr/share/wordlists/rockyou.txt`. No wordlists are downloaded during image build or container startup.

## Burp Suite on the host against VPN-only targets

Burp runs on macOS, but macOS has no route to the `10.x` targets. The container does. Chain them: browser → Burp on host → SOCKS on host → container `tun0` → target.

1. Start a SOCKS tunnel from the host into the container:

```bash
ssh -fN -D 1080 -p 2222 -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 kali@localhost
# resilient variant:
# autossh -M 0 -fN -D 1080 -p 2222 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 kali@localhost
```

The listener binds `127.0.0.1:1080` only, so nothing is exposed to the LAN. Confirm it with `lsof -nP -iTCP:1080 -sTCP:LISTEN`.

2. Verify the chain before touching Burp:

```bash
curl -x socks5h://127.0.0.1:1080 -I http://10.129.68.82/
curl -m 5 -I http://10.129.68.82/          # direct macOS access must time out
```

`socks5h` sends the hostname to the container, so DNS happens on the container side. Use `socks5://` when the name resolves locally.

3. In Burp: Settings → Network → Connections → SOCKS proxy.
- Host `127.0.0.1`, port `1080`
- Enable "Use SOCKS proxy"
- Enable "Do DNS lookups over SOCKS proxy", so names reach the container resolver

4. Point the browser at Burp:

- browser inside the container: proxy `host.docker.internal:8080`
- browser on macOS: proxy `127.0.0.1:8080`

Burp can keep listening on `127.0.0.1`. Docker Desktop forwards `host.docker.internal` to host loopback. Do not bind Burp to `0.0.0.0`; that exposes the proxy to your LAN.

5. Trust the Burp CA in whichever browser uses the proxy:

```bash
# inside the container
curl -s --proxy http://host.docker.internal:8080 -o /tmp/burp.der http://burp/cert
sudo openssl x509 -inform DER -in /tmp/burp.der -out /usr/local/share/ca-certificates/burp.crt
sudo update-ca-certificates
```

Firefox and Chromium keep their own certificate store; import `burp.crt` there as well.

6. HTB free labs push no DNS server, so `.htb` names do not resolve through the tunnel. Pin them in the container, not on macOS:

```bash
docker compose exec kali sh -c 'echo "10.129.68.82 paperwork.htb" | sudo tee -a /etc/hosts'
```

The entry is lost on container recreation; keep the current list in a file and re-apply it after `up`.

Verified chain on this host: `http://10.129.68.82/` answers `301` to `http://paperwork.htb/`, which answers `200` (nginx/1.28.0) through `socks5h`. Direct macOS access times out.

VPN reconnects do not break the tunnel; new flows still leave through the container. A container restart stops the SOCKS tunnel and drops the VPN, so restart both.

## Optional services and desktop

PostgreSQL and Redis run separately and are not exposed to the host:

```bash
docker compose --profile postgres up -d
docker compose --profile redis up -d
```

Enable XRDP by setting `INSTALL_XRDP=1`, `ENABLE_XRDP=1`, and a strong `RDP_PASSWORD` in `.env`, then rebuild. Connect an RDP client to `localhost:${XRDP_PORT}`. Keep XRDP disabled unless needed.

## VS Code Dev Container server download

VS Code downloads `vscode-server-linux-arm64` on the host before it enters the container. Some networks block the CDN (`vscode.download.prss.microsoft.com`), which shows up as `TypeError: Failed to fetch` and a zero-byte file under `.../vsch/serverCache/`.

Test the CDN first:

```bash
curl -sSL -r 0-1023 -o /dev/null -w '%{http_code}\n' \
  "https://update.code.visualstudio.com/commit:$(code --version | sed -n 2p)/server-linux-arm64/stable"
```

When the download fails, fetch the tarball over a working link (VPN, different network) and seed it into the persisted home. The extension then skips the download:

```bash
.devcontainer/scripts/seed-vscode-server.sh ~/Downloads/vscode-server-linux-arm64.tar.gz
# or let the script download it through a reachable mirror:
# .devcontainer/scripts/seed-vscode-server.sh https://<mirror>/vscode-server-linux-arm64.tar.gz
```

If you have an HTTP proxy, `remote.serverDownloadBaseUrl` in VS Code settings can point the download at it instead.

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
