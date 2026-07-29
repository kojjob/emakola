import { test, expect } from "@playwright/test";
import { MERCHANT_STORAGE_STATE } from "../support/auth-state";

// Reuse the session from the setup project — LoginLive caps logins at 10/min
// per IP, which a per-spec sign-in would exhaust.
test.use({ storageState: MERCHANT_STORAGE_STATE });

test.describe("Admin Dashboard & Navigation", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/dashboard");
    await page.waitForLoadState("networkidle");
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
    // The list renders twice — a `hidden md:block` desktop table and a mobile
    // card list — so scope to the variant actually shown at this viewport.
    await expect(
      page.getByText("Royal Adweneasa Kente Cloth").filter({ visible: true }).first()
    ).toBeVisible();

    await page.goto("/admin/orders");
    await expect(page.getByRole("heading", { name: "Orders" })).toBeVisible({ timeout: 10_000 });

    await page.goto("/admin/settings");
    await expect(page.getByRole("heading", { name: "Settings" })).toBeVisible({ timeout: 10_000 });
  });
});
