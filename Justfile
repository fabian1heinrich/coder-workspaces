os := `uname -s`
cluster := env("KIND_CLUSTER", "dev")
build_dir := env("BUILD_DIR")

[private]
_build-and-save containerfile image archive target="" project="" timestamp="":
    #!/usr/bin/env bash
    set -euo pipefail
    build=(podman build --platform linux/amd64)
    test -z {{ quote(target) }} || build+=(--target {{ quote(target) }})
    test -z {{ quote(project) }} || build+=(
      --build-arg PROJECT={{ quote(project) }}
      --build-arg SOURCE_REVISION="$(git rev-parse HEAD)"
    )
    test -z {{ quote(timestamp) }} || build+=(--timestamp {{ quote(timestamp) }})
    build+=(--file {{ quote(containerfile) }} --tag {{ quote(image) }} .)
    "${build[@]}"
    archive={{ quote(build_dir / archive) }}
    trap 'rm -f -- "${archive}.tmp"' EXIT
    podman save --format oci-archive --output "${archive}.tmp" {{ quote(image) }}
    mv -- "${archive}.tmp" "$archive"

# Build the local template images, including one per declared project.
build-template-artifacts:
    #!/usr/bin/env bash
    set -euo pipefail
    just _build-and-save publisher.Containerfile zarf.internal/coder-workspaces-publisher:local publisher.oci.tar
    just _build-and-save workspaces/python/images/code-server.Containerfile zarf.internal/coder-workspaces-code-server:local code-server.oci.tar
    just _build-and-save workspaces/python/extensions/python-extensions.Containerfile zarf.internal/coder-workspaces-python-vsix:local python-vsix.oci.tar
    just _build-and-save workspaces/python/images/python.Containerfile zarf.internal/coder-workspaces-python-workspace:local python-workspace.oci.tar runtime
    just _build-and-save workspaces/k8s-dev/image/Containerfile zarf.internal/coder-workspaces-k8s-workspace:local k8s-workspace.oci.tar
    just _build-and-save workspaces/k8s-dev/extensions/k8s-extensions.Containerfile zarf.internal/coder-workspaces-k8s-vsix:local k8s-vsix.oci.tar
    while IFS= read -r project; do
      just _build-and-save workspaces/python/images/python.Containerfile \
        "zarf.internal/coder-workspaces-${project}:local" "${project}.oci.tar" \
        project "$project" 315532800
    done < <(jq -r '.[].name' workspaces/python/projects.json)

# Build the local Coder and module images.
build-platform-artifacts:
    just _build-and-save modules/Containerfile zarf.internal/coder-modules:0.1.0 coder-modules.oci.tar "" "" 315532800
    just _build-and-save coder.Containerfile zarf.internal/coder-workspaces-coder:opentofu coder-opentofu.oci.tar

# Build all local images.
build-all: build-platform-artifacts build-template-artifacts

# Package the published images and full local platform.
package-registry:
    zarf package create dev --flavor full --confirm --output .

# Package only the published template artifacts.
package-registry-templates:
    zarf package create dev --confirm --output .

# Build and package the full local platform.
package-local: build-all (_package-local "full")

# Build and package only the local template artifacts.
package-local-templates: build-template-artifacts (_package-local "")

[private]
_package-local flavor:
    #!/usr/bin/env bash
    set -eo pipefail
    flavor={{ quote(flavor) }}
    digest() { skopeo inspect "oci-archive:$BUILD_DIR/$1.oci.tar" | jq -r .Digest; }
    args=(--set "BUILD_DIR=$BUILD_DIR")
    if test -n "$flavor"; then
      coder_digest="$(digest coder-opentofu)"
      args=(--flavor "$flavor" "${args[@]}" \
        --set "CODER_IMAGE_DIGEST=${coder_digest#sha256:}" \
        --set "CODER_MODULES_IMAGE=zarf.internal/coder-modules@$(digest coder-modules)")
    else
      args+=(--set CODER_IMAGE_DIGEST= --set CODER_MODULES_IMAGE=)
    fi
    args+=(
      --set "PUBLISHER_IMAGE=zarf.internal/coder-workspaces-publisher@$(digest publisher)"
      --set "CODE_SERVER_IMAGE=zarf.internal/coder-workspaces-code-server@$(digest code-server)"
      --set "WORKSPACE_IMAGE=zarf.internal/coder-workspaces-python-workspace@$(digest python-workspace)"
      --set "K8S_WORKSPACE_IMAGE=zarf.internal/coder-workspaces-k8s-workspace@$(digest k8s-workspace)"
      --set "K8S_VSIX_IMAGE=zarf.internal/coder-workspaces-k8s-vsix@$(digest k8s-vsix)"
      --set "VSIX_IMAGE=zarf.internal/coder-workspaces-python-vsix@$(digest python-vsix)"
      --set "DEJA_DOC_IMAGE=zarf.internal/coder-workspaces-deja-doc@$(digest deja-doc)"
      --set "DUPE_TROOPER_IMAGE=zarf.internal/coder-workspaces-dupe-trooper@$(digest dupe-trooper)"
    )
    zarf package create dev/local "${args[@]}" --confirm --output .

# Build production template publication media.
build-release:
    #!/usr/bin/env -S direnv exec . bash
    set -eo pipefail
    revision="$(git rev-parse HEAD)"
    date="$(git show -s --format=%cs HEAD)"
    release="${date//-/.}-g${revision:0:12}"
    root="$(git rev-parse --show-toplevel)"
    bundle="$BUILD_DIR/coder-workspaces"
    rm -rf "$bundle"
    mkdir -p "$bundle"
    zarf package create release/publish --architecture amd64 --output "$root" \
      --set RELEASE_ID="$release" --confirm
    cp "$root/zarf-package-coder-workspaces-publish-amd64-${release}.tar.zst" "$bundle/"
    printf 'release_id=%s\ngit_revision=%s\n' "$release" "$revision" > "$bundle/RELEASE-METADATA"
    cp -R release/airgapped/. "$bundle/"
    (cd "$bundle" && find . -type f ! -name SHA256SUMS -exec sha256sum {} + | sort -k2 > SHA256SUMS)

# Build publication and image mirror media.
build-release-all: build-release
    #!/usr/bin/env -S direnv exec . bash
    set -eo pipefail
    root="$(git rev-parse --show-toplevel)"
    bundle="$BUILD_DIR/coder-workspaces"
    release="$(sed -n 's/^release_id=//p' "$bundle/RELEASE-METADATA")"
    zarf package create release/images --architecture amd64 \
      --registry-override registry.invalid=ghcr.io --output "$root" \
      --set RELEASE_ID="$release" --confirm
    cp "$root/zarf-package-coder-workspaces-images-amd64-${release}.tar.zst" "$bundle/"
    (cd "$bundle" && find . -type f ! -name SHA256SUMS -exec sha256sum {} + | sort -k2 > SHA256SUMS)

# Create the local kind cluster.
create-kind-cluster:
    case "{{ os }}" in \
      Darwin) KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name {{ quote(cluster) }} ;; \
      Linux) systemd-run --scope --user -p "Delegate=yes" env KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name {{ quote(cluster) }} ;; \
      *) echo "Unsupported OS: {{ os }}" >&2; exit 1 ;; \
    esac

# Delete the local kind cluster.
delete-kind-cluster:
    kind delete cluster --name {{ quote(cluster) }}
