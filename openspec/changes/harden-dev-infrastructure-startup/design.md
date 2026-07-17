## Context

The default development command now selects the Compose `full` profile. During its first runtime verification, Compose created all containers and returned zero, but Dex exited immediately because the shared example config intentionally omitted a static-client secret. `scripts/dev.sh` invokes `up -d` without waiting for health or stable container state, so it printed a success banner despite the failed dependency.

The production Compose file also mounts `misc/dex-config.yaml`; changing that shared example would broaden the fix beyond local development. The development environment therefore needs an isolated Dex configuration and a readiness gate that uses Compose's own dependency and health model.

## Goals / Non-Goals

**Goals:**

- Start the local Dex container without committing or printing a real client secret.
- Reuse `OIDC_AUTH_CLIENT_SECRET` so the host application and Dex can share one explicit value when local OIDC is enabled.
- Return non-zero from `make dev-start` when a selected service exits, becomes unhealthy, or fails to become ready within a bounded time.
- Preserve successful exit-zero one-shot services such as the database/config initializers and sandbox image-preparation container.
- Stop all WeKnora development containers across profiles before a profile switch or restart, without deleting volumes or unrelated projects.

**Non-Goals:**

- Do not change production Compose, the production Dex example, public authentication APIs, or OIDC authorization behavior.
- Do not make OpenSearch Dashboards or `odl-hybrid` default services.
- Do not delete Docker volumes, images, or user data as part of ordinary startup.

## Decisions

### Use a development-only Dex configuration with `secretEnv`

`docker-compose.dev.yml` SHALL mount a dedicated local Dex config whose static client reads `OIDC_AUTH_CLIENT_SECRET` through Dex's `secretEnv` field. Compose SHALL inject that existing variable and use a clearly named local-only placeholder when it is absent. Developers enabling OIDC in the host application set `OIDC_AUTH_CLIENT_SECRET` in `.env`, which overrides the placeholder for both sides.

This avoids committing a real secret and avoids changing the shared config mounted by production Compose. A public Dex client was rejected because the WeKnora backend performs a confidential authorization-code exchange and requires a client secret.

### Let Docker Compose enforce readiness

The initial long-running-service call SHALL use `up -d --wait --wait-timeout`, with a positive integer timeout controlled by `DEV_START_WAIT_SEC` and a documented default. The wait targets SHALL be derived from the selected Compose profiles with `config --services`, so the script does not duplicate the long-running baseline list.

Compose treats dependency init containers that exit zero as completed, but it rejects a top-level one-shot service such as `sandbox` under `up --wait`. The script SHALL therefore run `sandbox` separately when selected, use `docker wait` to verify its real exit code, and exclude standalone/initializer service names from the dynamically derived wait targets. `searxng-init` and `langfuse-db-init` remain dependencies of their long-running consumers and are still started and checked by Compose.

Before startup, the script SHALL verify that the detected Compose implementation supports `--wait`. An unsupported legacy implementation fails with an upgrade instruction instead of falling back to false-success behavior. On startup failure, the script prints Compose status without exposing environment values.

The existing `odl-hybrid` HTTP readiness loop remains because that optional service has a specialized application-level health contract after Compose starts it.

### Tear down every development profile before switching modes

Docker Compose `down` without profile selection only removed the profile-less PostgreSQL, Redis, and DocReader containers in the reproduced environment. `dev-stop` SHALL select the Compose wildcard profile and use `--remove-orphans`, then query the same project to ensure no containers remain before reporting success. This stays scoped to `docker-compose.dev.yml` and does not pass `--volumes`, so unrelated Docker projects and persistent development data are preserved.

`dev-restart` SHALL stop immediately if teardown fails rather than starting on top of a partial old profile.

## Risks / Trade-offs

- [Legacy standalone `docker-compose` may not support `up --wait`] → Fail early with an actionable request to use current Docker Compose instead of silently weakening verification.
- [Healthy services can need longer on constrained machines] → Allow `DEV_START_WAIT_SEC` to raise the bounded wait without changing the Compose file.
- [The local-only default is discoverable] → Scope it to the development Compose file, label it as non-production, and require an explicit `.env` value when enabling host-side OIDC.
- [Services without health checks are considered ready once running] → Compose still catches immediate exits such as Dex; endpoint probes remain part of runtime verification for this change.
- [Compose rejects a successful top-level one-shot under `--wait`] → Run the standalone sandbox preparation task separately, verify its exit code, and wait only on dynamically selected long-running services.
- [`down` without profiles leaves selected-profile containers running] → Select the wildcard profile, remove project orphans, and verify the project has no remaining containers before success.

## Migration Plan

1. Add the development-only Dex config and wire the existing OIDC secret variable in `docker-compose.dev.yml`.
2. Add Compose wait capability detection and bounded startup waiting to `scripts/dev.sh`.
3. Make teardown profile-complete and verify the project container set is empty before a clean profile switch.
4. Update local configuration and OIDC guidance.
5. Recreate the Dex container, run `make dev-start`, and probe the selected baseline services.

Rollback restores the previous bind mount and `up -d` invocation. No volume or schema migration is involved.

## Open Questions

- None. The observed Dex error and Compose `--wait` failure propagation were reproduced locally.
