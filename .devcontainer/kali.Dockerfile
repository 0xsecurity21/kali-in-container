# syntax=docker/dockerfile:1.7

# ============================================================
# GLOBAL CONFIGURATION
# ============================================================

ARG KALI_IMAGE=kalilinux/kali-rolling:latest
ARG KALI_USER=kali
ARG KALI_UID=1000
ARG KALI_GID=1000
ARG INSTALL_RDP=1

# ============================================================
# STAGE 1: BASE
# Essential system and development utilities
# ============================================================

FROM ${KALI_IMAGE} AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        git \
        sudo \
        vim \
        nano \
        jq \
        unzip \
        zip \
        tar \
        xz-utils \
        tmux \
        zsh \
        bash-completion \
        less \
        file \
        tree \
        htop \
        procps \
        lsof \
        strace \
        iproute2 \
        iputils-ping \
        net-tools \
        dnsutils \
        netcat-openbsd \
        socat \
        python3 \
        python3-pip \
        python3-venv \
        pipx \
        golang \
        build-essential \
        pkg-config


# ============================================================
# STAGE 2: PENTEST / CTF TOOLKIT
# Common tools for HTB, CTF and security assessments
# ============================================================

FROM base AS pentest

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        nmap \
        netexec \
        ffuf \
        gobuster \
        feroxbuster \
        sqlmap \
        nikto \
        nuclei \
        hydra \
        john \
        hashcat \
        smbclient \
        enum4linux-ng \
        impacket-scripts \
        whatweb \
        exploitdb \
        seclists


# ============================================================
# STAGE 3: KALI HEADLESS
# Full official Kali headless metapackage
# ============================================================

FROM pentest AS headless

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    apt-get install -y kali-linux-headless


# ============================================================
# STAGE 4: DESKTOP (OPTIONAL)
# XFCE + xrdp. Kept separate so INSTALL_RDP=0 skips the layer.
# ============================================================

FROM headless AS desktop

ARG INSTALL_RDP=1

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    if [ "${INSTALL_RDP}" = "1" ]; then \
        apt-get install -y --no-install-recommends \
            xfce4 \
            xfce4-terminal \
            xfce4-goodies \
            dbus \
            dbus-x11 \
            fonts-dejavu-core \
            x11-xserver-utils \
            xrdp \
            xorgxrdp; \
    fi


# ============================================================
# STAGE 5: SERVICES / FINAL
# User, SSH, AI dirs, optional RDP wiring, entrypoint
# ============================================================

FROM desktop AS final

ARG KALI_USER=kali
ARG KALI_UID=1000
ARG KALI_GID=1000
ARG INSTALL_RDP=1

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-server \
        nodejs \
        npm \
        dbus-x11

# Create non-root user
RUN if ! getent passwd "${KALI_USER}" >/dev/null; then \
        if ! getent group "${KALI_GID}" >/dev/null; then \
            groupadd -g "${KALI_GID}" "${KALI_USER}"; \
        fi && \
        useradd -m \
            -u "${KALI_UID}" \
            -g "${KALI_GID}" \
            -s /usr/bin/zsh \
            "${KALI_USER}"; \
    fi && \
    mkdir -p /etc/sudoers.d && \
    echo "${KALI_USER} ALL=(ALL) NOPASSWD:ALL" \
        > "/etc/sudoers.d/${KALI_USER}" && \
    chmod 0440 "/etc/sudoers.d/${KALI_USER}" && \
    visudo -cf /etc/sudoers

# SSH: key-only, no root login
RUN mkdir -p /run/sshd /etc/ssh/sshd_config.d && \
    printf '%s\n' \
        'PermitRootLogin no' \
        'PubkeyAuthentication yes' \
        'PasswordAuthentication no' \
        'KbdInteractiveAuthentication no' \
        "AllowUsers ${KALI_USER}" \
        > /etc/ssh/sshd_config.d/agentic.conf && \
    sshd -t

# AI / MCP directories
RUN mkdir -p \
        /workspace \
        /opt/agentic \
        /opt/agentic/venvs \
        /opt/agentic/scripts \
        "/home/${KALI_USER}/.config" \
        "/home/${KALI_USER}/.local/bin" \
        "/home/${KALI_USER}/.cache" \
    && chown -R "${KALI_USER}:${KALI_GID}" \
        "/home/${KALI_USER}" \
        /opt/agentic

# RDP wiring: XFCE session, xrdp sockets, TLS key access
RUN if [ "${INSTALL_RDP}" = "1" ]; then \
        printf '%s\n' \
            '#!/bin/sh' \
            'if [ -r /etc/default/locale ]; then' \
            '  . /etc/default/locale' \
            '  export LANG' \
            'fi' \
            'exec dbus-launch --exit-with-session startxfce4' \
            > /etc/xrdp/startwm.sh && \
        chmod 0755 /etc/xrdp/startwm.sh && \
        getent group ssl-cert >/dev/null || groupadd --system ssl-cert; \
        usermod -aG ssl-cert xrdp && \
        mkdir -p /var/run/xrdp/sockdir /run/dbus && \
        chown xrdp:xrdp /var/run/xrdp /var/run/xrdp/sockdir && \
        chmod 0755 /var/run/xrdp /var/run/xrdp/sockdir; \
    fi

# Runtime entrypoint
COPY .devcontainer/entrypoint.sh /usr/local/bin/agentic-entrypoint

RUN chmod +x /usr/local/bin/agentic-entrypoint

ENV WORKSPACE=/workspace \
    KALI_USER=${KALI_USER}

WORKDIR /workspace

EXPOSE 22 3389

ENTRYPOINT ["/bin/bash", "/usr/local/bin/agentic-entrypoint"]

CMD ["sleep", "infinity"]
