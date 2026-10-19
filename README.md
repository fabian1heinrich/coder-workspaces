# Air-gapped Coder platform

This repository packages Coder Community Edition for local development and
owns two production workspace templates for disconnected Kubernetes. Platform
tooling is distributed as immutable OCI artifacts through Zarf; user data
persists under `/home/coder`.

## Repository layout

| Path                                                  | Responsibility                                                    |
| ----------------------------------------------------- | ----------------------------------------------------------------- |
| [`modules/`](modules/README.md)                       | Pinned Coder modules packaged as one OCI image                    |
| [`workspaces/`](workspaces/README.md)                 | Runtime images and the `python-workspace` and `k8s-dev` templates |
| [`template-publisher/`](template-publisher/README.md) | Publisher code and generic runtime                                |
| [`dev/`](dev/README.md)                               | Local package, publisher overlay, control plane, and Helm values  |
| [`release/`](release/README.md)                       | Production Flux source and image mirror packages                  |

The deployable package can either pull the repository's published,
SemVer-tagged and digest-pinned OCI images or consume OCI archives built from
this checkout.

## Requirements

- An amd64 Kubernetes cluster with OCI image-volume support, a default
  StorageClass, and a CNI that enforces `NetworkPolicy`.
- A connected Linux/amd64 package host with Bash, direnv, Just, mise 2026.10.14,
  Podman, Skopeo, jq, yq, ORAS, curl, Zarf, and `kubectl`. mise, Podman, and
  Skopeo are needed only for the local-build variant. Runtime deployment and
  workspace startup require no public internet access.

See [workspace requirements](workspaces/README.md#cluster-requirements) before
deployment.

## Setup

```sh
cp .env.example .env
direnv allow
```

`CACHE_DIR` defaults to `.cache`; relative values are resolved from the
repository root. Run `just --list` for the available operational commands.

## Local deployment

Follow [the development workflow](dev/README.md) for the explicit Zarf package
creation and deployment commands. `just package-registry` uses published images;
`just package-local` builds the same layers locally. Both write their package to
the repository root. Both publish all templates and update all outdated
workspaces by default; no registry push or host Coder CLI is needed.

Forward the Coder service with
`kubectl -n coder port-forward service/coder 8080:80`, then sign in at
`http://localhost:8080` as `admin@coder.local`. The proof-of-concept password
is `ChangeMe123_`; override `CODER_ADMIN_PASSWORD` for every non-ephemeral
deployment.

This repository is not a production-ready Coder or PostgreSQL deployment. It
does not configure high availability, backups, recovery, or monitoring.

## Production template publication

The production platform remains consumer-owned. This repository publishes an
independent `coder-workspaces` Flux OCI source containing the workspace
templates and generic publisher runtime. The consuming platform owns the
credentials, registry access, application of the digest selector entry point,
and production configuration. Its local configuration Kustomization creates the target
`coder-template-publisher` namespace and substitution values; the independently
sourced child Kustomization declares the production name prefix and targets that
namespace. Actual workspace resources remain in the separately configured
Coder namespace. The source owns the publisher Job, its immutable image
references, and the namespace-scoped RBAC for Secret-backed OpenTofu state.

Build an ordinary source release with `just build-release`; use
`just build-release-all` when a referenced image changed. On the disconnected
host, mirror images first and the source last, then apply the copied
`flux-entrypoint.yaml` to activate the exact built digest through Flux without
runtime Git or a Zarf deployment.
