# One Containerfile owns the shared runtime and project image targets. The uv
# image is only a pinned binary source for project builds.
FROM ghcr.io/astral-sh/uv@sha256:a5727064a0de127bdb7c9d3c1383f3a9ac307d9f2d8a391edc7896c54289ced0 AS uv

# VS Code Python devcontainer 1-3.13-bookworm, pinned to its
# multi-architecture manifest. The runtime target contains no project
# dependencies, source, virtual environments, VS Code Web, or extensions.
FROM mcr.microsoft.com/devcontainers/python@sha256:0aa711e570b306c02946cdda67587ce8c65978dbb65691341cbcfd4854dfcfff AS runtime

# The upstream devcontainer account is named vscode. Keep its UID/GID so the
# restricted pod security context remains valid, but expose the workspace user
# and login shell expected by the template.
RUN groupmod --new-name coder vscode \
    && usermod --login coder \
      --home /home/coder \
      --move-home \
      --shell /usr/bin/zsh \
      --gid coder \
      vscode \
    && sed 's/^vscode /coder /' /etc/sudoers.d/vscode > /etc/sudoers.d/coder \
    && chmod 0440 /etc/sudoers.d/coder \
    && rm /etc/sudoers.d/vscode \
    && test "$(getent passwd coder | cut -d: -f6-7)" = "/home/coder:/usr/bin/zsh"

ENV HOME=/home/coder \
    SHELL=/usr/bin/zsh

USER coder
WORKDIR /home/coder

LABEL org.opencontainers.image.title="Coder Python workspace runtime" \
      org.opencontainers.image.description="VS Code Python devcontainer runtime for an air-gapped Coder workspace" \
      org.opencontainers.image.source="https://github.com/fabian1heinrich/coder-workspaces" \
      org.opencontainers.image.version="0.1.0" \
      io.coder.workspace.runtime="python" \
      io.coder.workspace.source-image="mcr.microsoft.com/devcontainers/python@sha256:0aa711e570b306c02946cdda67587ce8c65978dbb65691341cbcfd4854dfcfff"

# Project images share the runtime layers above and add only a selected locked
# environment. Build the runtime target directly for a plain Python workspace.
FROM runtime AS project

ARG PROJECT
ARG SOURCE_REVISION

USER root
RUN install -d -o 1000 -g 1000 -m 0755 /opt/project-config /opt/uv-cache
COPY --from=uv --chmod=0555 /uv /uvx /usr/local/bin/
COPY --chown=1000:1000 --chmod=0444 workspaces/python/images/${PROJECT}/pyproject.toml workspaces/python/images/${PROJECT}/uv.lock /opt/project-config/

ENV UV_CACHE_DIR=/opt/uv-cache \
    UV_LINK_MODE=copy \
    UV_OFFLINE=true \
    UV_PROJECT_ENVIRONMENT=.venv \
    UV_PYTHON_DOWNLOADS=never

USER 1000:1000
WORKDIR /opt/project-config
RUN UV_OFFLINE=false uv sync --locked --all-groups --no-install-project \
    && rm -rf .venv \
    && test -n "$(find /opt/uv-cache -type f -print -quit)"

USER root
RUN chmod -R a-w /opt/project-config \
    && chmod -R a=rX /opt/project-config \
    && chmod -R u+rwX,go=rX /opt/uv-cache

USER 1000:1000
WORKDIR /home/coder

LABEL org.opencontainers.image.title="${PROJECT} Python environment" \
      org.opencontainers.image.description="Prebuilt offline uv environment for ${PROJECT}" \
      org.opencontainers.image.source="https://github.com/fabian1heinrich/coder-workspaces" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      io.coder.project.name="${PROJECT}" \
      io.coder.project.environment.python="3.13" \
      io.coder.project.environment.uv="0.8.15"
