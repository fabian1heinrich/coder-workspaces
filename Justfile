os := `uname -s`
cluster := env("KIND_CLUSTER", "dev")
build_dir := env("BUILD_DIR", justfile_directory() / ".cache/build")

# Package production from the published, digest-pinned images.
package-production-registry:
    just _package-production registry

# Build local images and package them for production.
package-production-local:
    just _package-production local

# Copy the built publication package and deployment files to transport media.
copy:
    just _copy-production publish

# Copy the built publication and image packages with their deployment files.
copy-all:
    just _copy-production all

[private]
_copy-production mode:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${RELEASE_DESTINATION:?Set RELEASE_DESTINATION to an existing writable transport directory}"
    destination="$(cd -- "$RELEASE_DESTINATION" && pwd -P)"
    revision="$(git rev-parse HEAD)"
    date="$(git show -s --format=%cs HEAD)"
    release="${date//-/.}-g${revision:0:12}"
    bundle={{ quote(build_dir) }}/releases/"$release"
    test -f "$bundle/SHA256SUMS" || {
      echo "Build this release first with just package-production-registry or just package-production-local." >&2
      exit 1
    }
    target="$destination/coder-workspaces/$release-{{ mode }}"
    mkdir -p "$(dirname "$target")"
    mkdir "$target" # Keep previously copied releases intact.
    cp "$bundle"/{Justfile,README.md,.envrc,.env.example,zarf-config.yaml,RELEASE-METADATA} \
      "$bundle/zarf-package-coder-workspaces-publish-amd64-${release}.tar.zst" "$target/"
    if test {{ quote(mode) }} = all; then
      cp "$bundle/zarf-package-coder-workspaces-images-amd64-${release}.tar.zst" "$target/"
    fi
    (cd "$target" && find . -type f ! -name SHA256SUMS -exec sha256sum {} + | sort -k2 > SHA256SUMS)
    find "$target" -type d -exec chmod 0755 {} +
    find "$target" -type f -exec chmod 0644 {} +
    sync
    printf 'Copied release: %s\n' "$target"

# Build and package the complete local development platform.
package-dev-local:
    #!/usr/bin/env bash
    set -euo pipefail
    just _build-images dev
    build_path={{ quote(build_dir) }}
    digest() { skopeo inspect "oci-archive:$build_path/$1.oci.tar" | jq -er .Digest; }
    coder_digest="$(digest coder)"
    args=(--set BUILD_DIR={{ quote(build_dir) }} --set "CODER_IMAGE_DIGEST=${coder_digest#sha256:}")
    for pair in CODER_MODULES:coder-modules PUBLISHER:publisher CODE_SERVER:code-server \
      WORKSPACE:python-workspace VSIX:python-vsix K8S_WORKSPACE:k8s-workspace \
      K8S_VSIX:k8s-vsix DEJA_DOC:deja-doc DUPE_TROOPER:dupe-trooper; do
      name="${pair#*:}"
      args+=(--set "${pair%:*}_IMAGE=registry.invalid/fabian1heinrich/coder-workspaces/$name@$(digest "$name")")
    done
    zarf package create dev/local "${args[@]}" --confirm --output {{ quote(build_dir) }}

[private]
_build-images mode:
    #!/usr/bin/env bash
    set -euo pipefail
    just _build-image modules/Containerfile coder-modules
    just _build-image publisher.Containerfile publisher
    just _build-image workspaces/python/images/code-server.Containerfile code-server
    just _build-image workspaces/python/extensions/python-extensions.Containerfile python-vsix
    just _build-image workspaces/python/images/python.Containerfile python-workspace runtime
    just _build-image workspaces/k8s-dev/image/Containerfile k8s-workspace
    just _build-image workspaces/k8s-dev/extensions/k8s-extensions.Containerfile k8s-vsix
    projects="$(jq -r '.[].name' workspaces/python/projects.json)"
    while IFS= read -r project; do
      just _build-image workspaces/python/images/python.Containerfile "$project" project "$project"
    done <<< "$projects"
    if test {{ quote(mode) }} = dev; then
      just _build-image coder.Containerfile coder
    fi

[private]
_build-image containerfile name target="" project="":
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{ quote(build_dir) }}
    image="registry.invalid/fabian1heinrich/coder-workspaces/{{ name }}:local"
    args=(--platform linux/amd64 --timestamp 315532800)
    test -z {{ quote(target) }} || args+=(--target {{ quote(target) }})
    test -z {{ quote(project) }} || args+=(--build-arg PROJECT={{ quote(project) }})
    podman build "${args[@]}" --file {{ quote(containerfile) }} --tag "$image" .
    archive={{ quote(build_dir / name) }}.oci.tar
    trap 'rm -f -- "${archive}.tmp"' EXIT
    podman save --format oci-archive --output "${archive}.tmp" "$image"
    mv -- "${archive}.tmp" "$archive"

[private]
_package-production source:
    #!/usr/bin/env bash
    set -euo pipefail
    test -z "$(git status --porcelain)" || {
      echo "Production releases must be built from a clean worktree." >&2
      exit 1
    }
    revision="$(git rev-parse HEAD)"
    date="$(git show -s --format=%cs HEAD)"
    release="${date//-/.}-g${revision:0:12}"
    build_path={{ quote(build_dir) }}
    bundle="$build_path/releases/$release"
    mkdir -p "$(dirname "$bundle")"
    mkdir "$bundle" # Never overwrite a release, including one built from another source.
    cp release/airgapped/{Justfile,README.md,.envrc,.env.example,zarf-config.yaml} "$bundle/"
    printf 'release_id=%s\ngit_revision=%s\nimage_source=%s\n' "$release" "$revision" {{ quote(source) }} > "$bundle/RELEASE-METADATA"
    image_package=release/images
    registry_args=(--registry-override registry.invalid=ghcr.io)
    args=(--set "RELEASE_ID=$release")
    if test {{ quote(source) }} = local; then
      just _build-images production
      image_package=release/images/local
      registry_args=()
      args+=(--set BUILD_DIR={{ quote(build_dir) }})
    fi
    # The mirror package owns the published pins. The publication package and
    # deployment config receive those same pins, or the local digests.
    references="$(zarf tools yq -r '.components[].images[]' release/images/zarf.yaml)"
    while IFS= read -r reference; do
      reference="${reference#registry.invalid/}"
      name="${reference##*/}"
      name="${name%%@*}"
      name="${name%%:*}"
      key="$(printf '%s_IMAGE' "$name" | tr '[:lower:]-' '[:upper:]_')"
      if test {{ quote(source) }} = local; then
        digest="$(skopeo inspect "oci-archive:$build_path/$name.oci.tar" | jq -er .Digest)"
        reference="fabian1heinrich/coder-workspaces/$name@$digest"
      fi
      args+=(--set "$key=$reference")
      printf '%s=%s\n' "$key" "$reference" >> "$bundle/RELEASE-METADATA"
      if test "$name" = deja-doc || test "$name" = dupe-trooper; then
        IMAGE="$reference" KEY="$key" zarf tools yq -i \
          '.package.deploy.set[strenv(KEY)] = (.package.deploy.set.REGISTRY + "/" + strenv(IMAGE))' \
          "$bundle/zarf-config.yaml"
      fi
    done <<< "$references"
    zarf package create "$image_package" --architecture amd64 \
      "${registry_args[@]}" --output "$bundle" "${args[@]}" --confirm
    zarf package create release/publish --architecture amd64 --output "$bundle" "${args[@]}" --confirm
    (cd "$bundle" && find . -type f ! -name SHA256SUMS -exec sha256sum {} + | sort -k2 > SHA256SUMS)
    printf 'Release: %s\n' "$bundle"

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
