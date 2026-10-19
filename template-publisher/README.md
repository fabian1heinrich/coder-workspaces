# Template publisher

This directory owns the OpenTofu configuration and source ConfigMap shared by
the local and production publisher Jobs. Credentials and production platform
values are supplied by the consuming environment.

The publisher manages both the `python-workspace` and `k8s-dev` templates.
It passes the digest-pinned `dupe-trooper` and `deja-doc` workspace images into
both templates; those optional images become entries in each template's
immutable project selector alongside `sandbox`.

The root kustomization contains the shared Job, namespace-scoped state-backend
RBAC, and publisher source. The local overlay under `dev/template-publisher/`
adds the workspace sources and local values for `dev/zarf.yaml`. The root Flux
source carries the generic production publisher and workspace payload. The
consuming GitOps repository supplies only its target namespace, name prefix,
credentials, registry endpoint, and environment values. Development and the
production contract use the dedicated `coder-template-publisher` namespace to
isolate the publisher runtime, token, and state. `CODER_WORKSPACES_NAMESPACE`
independently selects where Coder provisions workspace resources.

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

The local package's `PUBLISH_TEMPLATE` create-time setting scopes the existing
Job's import and apply to `python`, `k8s-dev`, or `all` using OpenTofu targeting.
Both resources remain configured in the shared state; selection never removes
the other template. The `all` selection applies both templates, including any
changes deferred during targeted iteration.

The local `UPDATE_WORKSPACE` setting defaults to `all`. After publication, the
Job lists outdated workspaces belonging to the selected template or templates
and updates them sequentially using its bundled Coder CLI and publisher token.
Set it to an existing `owner/workspace` to update only that workspace, or to an
empty value to publish only. Existing parameter values are reused and new
parameters use their defaults; new required values without defaults need user
input in Coder. An outdated workspace is stopped if running, updated, and
started. This adds no Zarf actions or host CLI dependency.

Set the template version in `template.tf`. A content hash is appended because
Coder template-version names are immutable. Use the
[local Zarf commands](../dev/README.md). The local build recipes resolve image
inputs from the OCI archives they create.

Production publication never updates existing workspaces automatically. Its
digest-pinned runner and workspace images must be mirrored before the Flux
source is published. The source owns those image digests and the Job contract;
the consumer supplies registry, state suffix, pull-secret, storage, Coder, Git,
authentication, and CA values through Flux substitutions.
