-- 0002: data-driven categories and incident workflow
CREATE TABLE categories (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id        uuid REFERENCES categories(id) ON DELETE RESTRICT,
  slug             text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name             text NOT NULL,
  description      text,
  taxonomy_version integer NOT NULL DEFAULT 1,
  sort_order       integer NOT NULL DEFAULT 0,
  active           boolean NOT NULL DEFAULT true,
  attributes       jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX categories_parent_idx ON categories (parent_id);

-- Lifecycle lives in data so states can change without code changes.
CREATE TABLE workflow_states (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        text NOT NULL UNIQUE,
  name        text NOT NULL,
  sort_order  integer NOT NULL DEFAULT 0,
  is_initial  boolean NOT NULL DEFAULT false,
  is_terminal boolean NOT NULL DEFAULT false,
  active      boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX workflow_one_initial ON workflow_states (is_initial) WHERE is_initial;

CREATE TABLE workflow_transitions (
  from_state_id uuid NOT NULL REFERENCES workflow_states(id),
  to_state_id   uuid NOT NULL REFERENCES workflow_states(id),
  PRIMARY KEY (from_state_id, to_state_id),
  CHECK (from_state_id <> to_state_id)
);
