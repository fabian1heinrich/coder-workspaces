# Kubernetes development workspace

An air-gapped development workspace deployed on Kubernetes and backed by the
approved Python 3.13 runtime, with code-server, approved extensions, persistent
user state, and access to repositories mirrored by Zarf.

The immutable **Project** selector always offers `sandbox` and adds `deja-doc`
and `dupe-trooper` when their digest-pinned images are supplied. Managed
projects set the repository, source revision, image, and recommended size as
one consistent profile. Selecting `sandbox` instead reveals the mirrored
repository, source revision, and approved workspace image controls.

## Using the workspace

- Open **code-server** from the workspace page. It opens the selected repository
  and starts integrated terminals there with zsh.
- Choose `sandbox`, `deja-doc`, or `dupe-trooper` as the project. `sandbox`
  allows any repository already available from the internal mirror and any
  approved image. The managed projects use their locked dependency image.
- Choose a Small, Standard, or Large workspace size. Enable **Customize
  specifications** to set CPU and memory independently.
- The web terminal and SSH start in the selected repository. When no repository
  is selected, they start in `/home/coder`.
- Use Coder's port-forwarding support for project services listening on
  localhost.

The packaged repository is cloned from the internal Gitea mirror. Its `origin`
is pull-only. Add a separate internal development remote before pushing:

```shell
git remote add development <internal-git-url>
git push --set-upstream development <branch>
```

## Persistence and storage

Everything under `/home/coder` persists across workspace stops and pod
replacement, including repositories, virtual environments, caches, settings,
and extensions. `/tmp` is ephemeral and is cleared when the pod is replaced.

The home disk can be increased from the workspace parameters when the cluster
StorageClass supports volume expansion. It cannot be reduced.

## Offline behavior

The workspace cannot reach public package registries or extension marketplaces.
Use dependencies supplied by the workspace image, the approved extensions, or
documented internal package and artifact services.
