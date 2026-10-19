# Kubernetes operations workspace

An air-gapped workspace for operating a Kubernetes cluster. It contains no
language or project runtime. Its dedicated workspace image is based on the VS
Code Debian Trixie devcontainer and contains `kubectl` 1.36.5 and Helm 4.3.1.
code-server and the approved Kubernetes extension set are separate, read-only
OCI image volumes.

## Workspace image

`image/Containerfile` is the image definition. It pins the Trixie devcontainer
by digest, renames its UID/GID 1000 `vscode` account to `coder`, and verifies
the resulting home, zsh shell, ownership, sudoers entry, and required command
set. On a connected build host, remote `ADD --checksum` instructions admit only
the recorded Helm and kubectl artifacts before copying the clients into the
runtime image.

Use `just build-template-artifacts` for the local OCI archive. The image
workflow publishes immutable `sha-<commit>` and SemVer tags. Resolve the SemVer
tag to a digest and set `K8S_WORKSPACE_IMAGE` to
`.../k8s-workspace:<version>@sha256:<digest>` when creating a registry-backed
or production images package. Package creation rejects an omitted or unversioned
value rather than falling back to a tool-less image.

To upgrade the base, update its exact release tag and multi-architecture digest
in both `FROM` instructions and the matching source-image label. To upgrade a
client, update its version, source URL, checksum, and OCI label together.

## Extensions

`extensions/k8s-extensions.Containerfile` packages Kubernetes Tools 1.4.1 and
its Red Hat YAML 2.0.0 dependency from the checksum-pinned sources in
`extensions/k8s-extensions.lock`. The independently released `k8s-vsix` image
starts at `0.1.0`. It is mounted read-only at `/opt/vsix`; startup installs the
local files into the extension directory under persistent `/home/coder` without
contacting a marketplace.

Set `K8S_VSIX_IMAGE` to
`.../k8s-vsix:<version>@sha256:<digest>` alongside `K8S_WORKSPACE_IMAGE` when
creating a registry-backed or production images package. To upgrade the set,
update every extension version, Open VSX URL, and SHA-256 in the lock together.

## Cluster access

The workspace uses the existing `kubernetes_service_account_name` in its own
namespace. Kubernetes mounts a short-lived, rotating projected token, and the
startup command writes a dedicated kubeconfig at
`~/.kube/coder-in-cluster` that refers to that token rather than copying it.
The kubeconfig defaults to `kubernetes_target_namespace`.

The template deliberately creates no RBAC objects. The platform owner must bind
the ServiceAccount only to the namespaces and verbs its users require. The
default ServiceAccount is safe for local evaluation but ordinarily has no API
permissions. Check the effective access from a workspace with:

```shell
kubectl auth can-i --list
```

## Using the workspace

- Open **code-server**, the web terminal, or SSH. All start in the selected
  repository, or `/home/coder` when no repository is configured, with zsh as
  the default shell.
- Use `kubectl`, `kubectl kustomize`, and `helm` directly from
  `/usr/local/bin`; they never install or download themselves at startup.
- Choose a Small, Standard, or Large workspace. Enable **Customize
  specifications** to set CPU and memory separately. The persistent home disk
  is an independent, increase-only setting.
- Use Coder port forwarding for services reached through the workspace.

The optional repository is cloned from the configured internal Git mirror. In
the local Zarf environment its `origin` is pull-only; add a separate internal
development remote before pushing.

## Persistence and offline behavior

Everything under `/home/coder` persists across workspace stops and pod
replacement, including repositories, additional kubeconfig files, Helm state,
caches, and editor settings. `/tmp` is ephemeral, and the managed in-cluster
kubeconfig is recreated at startup. The container root filesystem and all tool
layers are read-only.

Workspace startup performs no package-manager, extension-marketplace, or public
registry requests. The workspace, code-server, and k8s-vsix images must remain
digest-pinned and present in Zarf or the environment's internal registry.
