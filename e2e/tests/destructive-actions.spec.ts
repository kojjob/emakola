import { test, expect } from "@playwright/test";
import { MERCHANT_STORAGE_STATE } from "../support/auth-state";
import { waitForLiveView } from "../support/live-view";

/**
 * Confirmation modals must open on the FIRST click.
 *
 * The archive trigger fires `JS.push("open_archive") |> show_modal(...)`.
 * JS.show runs on the client immediately, while the push that selects the
 * product is a server round-trip — so a conditionally-rendered modal does not
 * exist yet when show runs. The first click silently did nothing and the
 * merchant had to click Archive twice, on a destructive control.
 *
 * These specs deliberately never double-click: a passing run means one click
 * is enough. They also cover re-opening after Cancel, which a naive
 * "render it already-shown" fix would break (the assign is unchanged, so the
 * element never re-mounts).
 */

// The #product-action-modal wrapper is `relative` with only `fixed` children,
// so it has a zero-size box and never satisfies toBeVisible. Assert on the
// container, which is what the user actually sees.
const MODAL = "#product-action-modal";
const MODAL_BOX = "#product-action-modal-container";

const PRODUCT = "Kente Bow Tie Set";

/**
 * The list renders twice — a `hidden md:block` desktop table and a mobile card
 * list — so a `tr` locator silently misses on mobile. Resolve whichever
 * variant is actually on screen at this viewport.
 */
function productBlock(page: import("@playwright/test").Page) {
  return page
    .locator("tr", { hasText: PRODUCT })
    // `.p-4` pins the mobile CARD; the desktop table wrapper is also
    // `bg-surface rounded-card` but has no padding class and holds every product.
    .or(page.locator("div.bg-surface.rounded-card.p-4", { hasText: PRODUCT }))
    .filter({ visible: true })
    .first();
}

test.use({ storageState: MERCHANT_STORAGE_STATE });

test.describe("Product archive confirmation", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/admin/products");
    await waitForLiveView(page);
  });

  test("the modal is always in the DOM but hidden at rest", async ({ page }) => {
    await expect(page.locator(MODAL)).toBeAttached();
    await expect(page.locator(MODAL_BOX)).toBeHidden();
  });

  test("one click opens the confirmation, naming the product", async ({ page }) => {
    const row = productBlock(page);
    await row.getByRole("button", { name: "Archive" }).click();

    await expect(page.locator(MODAL_BOX)).toBeVisible({ timeout: 10_000 });
    await expect(page.locator(MODAL_BOX)).toContainText("Archive Product");
    await expect(page.locator(MODAL_BOX)).toContainText(PRODUCT);
  });

  test("cancel closes it and it re-opens on the next single click", async ({ page }) => {
    const row = productBlock(page);

    await row.getByRole("button", { name: "Archive" }).click();
    await expect(page.locator(MODAL_BOX)).toBeVisible({ timeout: 10_000 });

    await page.locator(MODAL_BOX).getByRole("button", { name: "Cancel" }).click();
    await expect(page.locator(MODAL_BOX)).toBeHidden();

    // Same product again — @action_product is unchanged, so this only works
    // if the modal element is permanent rather than conditionally rendered.
    await row.getByRole("button", { name: "Archive" }).click();
    await expect(page.locator(MODAL_BOX)).toBeVisible({ timeout: 10_000 });
  });

  test("cancel does not archive the product", async ({ page }) => {
    const row = productBlock(page);

    await row.getByRole("button", { name: "Archive" }).click();
    await expect(page.locator(MODAL_BOX)).toBeVisible({ timeout: 10_000 });
    await page.locator(MODAL_BOX).getByRole("button", { name: "Cancel" }).click();
    await expect(page.locator(MODAL_BOX)).toBeHidden();

    // Still offering Archive means the status never changed.
    await expect(row.getByRole("button", { name: "Archive" })).toBeVisible();
    await expect(page.getByText("Product archived")).toHaveCount(0);
  });
});
