# Production release

Production uses two mirror-only Zarf packages: `source/` carries the Flux
source, while `images/` carries its publisher, workspace, code-server, and VSIX
images.

Use the root `build-release` or `copy-release` recipes for template changes and
their `-all` variants when image references change or complete recovery media
is needed. Mirror images before the Flux source that references them.

For an `-all` build, set `K8S_WORKSPACE_IMAGE` and `K8S_VSIX_IMAGE` to the
SemVer-tagged, digest-pinned references published by the container image
workflow, for example `ghcr.io/.../k8s-workspace:0.1.0@sha256:<digest>` and
`ghcr.io/.../k8s-vsix:0.1.0@sha256:<digest>`. The values are captured in the
images package; an unversioned or digest-free reference is rejected.
`RELEASE-METADATA` records the operator-facing version-and-digest references;
the Zarf transport image list remains digest-only for registry-tool
compatibility.

Consume these transport archives only with `zarf package mirror-resources`;
never deploy them.

Package versions and the OCI tag are derived from committed `HEAD` as
`YYYY.MM.DD-g<12-character-sha>`. The generated `flux-entrypoint.yaml` selects
the exact source digest; mirroring alone does not activate it.

The source is namespace-neutral. The consuming platform owns the
`OCIRepository`, child Kustomization, publisher namespace, and workspace
namespace configuration.

Artifact definitions use `registry.invalid` as a logical transport registry.
Release packaging resolves it to the fixed connected source registry
`ghcr.io`; the disconnected destination is selected by
`zarf package mirror-resources` and by the consuming Flux configuration.
