#!/bin/sh
# Reconcile image-owned workspace state before the Coder agent starts: the
# approved VS Code-compatible extension set and any opted-in Python environment.
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
# Python templates pass the required environment path explicitly. A missing
# image environment variable must not silently skip Python initialization.
python_environment="${1:-}"

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
  # The Kubernetes operations template calls this without a Python path.
  [ -n "${python_environment}" ] || return 0

  if [ -r "${python_config_dir}/pyproject.toml" ] &&
    [ -r "${python_config_dir}/uv.lock" ]; then
    # uv sync creates a missing venv and restores the locked dependencies.
    UV_PROJECT_ENVIRONMENT="${python_environment}" \
      uv sync --offline --no-python-downloads \
        --project "${python_config_dir}" \
        --locked \
        --all-groups \
        --no-install-project
  elif [ -e "${python_config_dir}/pyproject.toml" ] ||
    [ -e "${python_config_dir}/uv.lock" ]; then
    printf 'workspace-startup: managed Python project configuration is incomplete or unreadable\n' >&2
    return 1
  elif [ ! -r "${python_environment}/pyvenv.cfg" ] ||
    [ ! -x "${python_environment}/bin/python" ]; then
    uv venv --offline --no-python-downloads \
      --python /usr/local/bin/python3 "${python_environment}"
  fi

  # Do not start the agent/editor with a missing or incorrectly located venv.
  "${python_environment}/bin/python" - "${python_environment}" <<'PY'
import os
import sys

if sys.prefix == sys.base_prefix or not os.path.samefile(sys.prefix, sys.argv[1]):
    raise SystemExit(f"workspace-startup: invalid Python environment at {sys.argv[1]}")
print(f"workspace-startup: Python environment ready at {sys.prefix}", flush=True)
PY
}

sync_extensions
sync_python_environment
