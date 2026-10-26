# Template publisher

This directory owns the publisher script and the shared Job used by the local
and production publisher Jobs. The consuming environment supplies credentials
and platform values.

Publication is a Coder API operation performed with the Coder CLI, so the
publisher keeps no state: no backend, no lock, and no imported resources. A
template version is named `<template version>-<content revision>`, where the
content revision hashes the template's files together with the variable values
it is published with. Re-running the Job with unchanged input finds that
version already active and publishes nothing; a changed file or image digest
produces a new version. `PUBLISH_ID` appends a suffix for republishing
identical content.

The publisher manages both the `python-workspace` and `k8s-dev` templates. Each
template receives every variable it declares that the Job sets:
`TF_VAR_<name>` applies to any template declaring `<name>`, and
`TF_VAR_<prefix>_<name>` overrides it for one template, where the prefix is
`python` or `k8s_dev`. Anything the Job leaves unset keeps the template's own
default, so a mistyped name silently publishes a default value: check both
sides when changing one.

`base/` contains the reusable Job, its egress policy, the publisher source
ConfigMap, and a ServiceAccount with no Kubernetes permissions and no mounted
token. ConfigMap keys are the file names the templates expect, so the Job
mounts each ConfigMap as a directory. Each consumer generates the
`template-publisher-environment` ConfigMap from its own `publisher.env` and
patches only runtime details such as the publisher image. The token remains a
Secret referenced directly by the Job.

The local overlay is `dev/template-publisher/`; the production overlay is
`release/publish/manifests/`. Local development owns its publisher namespace,
while production requires the consuming platform to create the selected
publisher namespace. The publisher namespace is independent of the workspace
namespace.

Template description and icon are set when a template is first created, and the
icon on every publication. Later description changes need
`coder templates edit`, because that command submits the full template metadata
and would otherwise overwrite the scheduling and access settings that the
deployment owns.

Local packages publish both templates and update their outdated workspaces with
the bundled Coder CLI. Existing parameter values are reused; new parameters use
their defaults. New required parameters without defaults need user input.

Set the template version in `base/publish.sh`. Use the [local Zarf
commands](../dev/README.md).

Production publication does not update existing workspaces, and takes its
credential from `ZARF_VAR_CODER_TOKEN` at deploy time. The production package
creates the referenced Secret imperatively so the token never enters rendered
Helm release data, then deletes it on success or failure. Mirror its
digest-pinned images first; see the [production release workflow](../release/README.md).
