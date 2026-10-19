# AGENTS.md

## Scope and priorities

This repository packages an air-gapped Coder platform for local development and
owns the independently released production workspaces. It owns the server,
reusable `coderd-provider` image, Python workspace images, templates, publisher,
local aggregate package, and production Flux source and images packages.

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
  the VS Code Python devcontainer. Run as non-root `coder`; exclude VS Code Web, extensions, and project deps.
- VS Code Web: `workspaces/python/images/code-server.Containerfile`; mount its OCI image read-only
  at `/opt/vscode-server`; configure the offline module with that prefix.
- Extensions: `workspaces/python/extensions/python-extensions.Containerfile`; mount approved VSIX
  files read-only at `/opt/vsix`; install locally into writable `/home/coder`.
- Persistence: mount `/home/coder` on persistent writable storage so repositories, caches, settings, environments, and extensions survive pod replacement.
- Local deployment: `dev/` owns the Community server package, publisher
  overlay, built-in provisioner permissions, network policy, PostgreSQL
  connection, and Helm values.
- Provider runner: `coderd-provider.Containerfile` owns the reusable Coder API OpenTofu runner and offline `coder/coderd` provider mirror.
- Modules/templates: `modules/` owns pinned OpenTofu OCI artifacts; `workspaces/` owns the self-contained workspace templates.
- Publishing: `template-publisher/` owns the publisher code, shared Job, and
  namespace-scoped Kubernetes state-backend RBAC. Credentials remain
  environment-owned.
- Distribution: self-contained `dev/zarf.yaml` deploys all or only template
  components from locally built archives.
- Production: the Flux source carries the generic publisher runtime, state
  backend RBAC, and template payload; `release/` owns the mirror-only workspace
  image and Flux source packages. The consuming platform owns the dedicated
  `coder-template-publisher` namespace, configuration substitutions,
  credential, registry access, child Kustomization, and application of the
  generated digest selector entry point. Actual workspace resources remain in
  the independently configured Coder namespace.

## Air-gap and Kubernetes rules

- Use read-only Kubernetes OCI image volumes for `/opt/vscode-server` and `/opt/vsix`; never copy them with init containers.
- Treat `spec.volumes[].image` support, any `ImageVolume` gate, and executable
  mounts as prerequisites. Record checks in `workspaces/README.md`; align Coder's README.
- Pin deployed images and mirrored artifacts by digest or checksum; never use mutable tags such as `latest`.
- Declare every runtime artifact in Zarf or document its pre-seeded source. Never download publicly, refresh package managers, or contact marketplaces at workspace startup.
- Set explicit requests and limits with restricted pod defaults: non-root, no privilege escalation, and dropped capabilities.
- Keep secrets out of images, packages, and committed manifests.
- Keep the standalone local development package at `0.1.0`, and omit
  `metadata.version` from any imported component definitions. Derive the
  production source and images package versions and OCI tag from committed
  `HEAD` as `YYYY.MM.DD-g<12-character-sha>`; generate the Flux entry point with
  the resulting OCI digest. Never overwrite a published immutable tag.

## Working conventions

- Keep `Justfile` limited to build, packaging, deployment, and publication
  entrypoints that are actually used. Do not add metadata extraction, lockfile
  maintenance, one-off helpers, local validation, lint, test, render,
  smoke-test, or preflight recipes. Put CI and release plumbing in the owning
  workflow and use the underlying tool directly for infrequent maintenance.
- Keep the root, `modules/`, `workspaces/`, `template-publisher/`, and `dev/`
  READMEs short; point operations to `Justfile`.
- Record artifact source, immutable version or commit, and checksum in its owning
  Containerfile, package definition, or lock file. Put provenance and upgrade
  steps in the owning domain README.
- Include changed artifacts in Zarf and update every consumer to its digest or checksum. Do not create a separate repository-wide version inventory.
- Update dependency and source pins when the requested artifact change requires it; third-party chart versions are dependency pins.
- Do not edit production release identities by hand. Release builds derive
  them from committed `HEAD`; explicit dependency, image, and template version
  changes remain scoped to their owning files.
- Backward compatibility is not required; prefer the clean current interface.

## Validation

Local development does not include validation. Inspect the diff after a change,
but do not run or add builds, linters, renderers, tests, package inspection, or
cluster checks unless the user explicitly asks for them or a failure must be
diagnosed. Keep any requested check narrowly scoped and out of the `Justfile`.

## Principle

Platform tooling is immutable and centrally distributed through OCI and Zarf; user and project state is writable and persistent.
