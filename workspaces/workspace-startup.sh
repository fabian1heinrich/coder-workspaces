#!/bin/sh
# Reconcile image-owned workspace state before the Coder agent starts: the
# approved VS Code-compatible extension set and any managed Python environment.
#
# The approved set is platform state: it is rebuilt from the read-only
# /opt/vsix image volume whenever that payload changes, so a VSIX withdrawn
# from the set cannot survive in the persistent home directory. An unchanged
# payload is not reinstalled, and all other state under /home/coder is left
# untouched.
set -eu

vsix_dir="${CODER_VSIX_DIR:-/opt/vsix}"
code_server_prefix="${CODER_CODE_SERVER_PREFIX:-/opt/code-server}"
extensions_dir="${CODER_EXTENSIONS_DIR:-${HOME}/.local/share/code-server/extensions}"
payload_marker=".coder-vsix-payload"
python_config_dir="${CODER_PYTHON_CONFIG_DIR:-/opt/project-config}"
python_environment="${CODER_PYTHON_ENVIRONMENT:-${HOME}/.venv}"

# Image volumes are immutable for a given digest, so the file names and sizes
# of the payload identify it without reading every byte at startup.
payload_fingerprint() {
  for vsix in "${vsix_dir}"/*.vsix; do
    [ -e "${vsix}" ] || continue
    printf '%s %s\n' "${vsix##*/}" "$(wc -c < "${vsix}")"
  done | LC_ALL=C sort | sha256sum | cut -d' ' -f1
}

payload_count() {
  count=0
  for vsix in "${vsix_dir}"/*.vsix; do
    [ -e "${vsix}" ] || continue
    count=$((count + 1))
  done
  printf '%s\n' "${count}"
}

sync_extensions() {
  [ -d "${vsix_dir}" ] || return 0
  [ "$(payload_count)" -gt 0 ] || return 0

  fingerprint="$(payload_fingerprint)"
  if [ "$(cat "${extensions_dir}/${payload_marker}" 2>/dev/null || true)" = "${fingerprint}" ]; then
    return 0
  fi

  staging="${extensions_dir}.staging"
  previous="${extensions_dir}.previous"
  rm -rf -- "${staging}" "${previous}"
  mkdir -p -- "${staging}"
  for vsix in "${vsix_dir}"/*.vsix; do
    [ -e "${vsix}" ] || continue
    "${code_server_prefix}/bin/code-server" \
      --extensions-dir "${staging}" \
      --force \
      --install-extension "${vsix}"
  done
  printf '%s\n' "${fingerprint}" > "${staging}/${payload_marker}"

  # Swap the complete set into place so a partially installed directory is
  # never observed, and the previous set disappears with it.
  mkdir -p -- "$(dirname -- "${extensions_dir}")"
  if [ -d "${extensions_dir}" ]; then
    mv -- "${extensions_dir}" "${previous}"
  fi
  mv -- "${staging}" "${extensions_dir}"
  rm -rf -- "${previous}"
}

sync_python_environment() {
  [ -r "${python_config_dir}/pyproject.toml" ] || return 0
  [ -r "${python_config_dir}/uv.lock" ] || return 0

  command -v uv >/dev/null 2>&1 || {
    printf 'workspace-startup: managed Python project requires uv\n' >&2
    return 1
  }

  # The project definition is immutable image content. Materialize only its
  # dependencies in persistent storage; the application source remains in the
  # independently cloned checkout and needs no copied pyproject.toml.
  UV_PROJECT_ENVIRONMENT="${python_environment}" \
    uv sync \
      --project "${python_config_dir}" \
      --locked \
      --all-groups \
      --no-install-project
  test -x "${python_environment}/bin/python"
}

sync_extensions
sync_python_environment
