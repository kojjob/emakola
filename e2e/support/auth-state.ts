import path from "node:path";

/**
 * Shared auth constants. Lives outside `tests/` because Playwright forbids
 * one test file importing another.
 */

/** Session saved by the `setup` project and reused by authenticated specs. */
export const MERCHANT_STORAGE_STATE = path.join(__dirname, "../.auth/merchant.json");

export const MERCHANT = {
  email: "kwame@kentekingdom.com",
  password: "Password123!",
};
