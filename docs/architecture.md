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
| Database schema, migrations, seeds (areas, categories, workflow, users, roles, reports, incidents) | REAL, tested (Phase 2) |
| Scoped role check in SQL (`user_has_role_in_area`) | REAL, tested |
| Enforcing roles in the API, authentication | PLANNED (Phase 3) |
| Real area boundaries | PLANNED (needs data import) |
| Report submission, map, image upload | PLANNED (Phases 3-5) |
| AI processing, analytics, prediction | PLANNED / FUTURE |
