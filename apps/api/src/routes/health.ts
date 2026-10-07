import type { FastifyInstance } from "fastify";

export async function healthRoutes(app: FastifyInstance) {
  app.get("/v1/health", async () => ({
    status: "ok",
    service: "civiq-api",
    time: new Date().toISOString(),
  }));
}
