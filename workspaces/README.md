# Workspaces

This directory owns the `python-workspace` and `k8s-dev` templates, their shared
runtime artifacts, and independently versioned project environment images.
Both templates retain independent template source and versions.
The template publisher makes the project environments available as immutable
project choices only when their digest-pinned references are supplied.

| File                                                      | Contents                                                         |
| --------------------------------------------------------- | ---------------------------------------------------------------- |
| `python/images/python.Containerfile`                      | Shared runtime and locked project-image build targets            |
| `python/images/code-server.Containerfile`                 | Read-only code-server payload                                    |
| `python/extensions/python-extensions.Containerfile`       | Approved, version- and checksum-pinned VSIX payload              |
| `python/extensions/python-extensions.lock`                | Approved VSIX versions, sources, platforms, and checksums        |
| `python/images/dupe-trooper/`                             | Current locked `dupe-trooper` uv environment                     |
| `python/images/deja-doc/`                                 | Current locked `deja-doc` uv environment                         |

The template mounts code-server at `/opt/vscode-server` and extensions at
`/opt/vsix` using read-only OCI image volumes. It installs extensions locally
into the persistent `/home/coder` volume; repositories, settings, caches, and
Python environments persist there as well. Workspace startup does not contact
package managers, extension marketplaces, or public artifact registries.
The workspace account, Coder terminals, and code-server integrated terminals
use zsh by default.

The workspace form starts with one searchable, immutable **Project** selector.
`sandbox` uses the shared Python runtime; `deja-doc` and `dupe-trooper` select
their locked environments when those images are available. Managed project
profiles bind their repository, source revision, digest-pinned image, and
recommended size so developers cannot create mismatched combinations.
Selecting `sandbox` reveals inputs for any repository already in the internal
mirror, its source revision, and any approved workspace image; the packaged
starter and plain Python runtime remain the defaults. The form also offers
Small, Standard, and Large size profiles. A `Customize specifications` switch
reveals individual CPU and memory sliders directly below the size selector.
The resulting CPU and memory values are both requested and limited for
predictable scheduling. `/tmp` is limited to 4 GiB and the container requests
2 GiB with a 10 GiB ephemeral-storage limit.

The packaged starter repository is cloned from Zarf's internal Git mirror with
its pull-only credential. Its `origin` is intentionally read-only; configure a
separate internal development remote before pushing changes.
The production publisher instead supplies the Forgejo HTTPS origin and the
`forgejo` Coder external-auth provider. Production defaults to an empty
repository and dotfiles selection; choosing a repository requires each user to
authorize their own Forgejo account, and no shared Git credential is placed in
the Flux source.
The workspace form enables the centrally packaged dotfiles by default and lets
developers disable them with the `Configure dotfiles` switch. The repository
and branch are administrator-controlled, immutable template inputs rather than
editable workspace parameters. The workspace page provides a `Refresh
Dotfiles` action to apply them on demand. The configuration configures zsh
without contacting GitHub during workspace startup.
Its source is
[`fabian1heinrich/coder-dotfiles`](https://github.com/fabian1heinrich/coder-dotfiles)
at commit `4d8bd9bf877c32e257f671ab30c86e898261891e`. To upgrade it, update that
commit in the Zarf package definition and the matching `zarf-ref-<commit>`
defaults in the workspace and publisher variables.

Each workspace uses a replaceable Deployment and a `ReadWriteOnce` PVC. The pod
runs as UID/GID 1000, does not mount a service-account token, uses the runtime
default seccomp profile, disallows privilege escalation, and drops all
capabilities. code-server is the supported browser IDE; Coder's desktop
launchers are hidden.

## Cluster requirements

- amd64 nodes and Coder Community 2.36.0 with the provider versions pinned in
  the root control-plane Containerfiles.
- Kubernetes and a compatible CRI supporting `spec.volumes[].image`. Image
  volumes are [stable and enabled by default in Kubernetes
  1.36](https://kubernetes.io/docs/tasks/configure-pod-container/image-volumes/).
  Earlier releases that expose the feature may require the `ImageVolume` gate.
- Image-volume mounts must permit execution of
  `/opt/vscode-server/bin/code-server`; some runtimes mount them `noexec`.
- A default StorageClass or an explicit `home_storage_class`, plus a CNI that
  enforces the platform egress policy. The StorageClass must support volume
  expansion for developers to increase an existing home disk.

## Build and verification

Run `just build-template-artifacts` to build the workspace images and publisher
runner. For deployment, use the root
[local workflow](../README.md#local-deployment).

After publication, create a workspace and verify Python, code-server, and the
approved extensions without public egress. Recreate the workspace pod and
confirm that a marker under `/home/coder` survives.

Image sources and build logic live in the owning Containerfile; deployed outputs
are pinned by digest in Zarf. Extension versions, target platforms, source URLs,
and VSIX checksums are maintained in
`python/extensions/python-extensions.lock`. When upgrading an image, update
every consuming Zarf definition together.
