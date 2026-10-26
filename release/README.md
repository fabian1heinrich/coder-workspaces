# Production release

Production uses two Zarf packages. `coder-workspaces-image-mirror` is
mirror-only and carries the publisher, workspace, module, code-server, and
VSIX images. `coder-workspaces-template-publisher` is deployed and publishes
the workspace templates to an existing Coder deployment.

The production cluster uses its own registry for this independently released
payload. The publication package is deployed with `zarf package deploy
--connected`, which applies its fully qualified image references without
importing or rewriting them. Each reference is built from the `REGISTRY`
variable and the digests baked in at create time.

`SHA256SUMS` records the contents of the release media.

## Package release media

Run from the repository root with its direnv environment loaded. Package only the
publication package for template changes, or include the image mirror package
when an image reference changed:

```sh
just package-release-templates
just package-release
```

The bundle and its package archives are written directly to
`$BUILD_DIR/coder-workspaces`; production packaging does not stage another copy
in the repository root. `BUILD_DIR`, Zarf's cache, and temporary data all live
below `CACHE_DIR`, so set `CACHE_DIR` to a filesystem with enough free space
before entering the direnv environment when creating image-mirror packages.
Copy the bundle directory to the transport media. Mirror images before
publishing templates that reference them.

To build and copy directly to an existing writable transport-media directory,
run `just copy /path/to/media` for publication-only media or `just copy-all
/path/to/media` for publication and image-mirror media. `RELEASE_DESTINATION`
can provide the default when the positional destination is omitted. Each recipe
replaces only the destination's `coder-workspaces` directory.

## The publishing credential

The publisher authenticates with a short-lived Coder API token entered at the
hidden `just publish` prompt, never from a stored Secret. The copied release's
recipe maps that and the `.env` publication inputs into Zarf's deploy
configuration, then runs the package in connected mode. Create the token
manually in Coder from an account with Template Admin or Owner rights, and
revoke it immediately afterward. The package creates the Kubernetes Secret
imperatively rather than rendering it into Helm release data, runs the Job, and
deletes the Secret through `onSuccess` only after the Job health check has
completed. It deliberately does not use the earlier post-apply `after` phase.
On failure it deletes the Job before the Secret, preventing a retained Pod from
referencing a credential that no longer exists. If Kubernetes cannot confirm
Job deletion, cleanup stops and preserves the Secret for the still-existing
Job. The token is command-scoped and never enters this repository, package,
release media, or rendered Helm state.

A failed publication fails the deploy: the Job is a Zarf health check, so an
expired or insufficient token surfaces immediately rather than in a controller
log. Re-run the connected deployment with a fresh token.

Publication is idempotent. Unchanged template content and unchanged image
digests resolve to a template version that is already active, and nothing is
republished.

## Deployment-owned values

The package fixes the Coder and publisher namespaces, the publisher's
`zot-reader` pull Secret, Git auth mode, and default branches.
`release/publish/zarf.yaml` documents the remaining deployment values. The
consuming platform provides the registry, those fixed names, Git access, and
any selectable project images.

The templates resolve pinned upstream Coder modules from the `coder-modules`
image at `/opt/coder-modules`; the publisher bundles the repository-owned
`workspace-pod` module into each template archive. The consuming platform must
transport and mount that exact image digest on the control plane that runs the
built-in provisioners or upstream module resolution fails. The image remains
in this portable images package even when a
platform deployment package also transports it atomically with Coder. Before
creating its short-lived credential or Job, the publication package verifies
that the completed Coder rollout declares that exact volume reference and
read-only mount. The check does not require `pods/exec` permission.

Package versions and the publication package's OCI-free release identity are
derived from committed `HEAD` as `YYYY.MM.DD-g<12-character-sha>`.

Artifact definitions use `registry.invalid` as a logical transport registry.
Release packaging resolves it to the fixed connected source registry `ghcr.io`;
the disconnected destination is selected by `zarf package mirror-resources` and
by the `REGISTRY` variable at publication.

Consume `images/` only with `zarf package mirror-resources`; never deploy it.
