import { test, expect, Page } from "@playwright/test";

async function loginAsMerchant(page: Page) {
  await page.goto("/auth/login");
  await page.waitForLoadState("networkidle");
  await page.getByRole("textbox", { name: /business\.com/ }).fill("kwame@kentekingdom.com");
  await page.getByRole("textbox", { name: /password/i }).fill("Password123!");
  await page.getByRole("button", { name: "Sign In" }).click();
  await page.waitForURL("**/dashboard", { timeout: 20_000 });
}

test.describe("Admin Dashboard & Navigation", () => {
  test.beforeEach(async ({ page }) => {
    await loginAsMerchant(page);
  });

  test("dashboard shows metrics", async ({ page }) => {
    await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();
    await expect(page.getByRole("main").getByText("Revenue").first()).toBeVisible();
    await expect(page.getByRole("main").getByText("Orders").first()).toBeVisible();
    await expect(page.getByRole("main").getByText("Customers").first()).toBeVisible();
  });

  test("admin pages load with correct content", async ({ page }) => {
    await page.goto("/admin/products");
    await page.waitForLoadState("networkidle");
    await expect(page.getByRole("heading", { name: "Products" })).toBeVisible({ timeout: 10_000 });
    await expect(page.getByText("Royal Adweneasa Kente Cloth").first()).toBeVisible();

    await page.goto("/admin/orders");
    await expect(page.getByRole("heading", { name: "Orders" })).toBeVisible({ timeout: 10_000 });

    await page.goto("/admin/settings");
    await expect(page.getByRole("heading", { name: "Settings" })).toBeVisible({ timeout: 10_000 });
  });
});
