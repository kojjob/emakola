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

test.describe("Platform sidebar collapse", () => {
  test("has no CSP errors and persists across a full page load", async ({ browser, browserName }) => {
    test.skip(browserName !== "chromium", "one desktop browser covers the bundled CSP behaviour");

    const storageState = process.env.PLATFORM_STORAGE_STATE;
    test.skip(
      !storageState,
      "Set PLATFORM_STORAGE_STATE to an authenticated platform-owner Playwright state file",
    );

    const context = await browser.newContext({
      storageState,
      viewport: { width: 1280, height: 800 },
    });
    const page = await context.newPage();
    const errors = collectErrors(page);

    try {
      await page.goto("/platform");
      await page.waitForLoadState("networkidle");

      await page.evaluate(() => localStorage.removeItem("platform-sidebar-collapsed"));
      await page.reload();
      await page.waitForLoadState("networkidle");

      const shell = page.locator("#platform-shell");
      const toggle = page.locator("[data-toggle-platform-sidebar]");

      await expect(toggle).toBeVisible();
      await expect(toggle).toHaveAttribute("aria-expanded", "true");
      await expect(shell).not.toHaveClass(/collapsed/);

      await toggle.click();
      await expect(shell).toHaveClass(/collapsed/);
      await expect(toggle).toHaveAttribute("aria-expanded", "false");
      expect(
        await page.evaluate(() => localStorage.getItem("platform-sidebar-collapsed")),
      ).toBe("true");

      await page.reload();
      await page.waitForLoadState("networkidle");
      await expect(page.locator("#platform-shell")).toHaveClass(/collapsed/);
      expect(errors, "console/CSP errors on /platform").toEqual([]);
    } finally {
      await context.close();
    }
  });
});
