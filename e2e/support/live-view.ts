import { Page } from "@playwright/test";

/**
 * Wait until the page's main LiveView has actually joined its socket.
 *
 * `waitForURL`/`networkidle` are not enough: WebSocket joins don't count as
 * network activity, so a click can land in the gap between the dead render
 * and the socket join — a phx-submit form swallows that click silently (or
 * native-submits). This was the root cause of every intermittent login
 * failure in this suite.
 */
export async function waitForLiveView(page: Page) {
  await page
    .locator("[data-phx-main].phx-connected")
    .first()
    .waitFor({ state: "attached", timeout: 15_000 });
}
