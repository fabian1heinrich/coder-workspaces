# Offline Coder modules

`Containerfile` builds a scratch payload from the pinned releases in
`modules.lock`, verifies every archive checksum, and uses a fixed image
timestamp for reproducible amd64 output.

The build rewrites the modules' `coder/coder` provider source to match the
filesystem mirror in `coder.Containerfile`. Kubernetes mounts the resulting
image read-only at `/opt/coder-modules`, so built-in provisioners need neither
the public module registry nor registry credentials at runtime.

`workspace-pod/` is a repository-owned module that ships in the same payload.
It creates a workspace's persistent home claim and its Deployment, so the pod
security contract, the read-only OCI image volumes, and the persistence
boundary are defined once for every template. It also owns the generic Secret
wiring and runtime credential-helper configuration for HTTP Git credentials.
Because templates resolve the module by its mount path, any control plane that
provisions these templates must mount this image at `/opt/coder-modules`,
including in production.

Module versions, source URLs, and checksums are maintained in `modules.lock`;
the matching OCI labels are in `Containerfile`. To upgrade a module, update
those pins and labels, rebuild or publish it, then update every registry-backed
Zarf consumer to the new digest. A change to `workspace-pod/` changes this
image, so it needs the same digest update.
