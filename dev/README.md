# Development package

`zarf.yaml` is the self-contained local deployment package. The `full` flavor
deploys the platform and templates; without that flavor, the package includes
only bootstrap and template components. Run these commands from the repository
root after loading its direnv environment, against an initialized Zarf cluster
that meets the [workspace requirements](../workspaces/README.md#cluster-requirements).
Direnv defaults `ZARF_CONFIG` to the absolute path of `dev/zarf-config.yaml`;
the build command below creates that ignored file before Zarf reads it.

`just build-platform-artifacts` builds the Coder control plane and module
payload. `just build-template-artifacts` builds the publisher and workspace
images. Each command refreshes the local Zarf inputs for every complete
artifact group already present; `just build-all` builds both groups.

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

## Full local deployment

```sh
just build-all
zarf package create dev --flavor full --confirm --output .
zarf package deploy zarf-package-coder-local-dev-amd64-0.1.0-full.tar.zst \
  --components=template-artifacts,publish-template --confirm
```

## Template and workspace iteration

On an existing platform, publish one template and update every outdated
workspace created from it:

```sh
just build-template-artifacts # Omit when no template image changed.
zarf package create dev --set PUBLISH_TEMPLATE=python --confirm --output .
zarf package deploy zarf-package-coder-local-dev-amd64-0.1.0.tar.zst \
  --components=template-artifacts,publish-template --confirm
```

The build recipes refresh `dev/zarf-config.yaml` after writing the local OCI
archives. The generated file contains their digest-pinned references. If the
platform archives exist, their references are included for a later
`--flavor full` package creation.

Package selection belongs to `zarf package create`. `PUBLISH_TEMPLATE` accepts
`python`, `k8s-dev`, or `all`. `UPDATE_WORKSPACE` defaults to `all`, which means
all outdated workspaces from the selected template or templates. To update one
workspace or publish without updating workspaces, override it explicitly:

```sh
# Update one existing workspace after publishing Python.
zarf package create dev \
  --set PUBLISH_TEMPLATE=python \
  --set UPDATE_WORKSPACE=admin/my-python-dev \
  --confirm --output .

# Publish Python without updating any workspace.
zarf package create dev \
  --set PUBLISH_TEMPLATE=python \
  --set UPDATE_WORKSPACE= \
  --confirm --output .
```

The existing publisher Job runs its bundled Coder CLI with its existing token.
For `all`, it lists outdated workspaces belonging to each published template
and updates them sequentially. A running workspace is stopped, updated, and
started; stopped workspaces are also started by `coder update`. No host Coder
CLI is needed.

Recreate the package after rebuilding because its image inputs are baked into
the archive. Every template package includes all six local template images,
both project environments included, and the mirrored Git repositories. Only
`full` reads the Coder and module archives; template iteration does not redeploy
the platform.

Single-template publication uses a targeted apply in the existing publisher
Job and shared Kubernetes Secret-backed state. `all` performs a full apply of
both templates.

Never promote this package to production: its `.internal` image names exist
only inside the package.

Production workspace publication is a separate Flux OCI release under
`release/`; it does not replace or alter this local deployment workflow.

When upgrading the platform, update the chart, source-image digests, provider
versions, module locks, and Zarf consumers together. Database upgrades require
a tested backup and recovery path.
