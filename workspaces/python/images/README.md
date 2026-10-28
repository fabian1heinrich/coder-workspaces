# Python images

`python.Containerfile` is the only Python image definition. Its `runtime`
target is the plain shared Python 3.13 workspace, and its `project` target adds
a selected project's locked environment while reusing the runtime layers.
One directory per entry in
[`../projects.json`](../projects.json) contains only that project's current
`pyproject.toml` and `uv.lock`; application source and project virtual
environments never enter an image. The build and the CI matrix iterate the
catalog; template and package wiring remains explicit. Follow the
[project addition steps](../README.md) when adding an entry.

The runtime derives from the digest-pinned Microsoft Python 3.13 Trixie dev
container. To upgrade it, update the exact `FROM` reference and matching
source-image label together. Build assertions preserve the `coder` account
contract.

The shared runtime includes digest-pinned uv 0.8.15, including for the sandbox.
Each project pins Python and all dependencies, performs a locked sync without
installing the project, and stores its offline cache in `/opt/uv-cache`.

Every Python workspace creates its persistent `/home/coder/.venv` on first
start, exports it as `VIRTUAL_ENV`, and places its `bin` first on `PATH`, so the
Coder agent and its children inherit it. Image-owned Bash and Zsh hooks also
source the environment's activation script when a shell opens, even with an
existing home volume. User dotfiles can still deliberately override it.
`UV_OFFLINE=true` and `UV_PYTHON_DOWNLOADS=never` prevent public downloads;
managed projects also use `UV_LINK_MODE=copy` for the preloaded cache.
`/opt/project-config` contains the two managed files and is exported as
`UV_PROJECT`, so the source checkout does not need copies. On every start,
`workspace-startup` performs the locked offline sync into the same environment.
OCI labels record the image's SemVer release; the `sha-<commit>` tag provides
source traceability, and consumers use `:<version>@sha256:<digest>` references
so the operator-facing version never weakens the immutable identity.

## Updating project dependencies

Use exact versions under `[project].dependencies` and `[dependency-groups]`.
Regenerate `uv.lock` with uv 0.8.15 on a connected host in the project directory,
then commit it alongside `pyproject.toml`; do not edit the lockfile by hand.
The image build's `uv sync --locked` rejects inconsistent inputs. CI no longer
requires a GitHub App or pushes lockfile commits into pull requests.

CI publishes `sha-<commit>` traceability tags and mutable SemVer aliases for
each image. Consumers retain the readable version beside the immutable digest.
Keep older digests while a template revision, release, package, or workspace
uses them.
