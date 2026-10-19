# Python images

`python.Containerfile` is the only Python image definition. Its `runtime`
target is the plain shared Python 3.13 workspace, and its `project` target adds
a selected project's locked environment while reusing the runtime layers.
The `dupe-trooper/` and `deja-doc/` directories contain only their current
`pyproject.toml` and `uv.lock`; application source and project virtual
environments never enter an image.

The runtime derives directly from the digest-pinned VS Code Python 3.13 Trixie
devcontainer. To upgrade it, select an exact upstream image release, resolve
its multi-architecture digest, and update the `FROM` reference and matching
source-image label together; the build assertions preserve the `coder`
UID/GID 1000, home directory, shell, and sudoers contract.

Each project pins Python in `pyproject.toml` and resolves every runtime,
development, and build-backend dependency in `uv.lock`.
The project target derives from the runtime target and copies uv 0.8.15 from
`ghcr.io/astral-sh/uv@sha256:a5727064a0de127bdb7c9d3c1383f3a9ac307d9f2d8a391edc7896c54289ced0`.
The connected build runs a locked sync without installing the project and
stores the resulting cache in `/opt/uv-cache` in the final image.

At runtime `UV_OFFLINE=true`, `UV_PYTHON_DOWNLOADS=never`, and
`UV_LINK_MODE=copy` prevent public downloads and make the read-only image cache
usable. `UV_PROJECT_ENVIRONMENT=.venv` keeps the disposable environment in the
current checkout. `/opt/project-config` contains the two managed files. OCI
labels record the image's SemVer release; the `sha-<commit>` tag provides source
traceability, and consumers use `:<version>@sha256:<digest>` references so the
operator-facing version never weakens the immutable identity.

The Deja Doc environment is a model-free proof of concept for document
conversion, structure-aware chunk preparation, and MCP exposure. It uses
selected `docling-slim` formats and intentionally excludes inference engines,
model weights, embedding clients, vector databases, agent frameworks, and
model-provider SDKs. Add those only when the future agentic workflow chooses
its runtime architecture; any model artifacts must then be pinned and mirrored
rather than downloaded on first use.

`just build-template-artifacts` builds both project images for the local
package.

## Updating project dependencies

Declare runtime dependencies under `[project].dependencies` and development
dependencies under `[dependency-groups]`, using exact versions. Commit the
`pyproject.toml` change to a branch in this repository. Pull-request CI uses the
pinned uv image to regenerate and commit `uv.lock`; do not edit it manually.
The ordinary PR workflow then runs `uv lock --check`, and the project-image
build runs `uv sync --locked`.

The lockfile workflow requires a GitHub App installed on this repository with
Contents read/write permission. Store its client ID in the repository variable
`PYTHON_LOCK_BOT_CLIENT_ID` and its private key in the Actions secret
`PYTHON_LOCK_BOT_PRIVATE_KEY`. Fork pull requests never receive this credential
and must include their lockfile update.

CI publishes `sha-<commit>` and SemVer tags for each image. A SemVer tag may be
created once or reused for the same digest, but the workflow rejects moving it
to different content. Bump the changed image's version in both workflow
matrices and its owning Containerfile before publishing. Zarf and the templates
retain the version beside the digest. Keep older digests available while older
template revisions use them; their exact build inputs remain available from
repository history rather than parallel version directories at HEAD.
