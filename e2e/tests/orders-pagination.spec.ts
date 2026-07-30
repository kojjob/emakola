import { test, expect, Page } from "@playwright/test";
import { MERCHANT_STORAGE_STATE } from "../support/auth-state";
import { waitForLiveView } from "../support/live-view";

/**
 * The orders list is a WINDOW, not the whole table.
 *
 * It used to cap at 50 with no pagination, no "load more", and no notice —
 * so a merchant with 63 orders silently could not reach 13 of them, and
 * nothing on the page suggested they existed. Orders are the money record,
 * so unreachable rows are worse here than in most lists.
 */

const LOAD_MORE = "#load-more-orders";

test.use({ storageState: MERCHANT_STORAGE_STATE });

async function orderCount(page: Page): Promise<number> {
  const text = await page.locator("body").innerText();
  return new Set(text.match(/ORD-\d{8}-[A-Z0-9]+/g) ?? []).size;
}

test.describe("Orders list windowing", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/admin/orders");
    await waitForLiveView(page);
  });

  test("load more reveals the orders beyond the first window", async ({ page }) => {
    const initial = await orderCount(page);

    if (!(await page.locator(LOAD_MORE).isVisible().catch(() => false))) {
      test.skip(true, `store has only ${initial} orders — nothing beyond the window`);
    }

    // The window is capped, so the first page must not show everything.
    await expect(page.getByText(/Showing the \d+ most recent orders/)).toBeVisible();

    await page.locator(LOAD_MORE).click();

    await expect
      .poll(async () => await orderCount(page), { timeout: 15_000 })
      .toBeGreaterThan(initial);

    // Once the list is exhausted the control must disappear rather than
    // sit there loading nothing.
    await expect(page.locator(LOAD_MORE)).toBeHidden({ timeout: 15_000 });
  });

  test("changing the status filter resets the window", async ({ page }) => {
    if (!(await page.locator(LOAD_MORE).isVisible().catch(() => false))) {
      test.skip(true, "store has no orders beyond the first window");
    }

    await page.locator(LOAD_MORE).click();
    await expect(page.locator(LOAD_MORE)).toBeHidden({ timeout: 15_000 });

    // Filtering must re-window: keeping an expanded limit across a filter
    // change would quietly show a different number of rows per filter.
    await page.getByRole("button", { name: "Pending", exact: true }).first().click();

    // Poll: waitForLiveView returns immediately when the socket is already
    // connected, so it does not wait for the filtered re-render to land.
    await expect
      .poll(async () => await orderCount(page), { timeout: 15_000 })
      .toBeLessThanOrEqual(50);
  });
});
