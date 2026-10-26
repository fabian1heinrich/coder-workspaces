# workspace-pod

Repository-owned OpenTofu module that creates a workspace's persistent home
claim and its Deployment. Every template in this repository consumes it from
the Coder modules image at `/opt/coder-modules/workspace-pod`, so the pod
security contract, the read-only OCI image volumes, and the persistence
boundary exist in exactly one place. Workspace Pods never automount a
Kubernetes ServiceAccount token; cluster credentials belong in user-managed
persistent state.

`git_auth_mode=secret` adds URL-scoped Git configuration and reads `username`
and `password` from the named Kubernetes Secret. Git's inline credential
helper reads those runtime environment variables, so the module neither
assumes a Git implementation nor persists credentials in the home directory.
`anonymous` and `external-auth` add no Secret-backed environment variables.

Templates keep what is genuinely template-specific: parameters, the agent and
its modules, workspace metadata, and the `startup_commands` their runtime image
provides.

Because this module ships inside the modules image, the control plane must
mount that image at `/opt/coder-modules`; see
[`modules/README.md`](../README.md).
