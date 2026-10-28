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
and `SHA256SUMS`. The version comes from committed `HEAD`. Packaging refuses to
overwrite that directory, including when switching image sources. If a build
fails, remove only its incomplete output before retrying; retain completed
releases. Copy the complete directory to the disconnected host.

After either production build, copy the current commit's release to an existing
transport directory:

```sh
RELEASE_DESTINATION=/path/to/media just copy
RELEASE_DESTINATION=/path/to/media just copy-all
```

Choose `copy` for the publication package and deployment files when the images
are already mirrored, or `copy-all` to include the image package too. Both reuse
the built bundle, including its registry or local image references. They write
to `coder-workspaces/<release>-publish` or `coder-workspaces/<release>-all`
under the destination, regenerate checksums for the copied files, and refuse
to overwrite an existing directory. If a copy fails, remove only that incomplete
destination before retrying. `RELEASE_DESTINATION` can also be set in `.env`.

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
`zarf-config.yaml` supplies the deployment inputs. Pass your manually created
Coder token with `--set-variables CODER_TOKEN=...`, or as `ZARF_VAR_CODER_TOKEN`
to `just publish`, which forwards it to that flag. Keep the token out of config
files and release media.

The package declares a sensitive `CODER_TOKEN` variable and applies it through
the `coder-template-publisher-auth` Secret. It replaces the previous Job before
each deployment and waits for publication to complete. There are no Secret
cleanup hooks: the token remains in the Secret and Helm release history.
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
