## Context

`scripts/dev.sh start` currently activates only the `langfuse` profile. The application started by `dev-app` maps service hosts to localhost and can be configured to use Neo4j, MinIO, a vector database, search, or OIDC. Those services are already expressed in `docker-compose.dev.yml`, mostly under the `full` profile, but are silently omitted by the default command.

The Compose file deliberately keeps two services outside `full`: `odl-hybrid` builds a large local-only Docling image, and `opensearch-dashboards` is an inspection UI. The `sandbox` entry is in `full` but is an image-preparation job, not a long-running dependency.

## Goals / Non-Goals

**Goals:**

- Make a plain `make dev-start` activate every long-running local development dependency represented by the `full` Compose profile.
- Preserve an explicit way to exclude Langfuse and to enable the two intentionally on-demand services.
- Make console output and developer documentation describe the actual default service set and its host ports.
- Validate the default Compose service selection without depending on model credentials or application startup.

**Non-Goals:**

- Do not change production `docker-compose.yml`, service images, ports, environment-variable names, credentials, or application feature flags.
- Do not make `odl-hybrid` or OpenSearch Dashboards default services.
- Do not automatically stop services previously started with another profile.

## Decisions

### Default to the existing `full` Compose profile

`dev.sh` SHALL set its default profile selection to `--profile full`, rather than duplicating each service profile in the script. The Compose file remains the source of truth for full-environment membership, so future services added to `full` are included automatically.

Alternatives considered:

- Enumerate all individual profiles in `dev.sh`: rejected because the script could drift from Compose again.
- Make only Neo4j default: rejected because it solves the observed failure but retains the same omission risk for other supported local dependencies.

### Preserve explicit exclusions with a full-minus-Langfuse profile list

Because Docker Compose profiles are additive and `full` includes Langfuse, `--no-langfuse` SHALL select the complete non-Langfuse profile set individually. This preserves the existing opt-out meaning while keeping plain startup aligned to `full`.

`--odl-hybrid` SHALL continue to build and wait for the hybrid service only when explicitly requested. Existing feature-profile arguments remain accepted for command-line compatibility, even though the default already includes their services.

### Keep output and documentation contract-driven

The script SHALL list each default long-running service and host access address only when its selected profile starts it. The Make help and development guides SHALL state that plain startup launches the complete baseline and identify the two explicit opt-in services.

## Risks / Trade-offs

- [First startup downloads more images and uses more CPU, memory, disk, and host ports] → Document the expanded baseline and retain `--no-langfuse`; users can stop the environment with `make dev-stop`.
- [A host port conflict blocks complete startup] → Preserve Compose's explicit port error and list the affected ports in documentation for preflight troubleshooting.
- [Future `full` membership changes silently alter local resource usage] → Treat `docker-compose.dev.yml` as the single source of truth and verify the default command selects the `full` profile.
- [Previously started profile services remain after an opt-out invocation] → Document that profile selection controls what the command starts, not a teardown; use `make dev-stop` before a clean restart.

## Migration Plan

1. Update the startup script default and its output/help text.
2. Update the Make help and both development guides.
3. Verify shell syntax and inspect `docker compose --profile full config --services`.
4. Run `make dev-start` against the existing local Docker environment and verify the expected long-running containers are up.

Rollback is a one-line restoration of the script's default profile to `langfuse`; no data migration or external contract rollback is needed.

## Open Questions

- None. The user explicitly requested the complete local baseline, and `docker-compose.dev.yml` already defines it through `full`.
