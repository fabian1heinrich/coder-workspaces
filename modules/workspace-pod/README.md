# workspace-pod

Repository-owned OpenTofu module that creates a workspace's persistent home
claim and its Deployment. The publisher copies this directory into every
template archive, and each template consumes it through `./workspace-pod`.
This directory remains the single source of truth for the pod security
contract, read-only OCI image volumes, and persistence boundary. Workspace
Pods never automount a Kubernetes ServiceAccount token; cluster credentials
belong in user-managed persistent state.

`git_auth_mode=secret` adds URL-scoped Git configuration and reads `username`
and `password` from the named Kubernetes Secret. Git's inline credential
helper reads those runtime environment variables, so the module neither
assumes a Git implementation nor persists credentials in the home directory.
`anonymous` and `external-auth` add no Secret-backed environment variables.

Templates keep what is genuinely template-specific: parameters, the agent and
its modules, workspace metadata, and the `startup_commands` their runtime image
provides.

The separate modules image remains mounted at `/opt/coder-modules` for pinned
upstream Coder modules; see [`modules/README.md`](../README.md).
