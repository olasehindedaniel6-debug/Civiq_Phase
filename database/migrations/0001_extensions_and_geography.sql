-- 0001: extensions, generic geographic hierarchy (areas)
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS ltree;

-- One generic hierarchy for every country. "level"/"type" are data, not schema:
-- level 0 may be a continent, 1 a country, 2 a state/region, 3 a city, etc.
CREATE TABLE areas (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id   uuid REFERENCES areas(id) ON DELETE RESTRICT,
  level       integer NOT NULL,
  type        text NOT NULL,                       -- e.g. 'continent','country','state','city','district'
  name        text NOT NULL,
  slug        text NOT NULL CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  code        text,                                -- e.g. ISO code, optional
  path        ltree NOT NULL,                      -- maintained by trigger
  boundary    geometry(MultiPolygon, 4326),        -- NULL until real boundary data is imported
  centroid    geography(Point, 4326),
  source      text,                                -- where the boundary/name data came from
  provenance  text NOT NULL DEFAULT 'public_data'
              CHECK (provenance IN ('user_submitted','public_data','ai_generated','rule_derived','demo','synthetic')),
  active      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (parent_id, slug)
);
CREATE UNIQUE INDEX areas_root_slug_uniq ON areas (slug) WHERE parent_id IS NULL;
CREATE INDEX areas_parent_idx   ON areas (parent_id);
CREATE INDEX areas_path_gist    ON areas USING gist (path);
CREATE INDEX areas_boundary_gix ON areas USING gist (boundary);

-- Keep level and path consistent automatically.
CREATE FUNCTION areas_set_path() RETURNS trigger AS $$
DECLARE
  parent_path ltree;
  parent_level integer;
  label text := replace(NEW.slug, '-', '_');
BEGIN
  IF NEW.parent_id IS NULL THEN
    NEW.level := 0;
    NEW.path := text2ltree(label);
  ELSE
    SELECT path, level INTO parent_path, parent_level FROM areas WHERE id = NEW.parent_id;
    NEW.level := parent_level + 1;
    NEW.path := parent_path || text2ltree(label);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER areas_set_path_trg BEFORE INSERT ON areas
  FOR EACH ROW EXECUTE FUNCTION areas_set_path();

-- Most specific area (deepest level) whose boundary contains the point.
-- Returns NULL if no imported boundary covers it (honest: we don't guess).
CREATE FUNCTION area_for_point(pt geography) RETURNS uuid AS $$
  SELECT id FROM areas
  WHERE active AND boundary IS NOT NULL
    AND ST_Contains(boundary, pt::geometry)
  ORDER BY level DESC
  LIMIT 1;
$$ LANGUAGE sql STABLE;
