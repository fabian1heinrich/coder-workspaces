# syntax=docker/dockerfile:1.6
# Coder Community control-plane and built-in-provisioner runtime image.

# OpenTofu v1.12.1 minimal, pinned to its multi-architecture OCI manifest.
FROM ghcr.io/opentofu/opentofu@sha256:fbfeb438edb0d0116239096964595c7cbe57d9c9924359d8fa86297cf0f0f810 AS opentofu

# Coder v2.36.0, pinned to its multi-architecture OCI manifest.
FROM ghcr.io/coder/coder@sha256:215e6d4c1260e213a283dbac9b669b7bd79f5dd25974d72ae18b45c565f062bb AS provider-mirror

USER root
COPY --from=opentofu /usr/local/bin/tofu /usr/local/bin/tofu

ARG TARGETARCH
ARG CODER_PROVIDER_VERSION=2.18.0
ARG KUBERNETES_PROVIDER_VERSION=3.0.1

WORKDIR /work
# Coder expects the Terraform executable name. Using OpenTofu here is an
# explicit compatibility choice not officially supported by Coder:
# https://coder.com/docs/reference/glossary#opentofu
RUN set -eux; \
  ln -sf /usr/local/bin/tofu /usr/local/bin/terraform; \
  printf '%s\n' \
  'terraform {' \
  '  required_providers {' \
  '    coder = {' \
  '      source  = "registry.terraform.io/coder/coder"' \
  "      version = \"=${CODER_PROVIDER_VERSION}\"" \
  '    }' \
  '    kubernetes = {' \
  '      source  = "registry.terraform.io/hashicorp/kubernetes"' \
  "      version = \"=${KUBERNETES_PROVIDER_VERSION}\"" \
  '    }' \
  '  }' \
  '}' \
  > /work/main.tf; \
  tofu providers lock -platform="linux_${TARGETARCH}"; \
  tofu providers mirror -platform="linux_${TARGETARCH}" /out/providers; \
  cp /work/.terraform.lock.hcl /out/provider-lock.hcl

FROM ghcr.io/coder/coder@sha256:215e6d4c1260e213a283dbac9b669b7bd79f5dd25974d72ae18b45c565f062bb

USER root
ARG CODER_PROVIDER_VERSION=2.18.0
ARG KUBERNETES_PROVIDER_VERSION=3.0.1

COPY --from=opentofu /usr/local/bin/tofu /usr/local/bin/tofu
COPY --from=provider-mirror /out/providers /opt/tofu/providers
COPY --from=provider-mirror /out/provider-lock.hcl /opt/tofu/provider-lock.hcl

RUN set -eux; \
  ln -sf /usr/local/bin/tofu /usr/local/bin/terraform; \
  /opt/coder version >/dev/null; \
  tofu version >/dev/null; \
  mkdir -p /etc/tofu; \
  printf '%s\n' \
  'provider_installation {' \
  '  filesystem_mirror {' \
  '    path = "/opt/tofu/providers"' \
  '  }' \
  '}' \
  > /etc/tofu/offline.tfrc; \
  chmod -R a=rX /opt/tofu /etc/tofu

LABEL org.opencontainers.image.title="Coder air-gapped control plane" \
  org.opencontainers.image.description="Coder Community control plane with built-in offline Kubernetes provisioning" \
  org.opencontainers.image.source="https://github.com/fabian1heinrich/coder-workspaces" \
  org.opencontainers.image.version="2.36.0" \
  io.coder.runtime.role="control-plane-and-builtin-provisioner" \
  io.coder.builtin-provisioners="enabled-by-deployment-configuration" \
  io.coder.opentofu.version="1.12.1" \
  io.coder.provider.coder.version="${CODER_PROVIDER_VERSION}" \
  io.coder.provider.kubernetes.version="${KUBERNETES_PROVIDER_VERSION}" \
  io.coder.opentofu.source-image="ghcr.io/opentofu/opentofu@sha256:fbfeb438edb0d0116239096964595c7cbe57d9c9924359d8fa86297cf0f0f810" \
  io.coder.source-image="ghcr.io/coder/coder@sha256:215e6d4c1260e213a283dbac9b669b7bd79f5dd25974d72ae18b45c565f062bb"

ENV TF_CLI_CONFIG_FILE=/etc/tofu/offline.tfrc
USER 1000:1000
