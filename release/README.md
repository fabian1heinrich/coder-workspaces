# Production release

Production uses two mirror-only Zarf packages. `source/` carries the small,
frequently changing Flux source. `images/` carries the publisher, workspace,
code-server, and VSIX images and changes only when those artifacts change.

Use the repository-root `build-release` or `copy-release` recipes for ordinary
template changes. Use their `-all` variants when image references change or
when preparing complete recovery media. Images must reach Zot before the Flux
source that references them.

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
