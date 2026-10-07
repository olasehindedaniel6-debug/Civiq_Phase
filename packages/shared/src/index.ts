import { z } from "zod";

/**
 * Where a piece of data came from. Every record carries one of these so that
 * demo/synthetic data can never be mistaken for real data.
 */
export const Provenance = z.enum([
  "user_submitted",
  "public_data",
  "ai_generated",
  "rule_derived",
  "demo",
  "synthetic",
]);
export type Provenance = z.infer<typeof Provenance>;

/** Verification is a separate dimension from workflow status. */
export const VerificationState = z.enum([
  "unverified",
  "verified",
  "disputed",
  "duplicate",
  "invalid",
]);
export type VerificationState = z.infer<typeof VerificationState>;

/** Scoped role names. Roles are always granted for a specific area (or globally for owner). */
export const RoleName = z.enum([
  "owner",
  "super_admin",
  "admin",
  "moderator",
  "analyst",
  "agency_user",
  "citizen",
]);
export type RoleName = z.infer<typeof RoleName>;
