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
- A connected Linux/amd64 packaging host with Bash, direnv, Git, Just, jq, yq,
  ORAS, curl, Zarf 0.83 or later, and `kubectl`. Local image builds also require
  Podman and Skopeo; the local cluster recipes require kind.

See [workspace requirements](workspaces/README.md#cluster-requirements) before
deployment. Deployment and workspace startup require no public internet.

## Setup

```sh
cp .env.example .env
direnv allow
```

Run `just --list` for the local build, packaging, release, and kind-cluster
helpers. The owning README documents each workflow and its direct package
deployment command.

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

Production mirrors digest-pinned images into the internal registry, then
publishes the templates with `zarf package deploy --connected` against a
cluster that was never Zarf-initialized. The publishing token is supplied for
that one command and is never stored. The consuming platform owns credentials,
registry access, namespaces, and environment configuration. See the
[production release workflow](release/README.md).
