# Offline Coder modules

`Containerfile` builds a scratch payload from the pinned releases in
`modules.lock`, verifies every archive checksum, and uses a fixed image
timestamp for reproducible amd64 output.

The build rewrites the modules' `coder/coder` provider source to match the
filesystem mirror in `coder.Containerfile`. Kubernetes mounts the resulting
image read-only at `/opt/coder-modules`, so built-in provisioners need neither
the public module registry nor registry credentials at runtime.

Module versions, source URLs, and checksums are maintained in `modules.lock`;
the matching OCI labels are in `Containerfile`. To upgrade a module, update
those pins and labels, rebuild or publish it, then update every registry-backed
Zarf consumer to the new digest.
