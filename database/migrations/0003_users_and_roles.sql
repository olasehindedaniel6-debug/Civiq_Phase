-- 0003: users, organizations, area-scoped role assignments
-- Privacy: collect only what is needed. No phone, no real name required.
CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         text,
  display_name  text,
  password_hash text,               -- NULL when using external/social login
  status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','deleted')),
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX users_email_uniq ON users (lower(email)) WHERE email IS NOT NULL;

CREATE TABLE organizations (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL,
  type       text NOT NULL DEFAULT 'agency',   -- agency, ngo, research, media...
  area_id    uuid REFERENCES areas(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- A role is always "role OF an area". Owner is the only global role (area_id NULL).
CREATE TABLE role_assignments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role            text NOT NULL CHECK (role IN
                    ('owner','super_admin','admin','moderator','analyst','agency_user','citizen')),
  area_id         uuid REFERENCES areas(id),
  organization_id uuid REFERENCES organizations(id),
  granted_by      uuid REFERENCES users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  revoked_at      timestamptz,
  CHECK ((role = 'owner' AND area_id IS NULL) OR (role <> 'owner' AND area_id IS NOT NULL))
);
CREATE INDEX role_assignments_user_idx ON role_assignments (user_id) WHERE revoked_at IS NULL;

-- Does the user hold one of the roles on the target area, or on any ANCESTOR of it?
-- (A role on Oyo State applies to Ibadan; a role on Nigeria applies to everything in Nigeria.)
CREATE FUNCTION user_has_role_in_area(p_user uuid, p_area uuid, p_roles text[]) RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1
    FROM role_assignments ra
    LEFT JOIN areas granted ON granted.id = ra.area_id
    JOIN areas target ON target.id = p_area
    WHERE ra.user_id = p_user
      AND ra.revoked_at IS NULL
      AND ra.role = ANY (p_roles)
      AND (ra.role = 'owner' OR granted.path @> target.path)
  );
$$ LANGUAGE sql STABLE;
