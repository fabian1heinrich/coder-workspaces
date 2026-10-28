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
default. Runtime and tooling images are required inputs, so a missing image
fails publication instead of silently selecting an old public-registry pin.
Check names on both sides when changing them.

`base/` contains the reusable Job, its egress policy, the publisher source
ConfigMap, and a ServiceAccount with no Kubernetes permissions and no mounted
token. ConfigMap keys are the file names the templates expect, so the Job
mounts each ConfigMap as a directory. Each consumer generates the
`template-publisher-environment` ConfigMap from its own `publisher.env` and
patches only runtime details such as the publisher image. The token remains a
Secret referenced directly by the Job.

Both packages wait for the Job's `Complete=True` condition before finishing
deployment. The native Zarf wait allows 11 minutes, covering the Job's
10-minute deadline; a running or failed Job cannot satisfy it.

The local overlay is `dev/publisher/`; the production overlay is
`release/publisher/`. Local development owns its publisher namespace,
while production requires the consuming platform to create the selected
publisher namespace. The publisher namespace is independent of the workspace
namespace.

Template description and icon are set when a template is first created.
Later description changes need
`coder templates edit`, because that command submits the full template metadata
and would otherwise overwrite the scheduling and access settings that the
deployment owns.

Local packages publish both templates and update their outdated workspaces with
the bundled Coder CLI. Existing parameter values are reused; new parameters use
their defaults. New required parameters without defaults need user input.

Set the template version in `base/publish.sh`. Use the [local Zarf
commands](../dev/README.md).

Production publication does not update existing workspaces. Supply a manually
created token through the sensitive `CODER_TOKEN` deploy variable. The copied
release's `just publish` forwards `ZARF_VAR_CODER_TOKEN` to `--set-variables`.
The package applies a regular auth Secret and replaces the previous Job on
each deployment. The Secret and Helm release history retain the token value;
the operator revokes the API token in Coder after every attempt. Mirror the
digest-pinned images first; see the [production release workflow](../release/README.md).
