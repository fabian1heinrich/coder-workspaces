#!/usr/bin/env bash
# Publish the repository-owned template without contacting a public registry.
set -euo pipefail

publisher_dir="${PUBLISHER_DIR:-/workspace/config/publisher}"
organization="${CODER_ORGANIZATION:-default}"
selected_address=""
selected_templates=""
case "${PUBLISH_TEMPLATE:-all}" in
  all) selected_templates='python-workspace k8s-dev' ;;
  python)
    selected_address=coderd_template.python_workspace
    selected_templates=python-workspace
    ;;
  k8s-dev)
    selected_address=coderd_template.k8s_dev
    selected_templates=k8s-dev
    ;;
  *) echo 'PUBLISH_TEMPLATE must be python, k8s-dev, or all.' >&2; exit 1 ;;
esac
apply_args=()
if [[ -n "${selected_address}" ]]; then
  # Local iteration targets one independent template while retaining both in state.
  apply_args+=("-target=${selected_address}")
fi

: "${CODER_TOKEN:?CODER_TOKEN is required}"
: "${CODER_URL:?CODER_URL is required}"
: "${PUBLISHER_STATE_SUFFIX:?PUBLISHER_STATE_SUFFIX is required}"
export CODER_SESSION_TOKEN="${CODER_TOKEN}"
export CODER_ORGANIZATION="${organization}"

tofu -chdir="${publisher_dir}" init -input=false -lockfile=readonly \
  -backend-config="secret_suffix=${PUBLISHER_STATE_SUFFIX}"
state_addresses="$(tofu -chdir="${publisher_dir}" state list)"

for template in \
  'coderd_template.python_workspace|python-workspace|coderd_template.kubernetes_workspace' \
  'coderd_template.k8s_dev|k8s-dev|'
do
  IFS='|' read -r template_address template_name previous_address <<<"${template}"
  if [[ -n "${selected_address}" && "${template_address}" != "${selected_address}" ]]; then
    continue
  fi
  if ! grep -Fxq "${template_address}" <<<"${state_addresses}" \
    && { [[ -z "${previous_address}" ]] || ! grep -Fxq "${previous_address}" <<<"${state_addresses}"; }
  then
    if /opt/coder templates list --output json | grep -Eq "\"name\"[[:space:]]*:[[:space:]]*\"${template_name}\""; then
      tofu -chdir="${publisher_dir}" import -input=false -lock-timeout=5m \
        "${template_address}" "${organization}/${template_name}"
    fi
  fi
done

tofu -chdir="${publisher_dir}" apply -input=false -auto-approve -lock-timeout=5m "${apply_args[@]}"

# Local Zarf deployments update workspaces with the existing publisher credential.
case "${UPDATE_WORKSPACE:-}" in
  "") ;;
  all)
    for template_name in ${selected_templates}; do
      workspace_rows="$(
        /opt/coder list --search "template:${template_name} outdated:true" \
          --column workspace
      )"
      while IFS= read -r row; do
        [[ "${row}" == WORKSPACE* ]] && continue
        workspace="${row##* }"
        [[ "${workspace}" == */* ]] || continue
        /opt/coder update --use-parameter-defaults -- "${workspace}"
      done <<<"${workspace_rows}"
    done
    ;;
  *) /opt/coder update --use-parameter-defaults -- "${UPDATE_WORKSPACE}" ;;
esac
