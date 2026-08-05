import { test, expect, Page } from "@playwright/test";
import { MERCHANT_STORAGE_STATE } from "../support/auth-state";
import { waitForLiveView } from "../support/live-view";

/**
 * Merchant admin journeys: logout, live search, empty state, and the
 * real-time dashboard contract.
 */

const MERCHANT = { email: "kwame@kentekingdom.com", password: "Password123!" };
const STORE = "/s/kente-kingdom";

async function loginAsMerchant(page: Page) {
  await page.goto("/auth/login");
  await waitForLiveView(page);
  await page.locator("input[name='user[email]']").fill(MERCHANT.email);
  await page.locator("input[name='user[password]']").fill(MERCHANT.password);
  await page.getByRole("button", { name: "Sign In" }).click();
  await page.waitForURL("**/dashboard", { timeout: 20_000 });
}

test.describe("Merchant session", () => {
  test("sign out ends the session and protected pages bounce to login", async ({ page }) => {
    await loginAsMerchant(page);

    // Sign out lives inside the topbar user dropdown, so open that first.
    await page.locator("#user-dropdown button").first().click();

    // Rendered as <a href="/auth/session" data-method="delete">, which needs
    // the phoenix_html shim to issue a DELETE — a plain GET on that path is
    // the session *create* route, so a broken shim would silently not log out.
    const signOut = page.locator("#user-panel a[href='/auth/session']").first();
    await signOut.scrollIntoViewIfNeeded();
    await signOut.click();
    await page.waitForURL(url => !url.pathname.startsWith("/dashboard"), { timeout: 20_000 });

    await page.goto("/dashboard");
    await expect(page).toHaveURL(/\/auth\/login/, { timeout: 10_000 });
  });
});

test.describe("Admin product search", () => {
  test.use({ storageState: MERCHANT_STORAGE_STATE });

  test.beforeEach(async ({ page }) => {
    await page.goto("/admin/products");
    await waitForLiveView(page);
  });

  test("live search narrows the list without a page reload", async ({ page }) => {
    const search = page.locator("input[name='search']");
    await expect(page.getByText("Royal Adweneasa Kente Cloth").filter({ visible: true })).toHaveCount(
      1
    );

    await search.fill("Clutch");

    await expect(
      page.getByText("Handwoven Kente Clutch Bag").filter({ visible: true }).first()
    ).toBeVisible({ timeout: 10_000 });
    await expect(
      page.getByText("Royal Adweneasa Kente Cloth").filter({ visible: true })
    ).toHaveCount(0);

    // phx-change only — the URL must not change and the page must not reload.
    await expect(page).toHaveURL(/\/admin\/products$/);
  });

  test("a search with no matches shows an empty state, not a blank page", async ({ page }) => {
    await page.locator("input[name='search']").fill("zzzz-no-such-product-zzzz");

    await expect(
      page.getByText("Handwoven Kente Clutch Bag").filter({ visible: true })
    ).toHaveCount(0, { timeout: 10_000 });

    // Something must tell the merchant why the list is empty.
    await expect(page.getByRole("main")).toContainText(/no products|nothing|not found|no results/i);
  });
});

test.describe("Dashboard real-time updates", () => {
  test("a shopper's order appears on the merchant dashboard without a reload", async ({
    browser,
  }) => {
    // Two independent contexts: merchant watching the dashboard, shopper buying.
    // baseURL is passed explicitly — manually created contexts don't inherit
    // it from the project's `use` block.
    const baseURL = process.env.BASE_URL ?? "http://localhost:4000";
    const merchantCtx = await browser.newContext({
      baseURL,
      storageState: MERCHANT_STORAGE_STATE,
    });
    const shopperCtx = await browser.newContext({ baseURL });

    try {
      const merchantPage = await merchantCtx.newPage();
      await merchantPage.goto("/dashboard");
      await merchantPage.waitForLoadState("networkidle");

      const orderPattern = /ORD-\d{8}-[A-Z0-9]+/g;
      const before = new Set((await merchantPage.locator("body").innerText()).match(orderPattern) ?? []);

      const shopperPage = await shopperCtx.newPage();
      await shopperPage.goto(`${STORE}/products/handwoven-kente-clutch-bag`);
      await shopperPage.waitForLoadState("networkidle");
      await shopperPage.getByRole("button", { name: "Add to Bag" }).click();
      await expect(shopperPage.locator("#flash-info")).toContainText("Added to cart", {
        timeout: 10_000,
      });

      await shopperPage.goto(`${STORE}/checkout`);
      await shopperPage.waitForLoadState("networkidle");
      await shopperPage.locator("#phone").fill("0244555222");
      await shopperPage.locator("#fullname").fill("QA Realtime Shopper");
      await shopperPage.locator("#address").fill("77 PubSub Avenue, Osu");
      await shopperPage.getByRole("button", { name: /Place Order/i }).click();

      // Payment fails on placeholder gateway keys, but the order is created and
      // Dispatcher broadcasts :order_placed — which is what the dashboard needs.
      // Like error-messages.spec, this waits out a real api.paystack.co call;
      // a tarpitted runner only flashes after ~30s connect + 10s receive_timeout.
      await expect(shopperPage.locator("[role=alert]").first()).toContainText(
        /ORD-\d{8}-[A-Z0-9]+/,
        { timeout: 45_000 }
      );

      // The merchant page is never reloaded — this only passes via PubSub.
      await expect
        .poll(
          async () => {
            const now = (await merchantPage.locator("body").innerText()).match(orderPattern) ?? [];
            return now.some(n => !before.has(n));
          },
          { timeout: 20_000, message: "dashboard never received the new order over PubSub" }
        )
        .toBe(true);
    } finally {
      await merchantCtx.close();
      await shopperCtx.close();
    }
  });
});
