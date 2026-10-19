# Python images

`python.Containerfile` is the only Python image definition. Its `runtime`
target is the plain shared Python 3.13 workspace, and its `project` target adds
a selected project's locked environment while reusing the runtime layers.
The `dupe-trooper/` and `deja-doc/` directories contain only their current
`pyproject.toml` and `uv.lock`; application source and project virtual
environments never enter an image.

The runtime derives from the digest-pinned VS Code Python 3.13 Trixie
devcontainer. To upgrade it, update the exact `FROM` reference and matching
source-image label together. Build assertions preserve the `coder` account
contract.

Each project pins Python and all dependencies. The project target copies the
digest-pinned uv 0.8.15 binary, performs a locked sync without installing the
project, and stores the cache in `/opt/uv-cache`.

At runtime `UV_OFFLINE=true`, `UV_PYTHON_DOWNLOADS=never`, and
`UV_LINK_MODE=copy` prevent public downloads and make the read-only image cache
usable. `UV_PROJECT_ENVIRONMENT=.venv` keeps the disposable environment in the
current checkout. `/opt/project-config` contains the two managed files. OCI
labels record the image's SemVer release; the `sha-<commit>` tag provides source
traceability, and consumers use `:<version>@sha256:<digest>` references so the
operator-facing version never weakens the immutable identity.

## Updating project dependencies

Use exact versions under `[project].dependencies` and `[dependency-groups]`.
Pull-request CI uses the pinned uv image to regenerate and commit `uv.lock`; do
not edit it manually.

The lockfile workflow requires a GitHub App with Contents read/write permission.
Set `PYTHON_LOCK_BOT_CLIENT_ID` as a repository variable and
`PYTHON_LOCK_BOT_PRIVATE_KEY` as an Actions secret. Fork pull requests must
include their lockfile update.

CI publishes `sha-<commit>` traceability tags and mutable SemVer aliases for
each image. Consumers retain the readable version beside the immutable digest.
Keep older digests while a template revision, release, package, or workspace
uses them.
