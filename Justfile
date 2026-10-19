os := `uname -s`
cluster := env("KIND_CLUSTER", "dev")
build_dir := env("BUILD_DIR")

[private]
_build-and-save containerfile image archive target="" project="" timestamp="":
    #!/usr/bin/env bash
    set -euo pipefail
    target={{ quote(target) }}
    project={{ quote(project) }}
    timestamp={{ quote(timestamp) }}
    build=(podman build --platform linux/amd64)
    test -z "$target" || build+=(--target "$target")
    test -z "$project" || build+=(
      --build-arg "PROJECT=$project"
      --build-arg "SOURCE_REVISION=$(git rev-parse HEAD)"
    )
    test -z "$timestamp" || build+=(--timestamp "$timestamp")
    build+=(--file {{ quote(containerfile) }} --tag {{ quote(image) }} .)
    "${build[@]}"
    archive={{ quote(build_dir / archive) }}
    temporary_archive="${archive}.tmp"
    trap 'rm -f -- "${temporary_archive}"' EXIT
    podman save --format oci-archive --output "${temporary_archive}" {{ quote(image) }}
    mv -- "${temporary_archive}" "${archive}"

# Build the local template images.
build-template-artifacts:
    just _build-and-save coderd-provider.Containerfile zarf.internal/coder-workspaces-coderd-provider:opentofu coderd-provider-opentofu.oci.tar
    just _build-and-save workspaces/python/images/code-server.Containerfile zarf.internal/coder-workspaces-code-server:local code-server.oci.tar
    just _build-and-save workspaces/python/extensions/python-extensions.Containerfile zarf.internal/coder-workspaces-python-vsix:local python-vsix.oci.tar
    just _build-and-save workspaces/python/images/python.Containerfile zarf.internal/coder-workspaces-python-workspace:local python-workspace.oci.tar runtime
    just _build-and-save workspaces/python/images/python.Containerfile zarf.internal/coder-workspaces-dupe-trooper:local dupe-trooper.oci.tar project dupe-trooper 315532800
    just _build-and-save workspaces/python/images/python.Containerfile zarf.internal/coder-workspaces-deja-doc:local deja-doc.oci.tar project deja-doc 315532800
    just _build-and-save workspaces/k8s-dev/image/Containerfile zarf.internal/coder-workspaces-k8s-workspace:local k8s-workspace.oci.tar
    just _build-and-save workspaces/k8s-dev/extensions/k8s-extensions.Containerfile zarf.internal/coder-workspaces-k8s-vsix:local k8s-vsix.oci.tar

# Build the local Coder and module images.
build-platform-artifacts:
    just _build-and-save modules/Containerfile zarf.internal/coder-modules:0.1.0 coder-modules.oci.tar "" "" 315532800
    just _build-and-save coder.Containerfile zarf.internal/coder-workspaces-coder:opentofu coder-opentofu.oci.tar

# Build all local artifacts.
build-all: build-platform-artifacts build-template-artifacts

# Create the full deployable package from published registry images.
package-registry:
    zarf package create dev --flavor full --confirm --output .

# Create a templates-only package from published registry images.
package-registry-templates:
    zarf package create dev --confirm --output .

# Build local images and create the full deployable package from their OCI archives.
package-local: build-all
    just _package-local full

# Build local images and create a templates-only package.
package-local-templates: build-template-artifacts
    just _package-local ""

[private]
_package-local flavor:
    #!/usr/bin/env bash
    set -euo pipefail
    archives={{ quote(build_dir) }}
    flavor={{ quote(flavor) }}
    args=(--set "BUILD_DIR=$archives")
    add_image() {
      local digest
      digest="$(skopeo inspect "oci-archive:${archives}/$2.oci.tar" | jq -er '.Digest')"
      args+=(--set "$1=$3@${digest}")
    }
    if test "$flavor" = full; then
      coder_digest="$(skopeo inspect "oci-archive:${archives}/coder-opentofu.oci.tar" | jq -er '.Digest')"
      args+=(--set "CODER_IMAGE_DIGEST=${coder_digest#sha256:}")
      add_image CODER_MODULES_IMAGE coder-modules zarf.internal/coder-modules
    else
      args+=(--set CODER_IMAGE_DIGEST= --set CODER_MODULES_IMAGE=)
    fi
    add_image PUBLISHER_IMAGE coderd-provider-opentofu zarf.internal/coder-workspaces-coderd-provider
    add_image CODE_SERVER_IMAGE code-server zarf.internal/coder-workspaces-code-server:0.1.0
    add_image WORKSPACE_IMAGE python-workspace zarf.internal/coder-workspaces-python-workspace:0.1.0
    add_image K8S_WORKSPACE_IMAGE k8s-workspace zarf.internal/coder-workspaces-k8s-workspace:0.1.0
    add_image K8S_VSIX_IMAGE k8s-vsix zarf.internal/coder-workspaces-k8s-vsix:0.1.0
    add_image DUPE_TROOPER_IMAGE dupe-trooper zarf.internal/coder-workspaces-dupe-trooper:0.1.0
    add_image DEJA_DOC_IMAGE deja-doc zarf.internal/coder-workspaces-deja-doc:0.1.0
    add_image VSIX_IMAGE python-vsix zarf.internal/coder-workspaces-python-vsix:0.1.0
    flavor_args=()
    test -z "$flavor" || flavor_args=(--flavor "$flavor")
    zarf package create dev/local "${flavor_args[@]}" "${args[@]}" --confirm --output .

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
    repository_root="$(git rev-parse --show-toplevel)"
    source_package="$repository_root/zarf-package-coder-workspaces-amd64-${release_id}.tar.zst"
    bundle="$BUILD_DIR/coder-workspaces"
    work="$BUILD_DIR/coder-workspaces-source"
    rm -rf -- "$bundle" "$work"
    rm -f -- "$source_package"
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
    zarf package create "$work/package" --output "$repository_root" \
      --set RELEASE_ID="$release_id" --confirm
    cp -- "$source_package" "$bundle/"
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
    repository_root="$(git rev-parse --show-toplevel)"
    bundle="$BUILD_DIR/coder-workspaces"
    release_id="$(sed -n 's/^release_id=//p' "$bundle/RELEASE-METADATA")"
    images_package="$repository_root/zarf-package-coder-workspaces-images-amd64-${release_id}.tar.zst"
    rm -f -- "$images_package"
    zarf package create release/images \
      --architecture amd64 \
      --registry-override "registry.invalid=ghcr.io" \
      --output "$repository_root" \
      --set RELEASE_ID="$release_id" \
      --confirm
    cp -- "$images_package" "$bundle/"
    printf '%s\n' \
      "python_workspace_image=ghcr.io/fabian1heinrich/coder-workspaces/python-workspace:0.1.0@sha256:9da7db38010f8fca3b97436aada761112856cdf2631ceede34efbce30f985266" \
      "k8s_workspace_image=ghcr.io/fabian1heinrich/coder-workspaces/k8s-workspace:0.1.0@sha256:ef4b0b979aaa284ea8fef5040b6a8d9bb508da8d62d7d7b9bcc227b123d40493" \
      "k8s_vsix_image=ghcr.io/fabian1heinrich/coder-workspaces/k8s-vsix:0.1.0@sha256:94270796aebd22397cac6404eccf6b26275dee4b61c0a662fcba3575edf73836" \
      "code_server_image=ghcr.io/fabian1heinrich/coder-workspaces/code-server:0.1.0@sha256:8405424b2479f19052945ee65376fbbfabd97e1ac04bb9fabaf963074cb2cdf8" \
      "python_vsix_image=ghcr.io/fabian1heinrich/coder-workspaces/python-vsix:0.1.0@sha256:96e870317cbe15144a0d0f17ab2d8a1dc6d53dae121dc01f3d4751d62cbd628b" \
      >> "$bundle/RELEASE-METADATA"
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
