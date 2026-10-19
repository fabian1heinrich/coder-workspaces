# Development package

`zarf.yaml` uses published images; `local/zarf.yaml` builds them from this
checkout. Run commands from the repository root after loading its direnv
environment, against an initialized Zarf cluster that meets the [workspace
requirements](../workspaces/README.md#cluster-requirements).

## Platform contract

The full package deploys Coder Community 2.36.0 with two built-in provisioners,
an offline OpenTofu provider mirror, and read-only Coder modules. Its service
account manages workspace resources only in `coder`; a read-only cluster role
permits CRD discovery.

Coder and workspace pods run non-root. Telemetry, update checks, the template
builder, public STUN, the default GitHub integration, AI Gateway, and direct
workspace connections are disabled. `deny-public-egress` permits DNS,
supported in-cluster services, and private networks; the cluster CNI must
enforce `NetworkPolicy`.

The digest-pinned `cnpg-zarf` dependency provides a single PostgreSQL instance
without backups. PostgreSQL credentials are stored in Kubernetes Secrets. The
publisher uses a dedicated API token and runs with its OpenTofu backend in
`coder-template-publisher`; workspaces remain in `coder`.

## Published-image deployment

```sh
export K8S_WORKSPACE_IMAGE='ghcr.io/fabian1heinrich/coder-workspaces/k8s-workspace:0.1.0@sha256:<64-hex-digest>'
export K8S_VSIX_IMAGE='ghcr.io/fabian1heinrich/coder-workspaces/k8s-vsix:0.1.0@sha256:<64-hex-digest>'
just package-registry
zarf package deploy zarf-package-coder-registry-amd64-0.1.0-full.tar.zst \
  --components=template-artifacts,publish-template --confirm
```

The Kubernetes image variables are required digest-pinned references published
by the container-image workflow.

## Locally built deployment

```sh
just package-local
zarf package deploy zarf-package-coder-local-amd64-0.1.0-full.tar.zst \
  --components=template-artifacts,publish-template --confirm
```

This builds and packages OCI archives for every repository-owned image.

## Template and workspace iteration

On an existing platform, publish both templates and update every outdated
workspace:

```sh
export K8S_WORKSPACE_IMAGE='ghcr.io/fabian1heinrich/coder-workspaces/k8s-workspace:0.1.0@sha256:<64-hex-digest>'
export K8S_VSIX_IMAGE='ghcr.io/fabian1heinrich/coder-workspaces/k8s-vsix:0.1.0@sha256:<64-hex-digest>'
just package-registry-templates
zarf package deploy zarf-package-coder-registry-amd64-0.1.0.tar.zst \
  --components=template-artifacts,publish-template --confirm
```

For the same iteration with locally built images:

```sh
just package-local-templates
zarf package deploy zarf-package-coder-local-amd64-0.1.0.tar.zst \
  --components=template-artifacts,publish-template --confirm
```

Template packages publish both templates through the existing publisher Job
and update outdated workspaces sequentially. Running workspaces are stopped,
updated, and restarted; `coder update` also starts stopped workspaces. No host
Coder CLI is required. Only the `full` flavor includes the control plane and
module images.

When upgrading the platform, update the chart, source-image digests, provider
versions, module locks, and Zarf consumers together. Database upgrades require
a tested backup and recovery path.
