# Production release

Production needs two packages: `coder-workspaces-images` mirrors images into
an existing registry; `coder-workspaces-publish` publishes both templates into
an existing Coder Community deployment. Only the latter is deployed, with
`--connected` so Zarf preserves the internal image references.

| Path | Responsibility |
| --- | --- |
| `images-registry.yaml` | Mirror package using published, digest-pinned images |
| `images-local.yaml` | Mirror package using locally built OCI archives |
| `publish.yaml` | Template publication package |
| `publisher/` | Production publisher overlay |
| `deploy/` | Deployment files copied into each release bundle |

## Build

Choose one source, from a clean committed checkout:

| Command                            | Image source                                           |
| ---------------------------------- | ------------------------------------------------------ |
| `just package-production-registry` | Published digests in `images-registry.yaml`            |
| `just package-production-local`    | Images built from this checkout, saved as OCI archives |

Both produce `$BUILD_DIR/releases/YYYY.MM.DD-g<12-character-sha>` with the two
packages, deployment instructions, `zarf-config.yaml`, `.env.example`, `RELEASE-METADATA`,
and `SHA256SUMS`. The version comes from committed `HEAD`. Packaging builds in a
temporary directory and replaces the local bundle only after success, including
when switching image sources. A failed build leaves the previous bundle intact.

Build and copy the current commit's release to an existing transport directory:

```sh
just copy /path/to/media
just copy-all /path/to/media
just copy-all-local /path/to/media
```

Choose `copy` for the publication package and deployment files when the images
are already mirrored, or `copy-all` to include the image package too. These use
published image pins. Use `copy-all-local` to build local images and copy both
production packages with their deployment files. Every copy command rebuilds
its packages on every run; local image builds reuse cached layers where possible.
A failed build stops the copy. All require a clean committed checkout. They write
to `coder-workspaces/<release>-publish` or `coder-workspaces/<release>-all`
under the destination, overwrite matching files, and regenerate checksums.
Repeated runs can reuse the same destination; shipped configuration files are
also overwritten. Omit the argument to use `RELEASE_DESTINATION` from the
environment or `.env` loaded by direnv; an explicit argument takes precedence.

Run the recipes as your normal user with write access to the transport directory.
Release directories on the media are `0755`; shipped files and local production
bundle files are `0644`, even with a restrictive Linux umask. Copying stages the
payload before replacing shipped files, including read-only files from a previous
run. Existing operator files such as `.env` and `kubeconfig` keep their permissions
and are excluded from generated checksums. The recipes do not change ownership
or permissions on the transport directory or its ancestors; those must already
allow the intended users access.

`images-registry.yaml` owns the production pins. Packaging feeds those same
references into publication and fills the project images in `zarf-config.yaml`.
Local builds use the same repository paths and their actual archive digests.
No registry push is required to build local production media.
Preserve old digests while any template revision, package, release, or workspace
references them.

For a registry-based release containing image changes:

1. Merge the image sources and wait for the successful `main` image workflow.
2. Copy the changed images' references from that run's Actions summary into
   `images-registry.yaml`, replacing only `ghcr.io` with the package's logical
   registry `registry.invalid`. Commit the pin changes; keep unchanged pins.
3. Build from that clean commit with `just package-production-registry`.

Source changes alone never update deployed images. Local production packaging
uses the checkout's image sources directly and needs no registry publication.
Templates receive their image references from the publisher. Image versions
remain independent; packaging does not bump them.

## Publish

Follow the [copied release instructions](deploy/README.md). The shipped
`just deploy` mirrors that release's images and then publishes its templates;
`just publish` handles publication-only media. Packaging binds both recipes to
the exact release package names. Both use the adjacent `zarf-config.yaml`
explicitly, including when the shell has an inherited `ZARF_CONFIG`.
The config supplies the deployment inputs. `just deploy` and `just publish`
prompt for your manually created Coder token with input hidden; their Bash
prompt also works when invoked from Zsh. For noninteractive use, supply
`ZARF_VAR_CODER_TOKEN` in the environment. The recipe forwards the token through
`--set-variables`. Keep the token out of config files and release media.

The package declares a sensitive `CODER_TOKEN` variable and applies it through
the `coder-template-publisher-auth` Secret. Each deployment deletes the previous
publisher Job and applies the ConfigMaps normally. Deployment checks the new
Job UID, release annotations, publisher image, and every workspace/tooling image
reference in its environment ConfigMap against the requested release inputs.
It waits for completion and requires activation evidence for both templates from
that same Job. The publisher verifies that each active, successful version has
the expected hash of template files and supplied variables. A mismatch fails
deployment; failure output includes the Job status and recent publisher logs.
There are no Secret cleanup hooks: the token remains in the Secret and Helm
release history.
Revoke the API token in Coder after every attempt, including failed deployments.

Publication remains stateless and idempotent: template files and published
variables determine the version. Production never updates existing workspaces
automatically. A template-only release can use the registry recipe and skip
mirroring when all pinned images are already present.

## Platform responsibilities

The consuming platform provides the namespaces, Coder service, Git access,
and any platform CA. The credential responsibilities are:

| Namespace                                | Secret                          | Owner                                            |
| ---------------------------------------- | ------------------------------- | ------------------------------------------------ |
| `coder-template-publisher`               | `zot-reader`                    | Platform: registry pull access                   |
| `coder-template-publisher`               | `coder-template-publisher-auth` | Package: supplied Coder API token                |
| Workspace namespace (`coder` by default) | `private-registry`              | Platform: workspace and image-volume pull access |

The Coder token cannot replace either registry credential.

Mount the release's `CODER_MODULES_IMAGE` from `RELEASE-METADATA` read-only at
`/opt/coder-modules` on Coder's built-in provisioner control plane. The
repository-owned `workspace-pod` module travels inside the template payload.
Publication no longer inspects a particular Deployment's volume names; module
resolution errors fail the publication Job itself.
