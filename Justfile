os := `uname -s`
cluster := env("KIND_CLUSTER", "dev")
build_dir := env("BUILD_DIR", justfile_directory() / ".cache/build")

# Package production from the published, digest-pinned images.
package-production-registry:
    just _package-production registry

# Build local images and package them for production.
package-production-local:
    just _package-production local

# Rebuild production packages from registry images and copy publication files.
copy destination=env("RELEASE_DESTINATION", ""):
    just _copy-production publish registry {{ quote(destination) }}

# Rebuild from registry images and copy both production packages and deployment files.
copy-all destination=env("RELEASE_DESTINATION", ""):
    just _copy-production all registry {{ quote(destination) }}

# Rebuild local images and copy both production packages and deployment files.
copy-all-local destination=env("RELEASE_DESTINATION", ""):
    just _copy-production all local {{ quote(destination) }}

[private]
_copy-production mode source requested_destination:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 0022
    requested_destination={{ quote(requested_destination) }}
    : "${requested_destination:?Pass an existing writable destination or set RELEASE_DESTINATION}"
    destination="$(cd -- "$requested_destination" && pwd -P)"
    test -w "$destination" && test -x "$destination" || {
      echo "Transport directory must be writable and searchable: $destination" >&2
      exit 1
    }
    revision="$(git rev-parse HEAD)"
    date="$(git show -s --format=%cs HEAD)"
    release="${date//-/.}-g${revision:0:12}"
    bundle={{ quote(build_dir) }}/releases/"$release"
    target="$destination/coder-workspaces/$release-{{ mode }}"
    mkdir -p "$target"
    # Repair directories created by an earlier run with a restrictive umask.
    chmod 0755 "$destination/coder-workspaces" "$target"
    test -w "$target" || { echo "Release directory must be writable: $target" >&2; exit 1; }
    staging="$(mktemp -d "$destination/coder-workspaces/.copy.XXXXXX")"
    trap 'rm -rf -- "$staging"' EXIT
    just "package-production-{{ source }}"
    cp "$bundle"/{Justfile,README.md,.envrc,.env.example,zarf-config.yaml,RELEASE-METADATA} \
      "$bundle/zarf-package-coder-workspaces-publish-amd64-${release}.tar.zst" "$staging/"
    if test {{ quote(mode) }} = all; then
      cp "$bundle/zarf-package-coder-workspaces-images-amd64-${release}.tar.zst" "$staging/"
    fi
    (cd "$staging" && find . -type f ! -name SHA256SUMS -exec sha256sum {} + | sort -k2 > SHA256SUMS)
    find "$staging" -type f -exec chmod 0644 {} +
    # Replace shipped files without changing permissions on operator-owned files.
    shopt -s dotglob
    mv -f -- "$staging/"* "$target/"
    sync -f "$target"
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
    zarf package create dev/zarf.yaml "${args[@]}" --confirm --output {{ quote(build_dir) }}

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
    umask 0022
    mkdir -p {{ quote(build_dir) }}
    image="registry.invalid/fabian1heinrich/coder-workspaces/{{ name }}:local"
    args=(--layers --platform linux/amd64 --timestamp 315532800)
    test -z {{ quote(target) }} || args+=(--target {{ quote(target) }})
    test -z {{ quote(project) }} || args+=(--build-arg PROJECT={{ quote(project) }})
    podman build "${args[@]}" --file {{ quote(containerfile) }} --tag "$image" .
    archive={{ quote(build_dir / name) }}.oci.tar
    trap 'rm -f -- "${archive}.tmp"' EXIT
    podman save --format oci-archive --output "${archive}.tmp" "$image"
    chmod 0644 "${archive}.tmp"
    mv -- "${archive}.tmp" "$archive"

[private]
_package-production source:
    #!/usr/bin/env bash
    set -euo pipefail
    umask 0022
    test -z "$(git status --porcelain)" || {
      echo "Production releases must be built from a clean worktree." >&2
      exit 1
    }
    revision="$(git rev-parse HEAD)"
    date="$(git show -s --format=%cs HEAD)"
    release="${date//-/.}-g${revision:0:12}"
    build_path={{ quote(build_dir) }}
    target="$build_path/releases/$release"
    mkdir -p "$(dirname "$target")"
    bundle="$(mktemp -d "$build_path/releases/.${release}.XXXXXX")"
    trap 'rm -rf -- "$bundle"' EXIT
    cp release/deploy/{Justfile,README.md,.envrc,.env.example,zarf-config.yaml} "$bundle/"
    sed -i "s/###RELEASE_ID###/$release/g" "$bundle/Justfile"
    printf 'release_id=%s\ngit_revision=%s\nimage_source=%s\n' "$release" "$revision" {{ quote(source) }} > "$bundle/RELEASE-METADATA"
    image_package=release/images-registry.yaml
    registry_args=(--registry-override registry.invalid=ghcr.io)
    args=(--set "RELEASE_ID=$release")
    if test {{ quote(source) }} = local; then
      just _build-images production
      image_package=release/images-local.yaml
      registry_args=()
      args+=(--set BUILD_DIR={{ quote(build_dir) }})
    fi
    # The mirror package owns the published pins. The publication package and
    # deployment config receive those same pins, or the local digests.
    references="$(zarf tools yq -r '.components[].images[]' release/images-registry.yaml)"
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
    zarf package create release/publish.yaml --architecture amd64 --output "$bundle" "${args[@]}" --confirm
    (cd "$bundle" && find . -type f ! -name SHA256SUMS -exec sha256sum {} + | sort -k2 > SHA256SUMS)
    find "$bundle" -type d -exec chmod 0755 {} +
    find "$bundle" -type f -exec chmod 0644 {} +
    rm -rf -- "$target"
    mv -- "$bundle" "$target"
    printf 'Release: %s\n' "$target"

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
