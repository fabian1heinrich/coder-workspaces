# syntax=docker/dockerfile:1.6

FROM ghcr.io/opentofu/opentofu@sha256:fbfeb438edb0d0116239096964595c7cbe57d9c9924359d8fa86297cf0f0f810 AS opentofu

# The Coder base supplies a trusted CA bundle and a non-root runtime user while
# sharing its large layers with the control-plane image.
FROM ghcr.io/coder/coder@sha256:215e6d4c1260e213a283dbac9b669b7bd79f5dd25974d72ae18b45c565f062bb AS provider-mirror

USER root
COPY --from=opentofu /usr/local/bin/tofu /usr/local/bin/tofu

ARG TARGETARCH
ARG CODERD_PROVIDER_VERSION=0.0.23

WORKDIR /work
RUN set -eux; \
  printf '%s\n' \
  'terraform {' \
  '  required_providers {' \
  '    coderd = {' \
  '      source  = "registry.terraform.io/coder/coderd"' \
  "      version = \"=${CODERD_PROVIDER_VERSION}\"" \
  '    }' \
  '  }' \
  '}' \
  > /work/main.tf; \
  tofu providers lock -platform="linux_${TARGETARCH}"; \
  tofu providers mirror -platform="linux_${TARGETARCH}" /out/providers; \
  cp /work/.terraform.lock.hcl /out/provider-lock.hcl

FROM ghcr.io/coder/coder@sha256:215e6d4c1260e213a283dbac9b669b7bd79f5dd25974d72ae18b45c565f062bb

USER root
ARG CODERD_PROVIDER_VERSION=0.0.23

COPY --from=opentofu /usr/local/bin/tofu /usr/local/bin/tofu
COPY --from=provider-mirror /out/providers /opt/tofu/providers
COPY --from=provider-mirror /out/provider-lock.hcl /opt/tofu/provider-lock.hcl

RUN set -eux; \
  tofu version >/dev/null; \
  mkdir -p /etc/tofu /workspace/config /workspace/cache /workspace/state; \
  printf '%s\n' \
  'provider_installation {' \
  '  filesystem_mirror {' \
  '    path = "/opt/tofu/providers"' \
  '  }' \
  '}' \
  > /etc/tofu/offline.tfrc; \
  chown -R coder:coder /workspace; \
  chmod -R a=rX /opt/tofu /etc/tofu

LABEL org.opencontainers.image.title="Coder OpenTofu provider runner" \
  org.opencontainers.image.description="Reusable OpenTofu runner with Coder CLI and an offline coder/coderd provider mirror" \
  org.opencontainers.image.version="0.1.0" \
  org.opencontainers.image.source="https://github.com/fabian1heinrich/coder-workspaces" \
  io.coder.runtime.role="coderd-provider" \
  io.coder.opentofu.version="1.12.1" \
  io.coder.provider.coderd.version="${CODERD_PROVIDER_VERSION}" \
  io.coder.opentofu.source-image="ghcr.io/opentofu/opentofu@sha256:fbfeb438edb0d0116239096964595c7cbe57d9c9924359d8fa86297cf0f0f810"

ENV TF_CLI_CONFIG_FILE=/etc/tofu/offline.tfrc \
  TF_DATA_DIR=/workspace/cache/tofu \
  TF_IN_AUTOMATION=1 \
  TF_INPUT=0 \
  HOME=/workspace/cache/home

WORKDIR /workspace/config
USER 1000:1000
ENTRYPOINT ["/usr/local/bin/tofu"]
