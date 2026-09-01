import { test, expect } from "@playwright/test";
import { MERCHANT_STORAGE_STATE } from "../support/auth-state";
import { waitForLiveView } from "../support/live-view";

test.use({ storageState: MERCHANT_STORAGE_STATE });

/**
 * The Partners hub on a phone — where merchants actually open it. Nothing
 * may overflow sideways, the doors must be tappable, and a door must land
 * on its own page. Screenshots land in test-results for a human look.
 */
test.describe("Partners hub on a phone", () => {
  test("fits the viewport and every door opens its page", async ({ page }, testInfo) => {
    await page.goto("/admin/settings/supply-network");
    await waitForLiveView(page);

    await expect(page.locator("#partners-stats")).toBeVisible();
    await expect(page.locator("#first-money-journey")).toBeVisible();

    // No horizontal scroll: the page must be no wider than the window.
    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth
    );
    expect(overflow, "page wider than the viewport").toBeLessThanOrEqual(0);

    await page.screenshot({
      path: testInfo.outputPath("partners-hub.png"),
      fullPage: true,
    });

    const door = page.locator("#earn-tool-content-studio");
    await door.scrollIntoViewIfNeeded();
    const box = await door.boundingBox();
    expect(box?.height ?? 0, "door tap target").toBeGreaterThanOrEqual(44);

    await door.click();
    await page.waitForURL("**/supply-network/tools/content-studio");
    await waitForLiveView(page);
    await expect(page.locator("#earn-content-studio")).toBeVisible();
    // Scoped: the sidebar carries a "Partners" nav link too.
    await expect(
      page.locator("#supply-tool-content_studio").getByRole("link", { name: "Partners" })
    ).toBeVisible();

    await page.screenshot({
      path: testInfo.outputPath("content-studio.png"),
      fullPage: true,
    });
  });
});
