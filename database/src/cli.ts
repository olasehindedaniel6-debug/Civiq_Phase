import pg from "pg";
import { migrate, seed } from "./migrate.js";

const url = process.env.DATABASE_URL;
if (!url) {
  console.error("DATABASE_URL is not set (copy .env.example to .env and export it).");
  process.exit(1);
}
const cmd = process.argv[2];
const pool = new pg.Pool({ connectionString: url });

try {
  if (cmd === "migrate") console.log("Applied:", await migrate(pool));
  else if (cmd === "seed") console.log("Seeded:", await seed(pool));
  else {
    console.error("Usage: cli.ts migrate | seed");
    process.exitCode = 1;
  }
} finally {
  await pool.end();
}
