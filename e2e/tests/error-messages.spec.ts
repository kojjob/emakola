import { test, expect } from "@playwright/test";
import { waitForLiveView } from "../support/live-view";

/**
 * Regression coverage for user-facing error text.
 *
 * Both bugs below were invisible to the ExUnit suite because nothing asserted
 * on the *rendered* text of a failure path — the flows themselves worked, they
 * just told the user something unusable.
 */

const STORE = "/s/kente-kingdom";
const PRODUCT = `${STORE}/products/handwoven-kente-clutch-bag`;

/** Raw Elixir/Ash internals that must never reach a shopper or merchant. */
const INTERNALS = /%\{|=>|:gateway_error|invalid_Key|\{:error|Ash\.Error/;

test.describe("User-facing error messages", () => {
  test("registration surfaces the password limit, not a raw %{min} placeholder", async ({
    page,
  }) => {
    await page.goto("/auth/register");
    await waitForLiveView(page);

    await page.locator("input[name='user[name]']").fill("QA Short Password");
    await page
      .locator("input[name='user[email]']")
      .fill(`qa-shortpw-${Date.now()}@example.com`);
    // Passes the browser's own validation, fails Ash's min-length check.
    await page.locator("input[name='user[password]']").fill("abc12");

    await page.getByRole("button", { name: /Create Merchant Account/i }).click();

    const alert = page.locator("[role=alert]").first();
    await expect(alert).toContainText("greater than or equal to 8", { timeout: 10_000 });
    await expect(alert).not.toContainText("%{min}");
  });

  test("a failed payment shows a recovery message, not the gateway payload", async ({
    page,
  }) => {
    // Dev/CI run with placeholder Paystack keys, so initiating payment returns
    // a 401 from the gateway — exactly the path that used to dump the raw
    // {:gateway_error, %{...}} tuple into the page.
    // The 45s gateway-envelope wait below cannot fit the global 30s test
    // budget — give this test room for flow (~15s) + envelope (~40s).
    test.setTimeout(90_000);
    await page.goto(PRODUCT);
    await waitForLiveView(page);
    await page.getByRole("button", { name: "Add to Bag" }).click();
    await expect(page.locator("#flash-info")).toContainText("Added to cart", {
      timeout: 10_000,
    });

    await page.goto(`${STORE}/checkout`);
    await waitForLiveView(page);

    await page.locator("#phone").fill("0244123777");
    await page.locator("#fullname").fill("QA Friendly Error");
    await page.locator("#address").fill("5 Retry Lane, Osu");

    await page.getByRole("button", { name: /Place Order/i }).click();

    const alert = page.locator("[role=alert]").first();
    // This path really calls api.paystack.co (placeholder key → 401). When a
    // runner's egress is tarpitted, the flash only lands after the client's
    // failure envelope: ~30s connect timeout + 10s receive_timeout
    // (paystack_client.ex). 45s sits above that worst case.
    await expect(alert).toContainText("couldn't start your payment", { timeout: 45_000 });
    // The order still exists, so the message must tell the shopper which one.
    await expect(alert).toContainText(/ORD-\d{8}-[A-Z0-9]+/);

    const body = await page.locator("body").innerText();
    expect(body).not.toMatch(INTERNALS);
  });
});
