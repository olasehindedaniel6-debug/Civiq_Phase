# Database (Phase 2)

PostgreSQL 16 + PostGIS + ltree. Plain SQL migrations in `database/migrations`,
applied in order by `pnpm db:migrate` and tracked in `schema_migrations`.
Seeds in `database/seeds` are idempotent: `pnpm db:seed`.

## Tables
| Table | Purpose |
|---|---|
| `areas` | ONE generic geographic hierarchy (continent > country > state > city > district...). `path` (ltree) and `level` are maintained by trigger. `boundary` is NULL until real boundary data is imported. |
| `categories` | Data-driven taxonomy (self-referencing). Add or disable rows; no code change. |
| `workflow_states`, `workflow_transitions` | Incident lifecycle stored as data. A trigger rejects transitions not listed. |
| `users`, `organizations` | Minimal identity. Email optional, no phone or real name required. |
| `role_assignments` | Role OF an area (owner is the only global role). Revocable. |
| `reports` | One immutable citizen observation. Anonymous allowed (`reporter_id` NULL). |
| `incidents` | A real-world problem that 1..n reports describe. Has verification state, severity, confidence. |
| `media_assets` | Evidence images (jpeg/png/webp only). Tracks EXIF stripping and moderation. |
| `analyses` | Every AI/rule output with provider, model, version, confidence. Never overwrites human decisions. |
| `status_events` | Append-only incident history. |
| `audit_log` | Who did what. |

## Functions
- `user_has_role_in_area(user, area, roles[])`: true if the user holds one of the roles on the area OR an ancestor of it. Roles never apply upward. This is the basis for the owner > national > state > city hierarchy.
- `area_for_point(geography)`: deepest area whose imported boundary contains the point; NULL if none (it never guesses).

## Honesty notes
- Seeded areas are real names only (Africa, Nigeria, Oyo State, Ibadan). No boundaries or coordinates are invented.
- Test data is flagged `provenance = 'synthetic'` and only exists inside throwaway test databases.
- Not yet in the database: real boundaries, storage of actual image files, AI results (tables are ready, nothing writes to them yet).

## Testing
`pnpm test` runs 12 integration tests against a throwaway database when `DATABASE_URL` is set, and skips them otherwise.
