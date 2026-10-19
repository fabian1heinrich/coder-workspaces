# Template publisher

This directory owns the OpenTofu configuration and source ConfigMap shared by
the local and production publisher Jobs. Credentials and production platform
values are supplied by the consuming environment.

The publisher manages both the `python-workspace` and `k8s-dev` templates.
It passes the digest-pinned Python runtime, extension, and optional project
images only to `python-workspace`. `k8s-dev` receives its dedicated workspace
and Kubernetes VSIX images; it has no Python or project-image inputs.

The root kustomization contains the shared Job, namespace-scoped state-backend
RBAC, and publisher source. The local overlay under `dev/template-publisher/`
adds the workspace sources and local values for `dev/zarf.yaml`. The root Flux
source carries the generic production publisher and workspace payload. The
consuming GitOps repository supplies only its target namespace, name prefix,
credentials, registry endpoint, and environment values. Development and the
production contract use the dedicated `coder-template-publisher` namespace to
isolate the publisher runtime, token, and state. `CODER_WORKSPACES_NAMESPACE`
independently selects where Coder provisions workspace resources. The consumer
also supplies `CODER_WORKSPACES_KUBERNETES_SERVICE_ACCOUNT` and
`CODER_WORKSPACES_KUBERNETES_TARGET_NAMESPACE`; the named ServiceAccount and
its least-privilege RBAC remain environment-owned. It supplies the published
workspace image digest as `CODER_WORKSPACES_K8S_WORKSPACE_DIGEST`; the source
release pairs that digest with its operator-facing SemVer. It similarly
supplies `CODER_WORKSPACES_K8S_VSIX_DIGEST` for the `k8s-vsix:0.1.0` payload.
The Kubernetes template's optional repository is configured independently
through `CODER_WORKSPACES_K8S_DEFAULT_REPOSITORY` and
`CODER_WORKSPACES_K8S_DEFAULT_GIT_BRANCH`.

OpenTofu uses its Kubernetes backend. State is stored in
`Secret/tfstate-default-<PUBLISHER_STATE_SUFFIX>` in the Job namespace, and a
matching `Lease/lock-tfstate-default-<PUBLISHER_STATE_SUFFIX>` serializes
publisher runs. The dedicated service account can read and write only Secrets
and Leases in that namespace. A publisher-specific egress policy permits DNS,
the Coder namespace, and private internal endpoints. The backend objects are
created at runtime, outside the Flux inventory, so source pruning does not
remove them. If state is absent but either template already exists in Coder,
the publisher imports that template before applying it.

Treat the state Secret as sensitive backup data. The Kubernetes backend has a
1 MiB Secret limit; this configuration tracks only the two Coder template
resources and their metadata.

The local packages apply both templates. After publication, the Job lists and
updates all outdated workspaces belonging to either template using its bundled
Coder CLI and publisher token. Existing parameter values are reused and new
parameters use their defaults; new required values without defaults need user
input in Coder. An outdated workspace is stopped if running, updated, and
started. This adds no Zarf actions or host CLI dependency.

Set the template version in `template.tf`. A content hash is appended because
Coder template-version names are immutable. Use the
[local Zarf commands](../dev/README.md). The registry-backed package pulls image
inputs by immutable digest; the local package uses OCI archives built from this
checkout.

Production publication never updates existing workspaces automatically. Its
digest-pinned runner, workspace, and tooling images must be mirrored before the
Flux source is published. The source owns those image digests and the Job contract;
the consumer supplies registry, state suffix, pull-secret, storage, Coder, Git,
authentication, and CA values through Flux substitutions.
