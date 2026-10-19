# Template publisher

This directory owns the OpenTofu configuration and source ConfigMap used by the
local and production publisher Jobs. The consuming environment supplies
credentials and platform values.

The publisher manages both the `python-workspace` and `k8s-dev` templates.
It passes the digest-pinned Python runtime, extension, and optional project
images only to `python-workspace`. `k8s-dev` receives its dedicated workspace
and Kubernetes VSIX images; it has no Python or project-image inputs.

The root kustomization contains the shared Job, publisher source, and
namespace-scoped backend RBAC. The local overlay under
`dev/template-publisher/` adds workspace sources and local values. Production
uses the same generic payload with consumer-supplied substitutions listed in
`job.yaml`. The publisher namespace is independent of the workspace namespace;
the Kubernetes workspace ServiceAccount and its least-privilege RBAC remain
environment-owned.

OpenTofu state is stored in
`Secret/tfstate-default-<PUBLISHER_STATE_SUFFIX>` in the Job namespace, and a
matching `Lease/lock-tfstate-default-<PUBLISHER_STATE_SUFFIX>` serializes
publisher runs. The dedicated service account can read and write only Secrets
and Leases there. Backend objects are outside the Flux inventory. If state is
missing but a managed template exists, the publisher imports it before apply.

Treat the state Secret as sensitive backup data. The Kubernetes backend has a
1 MiB Secret limit.

Local packages apply both templates and update their outdated workspaces with
the bundled Coder CLI. Existing parameter values are reused; new parameters use
their defaults. New required parameters without defaults need user input.

Set the template version in `template.tf`; a content hash makes each Coder
template-version name unique. Use the [local Zarf commands](../dev/README.md).

Production publication does not update existing workspaces. Mirror its
digest-pinned images before publishing the Flux source.
