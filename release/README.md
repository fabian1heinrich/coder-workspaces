# Production release

Production uses two mirror-only Zarf packages: `source/` carries the Flux
source, while `images/` carries its publisher, workspace, code-server, and VSIX
images.

Use the root `build-release` or `copy-release` recipes for template changes and
their `-all` variants when image references change or complete recovery media
is needed. Mirror images before the Flux source that references them.

Published image references are pinned in `images/zarf.yaml` and recorded as
SemVer-and-digest references in `RELEASE-METADATA`. Update both consumers when
an image version changes. The Zarf transport image list remains digest-only for
registry-tool compatibility.

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
