import { test, expect } from "@playwright/test";
import { MERCHANT_STORAGE_STATE } from "../support/auth-state";
import { waitForLiveView } from "../support/live-view";

// Reuse the session from the setup project — LoginLive caps logins at 10/min.
test.use({ storageState: MERCHANT_STORAGE_STATE });

/**
 * Browser-only behaviour ExUnit cannot see: the composer is emptied by a
 * colocated JS hook after Send. For weeks app.js never handed colocated
 * hooks to the LiveSocket and every server-side test stayed green, so this
 * spec is the guard that actually types and clicks.
 */
test.describe("Merchant messages composer", () => {
  test("the box empties after Send and the message shows once", async ({ page }) => {
    await page.goto("/admin/messages");
    await waitForLiveView(page);

    // The seeded Makola support thread gives the merchant something to answer.
    await page.locator("a[href^='/admin/messages/']").first().click();
    await waitForLiveView(page);

    const input = page.locator("#chat-composer input[type='text']");
    await expect(input).toBeVisible();

    const body = `Reply at ${Date.now()}`;
    await input.fill(body);
    await page.getByRole("button", { name: "Send" }).click();

    // Once in the thread pane; the chat list previews the last message too,
    // so the count is scoped to #messages.
    await expect(page.locator("#messages").getByText(body)).toHaveCount(1);
    await expect(input).toHaveValue("");
    await expect(input).toBeFocused();
  });
});
