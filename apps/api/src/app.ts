import Fastify from "fastify";
import { healthRoutes } from "./routes/health.js";

export function buildApp() {
  const app = Fastify({
    logger: process.env.NODE_ENV !== "test",
    bodyLimit: 1_000_000, // 1 MB default; uploads get their own limits later
  });

  app.register(healthRoutes);
  return app;
}
