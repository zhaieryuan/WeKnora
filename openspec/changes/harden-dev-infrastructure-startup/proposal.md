## Why

`make dev-start` currently reports success as soon as Docker Compose creates the selected containers, even when a required long-running service exits immediately. The complete baseline exposed this gap: Dex exits because its static client has no secret, but the startup command still returns zero and presents the environment as ready.

## What Changes

- Configure the development Dex static client through the existing `OIDC_AUTH_CLIENT_SECRET` setting, with an explicitly local-only default so a clean development environment can start without committing a real credential.
- Make development startup wait for Compose services and propagate failed or unhealthy container state instead of printing a false success.
- Make development stop/restart cover containers from every Compose profile and refuse to report success while project containers remain.
- Document the readiness timeout and the relationship between the local Dex client secret and the backend OIDC setting.
- Add focused static and runtime verification for successful startup and failure propagation.

## Capabilities

### New Capabilities

- `reliable-local-dev-startup`: Development infrastructure startup only succeeds when the selected long-running services remain available, and the bundled local Dex configuration is internally consistent.

### Modified Capabilities

- None.

## Impact

- Affected files: `scripts/dev.sh`, `docker-compose.dev.yml`, a development-only Dex config under `misc/`, `.env.example`, and local development/OIDC documentation.
- The existing OIDC client-secret environment variable is reused; no production credential is committed or logged.
- No REST, gRPC, CLI, database, tenant, RBAC, API Key, or production deployment contract changes.
- Rollback restores the previous Compose invocation and Dex example; no data migration is required.
