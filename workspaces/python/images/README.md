# Python images

`python.Containerfile` is the only Python image definition. Its `runtime`
target is the plain shared Python 3.13 workspace, and its `project` target adds
a selected project's locked environment while reusing the runtime layers.
The `dupe-trooper/` and `deja-doc/` directories contain only their current
`pyproject.toml` and `uv.lock`; application source and project virtual
environments never enter an image.

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
labels record the environment release and source Git revision; consumers use
the published image digest as the immutable identity.

`just build-template-artifacts` builds both project images for the local
package.

To release an environment change, update the project's `pyproject.toml` and
`uv.lock`. CI publishes a unique `sha-<commit>` tag and records the resulting
digest. Zarf and the templates consume that digest, not a mutable release tag.
Keep older digests available while older template revisions use them; their
exact build inputs remain available from repository history rather than
parallel version directories at HEAD.
