# AGENTS.md

## Scope and priorities

This repository packages an air-gapped Coder platform for local development and
owns the independently released production workspaces. It owns the server,
reusable `publisher` image, Python workspace images, templates, publisher,
local aggregate package, and production publication and images packages.

Assume no public runtime internet. Artifacts must come from Zarf, an internal OCI
registry, or a documented internal source. Prioritize: secrets and air gap;
Coder Community Edition; layer ownership; and a lean `Justfile`.

## Coder constraints

- Target Coder Community Edition only. Exclude external provisioners, prebuilds,
  workspace proxies, HA, quotas, enforced scheduling, audit logging, AI Gateway, and Agent Firewall.
- Verify new features against current official Coder edition documentation.
- Use built-in provisioners. Put the offline Terraform provider mirror in the
  control-plane image and grant only required, namespace-scoped permissions.

## Architecture

Keep these layers separate and independently versioned:

- Workspace runtime: `workspaces/python/images/python.Containerfile`; one image based directly on
  the Microsoft Python dev container. Run as non-root `coder`; exclude code-server, extensions, and project deps.
- Workspace startup: `workspaces/workspace-startup.sh`; repo-owned shell belongs in the
  workspace image and is invoked by name from `startup_commands`. Never embed
  startup logic in a template's pod manifest.
  Prefer image-time configuration over a startup step for fixed behaviour that
  the persistent home directory must not mask.
- code-server: `workspaces/python/images/code-server.Containerfile`; mount its OCI image read-only
  at `/opt/code-server`; configure the offline module with that prefix.
- Extensions: `workspaces/python/extensions/python-extensions.Containerfile`; mount approved VSIX
  files read-only at `/opt/vsix`. The approved set is platform state: rebuild it
  from the payload when its fingerprint changes, and leave it alone when it does not.
- Persistence: mount `/home/coder` on persistent writable storage so repositories, caches, settings, environments, and extensions survive pod replacement.
- Local deployment: `dev/` owns the Community server package, publisher
  overlay, built-in provisioner permissions, network policy, PostgreSQL
  connection, and Helm values.
- Publisher runtime: `publisher.Containerfile` owns the reusable, generic Coder CLI runner. It carries no OpenTofu and no provider mirror.
- Modules/templates: `modules/` owns pinned OpenTofu OCI artifacts and the
  repository-owned `workspace-pod` module; `workspaces/` owns the
  self-contained workspace templates. A template declares its parameters,
  agent, and metadata and delegates its Pod and persistent home to
  `workspace-pod`; never duplicate a pod spec between templates.
- Projects: `workspaces/python/projects.json` is the single project catalog.
  The build, the CI matrix, and the template derive from it, and a deployment
  enables entries through the digest-pinned `project_images` pairs.
- Publishing: `template-publisher/` owns the publisher script and shared Job.
  Publish with the Coder CLI and keep publication stateless and idempotent:
  name a version after the hash of the template files and published variables.
  Do not reintroduce a state backend, lock, or resource import. Credentials
  remain environment-owned.
- Distribution: self-contained packages under `dev/` deploy all or only
  template components from either published, digest-pinned OCI images or local
  OCI archives.
- Production: `release/images/` is mirror-only; `release/publish/` is deployed
  with `zarf package deploy --connected` against a cluster that is not
  Zarf-initialized, and carries the publisher script, its Job and identity, and
  the template payload. Do not reintroduce Flux objects, a Flux OCI source, or
  `${}` substitution. Keep the fixed namespace, pull Secret, Git auth, and
  branch contract in the templates and manifests; expose only
  deployment-specific values as Zarf variables. The publishing token is
  supplied as `ZARF_VAR_CODER_TOKEN`
  for one deployment and deleted with its Secret afterwards; never store it.
  The consuming platform owns the registry, Git access, project images, the
  resources required by the fixed contract, and mounting the mirrored Coder
  modules image at
  `/opt/coder-modules` on its control plane. Actual workspace resources remain
  in the independently configured Coder namespace.

## Air-gap and Kubernetes rules

- Use read-only Kubernetes OCI image volumes for `/opt/code-server` and `/opt/vsix`; never copy them with init containers.
- Treat `spec.volumes[].image` support, any `ImageVolume` gate, and executable
  mounts as prerequisites. Record checks in `workspaces/README.md`; align Coder's README.
- Pin deployed images and mirrored artifacts by digest or checksum; never use mutable tags such as `latest`.
- Declare every runtime artifact in Zarf or document its pre-seeded source. Never download publicly, refresh package managers, or contact marketplaces at workspace startup.
- Set explicit requests and limits with restricted pod defaults: non-root, no privilege escalation, and dropped capabilities.
- Keep secrets out of images, packages, and committed manifests.
- Keep the standalone local development package at `0.1.0`, and omit
  `metadata.version` from any imported component definitions. Derive the
  production publication and images package versions from committed `HEAD` as
  `YYYY.MM.DD-g<12-character-sha>`. Never overwrite a published production
  release.

## Working conventions

- Keep the root `Justfile` to compact build, packaging, release, deployment,
  and kind-cluster helpers. Prefer a short Just recipe over a long README shell
  block, but do not hide operations in wrapper scripts. Public recipes take no
  positional arguments; use distinct names and environment variables instead.
  Do not add metadata extraction, lockfile maintenance, one-off helpers, local
  validation, lint, test, render, smoke-test, or preflight recipes.
- Keep the root, `modules/`, `workspaces/`, `template-publisher/`, and `dev/`
  READMEs concise and point repeated mechanics to `Justfile`.
- Record artifact source, exact version or commit, and checksum in its owning
  Containerfile, package definition, or lock file. Put provenance and upgrade
  steps in the owning domain README.
- Include changed artifacts in Zarf and update every consumer to its digest or checksum. Do not create a separate repository-wide version inventory.
- Update dependency and source pins when the requested artifact change requires it; third-party chart versions are dependency pins.
- Do not bump an artifact or package version unless the user explicitly requests or approves the bump. Workspace image SemVer tags are mutable publishing aliases; deployments and packages must remain digest-pinned. Before deleting a superseded digest, confirm that no retained template revision, release metadata, Zarf package, or deployed workspace references it.
- Do not edit production release identities by hand. Release builds derive
  them from committed `HEAD`; explicit dependency, image, and template version
  changes remain scoped to their owning files.
- Backward compatibility is not required; prefer the clean current interface.

## Validation

Local development does not include validation. Inspect the diff after a change,
but do not run or add builds, linters, renderers, tests, package inspection, or
cluster checks unless the user explicitly asks for them or a failure must be
diagnosed. Keep any requested check narrowly scoped and out of the `Justfile`.

CI validates container images only. The publisher, ConfigMap payloads, and
templates have no automated checks: a name that must stay in sync across the
Job, a template's variables, and a ConfigMap payload is verified by reading the
diff. Broken HCL, a missing required variable, and an unresolvable module fail
at publication.

## Principle

Platform tooling is immutable and centrally distributed through OCI and Zarf; user and project state is writable and persistent.
