# CIVIQ architecture (Phase 0 summary)

See the blueprint. Key points:
- Web (Next.js PWA) -> REST API (Fastify, TypeScript) -> PostgreSQL + PostGIS
- Background jobs in Postgres (pg-boss), added when first needed
- Ports/adapters for maps, storage, AI, auth, notifications
- Every record has provenance; AI output is a suggestion with confidence

## Status of components
| Component | Status |
|---|---|
| API skeleton + health endpoint | REAL |
| Dev database (PostGIS via Docker) | REAL (config only, not yet used by code) |
| Database schema | PLANNED (Phase 2) |
| Roles and scopes | DESIGNED (docs/roles-and-scopes.md) |
| Reports, map, AI, analytics | PLANNED / FUTURE |
