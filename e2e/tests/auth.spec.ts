import { test, expect } from "@playwright/test";
import { waitForLiveView } from "../support/live-view";

test.describe("Merchant Authentication", () => {
  test("shows login page with form elements", async ({ page }) => {
    await page.goto("/auth/login");
    await expect(page.getByRole("heading", { name: "Welcome back" })).toBeVisible();
    await expect(page.getByRole("textbox", { name: /business\.com/ })).toBeVisible();
    await expect(page.getByRole("textbox", { name: /password/i })).toBeVisible();
    await expect(page.getByRole("button", { name: "Sign In" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Create Account" })).toBeVisible();
  });

  test("shows error flash on invalid credentials", async ({ page }) => {
    await page.goto("/auth/login");
    await waitForLiveView(page);
    await page.getByRole("textbox", { name: /business\.com/ }).fill("wrong@email.com");
    await page.getByRole("textbox", { name: /password/i }).fill("badpassword");
    await page.getByRole("button", { name: "Sign In" }).click();

    // #flash-error is the put_flash error toast. A bare [role=alert] can never
    // pass strict mode here: the layout always mounts the hidden #client-error
    // and #server-error alerts alongside it.
    await expect(page.locator("#flash-error")).toContainText("Invalid email or password", {
      timeout: 10_000,
    });
    await expect(page).toHaveURL("/auth/login");
  });

  test("successful login redirects to dashboard", async ({ page }) => {
    await page.goto("/auth/login");
    await waitForLiveView(page);
    await page.getByRole("textbox", { name: /business\.com/ }).fill("kwame@kentekingdom.com");
    await page.getByRole("textbox", { name: /password/i }).fill("Password123!");
    await page.getByRole("button", { name: "Sign In" }).click();

    await expect(page).toHaveURL("/dashboard", { timeout: 15_000 });
    await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();
  });

  test("shows register page with form elements", async ({ page }) => {
    await page.goto("/auth/register");
    await expect(page.getByRole("heading", { name: "Create your account" })).toBeVisible();
    await expect(page.getByRole("button", { name: /Create Merchant Account/i })).toBeVisible();
  });

});
