#!/usr/bin/env bash
# Publish the repository-owned templates with the Coder CLI.
#
# Publication is stateless and idempotent. A template version is named after
# the hash of the template's files and of the variables it is published with,
# so unchanged input republishes nothing and no backend, lock, or imported
# state is needed to decide that.
set -euo pipefail
umask 077

coder="${CODER_CLI:-/opt/coder}"
template_version=0.1.0
source_dir="${PUBLISHER_SOURCE_DIR:-/source}"
work_dir="${PUBLISHER_WORK_DIR:-/workspace/templates}"
publish_id="${PUBLISH_ID:-}"

# /workspace is an emptyDir, so the writable home the CLI expects is created
# at runtime rather than baked into the image.
mkdir -p -- "${HOME:?HOME is required}"

: "${CODER_TOKEN:?CODER_TOKEN is required}"
: "${CODER_URL:?CODER_URL is required}"
export CODER_SESSION_TOKEN="${CODER_TOKEN}"
export CODER_URL

# name|variable prefix|source subdirectory|icon|description
templates=(
  'python-workspace|python|python-template|/icon/python.svg|Air-gapped Python workspaces on Kubernetes'
  'k8s-dev|k8s_dev|k8s-dev-template|/icon/k8s.svg|Air-gapped workspace for operating Kubernetes clusters'
)

# ConfigMap mounts are symlink farms, so the directory is dereferenced into a
# plain tree before the CLI archives it.
stage() {
  local name="$1" subdirectory="$2" staged="${work_dir}/$1"
  rm -rf -- "${staged}"
  mkdir -p -- "${staged}"
  cp -RL "${source_dir}/${subdirectory}/." "${staged}/"
  printf '%s\n' "${staged}"
}

# Every variable the template declares and the environment sets is published
# with it. TF_VAR_<prefix>_<name> overrides TF_VAR_<name> for one template, so
# templates can share a value or take their own. A variable the environment
# leaves unset keeps the template's own default.
template_variable_arguments=()
collect_variables() {
  local staged="$1" prefix="$2" variables_file="$3"
  local name value environment_name line
  template_variable_arguments=()
  : >"${variables_file}"
  while IFS= read -r name; do
    environment_name="TF_VAR_${prefix}_${name}"
    if [[ -z "${!environment_name+set}" ]]; then
      environment_name="TF_VAR_${name}"
    fi
    if [[ -n "${!environment_name+set}" ]]; then
      value="${!environment_name}"
      template_variable_arguments+=("--variable" "${name}=${value}")
      # Coder's string-array flag splits values on commas. Use its YAML
      # variables file instead so structured string values remain intact.
      printf '%s: |-\n' "${name}" >>"${variables_file}"
      while IFS= read -r line || [[ -n "${line}" ]]; do
        printf '  %s\n' "${line}" >>"${variables_file}"
      done <<<"${value}"
    fi
  done < <(
    grep -hoE '^variable "[a-z0-9_]+"' "${staged}"/*.tf |
      cut -d'"' -f2 |
      LC_ALL=C sort -u
  )
}

# The revision covers the template files and the published variable values, so
# a changed image digest produces a new version just as a changed file does.
content_revision() {
  local staged="$1"
  shift
  {
    find "${staged}" -type f -exec sha256sum {} + |
      sed "s| ${staged}/| |" |
      LC_ALL=C sort -k2
    printf '%s\n' "$@"
  } | sha256sum | cut -c1-12
}

template_exists() {
  # The runner image carries no JSON processor, so match the template name in
  # the API response directly.
  "${coder}" templates list --output json |
    grep -Eq "\"name\"[[:space:]]*:[[:space:]]*\"$1\""
}

# A missing template makes this list fail, which is the same answer as a
# missing version: the version has to be pushed.
version_row() {
  local name="$1" version="$2"
  "${coder}" templates versions list "${name}" --column name,active 2>/dev/null |
    awk -v version="${version}" '$1 == version { print; exit }'
}

published_templates=()
for entry in "${templates[@]}"; do
  IFS='|' read -r name prefix subdirectory icon description <<<"${entry}"

  staged="$(stage "${name}" "${subdirectory}")"
  variables_file="${work_dir}/.${name}-variables.yaml"
  collect_variables "${staged}" "${prefix}" "${variables_file}"
  revision="$(content_revision "${staged}" "${template_variable_arguments[@]}")"
  version="${template_version}-${revision}${publish_id:+-${publish_id}}"
  published_templates+=("${name}")

  row="$(version_row "${name}" "${version}" || true)"
  if [[ -n "${row}" ]]; then
    # This version name can only exist because this script pushed it with
    # --activate, so a version that is no longer active was superseded and
    # needs promoting back.
    if [[ "${row#"${version}"}" == *true* ]]; then
      echo "Template ${name} already serves ${version}."
    else
      echo "Promoting existing version ${version} of template ${name}."
      "${coder}" templates versions promote \
        --template "${name}" --template-version "${version}"
    fi
    continue
  fi

  created=false
  template_exists "${name}" || created=true
  echo "Publishing version ${version} of template ${name}."
  "${coder}" templates push "${name}" \
    --directory "${staged}" \
    --name "${version}" \
    --activate \
    --yes \
    --variables-file "${variables_file}"
  # Creation metadata needs a separate call, and is set at creation only:
  # `templates edit` submits the full template metadata, so running it on every
  # publication would overwrite scheduling and access settings owned elsewhere.
  if [[ "${created}" = true ]]; then
    "${coder}" templates edit "${name}" \
      --description "${description}" \
      --icon "${icon}" \
      --yes
  fi
done

# Local Zarf deployments update every outdated workspace with the existing
# publisher credential; production leaves UPDATE_WORKSPACE empty.
case "${UPDATE_WORKSPACE:-}" in
  "") ;;
  all)
    for name in "${published_templates[@]}"; do
      # Without a JSON processor in this image, request the single
      # workspace column and read owner/name rows from the table.
      workspace_rows="$(
        "${coder}" list --search "template:${name} outdated:true" --column workspace
      )"
      while IFS= read -r row; do
        [[ "${row}" == WORKSPACE* ]] && continue
        workspace="${row##* }"
        [[ "${workspace}" == */* ]] || continue
        "${coder}" update --use-parameter-defaults -- "${workspace}"
      done <<<"${workspace_rows}"
    done
    ;;
  *) echo 'UPDATE_WORKSPACE must be empty or all.' >&2; exit 1 ;;
esac
