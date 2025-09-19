# Urlaubsantraege Platform

Lead-engineered packaging for the [urlaubsverwaltung](https://github.com/urlaubsverwaltung/urlaubsverwaltung) HR leave management application. This repository vendors the upstream source as a git submodule and adds everything required to build, ship, and operate the service with Docker, Docker Compose, and GitHub Actions.

## Repository layout

```
app/urlaubsverwaltung   # upstream source (git submodule)
compose/                # docker compose stacks
config/                 # baseline Spring Boot configuration overlays
.github/workflows/      # CI/CD pipelines
scripts/                # helper scripts for local validation
Dockerfile              # production-grade image build
.dockerignore           # docker build context filter
.env.example            # base environment configuration
README.md               # this file
```

Run `git submodule update --init --recursive` after cloning to hydrate `app/urlaubsverwaltung`.

## Upstream requirements snapshot

| Concern | Value |
| --- | --- |
| JDK | 21 (Temurin) |
| Build tool | Maven Wrapper (`./mvnw`) |
| Database | PostgreSQL 15.x |
| Mail | SMTP (sample: Mailpit) |
| Profiles | `default` (production), `demodata` (demo/dev) |
| Optional auth | OpenID Connect (Keycloak example included) |

The upstream application exposes Spring Boot actuators at `/actuator/health`, `/actuator/health/readiness`, and `/actuator/health/liveness`. Our Docker image enables these endpoints for container health checks.

## Configuration defaults

Configuration lives under `config/` and is loaded by Spring when placed on the classpath (`--spring.config.additional-location=classpath:/config/`). Environment variables override every secret or deployment specific value.

| Environment variable | Purpose | Default |
| --- | --- | --- |
| `SERVER_PORT` | HTTP listener | `8080` |
| `SPRING_PROFILES_ACTIVE` | Active Spring profiles | `default` (production) |
| `SPRING_DATASOURCE_URL` | JDBC URL | `jdbc:postgresql://postgres:5432/urlaubsverwaltung` |
| `SPRING_DATASOURCE_USERNAME` | DB user | `urlaubsverwaltung` |
| `SPRING_DATASOURCE_PASSWORD` | DB password | `urlaubsverwaltung` |
| `SPRING_MAIL_HOST` | SMTP host | `mailpit` |
| `SPRING_MAIL_PORT` | SMTP port | `1025` |
| `SPRING_MAIL_USERNAME` | SMTP user | _empty_ |
| `SPRING_MAIL_PASSWORD` | SMTP password | _empty_ |
| `UV_MAIL_FROM` | Sender email | `urlaubsverwaltung@example.org` |
| `UV_MAIL_FROMDISPLAYNAME` | Sender display name | `Urlaubsverwaltung` |
| `UV_MAIL_REPLYTO` | Reply-to email | `no-reply@example.org` |
| `UV_MAIL_REPLYTODISPLAYNAME` | Reply-to display name | `Urlaubsverwaltung` |
| `UV_MAIL_APPLICATIONURL` | Public base URL | `http://localhost:8080` |
| `UV_CALENDAR_ORGANIZER` | Calendar organiser | `organizer@example.org` |
| `MANAGEMENT_HEALTH_MAIL_ENABLED` | Disable expensive mail health probe | `false` |

Optional OpenID Connect variables (used in the OIDC compose stack):

| Environment variable | Purpose | Default (OIDC stack) |
| --- | --- | --- |
| `SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_DEFAULT_CLIENT_ID` | OIDC client id | `urlaubsverwaltung` |
| `SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_DEFAULT_CLIENT_SECRET` | OIDC client secret | `urlaubsverwaltung-secret` |
| `SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_DEFAULT_CLIENT_NAME` | Display name | `urlaubsverwaltung` |
| `SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_DEFAULT_SCOPE` | Requested scopes | `openid,profile,email,roles` |
| `SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_DEFAULT_AUTHORIZATION_GRANT_TYPE` | Flow | `authorization_code` |
| `SPRING_SECURITY_OAUTH2_CLIENT_REGISTRATION_DEFAULT_REDIRECT_URI` | Redirect template | `http://localhost:8080/login/oauth2/code/{registrationId}` |
| `SPRING_SECURITY_OAUTH2_CLIENT_PROVIDER_DEFAULT_ISSUER_URI` | Issuer URL | `http://keycloak:8080/realms/urlaubsverwaltung` |
| `SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI` | Resource server issuer | `http://keycloak:8080/realms/urlaubsverwaltung` |
| `UV_SECURITY_OIDC_CLAIM_MAPPERS_GROUP_CLAIM_ENABLED` | Enable group claim mapping | `true` |
| `UV_SECURITY_OIDC_CLAIM_MAPPERS_GROUP_CLAIM_CLAIM_NAME` | Group claim name | `groups` |

All secrets (DB password, OIDC secret, SMTP credentials) must be provided via env vars or external secret managers. They never live in git.

## Building the Docker image

Requirements: Docker 24+, git submodules initialised.

```
docker build \
  -t flex420/urlaubsverwaltung:local \
  .
```

Key characteristics:

- Multi-stage build: Temurin 21 JDK for Maven build -> Temurin 21 JRE runtime.
- Uses Maven wrapper with dependency download caching via buildkit.
- Produces a non-root image (`uv` user, UID 1000) exposing port 8080.
- Boots with sensible `JAVA_TOOL_OPTIONS` (container aware heap and GC tuning).
- Declares an `HEALTHCHECK` hitting `/actuator/health/readiness`.

## Docker Compose stacks

We ship two Compose bundles under `compose/`.

### `docker-compose.dev.yml`

- Services: `app` (built locally), `postgres`, `mailpit`.
- Activates `demodata` profile by default for seeded demo accounts.
- Persists the database via the `urlaubsverwaltung-data` named volume.
- Mailpit listens on `localhost:8025` (UI) and `localhost:1025` (SMTP).

Usage:

```
cp .env.example .env
# edit credentials if needed
docker compose -f compose/docker-compose.dev.yml up --build
```

Visit http://localhost:8080 and sign in with the pre-seeded demo users described in the upstream README (`office@urlaubsverwaltung.cloud` / `secret`).

### `docker-compose.oidc.yml`

Extends the dev stack with Keycloak for OpenID Connect testing:

- Adds `keycloak` with an imported realm and demo users.
- Binds Keycloak to `localhost:8090` and wires the issuer into the app.
- Documents how to obtain tokens via `scripts/keycloak-demo.sh`.

Start it with:

```
docker compose \
  -f compose/docker-compose.dev.yml \
  -f compose/docker-compose.oidc.yml \
  up --build
```

## Helper scripts

`scripts/verify.sh` runs `docker build` and `docker compose config` validation locally. `scripts/keycloak-demo.sh` (requires curl and jq) demonstrates obtaining an OIDC token from the sample realm.

## CI/CD pipeline

`.github/workflows/ci.yml` performs:

1. Checks out this repo and pulls the upstream submodule.
2. Executes the upstream unit test suite via `./app/urlaubsverwaltung/mvnw -B -DskipITs test`.
3. Runs `scripts/verify.sh` to lint the Docker context and Compose files.
4. Builds the production image with caching and publishes to Docker Hub after every push using commit and branch tags (plus latest/release tags on main).
5. Publishes a lightweight SBOM and attaches it as workflow artifact.
GitHub secrets required (already provisioned):

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## Updating upstream

To update the upstream application:

```
git submodule update --remote app/urlaubsverwaltung
# optionally pin to a release tag, then commit
```

Re-run the CI pipeline to publish a refreshed image.
