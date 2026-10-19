# Air-gapped Coder workspace release

Run from the copied `coder-workspaces` directory. These are mirror archives;
never deploy them with Zarf. The consuming platform must provide the registry
writer credential and the runtime contracts configured in its Flux
substitution values. `WORKLOAD_NAMESPACE` identifies the dedicated
`coder-template-publisher` runtime namespace; it is distinct from the namespace
where Coder provisions user workspaces.

Prepare the environment and verify the copied release:

```sh
install -m 600 .env.example .env
$EDITOR .env
direnv allow
test -f "$KUBECONFIG"
sha256sum --check SHA256SUMS
```

For an ordinary template-only release, mirror the source:

```sh
just mirror
```

When a publisher, workspace, code-server, or VSIX image changed, mirror the
images first and the source last:

```sh
just mirror-all
```

Mirroring leaves the new source inactive. Confirm that Zot contains the digest
recorded in this release, then apply its generated release selector. On an
existing platform, the watched ConfigMap makes the application root update its
platform-owned `OCIRepository` to that exact digest:

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

On a first installation, activate the consuming application release now; it
creates the platform-owned `OCIRepository` and child Kustomization with the
already selected digest. For that first installation and for routine updates,
finish by waiting for the exact source, child reconciliation, and publisher Job:

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

To roll back, enter an older copied release, mirror its source if it is absent,
and reapply its digest-pinned `flux-entrypoint.yaml`. Never move or overwrite an
existing source tag. Desired-state rollback does not reverse publisher state or
changes already made through the Coder API.
