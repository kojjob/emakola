import { expect, test, type Page } from "@playwright/test";
import { MERCHANT_STORAGE_STATE } from "../support/auth-state";
import { waitForLiveView } from "../support/live-view";

/**
 * /admin/products/new is the photo-cards page: a photo becomes a card, a
 * card needs a name and a price, one button puts the finished cards in the
 * shop. Two things about it only a browser can check:
 *
 * - the photo inputs are full-size transparent overlays under the tiles
 *   (iOS Safari will not open the picker for a clipped input), and
 * - a big photo is shrunk on the phone before it uploads, which is the
 *   difference between a usable page and a stalled one on a market data
 *   plan.
 *
 * Runs under mobile-safari (375x812) because that is the viewport the
 * merchant has; desktop-chrome covers the three-column grid.
 */

test.use({ storageState: MERCHANT_STORAGE_STATE });

/** A 2400x2400 PNG built in the page so no fixture file is needed. */
async function bigPhoto(page: Page) {
  const dataUrl = await page.evaluate(() => {
    const canvas = document.createElement("canvas");
    canvas.width = 2400;
    canvas.height = 2400;
    const ctx = canvas.getContext("2d")!;
    const fill = ctx.createLinearGradient(0, 0, 2400, 2400);
    fill.addColorStop(0, "#f59e0b");
    fill.addColorStop(1, "#059669");
    ctx.fillStyle = fill;
    ctx.fillRect(0, 0, 2400, 2400);
    return canvas.toDataURL("image/png");
  });
  return {
    name: "big.png",
    mimeType: "image/png",
    buffer: Buffer.from(dataUrl.split(",")[1], "base64"),
  };
}

test.beforeEach(async ({ page }) => {
  await page.goto("/admin/products/new");
  await waitForLiveView(page);
});

test("the camera and the gallery are under the thumb, not behind a label", async ({ page }) => {
  await expect(page.locator("#add-products-form")).toBeVisible();

  for (const name of ["camera", "photos"]) {
    const input = page.locator(`input[name="${name}"]`);
    await expect(input).toHaveCount(1);
    // The tile is the tap target, so the input must cover it (inside the
    // tile's 2px dashed border, hence the 4px allowance).
    const tile = await input.locator("xpath=..").boundingBox();
    const box = await input.boundingBox();
    expect(box).not.toBeNull();
    expect(tile).not.toBeNull();
    expect(box!.width).toBeGreaterThanOrEqual(tile!.width - 4);
    expect(box!.height).toBeGreaterThanOrEqual(tile!.height - 4);
  }

  await expect(page.locator('input[name="camera"]')).toHaveAttribute("capture", "environment");
});

test("a big photo is shrunk on the phone before it uploads", async ({ page }) => {
  await page.locator('input[name="photos"]').setInputFiles(await bigPhoto(page));

  const preview = page.locator('[id^="card-photos-"] img').first();
  await expect(preview).toBeVisible();
  await expect
    .poll(async () => preview.evaluate((img: HTMLImageElement) => img.naturalWidth))
    .toBe(1600);
});

test("every photo becomes a card and the button counts what is ready", async ({ page }) => {
  const photo = await bigPhoto(page);
  await page.locator('input[name="photos"]').setInputFiles([
    { ...photo, name: "one.png" },
    { ...photo, name: "two.png" },
  ]);

  await expect(page.locator('[id^="card-photos-"]')).toHaveCount(2);
  await expect(page.locator("#publish-button")).toBeDisabled();
  await expect(page.locator("#publish-button")).toContainText("Put 0 in shop");

  const first = page.locator('[id^="card-photos-"]').first();
  await first.locator('input[name="card_name"]').fill("E2E eggs");
  await first.locator('input[name="card_price"]').fill("45");
  // phx-blur carries the value, so the field has to lose focus.
  await page.locator("h1").click();

  await expect(first).toHaveAttribute("data-state", "ready");
  await expect(page.locator("#publish-button")).toBeEnabled();
  await expect(page.locator("#publish-button")).toContainText("Put 1 in shop");
  await expect(page.locator("#publish-button")).toBeInViewport();
});
