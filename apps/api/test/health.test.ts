import { describe, it, expect } from "vitest";
import { buildApp } from "../src/app.js";
import { loadConfig } from "../src/config.js";

describe("health endpoint", () => {
  it("returns ok", async () => {
    const app = buildApp();
    const res = await app.inject({ method: "GET", url: "/v1/health" });
    expect(res.statusCode).toBe(200);
    expect(res.json().status).toBe("ok");
    await app.close();
  });
});

describe("config", () => {
  it("applies defaults", () => {
    expect(loadConfig({} as NodeJS.ProcessEnv).PORT).toBe(4000);
  });
  it("rejects invalid port", () => {
    expect(() => loadConfig({ PORT: "abc" } as unknown as NodeJS.ProcessEnv)).toThrow();
  });
});
