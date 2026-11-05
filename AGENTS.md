# AGENTS.md — Kali Workstation Infrastructure

## 1. Project Objective

Build a portable, persistent, and modular Kali Linux pentesting workstation using Docker Compose.

The project runs on macOS (Apple Silicon M2 Pro) and provides a complete penetration-testing and development environment.

The container must be disposable. All important user data, lab workspaces, custom tools, VPN configurations, and wordlists must persist on the host.

### Core Principles

1. **Disposable container:** Never store important user data exclusively inside the container.
2. **Host persistence:** Persist workspaces, tools, wordlists, VPN profiles, and user configurations.
3. **Minimal image:** Avoid installing unnecessary packages and large wordlists.
4. **Modularity:** Separate infrastructure, configuration, scripts, and persistent data.
5. **ARM64 first:** Optimize for native Apple Silicon execution.
6. **Reproducibility:** Rebuilding the image must produce a functional workstation.
7. **Security:** Never expose unnecessary services, credentials, or privileged access.
8. **Extensibility:** Support additional services and tools without restructuring the project.

---

## 2. Target Environment

| Component               | Requirement                             |
| ----------------------- | --------------------------------------- |
| Host OS                 | macOS                                   |
| Host architecture       | Apple Silicon ARM64                     |
| Hardware                | Apple M2 Pro                            |
| Container OS            | Kali Linux Rolling                      |
| Container runtime       | Docker Desktop                          |
| Orchestration           | Docker Compose                          |
| Development environment | VS Code Dev Containers                  |
| Remote access           | OpenSSH                                 |
| Optional desktop        | XRDP                                    |
| AI coding tools         | OpenCode, Codex, and compatible clients |
| Default user            | kali                                    |
| Workspace               | /home/kali(default user)                |

Use native ARM64 images wherever possible. Avoid unnecessary AMD64 emulation.

---

## 3. Project Structure

Implement and maintain the following directory structure:

```text
.
├── .devcontainer/
│   ├── devcontainer.json
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── config/
│   │   ├── sshd_config
│   │   └── supervisord.conf
│   └── scripts/
│       ├── install-tools.sh
│       ├── configure-ssh.sh
│       ├── configure-xrdp.sh
│       └── healthcheck.sh
│
├── .ssh/
│   └── authorized_keys
│
├── home/
│   ├── Documents/
│   │   ├── HTB/
│   │   │   ├── machines/
│   │   │   ├── challenges/
│   │   │   ├── pro-labs/
│   │   │   └── notes/
│   │   ├── THM/
│   │   ├── CTF/
│   │   └── HTB.md
│   │
│   ├── tools/
│   │   ├── bin/
│   │   ├── scripts/
│   │   ├── wordlists-generators/
│   │   └── custom/
│   │
│   ├── vpns/
│   │   ├── htb/
│   │   ├── thm/
│   │   └── other/
│   │
│   ├── wordlists/
│   │   ├── dirb/
│   │   ├── dirbuster/
│   │   ├── metasploit/
│   │   ├── SecLists/
│   │   └── rockyou.txt.gz
│   │
│   ├── .config/
│   │   ├── zsh/
|   │   │   ├── .zshrc
|   │   │   ├── .zshenv
|   │   │   ├── config/
|   │   │   │   ├── options.zsh
|   │   │   │   ├── aliases.zsh
|   │   │   │   ├── exports.zsh
|   │   │   │   ├── history.zsh
|   │   │   │   └── keybindings.zsh
|   │   │   │
|   │   │   ├── functions/
|   │   │   │   ├── navigation.zsh
|   │   │   │   ├── networking.zsh
|   │   │   │   ├── docker.zsh
|   │   │   │   ├── pentest.zsh
|   │   │   │   └── utilities.zsh
|   │   │   │
|   │   │   ├── completions/
|   │   │   ├── plugins/
|   │   │   ├── themes/
|   │   │   └── local.zsh
|   │   │
|   │   └── opencode/
│
├── .local/
│   ├── bin/
│   │   ├── update-tools
│   │   ├── vpn-connect
│   │   ├── htb
│   │   └── lab-init
│   │
│   └── share/
│       └── zsh/
│
├── .env
├── .env.example
├── .gitignore
├── compose.yaml
├── opencode.jsonc
├── README.md
└── AGENTS.md
```

Do not unnecessarily create empty directories or placeholder files without a functional purpose.

---

## 4. Dockerfile Requirements

Implement `.devcontainer/Dockerfile`.

Requirements:

- Use the official Kali Linux Rolling base image.
- Support native ARM64.
- Create a non-root `kali` user.
- Support configurable UID and GID.
- Install essential pentesting and development utilities.
- Install OpenSSH.
- Support optional XRDP installation.
- Install Git, curl, wget, Python, pip, Node.js, and other necessary development dependencies.
- Configure timezone.
- Configure the shell environment.
- Configure PATH for custom tools.
- Set appropriate permissions.
- Avoid installing large wordlist packages.
- Avoid installing unnecessary desktop environments.
- Keep Docker layers efficient.
- Use build arguments for optional features.

### Package Management

Use a centralized package installation section.

Separate packages into logical groups:

- Base utilities
- Network utilities
- Pentesting tools
- Development tools
- Optional desktop packages

Avoid duplicating packages and unnecessary package installations.

Do not install wordlists into the image.

---

## 5. Entrypoint Requirements

Implement `.devcontainer/entrypoint.sh`.

The entrypoint must:

1. Initialize the container environment.
2. Validate required directories.
3. Configure runtime permissions.
4. Initialize SSH when enabled.
5. Initialize XRDP when enabled.
6. Initialize optional services when configured.
7. Display workstation information.
8. Execute the container's main process.

### Service Configuration

Support environment variables:

```dotenv
ENABLE_SSH=1
ENABLE_XRDP=0
ENABLE_POSTGRESQL=0
ENABLE_REDIS=0
```

Do not blindly start every available service.

Use proper process management for multiple long-running services.

Prefer separate containers for PostgreSQL and Redis.

Use `exec "$@"` for the main process.

Do not use uncontrolled background processes.

---

## 6. SSH Requirements

Implement SSH key-based authentication.

Host directory:

```text
.ssh/authorized_keys
```

Container configuration:

```text
/etc/ssh/authorized_keys
```

Requirements:

- Public-key authentication only.
- Password authentication disabled by default.
- Root login disabled.
- Use the non-root `kali` account.
- Configure SSH host keys at runtime.
- Ensure correct permissions.
- Support configurable host port.
- Never store private SSH keys in the repository.

Default connection:

```bash
ssh kali@localhost -p 2222
```

---

## 7. Persistent Storage and Volume Mapping

All important user data must persist on the host.

### Required Mounts

| Host                     | Container                  | Access |
| ------------------------ | -------------------------- | ------ |
| `./home`                 | `/home/kali`               | RW     |
| `./home/tools`           | `/opt/custom-tools`        | RW     |
| `./home/vpns`            | `/root/vpns`               | RO     |
| `./home/wordlists`       | `/usr/share/wordlists`     | RO     |
| `./.ssh/authorized_keys` | `/etc/ssh/authorized_keys` | RO     |

### Workspace

Use:

```text
/home/kali
```

as the primary development workspace.

It should point to or mount the persistent host directory:

```text
./home/Documents
```

Avoid creating conflicting or redundant bind mounts.

Ensure the `kali` user can read and write workspace files.

Do not modify host files recursively with dangerous permission commands.

---

## 8. Wordlist Management

Wordlists must be maintained on the host.

The container must not install or duplicate large wordlist collections.

The host directory should follow Kali's standard structure:

```text
home/wordlists/
├── dirb/
├── dirbuster/
├── metasploit/
├── SecLists/
├── rockyou.txt.gz
└── ...
```

Requirements:

- Mount to `/usr/share/wordlists`.
- Prefer read-only container access.
- Preserve Kali-compatible paths.
- Do not download wordlists automatically during container startup.
- Do not commit large wordlists to Git.
- Provide documentation for obtaining and updating wordlists.
- Provide an optional synchronization script if useful.

Validate common paths:

```bash
/usr/share/wordlists/
/usr/share/wordlists/rockyou.txt
/usr/share/wordlists/SecLists/
```

Do not assume all optional wordlists exist.

---

## 9. Custom Tools

Host directory:

```text
home/tools/
```

Container directory:

```text
/opt/custom-tools/
```

Requirements:

- Add `home/tools/bin` to PATH.
- Preserve executable permissions where possible.
- Allow custom scripts and binaries.
- Do not require rebuilding the image when custom tools change.
- Avoid installing user-maintained tools directly into system directories.

Expected usage:

```bash
nmap
ffuf
my-custom-tool
```

Custom binaries and scripts should be independently manageable.

---

## 10. VPN Support and Networking

Support penetration-testing VPN connections.

Host directory:

```text
home/vpns/
```

Container directory:

```text
/root/vpns/
```

Requirements:

- Mount VPN configurations read-only.
- Support OpenVPN.
- Provide `/dev/net/tun`.
- Configure `NET_ADMIN` capability.
- Avoid unnecessary privileged mode.
- Support multiple VPN profiles.
- Document VPN connection and disconnection commands.
- Keep VPN credentials outside the repository.
- Ensure container networking does not accidentally expose services.

Example:

```bash
sudo openvpn --config /root/vpns/htb/profile.ovpn
```

### Networking Profiles

Design the infrastructure to support:

1. Default NAT networking.
2. VPN-enabled pentesting.
3. Optional isolated lab networks.
4. Optional service containers.

Do not assume macOS Docker Desktop supports Linux host networking or macvlan identically to native Linux.

Do not enable host networking by default.

---

## 11. Docker Compose Requirements

Implement `compose.yaml`.

Requirements:

- Build from `.devcontainer/Dockerfile`.
- Use `.env`.
- Configure container name and hostname.
- Configure restart policy.
- Enable `init: true`.
- Configure TTY and interactive mode.
- Configure persistent volumes.
- Configure SSH port mapping.
- Configure optional XRDP port mapping.
- Configure TUN device.
- Configure NET_ADMIN.
- Configure healthcheck.
- Support optional service profiles.

Default ports:

```dotenv
SSH_PORT=2222
XRDP_PORT=3389
```

Use environment variables instead of hardcoding configurable values.

Do not use privileged mode unless a documented requirement makes it unavoidable.

---

## 12. Dev Container Requirements

Implement `.devcontainer/devcontainer.json`.

Requirements:

- Reuse the Docker Compose service.
- Connect to the `kali` service.
- Use `/home/user(kali as default)` as workspace folder.
- Configure the non-root user.
- Forward SSH and XRDP ports.
- Configure useful VS Code extensions.
- Configure terminal shell.
- Support persistent workspace access.
- Avoid duplicate volume declarations when Compose already defines them.

The environment must work with:

```bash
docker compose up -d --build
```

and VS Code Dev Containers.

---

## 13. Environment Variables

Create `.env.example`.

Include:

```dotenv
# Container
CONTAINER_NAME=kali-workstation
KALI_USER=kali
KALI_UID=1000
KALI_GID=1000
TZ=Asia/Yangon

# Networking
SSH_PORT=2222
XRDP_PORT=3389

# Services
ENABLE_SSH=1
ENABLE_XRDP=0
ENABLE_POSTGRESQL=0
ENABLE_REDIS=0

# Features
INSTALL_XRDP=0
```

Requirements:

- Never commit `.env`.
- Never put private keys or sensitive VPN credentials in `.env.example`.
- Validate environment variables.
- Provide safe defaults.
- Document configuration options.

---

## 14. Security Requirements

- Run normal commands as non-root.
- Use `sudo` only when necessary.
- Disable SSH password authentication by default.
- Never commit private keys, credentials, or VPN secrets.
- Exclude wordlists and large artifacts from Git.
- Avoid unnecessary Linux capabilities.
- Avoid `privileged: true`.
- Use read-only mounts for sensitive configuration and wordlists.
- Avoid exposing unnecessary ports.
- Ensure services bind to appropriate interfaces.
- Do not weaken host filesystem permissions.
- Do not use destructive cleanup commands without explicit justification.

---

## 15. Git Ignore

Create a suitable `.gitignore`.

At minimum, exclude:

```gitignore
.env

# SSH
.ssh/*
!.ssh/authorized_keys

# VPN credentials and profiles
home/vpns/*
!home/vpns/.gitkeep

# Wordlists
home/wordlists/*

# Temporary files
*.log
*.tmp
*.swp
.DS_Store

# Lab artifacts
home/Documents/**/loot/
home/Documents/**/screenshots/
home/Documents/**/evidence/
```

Do not accidentally ignore source code, documentation, or custom scripts.

Review the treatment of VPN profiles and SSH public keys before committing. These files can contain sensitive information even when they are not private keys.

---

## 16. Documentation

Create `README.md` documenting:

1. Project overview.
2. Prerequisites.
3. Installation.
4. Environment configuration.
5. Docker Compose commands.
6. SSH access.
7. VS Code Dev Container usage.
8. VPN setup.
9. Wordlist setup.
10. Custom tools.
11. Networking architecture.
12. Troubleshooting.
13. Rebuilding and resetting the container.

Provide copy-pasteable commands.

---

## 17. Implementation Workflow

Implement the project in the following order.

### Phase 1 — Infrastructure

- Inspect the existing repository.
- Preserve existing useful files.
- Create the directory structure.
- Implement `.env.example`.
- Implement `.gitignore`.
- Implement Dockerfile.

### Phase 2 — Runtime

- Implement entrypoint.
- Implement SSH configuration.
- Implement optional XRDP configuration.
- Implement service management.
- Implement healthcheck.

### Phase 3 — Persistence

- Configure home directory.
- Configure workspace.
- Configure custom tools.
- Configure VPN mounts.
- Configure wordlist mounts.
- Validate permissions.

### Phase 4 — Docker Compose

- Implement compose.yaml.
- Configure networking.
- Configure capabilities and devices.
- Configure optional services.
- Validate Compose configuration.

### Phase 5 — Dev Container

- Implement devcontainer.json.
- Validate VS Code integration.
- Validate terminal and workspace access.

### Phase 6 — Testing

Test the following:

- Docker image builds successfully.
- Container starts successfully.
- Native ARM64 architecture is used.
- SSH key authentication works.
- SSH password authentication is disabled.
- Workspace files persist after container recreation.
- Custom tools are accessible through PATH.
- Wordlists are mounted correctly.
- VPN TUN device is accessible.
- XRDP works when enabled.
- Container can be rebuilt without losing host data.

### Phase 7 — Documentation

- Complete README.md.
- Document environment variables.
- Document networking.
- Document troubleshooting.
- Document optional services.

---

## 18. Acceptance Criteria

The project is complete when:

- [ ] Native ARM64 Kali container builds.
- [ ] Container starts through Docker Compose.
- [ ] Dev Container integration works.
- [ ] SSH key authentication works.
- [ ] Non-root Kali user works correctly.
- [ ] Workspace is persistent.
- [ ] Custom tools are mounted and accessible.
- [ ] VPN configurations are accessible.
- [ ] OpenVPN can use the TUN device.
- [ ] Wordlists are external to the image.
- [ ] Kali-compatible wordlist paths work.
- [ ] Optional services can be enabled independently.
- [ ] Container can be destroyed and recreated without losing data.
- [ ] No secrets are accidentally committed.
- [ ] Documentation is complete.

---

## 19. Instructions to AI Agents

When implementing this project:

1. Inspect existing files before changing anything.
2. Do not blindly overwrite existing configurations.
3. Implement working code, not pseudocode.
4. Do not leave TODO placeholders for required functionality.
5. Follow the defined directory structure.
6. Keep scripts modular and reusable.
7. Validate shell scripts with `shellcheck` where available.
8. Validate YAML and Docker Compose configurations.
9. Test every important feature.
10. Report any feature that cannot be tested in the current environment.
11. Do not claim successful execution without actual verification.
12. Update README.md whenever implementation details change.
13. Never delete user data, VPN files, wordlists, or lab evidence.
14. Prefer simple, maintainable solutions over unnecessary abstraction.

**Final objective:** Deliver a fully functional, reproducible, persistent Kali Linux workstation that can be rebuilt at any time without losing the host's pentesting environment or lab data.
