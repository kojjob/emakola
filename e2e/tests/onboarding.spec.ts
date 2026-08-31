import { expect, test } from "@playwright/test";
import { waitForLiveView } from "../support/live-view";

/**
 * Onboarding is the one flow whose whole premise is visual: the merchant's
 * shop sits above the question and fills in as they answer, instead of a
 * "Step 2 of 4" line they may not be able to read.
 *
 * That premise is only true if the shop and the question both fit on a
 * phone. This suite runs at 375x812 under mobile-safari, which is the
 * viewport the ExUnit render tests cannot see and a desktop browser will
 * not reproduce.
 *
 * Deliberately signed out: /onboarding renders for an anonymous visitor,
 * and a merchant who already has a store is redirected to /dashboard. Steps
 * 1-3 need no account; only finishing does, so the walkthrough stops there.
 */

const NAME = "Ama's Kitchen";

test.beforeEach(async ({ page }) => {
  await page.goto("/onboarding");
  await waitForLiveView(page);
});

test("the shop and the question share the screen", async ({ page }) => {
  // The failure this guards: on a phone the shop preview eats the viewport
  // and the question (or its button) is pushed off-screen, so the merchant
  // sees a shop but cannot answer anything.
  await expect(page.locator("#onboarding-shop-preview")).toBeInViewport();
  await expect(page.locator("#store_name")).toBeInViewport();
  await expect(page.locator("#onboarding-next-button")).toBeInViewport();
});

test("the sign takes the merchant's name as they type", async ({ page }) => {
  const sign = page.locator("#onboarding-shop-sign");
  await expect(sign).not.toContainText(NAME);

  await page.locator("#store_name").fill(NAME);

  await expect(sign).toContainText(NAME);
  await expect(page.locator("#store-slug-preview")).toHaveAttribute(
    "data-slug",
    "amas-kitchen",
  );
});

test("choosing money re-prices the shop", async ({ page }) => {
  const preview = page.locator("#onboarding-shop-preview");
  await expect(preview).toContainText("GH₵");

  await page.locator('button[phx-value-currency="NGN"]').click();

  await expect(preview).toContainText("₦120");
  await expect(preview).not.toContainText("GH₵");
});

test("progress is dots, and the current one moves", async ({ page }) => {
  await expect(page.locator("[data-onboarding-dot]")).toHaveCount(4);
  await expect(page.locator('[data-onboarding-dot="1"][aria-current="step"]')).toBeVisible();

  await page.locator("#store_name").fill(NAME);
  await page.locator("#onboarding-next-button").click();

  await expect(page.locator('[data-onboarding-dot="2"][aria-current="step"]')).toBeVisible();
});

test("a look from the far end of the strip can be reached and picked", async ({ page }) => {
  await page.locator("#store_name").fill(NAME);
  await page.locator("#onboarding-next-button").click();
  await expect(page.locator('button[phx-value-theme-id="market"]')).toBeVisible();

  const strip = page.locator('button[phx-value-theme-id="market"]').locator("..");
  const far = page.locator('button[phx-value-theme-id="adwuma"]');

  await far.scrollIntoViewIfNeeded();
  const scrolledTo = await strip.evaluate((el) => el.scrollLeft);

  await far.click();

  await expect(far).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator('button[phx-value-theme-id="market"]')).toHaveAttribute(
    "aria-pressed",
    "false",
  );

  // Adwuma's accent, painted onto the shop the moment it is picked.
  await expect(page.locator("#onboarding-shop-preview")).toContainText("₵");
  const previewFill = await page
    .locator("#onboarding-shop-preview")
    .getAttribute("style");
  expect(previewFill).toContain("#FBFBFA");

  // LiveView patches every swatch's classes on select. If that resets the
  // scroller, picking anything past the first few is unusable on a phone.
  if (scrolledTo > 0) {
    await expect
      .poll(() => strip.evaluate((el) => el.scrollLeft))
      .toBeGreaterThan(0);
  }
});

test("the first product lands on the shelf as it is named", async ({ page }) => {
  await page.locator("#store_name").fill(NAME);
  await page.locator("#onboarding-next-button").click();
  await expect(page.locator('button[phx-value-theme-id="market"]')).toBeVisible();

  await page.locator("#onboarding-next-button").click();
  await expect(page.locator("#product_name")).toBeVisible();

  await page.locator("#product_name").fill("Ankara Dress");

  await expect(page.locator("#onboarding-shelf-hero")).toContainText("Ankara Dress");
  await expect(page.locator("#onboarding-shop-preview")).toBeInViewport();
});
