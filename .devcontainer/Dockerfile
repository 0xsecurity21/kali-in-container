# syntax=docker/dockerfile:1
# Kali CTF / pentest / bug-bounty / HTB toolbox + opencode agent configuration.
# Build context is the repository root (see compose.yaml / devcontainer.json).


FROM kalilinux/kali-rolling as base


ARG DEBIAN_FRONTEND=noninteractive
ARG LANG=C.UTF-8
ARG LC_ALL=C.UTF-8
ARG PIPX_HOME=/opt/pipx
ARG PIPX_BIN_DIR=/usr/local/bin
ARG USER=ctf
ARG USER_PASSWORD=ctf
ARG X_ARCH=amd64
ARG PLAYWRIGHT_BROWSERS_PATH=/home/ctf/.cache/ms-playwright

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/usr/local/bin \
    PLAYWRIGHT_BROWSERS_PATH=/home/ctf/.cache/ms-playwright

# ---------------------------------------------------------------------------
# System toolchain
#
# One apt layer keeps the image small: lists are fetched and removed once.
# Grouped by job so it stays auditable — web, recon, AD, pwn/rev, forensics,
# networking, and shell/utility tools.
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    7zip \
    amass apktool arjun \
    bat binutils binwalk binfmt-support bloodhound.py build-essential \
    ca-certificates cewl cifs-utils chromium commix crunch curl \
    dalfox dbus-x11 default-jdk-headless dirb dirsearch dnsutils dnsx \
    enum4linux-ng ewf-tools evil-winrm exiftool \
    fd-find feroxbuster ffuf file fonts-liberation foremost fzf \
    gdb gdb-multiarch git gnupg gobuster golang-go gowitness gss-ntlmssp \
    hashcat htop httpx-toolkit hydra \
    imagemagick iputils-ping \
    jadx john jq \
    katana krb5-user \
    ldap-utils less libc6-dbg libcap2-bin libffi-dev libssl-dev ltrace \
    man-db manpages masscan mitmproxy \
    naabu nasm net-tools netcat-openbsd netexec nfs-common nikto nmap nuclei \
    nodejs npm \
    onesixtyone openvpn openssh-client \
    patchelf pkg-config pipx pngcheck poppler-utils proxychains4 \
    python3 python3-capstone python3-dev python3-gmpy2 python3-impacket \
    python3-pip python3-pwntools python3-pycryptodome python3-ropgadget \
    python3-sympy python3-venv python3-z3 \
    qemu-system-x86 qemu-user qemu-user-static \
    radare2 responder ripgrep rpcbind ruby ruby-dev \
    seclists shellcheck sleuthkit smbclient smbmap smtp-user-enum snmp socat \
    sqlmap sshpass steghide strace subfinder sudo \
    tcpdump testdisk testssl.sh tesseract-ocr tmux tor traceroute tree tshark tzdata \
    unzip upx-ucl vim \
    wafw00f wfuzz wget whatweb whois wireguard-tools wordlists \
    xvfb xxd xz-utils \
    zip zsh zstd \
 && (setcap -r /usr/lib/nmap/nmap 2>/dev/null || true) \
 && ln -sf /usr/bin/batcat /usr/local/bin/bat \
 && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Go tools Kali does not package (pinned to latest; rebuilds pull upstream).
# ---------------------------------------------------------------------------
RUN GOBIN=/usr/local/bin GOPATH=/tmp/go GOCACHE=/tmp/go-cache \
      go install \
        github.com/lc/gau/v2/cmd/gau@latest \
        github.com/tomnomnom/waybackurls@latest \
        github.com/ropnop/kerbrute@latest \
 && rm -rf /tmp/go /tmp/go-cache

# Ruby-based pwn/stego helpers (need ruby-dev + build-essential above).
RUN gem install --no-document one_gadget seccomp-tools zsteg

# Python tools Kali does not package. pipx keeps each in its own environment.
RUN pipx install pwncat-cs \
 && pipx install certipy-ad \
 && pipx install volatility3 \
 && pipx install playwright \
 && pipx install frida-tools \
 && pipx install objection \
 && pipx install ldapdomaindump \
 && pipx install jwt-tool

# ---------------------------------------------------------------------------
# Unprivileged user + directories that compose mounts as named volumes.
# Creating them in the image gives the volumes the right ownership on first use.
# ---------------------------------------------------------------------------
RUN useradd --create-home --shell /usr/bin/zsh --uid 1000 ctf \
 && usermod --append --groups sudo ctf \
 && echo 'ctf ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ctf \
 && chmod 0440 /etc/sudoers.d/ctf \
 && mkdir -p /workspaces/ctf \
             /home/ctf/.local/bin /home/ctf/.local/share /home/ctf/.local/state \
             /home/ctf/.config /home/ctf/.cache /home/ctf/.claude \
             /home/ctf/.ssh /home/ctf/nuclei-templates \
 && chmod 700 /home/ctf/.ssh \
 && ln -sfn /usr/share/wordlists /home/ctf/wordlists \
 && chown -R ctf:ctf /workspaces/ctf /home/ctf \
 && git config --system --add safe.directory /workspaces/ctf

# Dotfiles + agent configuration. The source layout is .devcontainer/config/;
# ~/.config is a compose volume, so these files seed it on first creation.
COPY --chown=ctf:ctf .devcontainer/config/zsh/.zshrc /home/ctf/.zshrc
COPY --chown=ctf:ctf .devcontainer/config/vim/.vimrc /home/ctf/.vimrc
COPY --chown=ctf:ctf .devcontainer/config/git/.gitconfig /home/ctf/.gitconfig
COPY --chown=ctf:ctf .devcontainer/config/zsh/bin/*.sh /home/ctf/.local/bin/
COPY --chown=ctf:ctf .devcontainer/config/zsh/bootstrap.zsh /home/ctf/.config/zsh/bootstrap.zsh
COPY --chown=ctf:ctf .devcontainer/config/.opencode/ /home/ctf/.config/opencode/

RUN chmod 0755 /home/ctf/.local/bin/*.sh \
 && chown -R ctf:ctf /home/ctf/.config /home/ctf/.local

# ---------------------------------------------------------------------------
# Browser automation: system Chromium + Playwright's bundled Chromium.
# Playwright installs into ~/.cache (a volume), so it survives rebuilds.
# ---------------------------------------------------------------------------
RUN su -s /bin/sh ctf -c 'playwright install chromium'

# GEF is opt-in; load it with: gdb -x ~/.gdbinit-gef.py ./challenge
RUN curl -fsSL https://gef.blah.cat/py -o /home/ctf/.gdbinit-gef.py \
 && chown ctf:ctf /home/ctf/.gdbinit-gef.py

# Nuclei templates are seeded into ~/nuclei-templates (a volume).
RUN su -s /bin/sh ctf -c 'nuclei -update-templates -silent || true'

# Agent CLIs installed as the unprivileged user. PATH is set explicitly below,
# so the installers never need to modify shell rc files.
RUN su -s /bin/sh ctf -c 'curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path' \
 && su -s /bin/sh ctf -c 'curl -fsSL https://pi.dev/install.sh | sh' \
 && su -s /bin/sh ctf -c 'curl -fsSL https://claude.ai/install.sh | bash' \
 && chown -R ctf:ctf /home/ctf

# XDG paths point at the persisted volumes; keep in sync with compose.yaml.
ENV PATH="/home/ctf/.local/bin:/home/ctf/.opencode/bin:/home/ctf/.pi/bin:/usr/local/bin:${PATH}" \
    XDG_CONFIG_HOME=/home/ctf/.config \
    XDG_CACHE_HOME=/home/ctf/.cache \
    XDG_DATA_HOME=/home/ctf/.local/share \
    XDG_STATE_HOME=/home/ctf/.local/state \
    CLAUDE_CONFIG_DIR=/home/ctf/.claude \
    HISTFILE=/home/ctf/.local/state/zsh_history \
    SHELL=/usr/bin/zsh

WORKDIR /workspaces/ctf
USER ctf
CMD ["sleep", "infinity"]
