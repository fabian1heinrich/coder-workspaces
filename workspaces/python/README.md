# Python workspace

An air-gapped Python 3.13 development environment with code-server, approved
extensions, persistent user state, and access to repositories mirrored by
Zarf.

Independently versioned images provide locked uv environments for
`dupe-trooper` and `deja-doc`; see [`images/README.md`](images/README.md).
They contain no application source.

The immutable **Project** selector always offers `sandbox` and adds `deja-doc`
and `dupe-trooper` when their digest-pinned images are supplied. Managed
projects set the repository, source revision, image, and recommended size as
one consistent profile. Selecting `sandbox` instead reveals the mirrored
repository, source revision, and approved workspace image controls.

## Using the workspace

- Choose `sandbox`, `deja-doc`, or `dupe-trooper` as the project. `sandbox`
  allows any repository already available from the internal mirror and any
  approved image. The managed projects use their locked dependency image.
- Choose a Small, Standard, or Large workspace size. Enable **Customize
  specifications** to set CPU, memory, persistent home storage, and dotfiles
  independently.
- code-server, the web terminal, and SSH start in the selected repository, or
  `/home/coder` when none is selected.

The packaged repository is cloned from the internal Gitea mirror. Its `origin`
is pull-only. Add a separate internal development remote before pushing:

```shell
git remote add development <internal-git-url>
git push --set-upstream development <branch>
```

## Persistence and offline behavior

Everything under `/home/coder` persists across workspace stops and pod
replacement, including repositories, virtual environments, caches, settings,
and extensions. `/tmp` is ephemeral and is cleared when the pod is replaced.

The home disk can be increased when the StorageClass supports expansion; it
cannot be reduced. Public package registries and extension marketplaces are
unavailable, so use the image, approved extensions, or internal artifact
services.
