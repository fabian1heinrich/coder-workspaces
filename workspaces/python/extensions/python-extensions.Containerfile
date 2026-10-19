# syntax=docker/dockerfile:1.6

FROM ghcr.io/coder/code-server@sha256:ccd326184d71efc5ebb94155eda7bb30153902342a35dbc8525450d81aa55012 AS validator

ARG TARGETARCH

RUN mkdir -p \
  /home/coder/vsix \
  /tmp/code-server-data \
  /tmp/code-server-extensions

COPY --chmod=0444 workspaces/python/extensions/python-extensions.lock /tmp/python-extensions.lock

# The lock records each approved extension's immutable version, platform,
# source URL, and VSIX checksum.
RUN set -eu; \
  if [ "${TARGETARCH}" != "amd64" ]; then \
  printf 'Unsupported extension architecture: %s (only amd64 is supported)\n' "${TARGETARCH}" >&2; \
  exit 1; \
  fi; \
  extension_count=0; \
  while IFS='|' read -r extension_id version platform expected_sha256 download_url; do \
  case "${extension_id}" in ''|'#'*) continue ;; esac; \
  extension_count=$((extension_count + 1)); \
  artifact="/home/coder/vsix/${extension_id}-${version}.vsix"; \
  printf 'Fetching %s@%s (%s)\n' "${extension_id}" "${version}" "${platform}"; \
  curl --compressed --fail --show-error --silent --location \
  "${download_url}" --output "${artifact}"; \
  printf '%s  %s\n' "${expected_sha256}" "${artifact}" | sha256sum --check --status; \
  done < /tmp/python-extensions.lock; \
  test "$(find /home/coder/vsix -maxdepth 1 -type f -name '*.vsix' | wc -l)" -eq "${extension_count}"

# Installing every local VSIX with networking disabled proves that the bundle
# is compatible with this code-server release and has no missing hard dependency.
RUN --network=none set -eu; \
  expected_extension_count=$(find /home/coder/vsix -maxdepth 1 -type f -name '*.vsix' | wc -l); \
  for extension in /home/coder/vsix/*.vsix; do \
  code-server \
  --user-data-dir /tmp/code-server-data \
  --extensions-dir /tmp/code-server-extensions \
  --install-extension "${extension}"; \
  done; \
  test "$(code-server \
  --user-data-dir /tmp/code-server-data \
  --extensions-dir /tmp/code-server-extensions \
  --list-extensions | wc -l)" -eq "${expected_extension_count}"

FROM scratch

LABEL org.opencontainers.image.title="Coder Python approved VSIX extension set" \
  org.opencontainers.image.description="Offline VS Code extension payload for the Python workspace" \
  org.opencontainers.image.source="https://github.com/fabian1heinrich/coder-workspaces" \
  org.opencontainers.image.version="0.1.0" \
  io.coder.extension-set="python" \
  io.coder.code-server.version="4.135.0" \
  io.coder.code-server.image="ghcr.io/coder/code-server@sha256:ccd326184d71efc5ebb94155eda7bb30153902342a35dbc8525450d81aa55012"

# The image root becomes /opt/vsix when consumed as a Kubernetes image volume.
COPY --from=validator --chown=1000:1000 /home/coder/vsix/ /
