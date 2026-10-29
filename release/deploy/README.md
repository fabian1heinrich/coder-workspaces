# Air-gapped Coder workspace release

Run from this copied release directory. The host needs Bash, Just,
direnv, Zarf 0.83 or later, kubectl, base64, and sha256sum. The platform must
already provide the publisher namespace and its `zot-reader` registry Secret,
and mount the module image recorded in `RELEASE-METADATA` on Coder.

## Configure

```sh
sha256sum --check SHA256SUMS
cp .env.example .env
$EDITOR .env
direnv allow
```

The shipped `zarf-config.yaml` contains all non-secret publication inputs,
including the project image digests filled in during packaging. Use it directly;
edit it only when the deployment values differ. Verify checksums before editing.
If you change `REGISTRY`, also change the registry hostname in the project image
references. An empty project image disables it. Never put a Coder API token in
either configuration file.

## Deploy

Create a short-lived API token manually in Coder with Template Admin or Owner
rights, then run:

```sh
just deploy
```

`just deploy` mirrors this release's images and then publishes its templates.
A failed mirror stops publication. Publication prompts for the token with input
hidden. The prompt runs in Bash inside the recipe, so the command also works
from Zsh. Revoke the API token in Coder immediately after the attempt, whether
deployment succeeds or fails.

For publication-only media whose images are already mirrored, use
`just publish` instead; it prompts in the same way. `just mirror` mirrors
images independently. The images package is mirror-only; never deploy it.

The recipes select the exact package names fixed during packaging and print
the release identity before running Zarf. They explicitly set `ZARF_CONFIG` to
this directory's `zarf-config.yaml`, overriding any inherited config path.
Keep the generated Justfile, packages, and config from the same release together.

For noninteractive use, supply `ZARF_VAR_CODER_TOKEN` in the environment to skip
the prompt. `just publish` forwards the token through `--set-variables`.
The package declares `CODER_TOKEN` as sensitive without a format regex.
The recipe and publisher reject empty values; Coder validates the
token. Zarf reads the other inputs from the release's `zarf-config.yaml`.

The package applies `coder-template-publisher-auth` as a regular Secret and
waits for the Job to complete. The Secret and its rendered value remain in the
cluster and Helm release history; `sensitive` suppresses logging, not storage.
Revoke the token in Coder after every attempt. Publisher logs are available with
`kubectl -n coder-template-publisher logs -f job/template-publisher`.
`zot-reader` remains platform-owned and is never created from the Coder token.

If publication fails because the legacy `coder-template-publisher-auth` Secret
lacks Helm ownership metadata, delete that Secret once, then retry `just publish`
with a fresh token. The package recreates it under Helm ownership; later
publications update it normally. This is a one-time migration, not a deploy step:

```sh
kubectl -n coder-template-publisher delete secret coder-template-publisher-auth
```

Run one publication at a time. Each deployment replaces the previous Job, applies
the ConfigMaps, and updates the Secret with the supplied token. It checks the new
Job UID, release annotations, publisher image, and requested workspace/tooling
image references before waiting for completion. Success requires both templates
to report the expected content-hashed version active, from that same Job. A
mismatch fails the deployment, which prints publisher status and recent logs.
Retry an interrupted deployment with a fresh token; unchanged
template content and variables reuse the same version. Publishing an older
release reactivates its template versions; existing workspaces retain their
versions until explicitly updated.

After successful publication, update existing workspaces to the new template
version. Restarting a workspace alone does not select the new version.
