# syntax=docker/dockerfile:1.6

# Template publication is a Coder API operation, so the runner is the pinned
# Coder CLI and nothing else: no OpenTofu, no provider mirror, and no state
# backend. The publisher code itself arrives at runtime from the deployed
# package, which keeps this image generic across releases.
FROM ghcr.io/coder/coder@sha256:215e6d4c1260e213a283dbac9b669b7bd79f5dd25974d72ae18b45c565f062bb

USER root

RUN set -eux; \
  /opt/coder version >/dev/null; \
  command -v bash; \
  command -v sha256sum; \
  install -d -o coder -g coder -m 0755 /workspace /workspace/home /workspace/templates

LABEL org.opencontainers.image.title="Coder template publisher runtime" \
  org.opencontainers.image.description="Generic Coder CLI runtime for publishing workspace templates offline" \
  org.opencontainers.image.version="0.1.0" \
  org.opencontainers.image.source="https://github.com/fabian1heinrich/coder-workspaces" \
  io.coder.runtime.role="template-publisher" \
  io.coder.source-image="ghcr.io/coder/coder@sha256:215e6d4c1260e213a283dbac9b669b7bd79f5dd25974d72ae18b45c565f062bb"

ENV HOME=/workspace/home

WORKDIR /workspace
USER 1000:1000
ENTRYPOINT ["/usr/bin/bash"]
