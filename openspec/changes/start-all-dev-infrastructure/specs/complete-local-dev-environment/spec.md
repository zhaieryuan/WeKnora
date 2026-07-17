## ADDED Requirements

### Requirement: Complete default development infrastructure
The development startup command (`make dev-start` and its underlying `scripts/dev.sh start`) SHALL activate the `full` Docker Compose profile by default, in addition to services without a profile.

#### Scenario: Default startup selects all baseline dependencies
- **WHEN** a developer runs `make dev-start` without profile arguments
- **THEN** the command SHALL invoke `docker-compose.dev.yml` with the `full` profile and start the baseline services defined by that profile.

#### Scenario: Graph-enabled application startup has a Neo4j service
- **WHEN** `NEO4J_ENABLE=true` and a developer runs the default development startup command
- **THEN** the command SHALL start the Neo4j service defined by `docker-compose.dev.yml` without requiring an additional profile argument.

### Requirement: Explicitly on-demand development services
The default development startup command MUST NOT start `odl-hybrid` or OpenSearch Dashboards unless the developer explicitly selects their respective on-demand profile.

#### Scenario: Default startup avoids optional heavy and UI services
- **WHEN** a developer runs `make dev-start` without profile arguments
- **THEN** the command SHALL not select the `odl-hybrid` or `opensearch-ui` profiles.

#### Scenario: Developer requests hybrid document parsing
- **WHEN** a developer runs `make dev-start DEV_ARGS=--odl-hybrid`
- **THEN** the command SHALL select and build the `odl-hybrid` service using the existing readiness workflow.

### Requirement: Accurate startup guidance and output
The development startup script and developer guides SHALL describe the default profile's services, host access points, opt-in services, and the effect of opting out of Langfuse accurately.

#### Scenario: Developer reviews default startup guidance
- **WHEN** a developer reads `make help`, `docs/开发指南.md`, or `docs/快速开发模式说明.md`
- **THEN** the documentation SHALL state that plain `make dev-start` starts the complete local development baseline and identify `odl-hybrid` and OpenSearch Dashboards as opt-in services.

#### Scenario: Developer excludes Langfuse
- **WHEN** a developer runs `make dev-start DEV_ARGS=--no-langfuse` from a clean environment
- **THEN** the command SHALL start the non-Langfuse complete baseline without selecting the Langfuse profile.
