# Production release

Production uses two Zarf packages. `images/` is mirror-only and carries the
publisher, workspace, module, code-server, and VSIX images. `publish/` is
deployed, and publishes the workspace templates to an existing Coder
deployment.

The production cluster is not Zarf-initialized. It has its own registry, so
the publication package is deployed with `zarf package deploy --connected`,
which applies the manifests as they are, without a Zarf registry, agent, or
image mutation. Every image reference it applies is already a fully qualified
reference to the internal registry, built from the `REGISTRY` variable and the
digests baked in at create time.

`SHA256SUMS` records the contents of the release media.

## Build release media

Run from the repository root with its direnv environment loaded. Build only the
publication package for template changes, or include the image mirror package
when an image reference changed:

```sh
just build-release
just build-release-all
```

The bundle is written to `$BUILD_DIR/coder-workspaces`. Copy that
directory to the transport media. Mirror images before publishing templates
that reference them.

## The publishing credential

The publisher authenticates with a Coder API token supplied at deploy time as
`ZARF_VAR_CODER_TOKEN`, never from a stored Secret. Create it with the Coder
CLI immediately before publishing, for an identity that holds only the rights
template publication needs. The package creates a Secret from it, runs the Job,
and deletes the Secret again on both the success and the failure path, so no
credential outlives the publication and none is ever written to this
repository, the package, or the release media.

A failed publication fails the deploy: the Job is a Zarf health check, so an
expired or insufficient token surfaces immediately rather than in a controller
log. Re-run the air-gapped publication command with a fresh token.

Publication is idempotent. Unchanged template content and unchanged image
digests resolve to a template version that is already active, and nothing is
republished.

## Deployment-owned values

The package fixes the Coder and publisher namespaces, pull Secret, Git auth
mode, and default branches. `release/publish/zarf.yaml` documents the remaining
deployment values. The consuming platform provides the registry, those fixed
names, Git access, and any selectable project images.

The templates resolve the pinned Coder modules and the shared `workspace-pod`
module from the `coder-modules` image at `/opt/coder-modules`. The consuming
platform must mount that image, mirrored by the images package, on the control
plane that runs the built-in provisioners; workspace builds fail at module
resolution otherwise.

Package versions and the publication package's OCI-free release identity are
derived from committed `HEAD` as `YYYY.MM.DD-g<12-character-sha>`.

Artifact definitions use `registry.invalid` as a logical transport registry.
Release packaging resolves it to the fixed connected source registry `ghcr.io`;
the disconnected destination is selected by `zarf package mirror-resources` and
by the `REGISTRY` variable at publication.

Consume `images/` only with `zarf package mirror-resources`; never deploy it.
