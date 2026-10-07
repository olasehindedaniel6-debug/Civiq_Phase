# CIVIQ - City Intelligence Quotient

Civic intelligence platform. First deployment: Ibadan, Oyo State, Nigeria.
Designed to expand to other states, countries and continents without schema changes.

> Status: Phase 2 (database). The API skeleton and the database schema exist and are tested. Reporting, maps and AI are not built yet.

## Quick start (local or GitHub Codespaces)

```bash
corepack enable
pnpm install
cp .env.example .env
pnpm test        # runs the tests
pnpm dev         # starts API on http://localhost:4000
curl http://localhost:4000/v1/health
```

Database (Codespaces provides it via the devcontainer; locally use Docker with `pnpm db:up`):

```bash
export DATABASE_URL=postgres://civiq:civiq_dev_password@localhost:5432/civiq   # in Codespaces use host "db" instead of "localhost"
pnpm db:migrate
pnpm db:seed
pnpm test        # database tests run when DATABASE_URL is set
```

See `docs/database.md`.

## Layout
- `apps/api` - REST API (Fastify + TypeScript)
- `packages/shared` - shared types/schemas (provenance, verification states, roles)
- `packages/ai`, `packages/geo` - provider interfaces (empty until needed)
- `database/` - SQL migrations, seeds, migration runner, schema tests
- `docs/` - architecture, ADRs, roles and scopes
- `infra/` - local docker compose

## Rules
- No secrets in code. `.env` is never committed.
- Demo/synthetic data must be flagged via `provenance`.
