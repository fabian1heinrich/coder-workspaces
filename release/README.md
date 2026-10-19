# Production release

Production uses two mirror-only Zarf packages. `source/` carries the small,
frequently changing Flux source. `images/` carries the publisher, workspace,
code-server, and VSIX images and changes only when those artifacts change.

Use the repository-root `build-release` or `copy-release` recipes for ordinary
template changes. Use their `-all` variants when image references change or
when preparing complete recovery media. Images must reach Zot before the Flux
source that references them. Generated Zarf package archives are written to the
repository root.

For an `-all` build, set `K8S_WORKSPACE_IMAGE` and `K8S_VSIX_IMAGE` to the
SemVer-tagged, digest-pinned references published by the container image
workflow, for example `ghcr.io/.../k8s-workspace:0.1.0@sha256:<digest>` and
`ghcr.io/.../k8s-vsix:0.1.0@sha256:<digest>`. The values are captured in the
images package; an unversioned or digest-free reference is rejected.
`RELEASE-METADATA` records the operator-facing version-and-digest references;
the Zarf transport image list remains digest-only for registry-tool
compatibility.

The packages are transport archives. Consume them only with
`zarf package mirror-resources`; never deploy them.

Both transferred package versions and the OCI tag are derived from committed
`HEAD` as `YYYY.MM.DD-g<12-character-sha>`. The source build renders
`flux-entrypoint.yaml` with the resulting digest. Mirroring does not activate
the source; applying that copied selector makes the consuming application root
activate it.

The source payload is namespace-neutral. Its generated entry point records the
exact OCI digest in the platform's watched release-selector ConfigMap. The
consuming platform owns the `OCIRepository` and child Kustomization that target
the dedicated `coder-template-publisher` namespace and configure the namespace
where Coder provisions user workspaces.

Artifact definitions use `registry.invalid` as a logical transport registry.
Release packaging resolves it to the fixed connected source registry
`ghcr.io`; the disconnected destination is selected by
`zarf package mirror-resources` and by the consuming Flux configuration.
