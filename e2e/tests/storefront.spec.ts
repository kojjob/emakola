import { test, expect } from "@playwright/test";

const STORE = "/s/kente-kingdom";

test.describe("Storefront Browsing", () => {
  test("store home page loads with products", async ({ page }) => {
    await page.goto(STORE);
    await page.waitForLoadState("networkidle");
    await expect(page).toHaveTitle(/Kente Kingdom/);
  });

  test("product listing shows all active products", async ({ page }) => {
    await page.goto(`${STORE}/products`);
    await page.waitForLoadState("networkidle");
    await expect(page.getByRole("heading", { name: "Shop All" })).toBeVisible();
    await expect(page.getByText("5 items")).toBeVisible();
  });

  test("product detail page shows product info and add to bag", async ({ page }) => {
    await page.goto(`${STORE}/products/handwoven-kente-clutch-bag`);
    await page.waitForLoadState("networkidle");
    await expect(
      page.getByRole("heading", { name: "Handwoven Kente Clutch Bag" })
    ).toBeVisible({ timeout: 10_000 });
    await expect(page.getByRole("button", { name: "Add to Bag" })).toBeVisible();
  });

  test("category pages load", async ({ page }) => {
    await page.goto(`${STORE}/category/kente-cloth`);
    await page.waitForLoadState("networkidle");
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
  });

  test("about page loads", async ({ page }) => {
    await page.goto(`${STORE}/about`);
    await expect(page).toHaveTitle(/Kente Kingdom/);
  });

  test("blog listing loads", async ({ page }) => {
    await page.goto(`${STORE}/blog`);
    await expect(page).toHaveTitle(/Kente Kingdom/);
  });

  test("footer shows payment methods and store info", async ({ page }) => {
    await page.goto(`${STORE}/products`);
    await page.waitForLoadState("networkidle");
    await expect(page.getByText("MTN MoMo").first()).toBeVisible();
    // Visible brand is "Makola" (the code namespace stays Emakola.* on purpose).
    await expect(page.getByText("Powered by Makola")).toBeVisible();
  });
});
