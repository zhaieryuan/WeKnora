## 1. Default startup behavior

- [x] 1.1 Update `scripts/dev.sh` so default startup selects the Compose `full` profile, preserves `--no-langfuse`, and keeps `odl-hybrid` explicitly opt-in.
- [x] 1.2 Update startup help and success output to describe every default long-running service and the explicitly on-demand services accurately.

## 2. Developer guidance

- [x] 2.1 Update `Makefile` help text for the new complete default development baseline.
- [x] 2.2 Update `docs/开发指南.md` and `docs/快速开发模式说明.md` with default services, ports, resource expectations, and opt-in service commands.

## 3. Verification

- [x] 3.1 Verify `scripts/dev.sh` shell syntax and the default/full and no-Langfuse Compose service selections.
- [x] 3.2 Run `make dev-start`, verify the expected baseline containers are started, and review the focused diff.
- [x] 3.3 Run `openspec validate start-all-dev-infrastructure` and record completed tasks.
