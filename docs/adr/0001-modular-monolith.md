# ADR 0001: Modular monolith, generic geographic hierarchy

Status: accepted

- One backend codebase with strict module boundaries; no microservices.
- One generic `areas` table (self-referencing) instead of country/state/city
  tables, so new countries need data, not schema changes.
- Reports (raw observations) and incidents (real-world problems) are separate.
- All external services sit behind interfaces so free tiers can be swapped out.
