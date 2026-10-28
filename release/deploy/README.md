# Air-gapped Coder workspace release

Run from this copied release directory. The host needs Bash, Just (optional),
direnv, Zarf 0.83 or later, kubectl, base64, and sha256sum. The platform must
already provide the publisher namespace and its `zot-reader` registry Secret,
and mount the module image recorded in `RELEASE-METADATA` on Coder.

## Configure and mirror

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

Mirror the images when their digests are not already present:

```sh
SSL_CERT_FILE="$REGISTRY_CA_FILE" \
ZARF_INIT_REGISTRY_PUSH_PASSWORD="$(
  kubectl -n "$REGISTRY_WRITER_SECRET_NAMESPACE" \
    get secret "$REGISTRY_WRITER_SECRET_NAME" \
    -o "jsonpath={.data.$REGISTRY_WRITER_SECRET_KEY}" | base64 --decode
)" \
zarf package mirror-resources \
  ./zarf-package-coder-workspaces-images-amd64-*.tar.zst \
  --registry-url "$(zarf tools yq -r '.package.deploy.set.REGISTRY' zarf-config.yaml)" \
  --registry-push-username "$REGISTRY_PUSH_USERNAME" \
  --images --no-img-checksum --confirm
```

The images package is mirror-only. Never deploy it.

## Publish

Create a short-lived API token manually in Coder with Template Admin or Owner
rights. In Bash, read it without echoing or recording its value in history:

```bash
read -r -s -p 'Coder API token: ' coder_token; printf '\n'
zarf package deploy ./zarf-package-coder-workspaces-publish-amd64-*.tar.zst \
  --connected --confirm --set-variables "CODER_TOKEN=$coder_token"
unset coder_token
```

The equivalent convenience command is
`ZARF_VAR_CODER_TOKEN="$coder_token" just publish`. Revoke the API token in
Coder immediately after deployment, whether deployment succeeds or fails.

`just publish` forwards its `ZARF_VAR_CODER_TOKEN` environment variable through
`--set-variables`. The package declares `CODER_TOKEN` as sensitive and requires
a non-empty value. Zarf reads the other inputs from `zarf-config.yaml`.

The package applies `coder-template-publisher-auth` as a regular Secret and
waits for the Job to complete. The Secret and its rendered value remain in the
cluster and Helm release history; `sensitive` suppresses logging, not storage.
Revoke the token in Coder after every attempt. Publisher logs are available with
`kubectl -n coder-template-publisher logs -f job/template-publisher`.
`zot-reader` remains platform-owned and is never created from the Coder token.

Run one publication at a time. Each deployment replaces the previous Job and
updates the Secret with the supplied token. Retry with a fresh token; unchanged
template content and variables reuse the same version. Publishing an older
release reactivates its template versions; existing workspaces retain their
versions until explicitly updated.
