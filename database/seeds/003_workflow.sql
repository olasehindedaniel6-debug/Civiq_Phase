-- Default incident lifecycle. Stored as data so it can evolve without code changes.
INSERT INTO workflow_states (slug, name, sort_order, is_initial, is_terminal) VALUES
  ('reported','Reported',10,true,false),
  ('processing','Processing',20,false,false),
  ('under-review','Under review',30,false,false),
  ('verified','Verified',40,false,false),
  ('prioritized','Prioritized',50,false,false),
  ('assigned','Assigned',60,false,false),
  ('in-progress','In progress',70,false,false),
  ('resolved','Resolved',80,false,false),
  ('closed','Closed',90,false,true)
ON CONFLICT (slug) DO NOTHING;

WITH t(a,b) AS (VALUES
  ('reported','processing'),
  ('processing','under-review'),
  ('under-review','verified'),
  ('under-review','closed'),      -- e.g. invalid or duplicate, closed after review
  ('verified','prioritized'),
  ('prioritized','assigned'),
  ('assigned','in-progress'),
  ('in-progress','resolved'),
  ('resolved','in-progress'),     -- reopened
  ('resolved','closed')
)
INSERT INTO workflow_transitions (from_state_id, to_state_id)
SELECT f.id, o.id FROM t
JOIN workflow_states f ON f.slug = t.a
JOIN workflow_states o ON o.slug = t.b
ON CONFLICT DO NOTHING;
