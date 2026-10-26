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
    build_image() { just _build-and-save "$1" "zarf.internal/coder-workspaces-$2:local" "$2.oci.tar" "${@:3}"; }
    build_image publisher.Containerfile publisher
    build_image workspaces/python/images/code-server.Containerfile code-server
    build_image workspaces/python/extensions/python-extensions.Containerfile python-vsix
    build_image workspaces/python/images/python.Containerfile python-workspace runtime
    build_image workspaces/k8s-dev/image/Containerfile k8s-workspace
    build_image workspaces/k8s-dev/extensions/k8s-extensions.Containerfile k8s-vsix
    while IFS= read -r project; do
      build_image workspaces/python/images/python.Containerfile "$project" \
        project "$project" 315532800
    done < <(jq -r '.[].name' workspaces/python/projects.json)

# Build the local Coder and module images.
build-platform-artifacts:
    just _build-and-save modules/Containerfile zarf.internal/coder-modules:0.1.0 coder-modules.oci.tar "" "" 315532800
    just _build-and-save coder.Containerfile zarf.internal/coder-workspaces-coder:opentofu coder-opentofu.oci.tar

# Build all local images.
build-all: build-platform-artifacts build-template-artifacts

# Package the published images and full local platform.
package-dev-registry:
    zarf package create dev --flavor full --confirm --output .
    mv -- zarf-package-coder-workspaces-dev-registry-amd64-0.1.0-full.tar.zst zarf-package-coder-dev-registry-platform-amd64-0.1.0-full.tar.zst

# Package only the published template artifacts.
package-dev-registry-templates:
    zarf package create dev --confirm --output .
    mv -- zarf-package-coder-workspaces-dev-registry-amd64-0.1.0.tar.zst zarf-package-coder-dev-registry-template-publisher-amd64-0.1.0.tar.zst

# Build and package the complete local development platform.
package-dev-local: build-all (_package-dev-local "full")

# Build and package only the local development template artifacts.
package-dev-local-templates: build-template-artifacts (_package-dev-local "")

[private]
_package-dev-local flavor:
    #!/usr/bin/env bash
    set -eo pipefail
    flavor={{ quote(flavor) }}
    digest() { skopeo inspect "oci-archive:$BUILD_DIR/$1.oci.tar" | jq -r .Digest; }
    args=(--set "BUILD_DIR=$BUILD_DIR")
    suffix=
    artifact=template-publisher
    if test -n "$flavor"; then
      coder_digest="$(digest coder-opentofu)"
      args=(--flavor "$flavor" "${args[@]}" \
        --set "CODER_IMAGE_DIGEST=${coder_digest#sha256:}" \
        --set "CODER_MODULES_IMAGE=zarf.internal/coder-modules@$(digest coder-modules)")
      suffix=-full
      artifact=platform
    else
      args+=(--set CODER_IMAGE_DIGEST= --set CODER_MODULES_IMAGE=)
    fi
    image() { args+=(--set "$1=zarf.internal/coder-workspaces-$2@$(digest "$2")"); }
    image PUBLISHER_IMAGE publisher
    image CODE_SERVER_IMAGE code-server
    image WORKSPACE_IMAGE python-workspace
    image K8S_WORKSPACE_IMAGE k8s-workspace
    image K8S_VSIX_IMAGE k8s-vsix
    image VSIX_IMAGE python-vsix
    image DEJA_DOC_IMAGE deja-doc
    image DUPE_TROOPER_IMAGE dupe-trooper
    zarf package create dev/local "${args[@]}" --confirm --output .
    mv -- "zarf-package-coder-workspaces-dev-local-amd64-0.1.0${suffix}.tar.zst" \
      "zarf-package-coder-dev-local-${artifact}-amd64-0.1.0${suffix}.tar.zst"

# Package production template publication and image-mirror media.
package-release: (_package-release "all")

# Package only the production template publication media.
package-release-templates: (_package-release "templates")

# Package and copy only the production template publication media.
copy destination=env("RELEASE_DESTINATION", ""): package-release-templates (_copy destination)

# Package and copy the production template publication and image-mirror media.
copy-all destination=env("RELEASE_DESTINATION", ""): package-release (_copy destination)

[private]
_copy requested_destination:
    #!/usr/bin/env -S direnv exec . bash
    set -euo pipefail
    requested_destination={{ quote(requested_destination) }}
    : "${requested_destination:?Pass an existing writable destination or set RELEASE_DESTINATION}"
    destination="$(realpath "$requested_destination")"
    target="$destination/coder-workspaces"
    repository="$(git rev-parse --show-toplevel)"
    test -d "$destination"
    test -w "$destination"
    test "$destination" != /
    [[ "$destination/" != "$repository/"* ]]
    [[ "$repository/" != "$target/"* ]]
    rm -rf -- "$target"
    cp -R -- "$BUILD_DIR/coder-workspaces" "$target"
    find "$target" -type d -exec chmod 0755 {} +
    find "$target" -type f -exec chmod 0644 {} +
    sync -f "$target"

[private]
_package-release mode:
    #!/usr/bin/env -S direnv exec . bash
    set -eo pipefail
    test -z "$(git status --porcelain)" || {
      echo "Production releases must be built from a clean worktree." >&2
      exit 1
    }
    revision="$(git rev-parse HEAD)"
    date="$(git show -s --format=%cs HEAD)"
    release="${date//-/.}-g${revision:0:12}"
    bundle="$BUILD_DIR/coder-workspaces"
    rm -rf -- "$bundle"
    mkdir -p -- "$bundle"
    zarf package create release/publish --architecture amd64 --output "$bundle" \
      --set RELEASE_ID="$release" --confirm
    mv -- "$bundle/zarf-package-coder-workspaces-publish-amd64-${release}.tar.zst" \
      "$bundle/zarf-package-coder-workspaces-template-publisher-amd64-${release}.tar.zst"
    printf 'release_id=%s\ngit_revision=%s\n' "$release" "$revision" > "$bundle/RELEASE-METADATA"
    cp -R release/airgapped/. "$bundle/"
    if test {{ quote(mode) }} = all; then
      zarf package create release/images --architecture amd64 \
        --registry-override registry.invalid=ghcr.io --output "$bundle" \
        --set RELEASE_ID="$release" --confirm
      mv -- "$bundle/zarf-package-coder-workspaces-images-amd64-${release}.tar.zst" \
        "$bundle/zarf-package-coder-workspaces-image-mirror-amd64-${release}.tar.zst"
    fi
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
