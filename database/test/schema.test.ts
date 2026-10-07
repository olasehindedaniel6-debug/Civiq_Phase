import { describe, it, expect, beforeAll, afterAll } from "vitest";
import pg from "pg";
import { randomBytes } from "node:crypto";
import { migrate, seed } from "../src/migrate.js";

const adminUrl = process.env.DATABASE_URL;

// Runs only when a database is available. Uses a throwaway database, never your dev data.
describe.skipIf(!adminUrl)("database schema", () => {
  const dbName = `civiq_test_${randomBytes(4).toString("hex")}`;
  let admin: pg.Pool;
  let pool: pg.Pool;

  const q = (text: string, params: unknown[] = []) => pool.query(text, params);
  const one = async (text: string, params: unknown[] = []) => (await q(text, params)).rows[0];
  const area = async (slug: string) => (await one("SELECT id FROM areas WHERE slug=$1", [slug])).id as string;
  const state = async (slug: string) => (await one("SELECT id FROM workflow_states WHERE slug=$1", [slug])).id as string;
  const cat = async (slug: string) => (await one("SELECT id FROM categories WHERE slug=$1", [slug])).id as string;
  const user = async (name: string) =>
    (await one("INSERT INTO users (display_name) VALUES ($1) RETURNING id", [name])).id as string;

  beforeAll(async () => {
    admin = new pg.Pool({ connectionString: adminUrl });
    admin.on("error", () => {});
    await admin.query(`CREATE DATABASE ${dbName}`);
    const u = new URL(adminUrl!);
    u.pathname = `/${dbName}`;
    pool = new pg.Pool({ connectionString: u.toString() });
    // Dropping the test DB can close idle connections; that is expected, not a failure.
    pool.on("error", () => {});
    await migrate(pool);
    await seed(pool);
  });

  afterAll(async () => {
    await pool?.end();
    await admin?.query(`DROP DATABASE IF EXISTS ${dbName} WITH (FORCE)`);
    await admin?.end();
  });

  it("migrations are idempotent and seeds are re-runnable", async () => {
    expect(await migrate(pool)).toEqual([]);
    await seed(pool);
    expect((await one("SELECT count(*)::int AS n FROM areas")).n).toBe(4);
  });

  it("builds the geographic hierarchy automatically", async () => {
    const r = await one("SELECT level, path::text AS path FROM areas WHERE slug='ibadan'");
    expect(r.level).toBe(3);
    expect(r.path).toBe("africa.nigeria.oyo.ibadan");
  });

  it("supports a new state without any schema change", async () => {
    await q(`INSERT INTO areas (parent_id, type, name, slug, provenance)
             VALUES ($1,'state','Test State','test-state','synthetic')`, [await area("nigeria")]);
    expect((await one("SELECT path::text AS p FROM areas WHERE slug='test-state'")).p).toBe("africa.nigeria.test_state");
  });

  describe("scoped roles", () => {
    it("admin of Oyo governs Ibadan but not another state", async () => {
      const u = await user("oyo-admin");
      await q("INSERT INTO role_assignments (user_id, role, area_id) VALUES ($1,'admin',$2)", [u, await area("oyo")]);
      const has = async (slug: string) =>
        (await one("SELECT user_has_role_in_area($1,$2,ARRAY['admin']) AS ok", [u, await area(slug)])).ok;
      expect(await has("ibadan")).toBe(true);
      expect(await has("oyo")).toBe(true);
      expect(await has("test-state")).toBe(false);
      expect(await has("nigeria")).toBe(false); // roles never apply upward
    });

    it("super admin of Nigeria governs every state below", async () => {
      const u = await user("national");
      await q("INSERT INTO role_assignments (user_id, role, area_id) VALUES ($1,'super_admin',$2)", [u, await area("nigeria")]);
      for (const s of ["oyo", "ibadan", "test-state"]) {
        expect((await one("SELECT user_has_role_in_area($1,$2,ARRAY['super_admin']) AS ok", [u, await area(s)])).ok).toBe(true);
      }
    });

    it("owner is global; revoked roles stop working", async () => {
      const o = await user("owner");
      await q("INSERT INTO role_assignments (user_id, role) VALUES ($1,'owner')", [o]);
      expect((await one("SELECT user_has_role_in_area($1,$2,ARRAY['owner']) AS ok", [o, await area("ibadan")])).ok).toBe(true);

      const m = await user("mod");
      const ra = await one("INSERT INTO role_assignments (user_id, role, area_id) VALUES ($1,'moderator',$2) RETURNING id", [m, await area("ibadan")]);
      await q("UPDATE role_assignments SET revoked_at = now() WHERE id=$1", [ra.id]);
      expect((await one("SELECT user_has_role_in_area($1,$2,ARRAY['moderator']) AS ok", [m, await area("ibadan")])).ok).toBe(false);
    });

    it("rejects malformed assignments", async () => {
      const u = await user("bad");
      await expect(q("INSERT INTO role_assignments (user_id, role, area_id) VALUES ($1,'owner',$2)", [u, await area("oyo")])).rejects.toThrow();
      await expect(q("INSERT INTO role_assignments (user_id, role) VALUES ($1,'admin')", [u])).rejects.toThrow();
    });
  });

  describe("reports, incidents and workflow", () => {
    async function newIncident() {
      return (await one(
        `INSERT INTO incidents (category_id, status_id, provenance) VALUES ($1,$2,'synthetic') RETURNING id`,
        [await cat("pothole"), await state("reported")]
      )).id as string;
    }

    it("only allows transitions defined in workflow data", async () => {
      const id = await newIncident();
      await expect(q("INSERT INTO status_events (incident_id, to_state_id) VALUES ($1,$2)", [id, await state("closed")])).rejects.toThrow(/not allowed/);
      await q("INSERT INTO status_events (incident_id, to_state_id) VALUES ($1,$2)", [id, await state("processing")]);
      const inc = await one("SELECT s.slug FROM incidents i JOIN workflow_states s ON s.id=i.status_id WHERE i.id=$1", [id]);
      expect(inc.slug).toBe("processing");
      const ev = await one("SELECT from_state_id FROM status_events WHERE incident_id=$1", [id]);
      expect(ev.from_state_id).toBe(await state("reported"));
    });

    it("keeps report_count in sync", async () => {
      const id = await newIncident();
      for (let i = 0; i < 2; i++) {
        await q(`INSERT INTO reports (category_id, location, incident_id, provenance)
                 VALUES ($1, ST_GeogFromText('POINT(3.9 7.4)'), $2, 'synthetic')`, [await cat("pothole"), id]);
      }
      expect((await one("SELECT report_count FROM incidents WHERE id=$1", [id])).report_count).toBe(2);
    });

    it("finds nearby reports with a spatial query (duplicate hints)", async () => {
      await q(`INSERT INTO reports (category_id, location, provenance) VALUES
        ($1, ST_GeogFromText('POINT(10.0000 5.0000)'), 'synthetic'),
        ($1, ST_GeogFromText('POINT(10.0004 5.0000)'), 'synthetic'),
        ($1, ST_GeogFromText('POINT(10.0200 5.0000)'), 'synthetic')`, [await cat("flooding")]);
      const near = await q(`SELECT count(*)::int AS n FROM reports
        WHERE ST_DWithin(location, ST_GeogFromText('POINT(10.0000 5.0000)'), 100) AND provenance='synthetic'
          AND category_id=$1`, [await cat("flooding")]);
      expect(near.rows[0].n).toBe(2); // ~44 m away counts; ~2 km away does not
    });

    it("rejects invalid values", async () => {
      await expect(q("INSERT INTO incidents (category_id,status_id,severity) VALUES ($1,$2,6)", [await cat("pothole"), await state("reported")])).rejects.toThrow();
      await expect(q("INSERT INTO reports (category_id,location,provenance) VALUES ($1, ST_GeogFromText('POINT(3 7)'),'made_up')", [await cat("pothole")])).rejects.toThrow();
    });
  });

  it("area_for_point picks the deepest area with an imported boundary, and never guesses", async () => {
    const parent = await area("nigeria");
    await q(`INSERT INTO areas (parent_id,type,name,slug,provenance,boundary) VALUES
      ($1,'state','Boxland','boxland','synthetic', ST_Multi(ST_GeomFromText('POLYGON((20 20,20 30,30 30,30 20,20 20))',4326)))`, [parent]);
    const boxId = await area("boxland");
    await q(`INSERT INTO areas (parent_id,type,name,slug,provenance,boundary) VALUES
      ($1,'city','Smallbox','smallbox','synthetic', ST_Multi(ST_GeomFromText('POLYGON((24 24,24 26,26 26,26 24,24 24))',4326)))`, [boxId]);
    const inside = await one("SELECT area_for_point(ST_GeogFromText('POINT(25 25)')) AS id");
    expect(inside.id).toBe(await area("smallbox"));
    const outsideSmall = await one("SELECT area_for_point(ST_GeogFromText('POINT(21 21)')) AS id");
    expect(outsideSmall.id).toBe(boxId);
    const nowhere = await one("SELECT area_for_point(ST_GeogFromText('POINT(-50 -50)')) AS id");
    expect(nowhere.id).toBeNull();
  });
});
