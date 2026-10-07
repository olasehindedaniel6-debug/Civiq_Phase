# CIVIQ - City Intelligence Quotient

Civic intelligence platform. First deployment: Ibadan, Oyo State, Nigeria.
Designed to expand to other states, countries and continents without schema changes.

> Status: Phase 1 (foundation). Only the API skeleton exists. Nothing else is implemented yet.

## Quick start (local or GitHub Codespaces)

```bash
corepack enable
pnpm install
cp .env.example .env
pnpm test        # runs the tests
pnpm dev         # starts API on http://localhost:4000
curl http://localhost:4000/v1/health
```

Database (needs Docker; Codespaces provides it via the devcontainer):

```bash
pnpm db:up
```

## Layout
- `apps/api` - REST API (Fastify + TypeScript)
- `packages/shared` - shared types/schemas (provenance, verification states, roles)
- `packages/ai`, `packages/geo` - provider interfaces (empty until needed)
- `database/` - migrations and seeds (Phase 2)
- `docs/` - architecture, ADRs, roles and scopes
- `infra/` - local docker compose

## Rules
- No secrets in code. `.env` is never committed.
- Demo/synthetic data must be flagged via `provenance`.
