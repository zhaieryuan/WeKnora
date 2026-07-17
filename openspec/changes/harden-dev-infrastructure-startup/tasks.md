## 1. Local Dex configuration

- [x] 1.1 Add a development-only Dex configuration whose static client reads `OIDC_AUTH_CLIENT_SECRET` through `secretEnv`.
- [x] 1.2 Wire `docker-compose.dev.yml` to the development config and inject the existing OIDC secret variable with a clearly local-only default.

## 2. Startup readiness

- [x] 2.1 Update `scripts/dev.sh` to validate a positive `DEV_START_WAIT_SEC`, require Compose `up --wait` support, and wait for the selected services.
- [x] 2.2 Verify the standalone sandbox task separately, preserve optional `odl-hybrid` handling, and print Compose status on readiness failure without exposing environment values.
- [x] 2.3 Make `dev-stop` remove containers from every development profile, verify the project is empty, and prevent restart after incomplete teardown.

## 3. Developer guidance

- [x] 3.1 Update `.env.example`, development guides, and OIDC guidance with the readiness timeout and local Dex secret behavior.

## 4. Verification

- [x] 4.1 Run shell syntax and Compose configuration checks, including invalid-timeout failure behavior.
- [x] 4.2 Recreate the development environment, verify every selected long-running container and key local endpoint, and confirm expected one-shot exits are zero.
- [x] 4.3 Review the focused diff and run `openspec validate harden-dev-infrastructure-startup` plus the existing startup change validation.
