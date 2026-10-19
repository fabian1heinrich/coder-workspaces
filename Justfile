os := `uname -s`
cluster := env("KIND_CLUSTER", "dev")
build_dir := env("BUILD_DIR")

[private]
_build-image containerfile image:
    podman build --platform linux/amd64 --file {{ quote(containerfile) }} --tag {{ quote(image) }} .

[private]
_save-image-archive image archive:
    #!/usr/bin/env bash
    set -euo pipefail
    archive={{ quote(build_dir / archive) }}
    temporary_archive="${archive}.tmp"
    trap 'rm -f -- "${temporary_archive}"' EXIT
    podman save --format oci-archive --output "${temporary_archive}" {{ quote(image) }}
    mv -- "${temporary_archive}" "${archive}"

[private]
_build-project-images:
    #!/usr/bin/env bash
    set -euo pipefail
    for project in dupe-trooper deja-doc; do
      image="zarf.internal/coder-workspaces-${project}:local"
      podman build \
        --platform linux/amd64 \
        --timestamp 315532800 \
        --target project \
        --build-arg PROJECT="${project}" \
        --build-arg SOURCE_REVISION="$(git rev-parse HEAD)" \
        --file workspaces/python/images/python.Containerfile \
        --tag "${image}" \
        .
      just _save-image-archive "${image}" "${project}.oci.tar"
    done

# Build the pinned Coder module payload.
[private]
_build-coder-modules-image:
    podman build --platform linux/amd64 --timestamp 315532800 --file modules/Containerfile --tag zarf.internal/coder-modules:0.1.0 .
    just _save-image-archive zarf.internal/coder-modules:0.1.0 coder-modules.oci.tar

# Build the local Coder image.
[private]
_build-coder-image: _build-coder-modules-image
    just _build-image coder.Containerfile zarf.internal/coder-workspaces-coder:opentofu
    just _save-image-archive zarf.internal/coder-workspaces-coder:opentofu coder-opentofu.oci.tar

# Build the local coderd provider image.
[private]
_build-coderd-provider-image:
    just _build-image coderd-provider.Containerfile zarf.internal/coder-workspaces-coderd-provider:opentofu
    just _save-image-archive zarf.internal/coder-workspaces-coderd-provider:opentofu coderd-provider-opentofu.oci.tar

# Build the local VS Code Web image.
[private]
_build-vscode-web-image:
    just _build-image workspaces/python/images/code-server.Containerfile zarf.internal/coder-workspaces-code-server:local
    just _save-image-archive zarf.internal/coder-workspaces-code-server:local code-server.oci.tar

# Build the local Python VSIX image.
[private]
_build-python-vsix-image:
    just _build-image workspaces/python/extensions/python-extensions.Containerfile zarf.internal/coder-workspaces-python-vsix:local
    just _save-image-archive zarf.internal/coder-workspaces-python-vsix:local python-vsix.oci.tar

# Build the local Python workspace image.
[private]
_build-python-workspace-image:
    podman build --platform linux/amd64 --target runtime --file workspaces/python/images/python.Containerfile --tag zarf.internal/coder-workspaces-python-workspace:local .
    just _save-image-archive zarf.internal/coder-workspaces-python-workspace:local python-workspace.oci.tar

# Build all local template artifacts and refresh the local Zarf inputs.
build-template-artifacts: _build-coderd-provider-image _build-vscode-web-image _build-python-vsix-image _build-python-workspace-image _build-project-images
    just _generate-local-zarf-config

# Build all local platform artifacts and refresh the local Zarf inputs.
build-platform-artifacts: _build-coder-image
    just _generate-local-zarf-config

# Build all local artifacts.
build-all: build-platform-artifacts build-template-artifacts

[private]
_generate-local-zarf-config:
    #!/usr/bin/env bash
    set -euo pipefail
    archives={{ quote(build_dir) }}
    config=dev/zarf-config.yaml
    temporary_config="${config}.tmp"
    trap 'rm -f -- "${temporary_config}"' EXIT
    args=(--arg BUILD_DIR "${archives}" --arg PUBLISH_TEMPLATE all --arg UPDATE_WORKSPACE all)
    add_image() {
      local digest
      digest="$(skopeo inspect "oci-archive:${archives}/$2.oci.tar" | jq -er '.Digest')"
      args+=(--arg "$1" "$3@${digest}")
    }
    archives_exist() {
      local archive
      for archive in "$@"; do
        [[ -f "${archives}/${archive}.oci.tar" ]] || return 1
      done
    }
    if archives_exist coder-opentofu coder-modules; then
      coder_digest="$(skopeo inspect "oci-archive:${archives}/coder-opentofu.oci.tar" | jq -er '.Digest')"
      args+=(--arg CODER_IMAGE_DIGEST "${coder_digest#sha256:}")
      add_image CODER_MODULES_IMAGE coder-modules zarf.internal/coder-modules
    else
      args+=(--arg CODER_IMAGE_DIGEST "" --arg CODER_MODULES_IMAGE "")
    fi
    if archives_exist coderd-provider-opentofu code-server python-workspace dupe-trooper deja-doc python-vsix; then
      add_image PUBLISHER_IMAGE coderd-provider-opentofu zarf.internal/coder-workspaces-coderd-provider
      add_image CODE_SERVER_IMAGE code-server zarf.internal/coder-workspaces-code-server
      add_image WORKSPACE_IMAGE python-workspace zarf.internal/coder-workspaces-python-workspace
      add_image DUPE_TROOPER_IMAGE dupe-trooper zarf.internal/coder-workspaces-dupe-trooper
      add_image DEJA_DOC_IMAGE deja-doc zarf.internal/coder-workspaces-deja-doc
      add_image VSIX_IMAGE python-vsix zarf.internal/coder-workspaces-python-vsix
    else
      args+=(
        --arg PUBLISHER_IMAGE ""
        --arg CODE_SERVER_IMAGE ""
        --arg WORKSPACE_IMAGE ""
        --arg DUPE_TROOPER_IMAGE ""
        --arg DEJA_DOC_IMAGE ""
        --arg VSIX_IMAGE ""
      )
    fi
    jq -nr "${args[@]}" \
      '$ARGS.named | "package:\n  create:\n    set:\n" + (to_entries | map("      \(.key): \(.value | @json)") | join("\n"))' \
      > "${temporary_config}"
    mv -- "${temporary_config}" "${config}"

# Create the local kind cluster.
create-kind-cluster cluster=cluster:
    case "{{ os }}" in \
      Darwin) KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name {{ quote(cluster) }} ;; \
      Linux) systemd-run --scope --user -p "Delegate=yes" env KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name {{ quote(cluster) }} ;; \
      *) echo "Unsupported OS: {{ os }}" >&2; exit 1 ;; \
    esac

# Delete the local kind cluster.
delete-kind-cluster cluster=cluster:
    kind delete cluster --name {{ quote(cluster) }}

# Build the production Flux workspace source package.
build-release:
    #!/usr/bin/env -S direnv exec . bash
    set -euo pipefail
    test -z "$(git status --porcelain)"
    git_revision="$(git rev-parse HEAD)"
    release_date="$(git show -s --format=%cs HEAD)"
    release_id="${release_date//-/.}-g${git_revision:0:12}"
    source_repository="registry.invalid/fabian1heinrich/coder-workspaces/source"
    source_ref="$source_repository:$release_id"
    bundle="$BUILD_DIR/coder-workspaces"
    work="$BUILD_DIR/coder-workspaces-source"
    rm -rf -- "$bundle" "$work"
    mkdir -p -- "$bundle" "$work/package"
    cp -- release/source/zarf.yaml "$work/package/zarf.yaml"
    git archive --format=tar.gz --output="$work/source.tgz" \
      'HEAD^{tree}' kustomization.yaml template-publisher workspaces
    printf '{}\n' > "$work/config.json"
    (cd "$work" && oras push --oci-layout-path layout --image-spec v1.0 \
      --config config.json:application/vnd.cncf.flux.config.v1+json \
      "$source_ref" source.tgz:application/vnd.cncf.flux.content.v1.tar+gzip)
    source_digest="$(yq -r '.manifests[0].digest' "$work/layout/index.json")"
    tar -C "$work/layout" -cf "$work/package/coder-workspaces-source-oci.tar" .
    zarf package create "$work/package" --output "$bundle" \
      --set RELEASE_ID="$release_id" --confirm
    printf '%s\n' \
      "release_id=$release_id" \
      "source_repository=$source_repository" \
      "source_tag=$release_id" \
      "source_digest=$source_digest" \
      "git_revision=$git_revision" > "$bundle/RELEASE-METADATA"
    cp -R -- release/airgapped/. "$bundle/"
    sed "s|###SOURCE_DIGEST###|$source_digest|" \
      release/airgapped/flux-entrypoint.yaml > "$bundle/flux-entrypoint.yaml"
    (cd "$bundle" && find . -type f ! -name SHA256SUMS -exec sha256sum {} + | sort -k2 > SHA256SUMS)
    rm -rf -- "$work"

# Build the production Flux source and workspace image mirror packages.
build-release-all: build-release
    #!/usr/bin/env -S direnv exec . bash
    set -euo pipefail
    bundle="$BUILD_DIR/coder-workspaces"
    release_id="$(sed -n 's/^release_id=//p' "$bundle/RELEASE-METADATA")"
    zarf package create release/images \
      --architecture amd64 \
      --registry-override "registry.invalid=ghcr.io" \
      --output "$bundle" \
      --set RELEASE_ID="$release_id" \
      --confirm
    (cd "$bundle" && find . -type f ! -name SHA256SUMS -exec sha256sum {} + | sort -k2 > SHA256SUMS)

# Build and copy the production Flux source release.
copy-release dest: build-release (_copy-release dest)

# Build and copy the production Flux source and image packages.
copy-release-all dest: build-release-all (_copy-release dest)

[private]
_copy-release dest:
    #!/usr/bin/env -S direnv exec . bash
    set -euo pipefail
    destination="$(realpath {{ quote(dest) }})"
    target="$destination/coder-workspaces"
    test -d "$destination"
    test -w "$destination"
    test "$destination" != /
    [[ "$destination/" != "$(git rev-parse --show-toplevel)/"* ]]
    rm -rf -- "$target"
    cp -R -- "$BUILD_DIR/coder-workspaces" "$target"
    find "$target" -type d -exec chmod 0755 {} +
    find "$target" -type f -exec chmod 0644 {} +
    sync -f "$target"
