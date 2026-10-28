# Development package

`local/zarf.yaml` packages locally built OCI images and imports shared platform
components from `zarf.yaml`. Run from the repository root with direnv loaded.

```sh
just create-kind-cluster
zarf init --components git-server --confirm
just package-dev-local
zarf package deploy "$BUILD_DIR/zarf-package-coder-workspaces-dev-local-amd64-0.1.0.tar.zst" --confirm
```

The cluster must meet the [workspace requirements](../workspaces/README.md#cluster-requirements).
The package includes Coder Community 2.36.0, PostgreSQL, two built-in
provisioners with an offline provider mirror, read-only Coder modules, both
workspace templates, and mirrored Git repositories. Runtime image references
use the digests of the local OCI archives. Development stays at `0.1.0`.

Rebuild and redeploy the same package to iterate. Container caching reuses
unchanged layers. Publication reuses unchanged template versions and updates
outdated workspaces sequentially. `coder update` stops and restarts running
workspaces and also starts stopped workspaces.

The development bootstrap creates its own publisher credential. Production
uses the separate [manually supplied token workflow](../release/README.md).
The development publisher maps Zarf's `private-git-server` Secret into the
templates' generic Git interface. Workspaces live in `coder`; publication runs
in `coder-template-publisher` without Kubernetes API permissions.

Coder and workspace pods run non-root. Namespace-scoped provisioner permissions
and a read-only CRD discovery role support provisioning; network policy limits
egress. `k8s-dev` mounts no ServiceAccount token: users supply `~/.kube/config`.
The local platform is a proof of concept without HA, backups, or recovery.
