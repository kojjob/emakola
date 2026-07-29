import { test, expect, Page } from "@playwright/test";

/**
 * Guards against JavaScript that silently dies in the browser.
 *
 * The merchant sidebar-collapse button shipped broken for a long time: its
 * handler was an un-nonced inline <script> plus an `onclick="…"` attribute,
 * both blocked by the app's `script-src 'self' 'nonce-…'` policy. Nothing
 * server-side could catch it — the page rendered fine, the button just did
 * nothing. These specs fail on any console error, CSP violations included.
 */

import { MERCHANT_STORAGE_STATE } from "../support/auth-state";

/** Console noise that is environmental rather than a real defect. */
const IGNORED = [
  /apple-mobile-web-app-capable/i, // deprecation notice from the PWA meta tag
  /live_reload/i, // dev-only server log mirroring
  /Download the .* DevTools/i,
];

function collectErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on("console", msg => {
    if (msg.type() !== "error") return;
    const text = msg.text();
    if (IGNORED.some(re => re.test(text))) return;
    errors.push(text);
  });
  page.on("pageerror", err => errors.push(String(err)));
  return errors;
}

test.describe("Console health — public pages", () => {
  for (const path of ["/", "/stores", "/auth/login", "/s/kente-kingdom"]) {
    test(`public page ${path} loads with no console errors`, async ({ page }) => {
      const errors = collectErrors(page);
      await page.goto(path);
      await page.waitForLoadState("networkidle");
      expect(errors, `console errors on ${path}`).toEqual([]);
    });
  }
});

test.describe("Console health — merchant admin", () => {
  test.use({ storageState: MERCHANT_STORAGE_STATE });

  test("merchant dashboard loads with no console errors (CSP regression)", async ({ page }) => {
    const errors = collectErrors(page);
    await page.goto("/dashboard");
    await page.waitForLoadState("networkidle");
    expect(errors, "console errors on /dashboard").toEqual([]);
  });
});

test.describe("Admin sidebar collapse", () => {
  test.use({ storageState: MERCHANT_STORAGE_STATE });

  test("toggle collapses, persists, and restores across navigation", async ({ page }) => {
    await page.goto("/dashboard");
    await page.waitForLoadState("networkidle");

    const shell = page.locator("#admin-shell");
    const toggle = page.locator("[data-toggle-sidebar]");

    // Desktop-only control; skip where it isn't rendered.
    if (!(await toggle.isVisible().catch(() => false))) {
      test.skip(true, "collapse toggle is desktop-only");
    }

    await expect(shell).not.toHaveClass(/collapsed/);

    await toggle.click();
    await expect(shell).toHaveClass(/collapsed/);
    expect(await page.evaluate(() => localStorage.getItem("sidebar-collapsed"))).toBe("true");

    // Persisted state survives a full page load.
    await page.goto("/admin/products");
    await page.waitForLoadState("networkidle");
    await expect(page.locator("#admin-shell")).toHaveClass(/collapsed/);

    await page.locator("[data-toggle-sidebar]").click();
    await expect(page.locator("#admin-shell")).not.toHaveClass(/collapsed/);
  });
});
