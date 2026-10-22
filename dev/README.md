# Development package

`zarf.yaml` uses published images; `local/zarf.yaml` builds them from this
checkout. Run commands from the repository root after loading its direnv
environment.

## Cluster preparation

Create the development cluster and initialize Zarf with its Git server before
deploying either package. Its internal registry serves the workspace images,
while the Git server serves the mirrored repository and dotfiles:

```sh
just create-kind-cluster
zarf init --components git-server --confirm
```

The cluster must meet the [workspace
requirements](../workspaces/README.md#cluster-requirements).

The development publisher selects `git_auth_mode=secret` and maps Zarf's
`private-git-server` Secret into the templates' generic Git interface; the
templates themselves do not depend on Zarf-specific names or behavior.

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
publisher runs in `coder-template-publisher` with a dedicated API token, no
Kubernetes permissions, and no persistent state; workspaces remain in `coder`.

The `k8s-dev` workspace mounts no Kubernetes ServiceAccount token. Users place
their own kubeconfig at `~/.kube/config`, which persists with the workspace
home directory.

## Published-image deployment

```sh
just package-registry
zarf package deploy zarf-package-coder-registry-amd64-0.1.0-full.tar.zst --confirm
```

The package definition records every published image by immutable digest.

## Locally built deployment

```sh
just package-local
zarf package deploy zarf-package-coder-local-amd64-0.1.0-full.tar.zst --confirm
```

This builds and packages OCI archives for every repository-owned image.

## Template and workspace iteration

On an existing platform, publish both templates and update every outdated
workspace:

```sh
just package-registry-templates
zarf package deploy zarf-package-coder-registry-amd64-0.1.0.tar.zst --confirm
```

For the same iteration with locally built images:

```sh
just package-local-templates
zarf package deploy zarf-package-coder-local-amd64-0.1.0.tar.zst --confirm
```

Template packages publish both templates through the existing publisher Job
and update outdated workspaces sequentially. Publication is idempotent:
re-deploying unchanged templates with unchanged image digests leaves the active
template version in place. Running workspaces are stopped,
updated, and restarted; `coder update` also starts stopped workspaces. No host
Coder CLI is required. Only the `full` flavor includes the control plane and
module images.

When upgrading the platform, update the chart, source-image digests, provider
versions, module locks, and Zarf consumers together. Database upgrades require
a tested backup and recovery path.
