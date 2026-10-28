# uv 0.8.15, shared by sandbox and managed project workspaces.
FROM ghcr.io/astral-sh/uv@sha256:a5727064a0de127bdb7c9d3c1383f3a9ac307d9f2d8a391edc7896c54289ced0 AS uv

FROM mcr.microsoft.com/devcontainers/python:3.2.6-3.13-trixie@sha256:5ea7e72d3c1beb6aefdfea8001483345c39af4898e22f2c543deb6a00802ede4 AS runtime

ARG IMAGE_VERSION=0.1.0

# The upstream devcontainer account is named vscode. Rename it in place so all
# files that already belong to UID/GID 1000 remain accessible, then assert the
# complete account contract required by the restricted pod security context.
RUN set -eux; \
    test "$(id -u vscode)" = "1000"; \
    test "$(id -g vscode)" = "1000"; \
    test "$(getent group 1000 | cut -d: -f1)" = "vscode"; \
    groupmod --new-name coder vscode \
    && usermod --login coder \
      --home /home/coder \
      --move-home \
      --shell /usr/bin/zsh \
      --gid coder \
      vscode \
    && sed 's/vscode/coder/g' /etc/sudoers.d/vscode > /etc/sudoers.d/coder \
    && chmod 0440 /etc/sudoers.d/coder \
    && rm /etc/sudoers.d/vscode \
    && install -d -o coder -g coder -m 0755 \
      /home/coder \
      /home/coder/.cache \
      /home/coder/.config \
      /home/coder/.local \
    && chown -R coder:coder /home/coder \
    && test "$(id -u coder)" = "1000" \
    && test "$(id -g coder)" = "1000" \
    && test "$(getent group 1000 | cut -d: -f1)" = "coder" \
    && test "$(getent passwd coder | cut -d: -f6-7)" = "/home/coder:/usr/bin/zsh" \
    && test "$(stat -c '%u:%g:%a' /home/coder)" = "1000:1000:755" \
    && grep -Eq '^coder[[:space:]]+ALL=' /etc/sudoers.d/coder \
    && ! getent passwd vscode \
    && ! getent group vscode

# Workspace startup is repo-owned shell, so it lives in the image instead of
# being embedded in a template pod manifest.
COPY --chown=root:root --chmod=0555 \
    workspaces/workspace-startup.sh \
    /usr/local/bin/workspace-startup
COPY --from=uv --chmod=0555 /uv /uvx /usr/local/bin/
COPY --chown=root:root --chmod=0444 \
    workspaces/python/images/activate-venv.sh \
    /etc/profile.d/coder-venv.sh
# Login Bash reads profile.d; interactive Bash and Zsh also activate it.
# Keep these hooks outside the PVC-backed home, including for existing homes.
RUN printf '\n. /etc/profile.d/coder-venv.sh\n' >> /etc/bash.bashrc \
    && printf '\n. /etc/profile.d/coder-venv.sh\n' >> /etc/zsh/zshrc

ENV HOME=/home/coder \
    SHELL=/usr/bin/zsh \
    USER=coder \
    LOGNAME=coder \
    CODER_PYTHON_ENVIRONMENT=/home/coder/.venv \
    VIRTUAL_ENV=/home/coder/.venv \
    UV_OFFLINE=true \
    UV_PYTHON_DOWNLOADS=never \
    PATH="/home/coder/.venv/bin:${PATH}"

USER coder
WORKDIR /home/coder

LABEL org.opencontainers.image.title="Coder Python workspace runtime" \
      org.opencontainers.image.description="Python dev container runtime for an air-gapped Coder workspace" \
      org.opencontainers.image.source="https://github.com/fabian1heinrich/coder-workspaces" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      io.coder.workspace.runtime="python" \
      io.coder.workspace.source-image="mcr.microsoft.com/devcontainers/python:3.2.6-3.13-trixie@sha256:5ea7e72d3c1beb6aefdfea8001483345c39af4898e22f2c543deb6a00802ede4"

FROM runtime AS project

ARG PROJECT
ARG IMAGE_VERSION=0.1.0

USER root
RUN install -d -o 1000 -g 1000 -m 0755 /opt/project-config /opt/uv-cache
COPY --chown=1000:1000 --chmod=0444 workspaces/python/images/${PROJECT}/pyproject.toml workspaces/python/images/${PROJECT}/uv.lock /opt/project-config/

ENV UV_CACHE_DIR=/opt/uv-cache \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=.venv

USER 1000:1000
WORKDIR /opt/project-config
RUN UV_OFFLINE=false uv sync --locked --all-groups --no-install-project \
    && rm -rf .venv \
    && test -n "$(find /opt/uv-cache -type f -print -quit)"

USER root
RUN chmod -R a-w /opt/project-config \
    && chmod -R a=rX /opt/project-config \
    && chmod -R u+rwX,go=rX /opt/uv-cache

# The managed config stays immutable in the image while its environment lives
# on the persistent home volume. workspace-startup syncs it before the Coder
# agent starts; every child process then sees the environment as active.
ENV UV_PROJECT=/opt/project-config \
    UV_PROJECT_ENVIRONMENT=/home/coder/.venv

USER 1000:1000
WORKDIR /home/coder

LABEL org.opencontainers.image.title="${PROJECT} Python environment" \
      org.opencontainers.image.description="Prebuilt offline uv environment for ${PROJECT}" \
      org.opencontainers.image.source="https://github.com/fabian1heinrich/coder-workspaces" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      io.coder.project.name="${PROJECT}" \
      io.coder.project.environment.python="3.13" \
      io.coder.project.environment.uv="0.8.15"
