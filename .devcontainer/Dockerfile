# syntax=docker/dockerfile:1
FROM kalilinux/kali-rolling:latest

ARG KALI_USER=kali
ARG KALI_UID=1000
ARG KALI_GID=1000
ARG INSTALL_XRDP=0
ARG INSTALL_PENTEST=1
ARG INSTALL_DEV=0
ARG INSTALL_PROXY=1
ARG TZ=Etc/UTC

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color \
    PATH=/opt/custom-tools/bin:/home/${KALI_USER}/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    ZDOTDIR=/home/${KALI_USER}/.config/zsh

COPY .devcontainer/scripts/install-tools.sh /usr/local/libexec/install-tools
RUN chmod 0755 /usr/local/libexec/install-tools \
    && /usr/local/libexec/install-tools "${INSTALL_XRDP}" "${INSTALL_PENTEST}" "${INSTALL_DEV}" "${INSTALL_PROXY}" \
    && ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
    && echo "${TZ}" > /etc/timezone

RUN if getent group "${KALI_GID}" >/dev/null; then \
        group_name="$(getent group "${KALI_GID}" | cut -d: -f1)"; \
    else \
        groupadd --gid "${KALI_GID}" "${KALI_USER}"; group_name="${KALI_USER}"; \
    fi \
    && if ! id "${KALI_USER}" >/dev/null 2>&1; then \
        if getent passwd "${KALI_UID}" >/dev/null; then \
            echo "KALI_UID ${KALI_UID} is already used by '$(getent passwd "${KALI_UID}" | cut -d: -f1)'; set a free KALI_UID in .env" >&2; exit 1; \
        fi; \
        useradd --uid "${KALI_UID}" --gid "${group_name}" --create-home --shell /usr/bin/zsh "${KALI_USER}"; \
    fi \
    && usermod --append --groups sudo "${KALI_USER}" \
    && passwd --delete "${KALI_USER}" \
    && echo "${KALI_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${KALI_USER}" \
    && chmod 0440 "/etc/sudoers.d/${KALI_USER}" \
    && mkdir -p /workspace /opt/custom-tools /root/vpns /usr/share/wordlists /run/sshd /etc/ssh/sshd_config.d \
    && chown "${KALI_UID}:${KALI_GID}" /workspace /opt/custom-tools \
    && chmod 0755 /workspace /opt/custom-tools

COPY .devcontainer/config/sshd_config /etc/ssh/sshd_config.d/workstation.conf
COPY .devcontainer/config/proxychains4.conf /etc/proxychains4.conf
COPY .devcontainer/config/supervisord.conf /etc/supervisor/conf.d/workstation.conf
COPY .devcontainer/scripts/configure-ssh.sh /usr/local/libexec/configure-ssh
COPY .devcontainer/scripts/configure-xrdp.sh /usr/local/libexec/configure-xrdp
COPY .devcontainer/scripts/healthcheck.sh /usr/local/bin/workstation-healthcheck
COPY .devcontainer/entrypoint.sh /usr/local/bin/workstation-entrypoint
RUN chmod 0755 /usr/local/libexec/configure-ssh /usr/local/libexec/configure-xrdp \
    /usr/local/bin/workstation-healthcheck /usr/local/bin/workstation-entrypoint

ENV KALI_USER=${KALI_USER} \
    WORKSPACE=/home/${KALI_USER}

WORKDIR /home/${KALI_USER}
EXPOSE 22 3389
ENTRYPOINT ["/usr/local/bin/workstation-entrypoint"]
CMD ["sleep", "infinity"]
