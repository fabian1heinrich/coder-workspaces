# Kubernetes operations workspace

An air-gapped, language-neutral workspace with `kubectl` 1.36.5 and Helm 4.3.1.
code-server and approved extensions are separate read-only OCI image volumes.

## Workspace image

`image/Containerfile` pins the Trixie devcontainer and Kubernetes clients by
digest or checksum and verifies the non-root `coder` account contract.

Use `just build-template-artifacts` for the local OCI archive. The image
workflow publishes `sha-<commit>` traceability tags and SemVer tags. After
publishing a new version, update its tag-and-digest reference in the template
publisher and its digest-only reference in each transport package.

To upgrade the base, update its exact release tag and multi-architecture digest
in both `FROM` instructions and the matching source-image label. To upgrade a
client, update its version, source URL, checksum, and OCI label together.

## Extensions

`extensions/k8s-extensions.Containerfile` packages Kubernetes Tools 1.4.1 and
Red Hat YAML 2.0.0 from `extensions/k8s-extensions.lock`. The `k8s-vsix` image
is mounted at `/opt/vsix`, and `workspace-startup` installs it into persistent
storage, rebuilding the set only when the payload digest changes.

After publishing a new `k8s-vsix` version, update its tag-and-digest reference
and every transport-package digest together with each lock entry's version, URL,
and checksum.

## Cluster access

The workspace mounts no Kubernetes ServiceAccount token. Supply a kubeconfig at
`~/.kube/config`; it persists with the workspace home directory. Restrict the
file to the workspace user and check its effective access with:

```shell
chmod 700 ~/.kube
chmod 600 ~/.kube/config
kubectl auth can-i --list
```

The API server named by the kubeconfig must be reachable from the workspace,
and any referenced credential plugin must already be available offline.

## Using the workspace

- code-server, the web terminal, and SSH start in the selected repository, or
  `/home/coder` when none is configured.
- Use `kubectl`, `kubectl kustomize`, and `helm` from `/usr/local/bin`.
- Choose a Small, Standard, or Large workspace. Enable **Customize
  specifications** to set CPU and memory separately. The persistent home disk
  is an independent, increase-only setting.

The published `git_auth_mode` selects anonymous access, a generic Kubernetes
Secret, or Coder external auth. No option is tied to a particular Git service
or deployment tool.

## Persistence and offline behavior

Everything under `/home/coder`, including `~/.kube/config`, persists across
stops and pod replacement. `/tmp` is ephemeral, and the root filesystem and
tool layers are read-only.

Workspace startup performs no package-manager, extension-marketplace, or public
registry requests. The workspace, code-server, and k8s-vsix images must remain
digest-pinned and present in the environment's internal registry.
