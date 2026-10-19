# Development package

`zarf.yaml` is the registry-backed deployment package; `local/zarf.yaml` is the
equivalent package for images built from this checkout. The `full` flavor
deploys the platform and templates. Run these commands from the repository root
after loading its direnv environment, against an initialized Zarf cluster that
meets the [workspace requirements](../workspaces/README.md#cluster-requirements).
Deployment and workspace startup remain disconnected for both variants.

## Platform contract

The package deploys Coder Community 2.36.0 with two built-in provisioners. Its
service account manages workspace resources only in the `coder` namespace; a
read-only cluster role permits the CRD discovery required by
`kubernetes_manifest`. The control-plane image supplies the offline OpenTofu
provider mirror, while the module payload is mounted read-only at
`/opt/coder-modules`.

Coder and workspace pods run non-root. Telemetry, update checks, the template
builder, public STUN, the default GitHub integration, AI Gateway, and direct
workspace connections are disabled. `deny-public-egress` permits DNS,
supported in-cluster services, and private networks; the cluster CNI must
enforce `NetworkPolicy`.

The package imports the digest-pinned `cnpg-zarf` package for CloudNativePG.
Its single-instance database defaults and lack of backups are suitable only for
this proof of concept. PostgreSQL and publisher credentials are created as
Kubernetes Secrets; the publisher receives a dedicated API token rather than
the administrator password. The publisher Job, token, and OpenTofu backend run
in `coder-template-publisher`; workspace resources remain in `coder`.

## Published-image deployment

```sh
export K8S_WORKSPACE_IMAGE='ghcr.io/fabian1heinrich/coder-workspaces/k8s-workspace:0.1.0@sha256:<64-hex-digest>'
export K8S_VSIX_IMAGE='ghcr.io/fabian1heinrich/coder-workspaces/k8s-vsix:0.1.0@sha256:<64-hex-digest>'
just package-registry
zarf package deploy zarf-package-coder-registry-amd64-0.1.0-full.tar.zst \
  --components=template-artifacts,publish-template --confirm
```

This variant pulls every project-owned image from GHCR by immutable digest when
the package is created. `K8S_WORKSPACE_IMAGE` and `K8S_VSIX_IMAGE` are required
because their digests are produced only after the container image workflow
publishes the current commit.

## Locally built deployment

```sh
just package-local
zarf package deploy zarf-package-coder-local-amd64-0.1.0-full.tar.zst \
  --components=template-artifacts,publish-template --confirm
```

This variant builds the Coder control plane, module payload, publisher,
workspace, code-server, Python and Kubernetes VSIX, and project images, then
packages their OCI archives. The Kubernetes workspace is built from the pinned
devcontainer base with checksum-locked kubectl and Helm clients.

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

The existing publisher Job runs its bundled Coder CLI with its existing token.
It lists outdated workspaces belonging to both templates and updates them
sequentially. A running workspace is stopped, updated, and started; stopped
workspaces are also started by `coder update`. No host Coder CLI is needed.

Recreate the registry package after changing an image pin, or rebuild the local
package after changing its image inputs. Every template package includes all
repository-owned images, both Python project environments, the Kubernetes
workspace and VSIX images, and the mirrored Git repositories. Only `full`
includes the Coder control-plane and module images; template iteration does not
redeploy the platform.

Publication performs a full apply of both templates using the shared Kubernetes
Secret-backed state.

This remains a proof-of-concept deployment package; it does not add production
database backups, recovery, high availability, or monitoring.

Production workspace publication is a separate Flux OCI release under
`release/`; it does not replace or alter this local deployment workflow.

When upgrading the platform, update the chart, source-image digests, provider
versions, module locks, and Zarf consumers together. Database upgrades require
a tested backup and recovery path.
