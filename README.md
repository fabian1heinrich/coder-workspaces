# Air-gapped Coder platform

This repository packages Coder Community Edition and two workspace templates
for disconnected Kubernetes. Platform tooling is distributed through OCI and
Zarf; workspace state persists under `/home/coder`.

## Repository layout

| Path                                                  | Responsibility                                                    |
| ----------------------------------------------------- | ----------------------------------------------------------------- |
| [`modules/`](modules/README.md)                       | Pinned Coder modules packaged as one OCI image                    |
| [`workspaces/`](workspaces/README.md)                 | Runtime images and the `python-workspace` and `k8s-dev` templates |
| [`template-publisher/`](template-publisher/README.md) | Publisher script and generic Coder CLI runtime                    |
| [`dev/`](dev/README.md)                               | Local package, publisher overlay, control plane, and Helm values  |
| [`release/`](release/README.md)                       | Production template publication and image mirror packages         |

## Requirements

- An amd64 Kubernetes cluster with OCI image volumes, a default StorageClass,
  and a CNI that enforces `NetworkPolicy`.
- A connected Linux/amd64 packaging host with Bash, direnv, Git, Just, jq,
  sha256sum, Zarf 0.83 or later, and `kubectl`. Local image builds also require
  Podman and Skopeo; the local cluster recipes require kind.

See [workspace requirements](workspaces/README.md#cluster-requirements) before
deployment. Deployment and workspace startup require no public internet.

## Setup

```sh
cp .env.example .env
direnv allow
```

There are three packaging commands:

| Command | Result |
| --- | --- |
| `just package-production-registry` | Production media using published, pinned images |
| `just package-production-local` | Production media using images built from this checkout |
| `just package-dev-local` | Complete development platform using local image builds |

Production output is versioned under `$BUILD_DIR/releases`; development output
is directly under `$BUILD_DIR`. Use `just copy` for publication-only media or
`just copy-all` for the complete production bundle, with `RELEASE_DESTINATION`
set to the transport directory. `just --list` also includes kind-cluster helpers.
The owning READMEs document copying and deployment.

## Local deployment

Follow the [development workflow](dev/README.md) to build and deploy the local
platform.

Forward the Coder service with
`kubectl -n coder port-forward service/coder 8080:80`, then sign in at
`http://localhost:8080` as `admin@coder.local`. The proof-of-concept password
is `CoderZarf123?!`; override `CODER_ADMIN_PASSWORD` for every non-ephemeral
deployment.

The local package is a proof of concept without high availability, backups,
recovery, or monitoring.

## Production template publication

Production mirrors digest-pinned images into the internal registry, then
publishes the templates with `zarf package deploy --connected` using the
platform's existing registry without image rewriting. The publishing token is
supplied for that one command and never stored in release media. The consuming platform owns
credentials, registry access, namespaces, and environment configuration. See the
[production release workflow](release/README.md).

## Image CI

One workflow builds the image matrix on image-input changes. Projects come from
`workspaces/python/projects.json`; BuildKit caching handles unchanged images.
Pull requests build only; pushes and manual runs on `main` also publish.
The same build options apply to both. Locked `uv sync` inside project builds
rejects stale lockfiles; CI does not rewrite branches or need a lockfile bot.
Published references appear in the Actions summary. Copy changed digests into
`release/images/zarf.yaml` before packaging from the registry. Templates
require the publisher to supply image references; they have no public-registry
fallbacks. Template and publisher validation happens at publication.
