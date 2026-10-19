# Air-gapped Coder platform

This repository packages Coder Community Edition and two workspace templates
for disconnected Kubernetes. Platform tooling is distributed through OCI and
Zarf; workspace state persists under `/home/coder`.

## Repository layout

| Path                                                  | Responsibility                                                    |
| ----------------------------------------------------- | ----------------------------------------------------------------- |
| [`modules/`](modules/README.md)                       | Pinned Coder modules packaged as one OCI image                    |
| [`workspaces/`](workspaces/README.md)                 | Runtime images and the `python-workspace` and `k8s-dev` templates |
| [`template-publisher/`](template-publisher/README.md) | Publisher code and generic runtime                                |
| [`dev/`](dev/README.md)                               | Local package, publisher overlay, control plane, and Helm values  |
| [`release/`](release/README.md)                       | Production Flux source and image mirror packages                  |

## Requirements

- An amd64 Kubernetes cluster with OCI image volumes, a default StorageClass,
  and a CNI that enforces `NetworkPolicy`.
- A connected Linux/amd64 packaging host with Bash, direnv, Just, mise
  2026.10.14, jq, yq, ORAS, curl, Zarf, and `kubectl`. Local image builds also
  require Podman and Skopeo.

See [workspace requirements](workspaces/README.md#cluster-requirements) before
deployment. Deployment and workspace startup require no public internet.

## Setup

```sh
cp .env.example .env
direnv allow
```

Run `just --list` for the operational commands.

## Local deployment

Follow the [development workflow](dev/README.md) to create and deploy either a
registry-backed package or one built from this checkout.

Forward the Coder service with
`kubectl -n coder port-forward service/coder 8080:80`, then sign in at
`http://localhost:8080` as `admin@coder.local`. The proof-of-concept password
is `ChangeMe123_`; override `CODER_ADMIN_PASSWORD` for every non-ephemeral
deployment.

The local package is a proof of concept without high availability, backups,
recovery, or monitoring.

## Production template publication

Production publication uses digest-pinned Flux OCI source and mirror-only Zarf
packages. The consuming platform owns credentials, registry access, namespaces,
and environment configuration. See the [production release
workflow](release/README.md).
