import { test, expect } from "@playwright/test";
import { waitForLiveView } from "../support/live-view";

/**
 * Full journey: request reset -> pull the real link out of the dev mailbox
 * (/dev/mailbox/json, Swoosh Local adapter) -> set a new password -> sign in
 * with it.
 *
 * Always sets the same password so reruns are stable: requesting a reset
 * never needs the old password.
 *
 * Reset tokens are single-use and the dev mailbox is global, so the two
 * Playwright projects must not share an account: whichever submits second
 * would find its token already consumed. Each project gets its own seeded
 * merchant. kwame is excluded — his credentials back the shared storageState.
 */
const MERCHANT_BY_PROJECT: Record<string, string> = {
  "desktop-chrome": "efua@tinystitches.com",
  "mobile-safari": "adjoa@accrafresh.com",
};

const NEW_PASSWORD = "Reset-Password-99!";

test.describe("Merchant password reset", () => {
  test("request -> email link -> new password -> login", async ({ page, request }, testInfo) => {
    const EMAIL = MERCHANT_BY_PROJECT[testInfo.project.name] ?? "efua@tinystitches.com";

    await page.goto("/auth/forgot-password");
    await waitForLiveView(page);
    await page.locator("input[name='forgot[email]']").fill(EMAIL);
    await page.getByRole("button", { name: "Send Reset Link" }).click();
    await expect(page.getByText(/If that email has a Makola account/)).toBeVisible({
      timeout: 10_000,
    });

    // The Local adapter's mailbox lists newest first.
    const mailbox = await request.get("/dev/mailbox/json");
    expect(mailbox.ok()).toBe(true);
    const body = await mailbox.json();
    const emails: any[] = Array.isArray(body) ? body : body.data ?? body.emails ?? [];
    // Reruns accumulate reset emails whose earlier tokens are already
    // consumed — always take the NEWEST matching email, never trust order.
    const resetMail = emails
      .filter(
        (m) =>
          JSON.stringify(m.to ?? "").includes(EMAIL) &&
          String(m.subject ?? "").includes("Reset your Makola password")
      )
      .sort((a, b) => String(b.sent_at ?? "").localeCompare(String(a.sent_at ?? "")))[0];
    expect(resetMail, "reset email not found in /dev/mailbox/json").toBeTruthy();

    const haystack = JSON.stringify(resetMail);
    const match = haystack.match(/\/auth\/reset-password\?token=[A-Za-z0-9._~-]+/);
    expect(match, "no reset link in the email body").toBeTruthy();

    await page.goto(match![0]);
    await waitForLiveView(page);
    await expect(page.getByRole("heading", { name: "Set a new password" })).toBeVisible();
    await page.locator("input[name='reset[password]']").fill(NEW_PASSWORD);
    await page.locator("input[name='reset[password_confirmation]']").fill(NEW_PASSWORD);
    await page.getByRole("button", { name: "Update Password" }).click();

    await page.waitForURL("**/auth/login", { timeout: 15_000 });
    await waitForLiveView(page);
    await expect(page.locator("[role=alert], [role=status]").first()).toContainText(
      /Password updated/,
      { timeout: 10_000 }
    );

    // session_live? kills tokens issued in the same whole second as the
    // reset's sessions_valid_from cutoff (deliberately — same-second OLD
    // tokens must die). Humans never log back in within one second;
    // Playwright does, and the fresh session bounces. Wait out the second.
    await page.waitForTimeout(1100);

    await page.locator("input[name='user[email]']").fill(EMAIL);
    await page.locator("input[name='user[password]']").fill(NEW_PASSWORD);
    await page.getByRole("button", { name: "Sign In" }).click();
    await page.waitForURL("**/dashboard", { timeout: 20_000 });
  });

  test("a garbage token shows the invalid-link state", async ({ page }) => {
    await page.goto("/auth/reset-password?token=garbage");
    await waitForLiveView(page);
    await page.locator("input[name='reset[password]']").fill(NEW_PASSWORD);
    await page.locator("input[name='reset[password_confirmation]']").fill(NEW_PASSWORD);
    await page.getByRole("button", { name: "Update Password" }).click();
    await expect(page.getByText(/link is invalid or has expired/)).toBeVisible({
      timeout: 10_000,
    });
    await expect(page.locator("a[href='/auth/forgot-password']")).toBeVisible();
  });
});
