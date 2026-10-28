# Python workspace

An air-gapped Python 3.13 development environment with code-server, approved
extensions, persistent user state, and optional access to a deployment-owned
Git service.

`projects.json` supplies project descriptions, recommended sizes, and the local
build and CI matrix. Template variables and package wiring are explicit. Each
project has an independently versioned image with a locked uv environment;
see [`images/README.md`](images/README.md). Images contain no application source.

The immutable **Project** selector always offers `sandbox` and adds an entry
for every catalog project whose per-project digest-pinned image variable the
deployment supplies. Each project has its own image and repository variables,
so it preselects the repository, source revision, image, and recommended size
as one consistent profile. When a Git service is configured, every project
reveals editable repository and source revision controls with the profile
values prefilled. Selecting `sandbox` additionally lets the user set the
workspace, code-server, and VSIX payload images. Image
references are paths within the deployment-owned registry: the template
prepends the registry from its default workspace image and requires every
selection to be digest-pinned. Custom images must implement the same runtime
and mounted-payload layouts as the repository-owned defaults.

To add a project:

1. Add its catalog entry and `images/<name>/{pyproject.toml,uv.lock}`. Local image
   builds and the CI matrix follow automatically.
2. Add its image/repository variables in `variables.tf`, its profile in
   `locals.tf`, and the matching entries in both publisher overlays.
3. Wire its image into `dev/local/zarf.yaml`, both production image package
   definitions, and the image argument/config handling in `Justfile`. Add its
   deployment inputs to `dev/zarf.yaml`, `release/publish/zarf.yaml`, and
   `release/airgapped/zarf-config.yaml`.

A catalog entry alone does not enable a project in a deployed template.

## Using the workspace

- Choose `sandbox` or one of the offered projects. `sandbox` can clone from the
  configured Git service; a project uses its own locked dependency image.
- Choose a Small, Standard, or Large workspace size. Enable **Customize
  specifications** to set CPU, memory, and dotfiles independently. The
  persistent home disk is an independent, increase-only setting.
- code-server, the web terminal, and SSH start in the selected repository, or
  `/home/coder` when none is selected.
- Every Python workspace starts with its persistent `/home/coder/.venv` active.
  A managed project synchronizes its locked dependencies into that environment;
  its `pyproject.toml` and `uv.lock` remain immutable at `/opt/project-config`
  and do not need to exist in or be uploaded to the source checkout. `uv` uses
  that config automatically. The sandbox also includes uv; neither mode
  downloads Python or public packages at startup.

`code-server-settings.json` supplies the default interpreter
`/home/coder/.venv/bin/python`, terminal activation, offline editor defaults,
and basic whitespace settings. The existing code-server module merges these
keys into its persistent User settings on startup; no settings-copy script is
needed. Repository settings can override User settings. A workspace with a
previously selected Python interpreter may need **Python: Select Interpreter**
once, because the extension remembers that selection separately from its
default. New terminals also activate the environment through image-owned shell
hooks, so web terminals and SSH do not depend on the editor extension.

The published `git_auth_mode` selects anonymous access, a generic Kubernetes
Secret, or Coder external auth. No option is tied to a particular Git service
or deployment tool.

## Persistence and offline behavior

Everything under `/home/coder` persists across workspace stops and pod
replacement, including repositories, virtual environments, caches, settings,
and extensions. `/tmp` is ephemeral and is cleared when the pod is replaced.

The home disk can be increased when the StorageClass supports expansion; it
cannot be reduced. Public package registries and extension marketplaces are
unavailable, so use the image, approved extensions, or internal artifact
services.
