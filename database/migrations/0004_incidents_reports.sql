-- 0004: incidents, reports, evidence, analyses, history, audit
CREATE TABLE incidents (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id        uuid NOT NULL REFERENCES categories(id),
  centroid           geography(Point, 4326),
  area_id            uuid REFERENCES areas(id),
  status_id          uuid NOT NULL REFERENCES workflow_states(id),
  verification_state text NOT NULL DEFAULT 'unverified'
                     CHECK (verification_state IN ('unverified','verified','disputed','duplicate','invalid')),
  severity           smallint CHECK (severity BETWEEN 1 AND 5),
  confidence         numeric(3,2) CHECK (confidence BETWEEN 0 AND 1),
  first_reported_at  timestamptz NOT NULL DEFAULT now(),
  report_count       integer NOT NULL DEFAULT 0,
  provenance         text NOT NULL DEFAULT 'user_submitted'
                     CHECK (provenance IN ('user_submitted','public_data','ai_generated','rule_derived','demo','synthetic')),
  attributes         jsonb NOT NULL DEFAULT '{}'::jsonb,
  schema_version     integer NOT NULL DEFAULT 1,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX incidents_centroid_gix ON incidents USING gist (centroid);
CREATE INDEX incidents_area_idx     ON incidents (area_id, category_id, status_id);
CREATE INDEX incidents_time_idx     ON incidents (first_reported_at DESC);

-- A report is one immutable citizen observation. It may later be linked to an incident.
CREATE TABLE reports (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id         uuid REFERENCES users(id) ON DELETE SET NULL,   -- NULL = anonymous
  category_id         uuid NOT NULL REFERENCES categories(id),
  description         text CHECK (char_length(description) <= 5000),
  location            geography(Point, 4326) NOT NULL,
  location_accuracy_m numeric,
  area_id             uuid REFERENCES areas(id),
  incident_id         uuid REFERENCES incidents(id),
  observed_at         timestamptz,
  submitted_at        timestamptz NOT NULL DEFAULT now(),
  idempotency_key     text,
  provenance          text NOT NULL DEFAULT 'user_submitted'
                      CHECK (provenance IN ('user_submitted','public_data','ai_generated','rule_derived','demo','synthetic')),
  attributes          jsonb NOT NULL DEFAULT '{}'::jsonb,
  schema_version      integer NOT NULL DEFAULT 1,
  deleted_at          timestamptz
);
CREATE INDEX reports_location_gix ON reports USING gist (location);
CREATE INDEX reports_area_idx     ON reports (area_id, category_id, submitted_at DESC);
CREATE INDEX reports_incident_idx ON reports (incident_id);
CREATE UNIQUE INDEX reports_idem_uniq ON reports (reporter_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL AND reporter_id IS NOT NULL;

CREATE TABLE media_assets (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id        uuid NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  storage_key      text NOT NULL UNIQUE,
  mime             text NOT NULL CHECK (mime IN ('image/jpeg','image/png','image/webp')),
  bytes            bigint NOT NULL CHECK (bytes > 0),
  sha256           text NOT NULL,
  exif_stripped    boolean NOT NULL DEFAULT false,
  moderation_state text NOT NULL DEFAULT 'pending' CHECK (moderation_state IN ('pending','approved','rejected')),
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX media_report_idx ON media_assets (report_id);

-- Every AI/rule output is stored with its source, version and confidence.
CREATE TABLE analyses (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_type  text NOT NULL CHECK (subject_type IN ('report','incident','media_asset')),
  subject_id    uuid NOT NULL,
  kind          text NOT NULL,        -- 'category_suggestion','duplicate_hint','severity',...
  provider      text NOT NULL,        -- 'rules','local','api-name'
  model         text,
  model_version text,
  output        jsonb NOT NULL,
  confidence    numeric(3,2) CHECK (confidence BETWEEN 0 AND 1),
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX analyses_subject_idx ON analyses (subject_type, subject_id, kind);

CREATE TABLE status_events (
  id            bigserial PRIMARY KEY,
  incident_id   uuid NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  from_state_id uuid REFERENCES workflow_states(id),
  to_state_id   uuid NOT NULL REFERENCES workflow_states(id),
  actor_id      uuid REFERENCES users(id),
  note          text,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX status_events_incident_idx ON status_events (incident_id, created_at);

-- Enforce the data-driven workflow: only allowed transitions, and keep incident in sync.
CREATE FUNCTION status_event_apply() RETURNS trigger AS $$
DECLARE current_state uuid;
BEGIN
  SELECT status_id INTO current_state FROM incidents WHERE id = NEW.incident_id FOR UPDATE;
  IF NOT EXISTS (SELECT 1 FROM workflow_transitions
                 WHERE from_state_id = current_state AND to_state_id = NEW.to_state_id) THEN
    RAISE EXCEPTION 'Transition not allowed by workflow';
  END IF;
  NEW.from_state_id := current_state;
  UPDATE incidents SET status_id = NEW.to_state_id, updated_at = now() WHERE id = NEW.incident_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER status_event_apply_trg BEFORE INSERT ON status_events
  FOR EACH ROW EXECUTE FUNCTION status_event_apply();

-- Keep the cached report_count honest.
CREATE FUNCTION incident_report_count_sync() RETURNS trigger AS $$
BEGIN
  IF TG_OP IN ('UPDATE') AND OLD.incident_id IS NOT NULL AND OLD.incident_id IS DISTINCT FROM NEW.incident_id THEN
    UPDATE incidents SET report_count = report_count - 1 WHERE id = OLD.incident_id;
  END IF;
  IF NEW.incident_id IS NOT NULL AND (TG_OP = 'INSERT' OR OLD.incident_id IS DISTINCT FROM NEW.incident_id) THEN
    UPDATE incidents SET report_count = report_count + 1 WHERE id = NEW.incident_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER reports_count_trg AFTER INSERT OR UPDATE OF incident_id ON reports
  FOR EACH ROW EXECUTE FUNCTION incident_report_count_sync();

CREATE TABLE audit_log (
  id          bigserial PRIMARY KEY,
  actor_id    uuid REFERENCES users(id) ON DELETE SET NULL,
  action      text NOT NULL,
  target_type text,
  target_id   text,
  detail      jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_log_time_idx ON audit_log (created_at DESC);
