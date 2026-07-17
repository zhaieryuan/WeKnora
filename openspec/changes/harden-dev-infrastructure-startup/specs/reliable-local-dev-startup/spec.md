## ADDED Requirements

### Requirement: Development startup reports selected service failure
The development startup command SHALL return success only after Docker Compose reports that all selected services are running or healthy and all selected one-shot services have completed successfully within the configured timeout.

#### Scenario: Selected service exits during startup
- **WHEN** a selected long-running development service exits with a non-zero status during startup
- **THEN** `make dev-start` SHALL return non-zero and SHALL NOT print the successful-environment banner

#### Scenario: Selected services become ready
- **WHEN** all selected long-running services are running or healthy and selected one-shot services complete successfully
- **THEN** `make dev-start` SHALL return zero and print the successful-environment guidance

#### Scenario: Compose lacks readiness support
- **WHEN** the detected Docker Compose implementation does not support bounded `up --wait`
- **THEN** startup SHALL fail before creating services and provide an actionable Compose upgrade message

### Requirement: Local Dex has a consistent confidential client
The development Compose environment SHALL start Dex with a non-empty local static-client secret sourced from `OIDC_AUTH_CLIENT_SECRET`, without committing or logging a real credential and without changing production Compose behavior.

#### Scenario: Clean local environment starts Dex
- **WHEN** a developer has not set `OIDC_AUTH_CLIENT_SECRET` and runs the default development startup command
- **THEN** the Dex container SHALL use the documented local-only placeholder and remain running

#### Scenario: Developer enables local OIDC
- **WHEN** a developer sets `OIDC_AUTH_CLIENT_SECRET` in `.env` and starts the development environment and host application
- **THEN** both the local Dex static client and the WeKnora OIDC client SHALL use that explicit value

#### Scenario: Secret remains undisclosed
- **WHEN** development startup succeeds or fails
- **THEN** the startup output and committed configuration SHALL NOT expose a real client secret

### Requirement: Readiness waiting is bounded and configurable
Development startup SHALL apply a documented positive-integer readiness timeout and SHALL allow developers to increase it for resource-constrained machines.

#### Scenario: Service readiness exceeds the timeout
- **WHEN** selected services do not reach an accepted Compose state before `DEV_START_WAIT_SEC` elapses
- **THEN** startup SHALL return non-zero and show container status for diagnosis

#### Scenario: Invalid timeout is configured
- **WHEN** `DEV_START_WAIT_SEC` is empty, zero, negative, or non-numeric
- **THEN** startup SHALL return non-zero before invoking Compose and explain the valid format

### Requirement: Development teardown covers every profile
The development stop and restart commands SHALL remove all containers belonging to `docker-compose.dev.yml` regardless of which profiles started them, while preserving named volumes and unrelated Docker projects.

#### Scenario: Developer switches from full to non-Langfuse mode
- **WHEN** the full profile is running and the developer runs `make dev-stop`
- **THEN** all WeKnora development containers, including Langfuse and other profiled services, SHALL be removed before the command returns success

#### Scenario: Teardown leaves project containers behind
- **WHEN** Compose teardown returns but any WeKnora development project container remains
- **THEN** `make dev-stop` SHALL return non-zero and identify that teardown is incomplete

#### Scenario: Restart teardown fails
- **WHEN** `make dev-restart` cannot completely stop the existing development environment
- **THEN** it SHALL return non-zero without starting another environment on top of the partial state
