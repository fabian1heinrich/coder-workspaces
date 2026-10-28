# Offline Coder modules

`Containerfile` builds a scratch payload from the pinned releases in
`modules.lock`, verifies every archive checksum, and uses a fixed image
timestamp for reproducible amd64 output.

The build rewrites the modules' `coder/coder` provider source to match the
filesystem mirror in `coder.Containerfile`. Kubernetes mounts the resulting
image read-only at `/opt/coder-modules`, so built-in provisioners need neither
the public module registry nor registry credentials at runtime.

`workspace-pod/` is a repository-owned module. The publisher copies it into
each template archive, which resolves it through the relative
`./workspace-pod` path. It also remains in the module image for artifact
provenance, but provisioning does not resolve that copy. It creates a
workspace's persistent home claim and its Deployment, so the pod security
contract, the read-only OCI image volumes, and the persistence boundary are
defined once for every template. It also owns the generic Secret wiring and
runtime credential-helper configuration for HTTP Git credentials.
The control plane must still mount the image at `/opt/coder-modules` because
the templates resolve the pinned upstream Coder modules from that path.

Module versions, source URLs, and checksums are maintained in `modules.lock`;
the matching OCI labels are in `Containerfile`. To upgrade a module, update
those pins and labels, rebuild or publish it, then update every registry-backed
Zarf consumer to the new digest. A `workspace-pod/` change requires a new
template publication but does not by itself trigger image CI; its unused
provenance copy changes the next time the image is built. Production keeps its
pinned upstream module digest until that dependency is deliberately upgraded.
