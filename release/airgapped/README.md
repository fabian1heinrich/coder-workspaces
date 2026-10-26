# Air-gapped Coder workspace release

Run from the copied `coder-workspaces` directory. The images archive is a
mirror archive and is never deployed; the publication package is deployed
against the existing Coder deployment. The consuming platform provides registry
credentials and the publication values.

The host needs Bash, Just, direnv, Zarf, `kubectl`, jq, base64, and sha256sum.

Prepare the environment and verify the copied release:

```sh
install -m 600 .env.example .env
$EDITOR .env
direnv allow
test -f "$KUBECONFIG"
sha256sum --check SHA256SUMS
kubectl -n coder-template-publisher get secret/zot-reader
```

When an image changed, mirror images before publishing:

```sh
SSL_CERT_FILE="$REGISTRY_CA_FILE" \
ZARF_INIT_REGISTRY_PUSH_PASSWORD="$(
  kubectl -n "$REGISTRY_WRITER_SECRET_NAMESPACE" \
    get secret "$REGISTRY_WRITER_SECRET_NAME" \
    -o "jsonpath={.data.$REGISTRY_WRITER_SECRET_KEY}" | base64 --decode
)" \
zarf package mirror-resources \
  ./zarf-package-coder-workspaces-image-mirror-amd64-*.tar.zst \
  --registry-url "$ZARF_VAR_REGISTRY" \
  --registry-push-username "$REGISTRY_PUSH_USERNAME" \
  --components=workspace-runtime,coder-modules,workspace-tooling,project-images,publisher-runtime \
  --images \
  --no-img-checksum \
  --confirm
```

After any required mirroring, create a short-lived API token manually in Coder
from an account with Template Admin or Owner rights. Keep it out of `.env` and
shell history. Run the publication recipe, enter the token at its hidden prompt,
and revoke it in Coder immediately afterward. Paste the token once and press
Enter; the terminal intentionally displays no characters while reading it.

```sh
just publish
```

`just publish` reads the token inside its Bash process and maps it with the
other `ZARF_VAR_*` inputs into Zarf's
`package.deploy.set` configuration before running `zarf package deploy
--connected --confirm`. Zarf exposes deployment variables to package actions
with `ZARF_VAR_*` names, but does not consume arbitrary `ZARF_VAR_*` shell
variables as deployment inputs. Calling the raw deploy command with `--confirm`
would therefore skip prompts and use empty values.

The publication package first verifies that `zot-reader` contains credentials
for the configured registry and that the completed Coder rollout declares the
expected digest-pinned module image at `/opt/coder-modules`. This check reads
the Deployment specification and does not require `pods/exec` access. It then
creates the credential Secret imperatively, outside its rendered manifests, and
runs the publisher Job as a Zarf health check. Success deletes the Secret after
the Job health check through Zarf's `onSuccess` action; an `after` action would
run immediately after applying the Job and is therefore intentionally not used.
Failure deletes the Job before deleting the Secret, so Kubernetes never retains
a Pod that references a removed credential. If Kubernetes cannot confirm Job
deletion, cleanup stops and preserves the Secret for the still-existing Job.
The token is therefore absent from Helm release data. Revoking the Coder API
token remains an operator action. A rejected token, an unreachable Coder
deployment, or a template that fails to build fails the deploy in front of you.
Follow the Job's output while the deployment is active with:

```sh
kubectl -n coder-template-publisher logs --follow job/template-publisher
```

Publication is idempotent: unchanged template content and unchanged image
digests leave the active template version in place. To roll back, publish from
an older copied release; rollback does not reverse prior Coder API changes, and
existing workspaces keep the template version they were built from.
