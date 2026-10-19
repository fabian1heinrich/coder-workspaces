# Offline Coder modules

`Containerfile` builds one scratch payload image from the pinned `code-server`,
`coder-login`, `dotfiles`, `git-clone`, and `git-config` releases in
`modules.lock`. The build verifies every archive checksum and uses a fixed image
timestamp so unchanged inputs produce the same amd64 OCI image digest.

The build rewrites the modules' `coder/coder` provider source to match the
filesystem mirror in `coder.Containerfile`. Kubernetes mounts the resulting
image read-only at `/opt/coder-modules`, so built-in provisioners need neither
the public module registry nor registry credentials at runtime.

Build it with the other local platform artifacts:

```sh
just build-platform-artifacts
```

Module versions, source URLs, and checksums are maintained in `modules.lock`;
the matching OCI labels are in `Containerfile`. To upgrade a module, update
those pins and labels, rebuild, then update every Zarf consumer to the new
digest.
