# Air-gapped Coder workspace release

Run from the copied `coder-workspaces` directory. These are mirror archives;
never deploy them. The consuming platform provides registry credentials and
Flux substitutions. `WORKLOAD_NAMESPACE` is the publisher namespace, not the
workspace namespace.

Prepare the environment and verify the copied release:

```sh
install -m 600 .env.example .env
$EDITOR .env
direnv allow
test -f "$KUBECONFIG"
sha256sum --check SHA256SUMS
```

For a template-only release:

```sh
just mirror
```

When an image changed, mirror images before the source:

```sh
just mirror-all
```

Mirroring leaves the source inactive. Verify the recorded digest, then apply
the generated selector:

```sh
release_id="$(sed -n 's/^release_id=//p' RELEASE-METADATA)"
source_tag="$(sed -n 's/^source_tag=//p' RELEASE-METADATA)"
source_digest="$(sed -n 's/^source_digest=//p' RELEASE-METADATA)"
source_repository="${REGISTRY_URL%/}/fabian1heinrich/coder-workspaces/source"
source_revision="$source_digest"
docker_config="$(mktemp -d)"
export DOCKER_CONFIG="$docker_config"
kubectl -n flux-system get secret zot-reader \
  -o jsonpath='{.data.\.dockerconfigjson}' | base64 --decode \
  > "$DOCKER_CONFIG/config.json"
chmod 0600 "$DOCKER_CONFIG/config.json"

test "$source_tag" = "$release_id"
test "$(SSL_CERT_FILE="$REGISTRY_CA_FILE" \
  zarf tools registry digest "$source_repository:$source_tag")" = "$source_digest"
rm -rf -- "$docker_config"
unset DOCKER_CONFIG
kubectl apply --server-side -f flux-entrypoint.yaml
```

On first installation, activate the consuming application release. Then wait
for the exact source, child reconciliation, and publisher Job:

```sh
kubectl -n flux-system wait ocirepository/coder-workspaces \
  --for=jsonpath="{.status.artifact.revision}=$source_revision" --timeout=5m
kubectl -n flux-system wait kustomization/coder-workspaces \
  --for=jsonpath="{.status.lastAppliedRevision}=$source_revision" --timeout=15m
kubectl -n flux-system wait kustomization/coder-workspaces \
  --for=condition=ready --timeout=15m
kubectl -n "$WORKLOAD_NAMESPACE" wait "job/$PUBLISHER_JOB_NAME" \
  --for=condition=Complete --timeout=10m
```

To roll back, use an older copied release, mirror its source if needed, and
reapply its `flux-entrypoint.yaml`. Never overwrite a source tag. Rollback does
not reverse publisher state or prior Coder API changes.
