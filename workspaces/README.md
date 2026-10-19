# Workspaces

This directory owns two independent Coder templates for disconnected
Kubernetes environments:

- `python-workspace` is a Python 3.13 development environment with approved
  extensions and optional locked project environments.
- `k8s-dev` is a language-neutral operations environment for working with a
  Kubernetes cluster through `kubectl`, Kustomize, and Helm.

| Path                                                | Contents                                                |
| --------------------------------------------------- | ------------------------------------------------------- |
| `python/images/python.Containerfile`                | Python runtime and locked project-image build targets   |
| `python/images/code-server.Containerfile`           | Shared read-only code-server payload                    |
| `python/extensions/python-extensions.Containerfile` | Approved Python VSIX payload                            |
| `python/extensions/python-extensions.lock`          | VSIX versions, sources, platforms, and checksums        |
| `python/images/dupe-trooper/`                       | Locked `dupe-trooper` uv environment                    |
| `python/images/deja-doc/`                           | Locked `deja-doc` uv environment                        |
| `k8s-dev/`                                          | Kubernetes client workspace and cluster-access contract |
| `k8s-dev/image/Containerfile`                       | Kubernetes runtime, clients, sources, and checksums     |
| `k8s-dev/extensions/k8s-extensions.Containerfile`   | Approved Kubernetes VSIX payload                        |
| `k8s-dev/extensions/k8s-extensions.lock`            | Kubernetes VSIX sources, versions, and checksums        |

## Runtime behavior

Both templates persist `/home/coder`, request and limit CPU and memory, limit
ephemeral storage, and run as UID/GID 1000 with the restricted pod defaults.
code-server is mounted read-only at `/opt/vscode-server`. Each template mounts
its independently versioned approved VSIX set at `/opt/vsix` and installs it
into persistent `/home/coder`; the Kubernetes template gets checksum-locked
`kubectl` and Helm clients from its dedicated workspace image. Startup never
contacts package managers, extension marketplaces, or public artifact
registries.

The Python template's project profiles and image choices are documented in
[`python/README.md`](python/README.md). The Kubernetes template exposes no
Python or project-image choices. It uses a Trixie devcontainer runtime, an
optional mirrored Git repository, and an in-cluster kubeconfig backed by the
Pod's rotating ServiceAccount token; see [`k8s-dev/README.md`](k8s-dev/README.md).

The environment that publishes `k8s-dev` selects the existing ServiceAccount
and default target namespace. RBAC remains environment-owned so the template
cannot silently grant cluster-wide access. Bind only the namespaces and verbs
that workspace users require. The local default ServiceAccount normally has no
API permissions.

## Cluster requirements

- amd64 nodes and Coder Community 2.36.0 with the provider versions pinned in
  the control-plane Containerfiles.
- Kubernetes and a compatible CRI supporting `spec.volumes[].image`. Image
  volumes are [stable and enabled by default in Kubernetes
  1.36](https://kubernetes.io/docs/tasks/configure-pod-container/image-volumes/).
  Earlier releases that expose the feature may require the `ImageVolume` gate.
- The code-server image-volume mount must permit execution; some runtimes mount
  image volumes `noexec`.
- A default StorageClass or an explicit `home_storage_class`, plus a CNI that
  enforces the platform egress policy. The StorageClass must support volume
  expansion to grow an existing home disk.

## Release and verification

`just build-template-artifacts` builds the repository-owned workspace images
and publisher runner for the local package. For deployment, use the root
[local workflow](../README.md#local-deployment).

After publication, verify each template without public egress. For `k8s-dev`,
confirm `kubectl version --client`, `helm version`, the expected result from
`kubectl auth can-i --list`, and persistence of a marker under `/home/coder`
after Pod replacement. For `python-workspace`, verify Python, code-server, and
the approved extensions.

Containerfile-based image sources live in their owning Containerfiles. The
Kubernetes workspace source and tool provenance live in `k8s-dev/image/`.
Extension provenance remains in the owning Python and Kubernetes extension
locks.

Published workspace images have independent SemVer tags and `sha-<commit>`
traceability tags. Consumers retain the readable version in a
`:<version>@sha256:<digest>` reference; update every consumer whenever a
published image digest changes. The first `0.1.0` publication may replace a
pre-policy tag that lacks `io.coder.semver-policy=immutable-v1`; the old digest
remains reachable by its commit tag. Once marked, CI refuses to move that
SemVer tag.
