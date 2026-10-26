# Air-gapped Coder workspace release

Run from the copied `coder-workspaces` directory. The images archive is a
mirror archive and is never deployed; the publication package is deployed
against the existing Coder deployment. The consuming platform provides registry
credentials and the publication values.

The host needs Bash, direnv, Just, curl, jq, the Coder CLI, Zarf, and `kubectl`.

Prepare the environment and verify the copied release:

```sh
install -m 600 .env.example .env
$EDITOR .env
direnv allow
test -f "$KUBECONFIG"
sha256sum --check SHA256SUMS
```

For a template-only release, publish with the password-authenticated identity
configured by `CODER_URL` and `CODER_EMAIL`:

```sh
just publish
```

The recipe prompts for the password, creates a uniquely named one-hour API
token, passes it only to the connected Zarf deployment, then hard-deletes that
token and logs out the password session on both success and failure. Set
`PUBLISH_PACKAGE` only when the directory contains more than one publication
package.

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
  --components=workspace-runtime,coder-modules,workspace-tooling,publisher-runtime \
  --images \
  --no-img-checksum \
  --confirm
```

Then run `just publish`.

The publication package creates the credential Secret imperatively, outside
its rendered manifests, runs the publisher Job as a Zarf health check, and
deletes the Secret again on both the success and the failure path. The token is
therefore absent from Helm release data. A rejected token, an unreachable Coder
deployment, or a template that fails to build fails the deploy in front of you.
Read the Job's output with:

```sh
kubectl -n coder-template-publisher logs job/template-publisher
```

Publication is idempotent: unchanged template content and unchanged image
digests leave the active template version in place. To roll back, publish from
an older copied release; rollback does not reverse prior Coder API changes, and
existing workspaces keep the template version they were built from.
