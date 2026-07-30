import { test, expect } from "@playwright/test";
import { waitForLiveView } from "../support/live-view";

/**
 * When the socket drops, the user must be told — a LiveView page with a dead
 * socket looks identical to a working one, so buttons silently do nothing.
 *
 * The banner lives in `<.flash_group>`, which all three layouts render. Note
 * `context.setOffline(true)` alone is not enough to assert on: the websocket
 * stays open until it next tries to send, so detection waits on LiveView's
 * heartbeat. These specs close the socket explicitly so the assertion is about
 * the banner wiring rather than heartbeat timing.
 *
 * NOT covered here: the full-page auth screens mount with `layout: false`, so
 * they have no layout to inherit the banner from and stay silent on a dropped
 * socket. Recorded as a known gap rather than asserted.
 */

async function dropSocket(page: import("@playwright/test").Page) {
  await page.evaluate(() => (window as any).liveSocket?.disconnect());
}

async function restoreSocket(page: import("@playwright/test").Page) {
  await page.evaluate(() => (window as any).liveSocket?.connect());
}

test.describe("Dropped socket", () => {
  test("the storefront tells the shopper the connection is gone", async ({ page }) => {
    await page.goto("/s/kente-kingdom/products/handwoven-kente-clutch-bag");
    await waitForLiveView(page);
    await expect(page.locator("#client-error")).toBeHidden();

    await dropSocket(page);
    await expect(page.locator("#client-error")).toBeVisible({ timeout: 20_000 });

    await restoreSocket(page);
    await expect(page.locator("#client-error")).toBeHidden({ timeout: 20_000 });
  });

  test("the cart page tells the shopper too", async ({ page }) => {
    await page.goto("/s/kente-kingdom/cart");
    await waitForLiveView(page);
    await expect(page.locator("#client-error")).toBeHidden();

    await dropSocket(page);
    await expect(page.locator("#client-error")).toBeVisible({ timeout: 20_000 });

    await restoreSocket(page);
    await expect(page.locator("#client-error")).toBeHidden({ timeout: 20_000 });
  });
});
