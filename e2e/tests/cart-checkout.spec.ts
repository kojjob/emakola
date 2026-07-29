import { test, expect } from "@playwright/test";
import { waitForLiveView } from "../support/live-view";

const STORE = "/s/kente-kingdom";

test.describe("Cart & Checkout Flow", () => {
  test("add product to cart and see flash confirmation", async ({ page }) => {
    await page.goto(`${STORE}/products/handwoven-kente-clutch-bag`);
    await waitForLiveView(page);
    await page.getByRole("button", { name: "Add to Bag" }).click();

    await expect(page.locator("#flash-info")).toContainText("Added to cart", {
      timeout: 10_000,
    });
  });

  test("cart page shows added product with order summary", async ({ page }) => {
    await page.goto(`${STORE}/products/handwoven-kente-clutch-bag`);
    await waitForLiveView(page);
    await page.getByRole("button", { name: "Add to Bag" }).click();
    await expect(page.locator("#flash-info")).toContainText("Added to cart", {
      timeout: 10_000,
    });

    await page.goto(`${STORE}/cart`);
    await page.waitForLoadState("networkidle");

    await expect(page.getByRole("heading", { name: "Shopping Bag" })).toBeVisible();
    await expect(page.getByText("Handwoven Kente Clutch Bag").first()).toBeVisible();
    await expect(page.getByRole("heading", { name: "Order Summary" })).toBeVisible();
    await expect(page.getByRole("link", { name: /Proceed to Checkout/i })).toBeVisible();
  });

  test("checkout page loads with form and payment options", async ({ page }) => {
    await page.goto(`${STORE}/products/handwoven-kente-clutch-bag`);
    await waitForLiveView(page);
    await page.getByRole("button", { name: "Add to Bag" }).click();
    await expect(page.locator("#flash-info")).toContainText("Added to cart", {
      timeout: 10_000,
    });

    await page.goto(`${STORE}/checkout`);
    await page.waitForLoadState("networkidle");

    await expect(page.getByRole("heading", { name: "Contact" })).toBeVisible({ timeout: 10_000 });
    await expect(page.getByRole("heading", { name: "Shipping Address" })).toBeVisible();
    await expect(page.locator("#phone")).toBeVisible();
    await expect(page.locator("#fullname")).toBeVisible();
    await expect(page.locator("#address")).toBeVisible();
    await expect(page.getByRole("button", { name: /Place Order/i })).toBeVisible();
  });

  test("empty cart shows appropriate state", async ({ page }) => {
    await page.goto(`${STORE}/cart`);
    await page.waitForLoadState("networkidle");
    await expect(page.getByRole("heading", { name: "Shopping Bag" })).toBeVisible();
  });

  test("cart has continue shopping link back to store", async ({ page }) => {
    await page.goto(`${STORE}/cart`);
    await page.waitForLoadState("networkidle");
    await expect(page.getByRole("link", { name: /Continue Shopping/i })).toHaveAttribute(
      "href",
      STORE
    );
  });
});
