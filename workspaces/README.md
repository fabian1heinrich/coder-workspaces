# Workspaces

This directory owns two Coder templates for disconnected Kubernetes:

- `python-workspace` is a Python 3.13 development environment with approved
  extensions and optional locked project environments.
- `k8s-dev` is a language-neutral operations environment for working with a
  Kubernetes cluster through `kubectl`, Kustomize, and Helm.

## Runtime behavior

Both templates create their Pod and persistent home through the shared
[`workspace-pod`](../modules/workspace-pod/README.md) module in the Coder
template archive, so they persist `/home/coder`, request and limit CPU and
memory, limit ephemeral storage, and run as UID/GID 1000 with the restricted
pod defaults identically.
code-server is mounted read-only at `/opt/code-server`. Each template mounts
its independently versioned approved VSIX set at `/opt/vsix`; the Kubernetes
template gets checksum-locked `kubectl` and Helm clients from its dedicated
workspace image. Startup never contacts package managers, extension
marketplaces, or public artifact registries.

Startup is `workspace-startup` from the workspace image, not shell embedded in
the template. It reconciles the approved extension set and, when the image
contains a managed Python project, materializes its locked environment before
the Coder agent starts. Extensions are platform state, so the set is rebuilt
from `/opt/vsix` whenever that payload changes and left untouched when it has
not, which keeps a withdrawn VSIX from surviving in the persistent home
directory.

Repository authentication is deployment-owned. `git_auth_mode` explicitly
selects `anonymous`, `secret`, or `external-auth`. Secret mode consumes a
generic Kubernetes Secret with `username` and `password` keys through the
shared workspace-pod module; external-auth uses a configured Coder provider.
The shared module supplies Secret credentials through Git's runtime
credential-helper configuration, while the workspace image, startup command,
and persistent home remain independent of that choice.

See the [Python workspace](python/README.md) and [Kubernetes
workspace](k8s-dev/README.md) documentation for template-specific behavior.

The `k8s-dev` environment mounts no ServiceAccount token. Users supply
`~/.kube/config` in their persistent home directory.

## Cluster requirements

- amd64 nodes and Coder Community 2.36.0 with the provider versions pinned in
  the control-plane Containerfiles.
- The Coder modules image mounted read-only at `/opt/coder-modules` on the
  control plane that runs the built-in provisioners. Templates resolve the
  pinned upstream modules from it; the shared `workspace-pod` module is bundled
  in each template archive.
- Kubernetes and a compatible CRI supporting `spec.volumes[].image`. Image
  volumes are [stable and enabled by default in Kubernetes
  1.36](https://kubernetes.io/docs/tasks/configure-pod-container/image-volumes/).
  Earlier releases that expose the feature may require the `ImageVolume` gate.
- The code-server image-volume mount must permit execution; some runtimes mount
  image volumes `noexec`.
- Digest-pinned workspace, code-server, and VSIX references that the cluster
  can resolve from its internal registry. If an image-rewriting agent is used,
  it must rewrite both `spec.containers[].image` and
  `spec.volumes[].image.reference` on dynamically provisioned Pods.
- A default StorageClass or an explicit `home_storage_class`, plus a CNI that
  enforces the platform egress policy. The StorageClass must support volume
  expansion to grow an existing home disk.

## Build and release

`just build-template-artifacts` builds the workspace images and publisher for
the local package. Use the root [local workflow](../README.md#local-deployment)
for deployment.

Image provenance and upgrade steps live in each workspace's Containerfiles,
locks, and README.

Published workspace images have mutable SemVer aliases and `sha-<commit>`
traceability tags. Consumers retain the readable version in a
`:<version>@sha256:<digest>` reference; the digest, not the tag, is the
immutable identity. Update every consumer when a digest changes. Retain old
digests while any template revision, release, package, or workspace uses them.
