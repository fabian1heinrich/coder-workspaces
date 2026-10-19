# syntax=docker/dockerfile:1.6

FROM ghcr.io/coder/code-server@sha256:ccd326184d71efc5ebb94155eda7bb30153902342a35dbc8525450d81aa55012 AS source

USER root

ARG CODE_SERVER_VERSION=4.135.0
ARG TARGETARCH

# Recreate the layout produced by code-server's standalone installer. The
# relative link remains valid when the payload image is mounted at an arbitrary
# installation prefix, such as /opt/vscode-server.
RUN set -eu; \
  mkdir -p /opt/code-server/bin /opt/code-server/lib; \
  cp -a /usr/lib/code-server "/opt/code-server/lib/code-server-${CODE_SERVER_VERSION}"; \
  ln -s "../lib/code-server-${CODE_SERVER_VERSION}/bin/code-server" \
  /opt/code-server/bin/code-server; \
  /opt/code-server/bin/code-server --version \
  | awk -v expected="${CODE_SERVER_VERSION}" \
  '$1 == expected { found = 1 } END { exit !found }'

FROM scratch

ARG CODE_SERVER_VERSION=4.135.0

LABEL org.opencontainers.image.title="Coder code-server standalone payload" \
  org.opencontainers.image.description="Read-only code-server payload for an air-gapped Coder workspace" \
  org.opencontainers.image.source="https://github.com/fabian1heinrich/coder-workspaces" \
  org.opencontainers.image.version="${CODE_SERVER_VERSION}" \
  io.coder.code-server.version="${CODE_SERVER_VERSION}" \
  io.coder.code-server.source-image="ghcr.io/coder/code-server@sha256:ccd326184d71efc5ebb94155eda7bb30153902342a35dbc8525450d81aa55012" \
  io.coder.image-volume.mount-path="/opt/vscode-server"

# The image root becomes /opt/vscode-server when consumed as a Kubernetes
# image volume. Runtime configuration, extensions, and user data stay outside
# this read-only image.
COPY --from=source /opt/code-server/ /
