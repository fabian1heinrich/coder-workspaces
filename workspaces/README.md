# Workspaces

This directory owns two Coder templates for disconnected Kubernetes:

- `python-workspace` is a Python 3.13 development environment with approved
  extensions and optional locked project environments.
- `k8s-dev` is a language-neutral operations environment for working with a
  Kubernetes cluster through `kubectl`, Kustomize, and Helm.

## Runtime behavior

Both templates persist `/home/coder`, request and limit CPU and memory, limit
ephemeral storage, and run as UID/GID 1000 with the restricted pod defaults.
code-server is mounted read-only at `/opt/vscode-server`. Each template mounts
its independently versioned approved VSIX set at `/opt/vsix` and installs it
into persistent `/home/coder`; the Kubernetes template gets checksum-locked
`kubectl` and Helm clients from its dedicated workspace image. Startup never
contacts package managers, extension marketplaces, or public artifact
registries.

See the [Python workspace](python/README.md) and [Kubernetes
workspace](k8s-dev/README.md) documentation for template-specific behavior.

The `k8s-dev` environment selects an existing ServiceAccount and target
namespace. RBAC remains environment-owned; grant only the required namespaces
and verbs.

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
