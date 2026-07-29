import { test as setup, expect } from "@playwright/test";
import { MERCHANT, MERCHANT_STORAGE_STATE } from "../support/auth-state";
import { waitForLiveView } from "../support/live-view";

/**
 * Authenticate once and persist the session for reuse.
 *
 * LoginLive enforces its own 10-logins-per-minute-per-IP limit via
 * `Emakola.RateLimit.check_rate/3`. That limiter is deliberately NOT covered
 * by `config :emakola, :disable_rate_limit` (ExUnit tests assert on it), and
 * every Playwright request originates from 127.0.0.1 — so a suite that logs
 * in per-spec throttles itself and fails intermittently.
 *
 * Specs that merely need to *be* authenticated opt in with:
 *   test.use({ storageState: MERCHANT_STORAGE_STATE })
 *
 * Specs that exercise login/logout themselves must keep signing in for real.
 */
setup("authenticate as merchant", async ({ page }) => {
  await page.goto("/auth/login");
  await waitForLiveView(page);

  await page.locator("input[name='user[email]']").fill(MERCHANT.email);
  await page.locator("input[name='user[password]']").fill(MERCHANT.password);
  await page.getByRole("button", { name: "Sign In" }).click();

  await page.waitForURL("**/dashboard", { timeout: 30_000 });
  await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();

  await page.context().storageState({ path: MERCHANT_STORAGE_STATE });
});
