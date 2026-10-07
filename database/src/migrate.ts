import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { Pool } from "pg";

const here = path.dirname(fileURLToPath(import.meta.url));
export const MIGRATIONS_DIR = path.resolve(here, "../migrations");
export const SEEDS_DIR = path.resolve(here, "../seeds");

async function sqlFiles(dir: string): Promise<string[]> {
  return (await readdir(dir)).filter((f) => f.endsWith(".sql")).sort();
}

/** Apply pending migrations in order, each in its own transaction. Returns names applied. */
export async function migrate(pool: Pool, dir = MIGRATIONS_DIR): Promise<string[]> {
  await pool.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
    name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())`);
  const done = new Set((await pool.query("SELECT name FROM schema_migrations")).rows.map((r) => r.name));
  const applied: string[] = [];
  for (const file of await sqlFiles(dir)) {
    if (done.has(file)) continue;
    const sql = await readFile(path.join(dir, file), "utf8");
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(sql);
      await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [file]);
      await client.query("COMMIT");
      applied.push(file);
    } catch (err) {
      await client.query("ROLLBACK");
      throw new Error(`Migration ${file} failed: ${(err as Error).message}`);
    } finally {
      client.release();
    }
  }
  return applied;
}

/** Seeds are idempotent (ON CONFLICT DO NOTHING), so they are safe to re-run. */
export async function seed(pool: Pool, dir = SEEDS_DIR): Promise<string[]> {
  const ran: string[] = [];
  for (const file of await sqlFiles(dir)) {
    await pool.query(await readFile(path.join(dir, file), "utf8"));
    ran.push(file);
  }
  return ran;
}
