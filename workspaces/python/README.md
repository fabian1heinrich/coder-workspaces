# Python workspace

An air-gapped Python 3.13 development environment with code-server, approved
extensions, persistent user state, and optional access to a deployment-owned
Git service.

Projects are declared once in `projects.json`, which this template carries and
the build and CI read. Each entry has an independently versioned image with a
locked uv environment; see [`images/README.md`](images/README.md). They contain
no application source.

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

To add a project: add its entry to `projects.json`, add `pyproject.toml` and
`uv.lock` under `images/<name>/`, add its image and repository variables to the
template and publisher environment, and add its image to the transport package
lists. The build and CI matrix follow from the catalog.

## Using the workspace

- Choose `sandbox` or one of the offered projects. `sandbox` can clone from the
  configured Git service; a project uses its own locked dependency image.
- Choose a Small, Standard, or Large workspace size. Enable **Customize
  specifications** to set CPU, memory, and dotfiles independently. The
  persistent home disk is an independent, increase-only setting.
- code-server, the web terminal, and SSH start in the selected repository, or
  `/home/coder` when none is selected.

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
