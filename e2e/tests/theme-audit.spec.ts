import { test } from "@playwright/test";
import * as fs from "fs";
import * as path from "path";
import { waitForLiveView } from "../support/live-view";

/**
 * Theme design-audit capture pass — NOT part of the CI suite.
 *
 * Captures full-page screenshots of every theme's buyer funnel (home, PLP,
 * PDP, about, cart) on both viewport projects, against the `<theme>-demo`
 * stores created by `mix emakola.seed_theme_demos`. Records findings
 * (HTTP status, LiveView connection, horizontal overflow) as JSONL.
 *
 * Run: THEME_AUDIT=1 BASE_URL=http://localhost:4004 npx playwright test theme-audit --no-deps
 */

// Mirrors ThemeResolver.theme_ids/0 (lib/emakola/themes/theme_resolver.ex).
const THEMES = [
  "adwuma", "akwaaba", "atelier", "beauty", "bold", "chale", "dede", "depot",
  "electronics", "fashion", "fie", "fresh", "heirloom", "home_living",
  "market", "ntoma", "pace", "pharmacy", "sika", "spotlight", "starter",
  "vibrant",
];

// Checkout is a shared DefaultRenderer — captured deeply on 3 representatives.
const CHECKOUT_THEMES = ["market", "atelier", "adwuma"];

// Product slugs from the shared demo catalogue (mix emakola.seed_theme_demos).
const PDP_SLUG = "royal-adweneasa-kente-cloth";
const CART_ADD_SLUG = "kente-fusion-dress";

const OUT_ROOT = path.resolve(
  __dirname,
  "../../.claude/qa-archives/theme-audit-2026-08-16",
);

test.skip(!process.env.THEME_AUDIT, "Set THEME_AUDIT=1 to run the capture pass");

// Retries would duplicate JSONL findings; a failed capture is itself a finding.
test.describe.configure({ retries: 0, timeout: 240_000 });

type Finding = {
  theme: string;
  page: string;
  viewport: string;
  url: string;
  status: number;
  liveViewConnected: boolean;
  horizontalOverflow: boolean;
  note?: string;
};

function viewportName(projectName: string): string {
  return projectName.startsWith("mobile") ? "mobile" : "desktop";
}

function recordFinding(viewport: string, finding: Finding) {
  fs.mkdirSync(OUT_ROOT, { recursive: true });
  fs.appendFileSync(
    path.join(OUT_ROOT, `findings-${viewport}.jsonl`),
    JSON.stringify(finding) + "\n",
  );
}

/** Scroll through the page so lazy images load, then return to the top. */
async function settle(page: import("@playwright/test").Page) {
  await page.waitForLoadState("networkidle").catch(() => {});
  await page
    .evaluate(async () => {
      const step = window.innerHeight;
      for (let y = 0; y < document.body.scrollHeight; y += step) {
        window.scrollTo(0, y);
        await new Promise((r) => setTimeout(r, 120));
      }
      window.scrollTo(0, 0);
    })
    .catch(() => {});
  await page.waitForTimeout(300);
}

async function capture(
  page: import("@playwright/test").Page,
  theme: string,
  pageName: string,
  viewport: string,
  urlPath: string,
  note?: string,
) {
  const response = await page
    .goto(urlPath, { waitUntil: "domcontentloaded" })
    .catch(() => null);
  const status = response?.status() ?? 0;

  let liveViewConnected = true;
  await waitForLiveView(page).catch(() => {
    liveViewConnected = false;
  });

  await settle(page);

  const horizontalOverflow = await page
    .evaluate(
      () =>
        document.documentElement.scrollWidth >
        document.documentElement.clientWidth,
    )
    .catch(() => false);

  const dir = path.join(OUT_ROOT, theme);
  fs.mkdirSync(dir, { recursive: true });
  await page
    .screenshot({ path: path.join(dir, `${pageName}-${viewport}.png`), fullPage: true })
    .catch(() => {});

  recordFinding(viewport, {
    theme,
    page: pageName,
    viewport,
    url: urlPath,
    status,
    liveViewConnected,
    horizontalOverflow,
    ...(note ? { note } : {}),
  });
}

for (const theme of THEMES) {
  test(`${theme} funnel capture`, async ({ page }, testInfo) => {
    const viewport = viewportName(testInfo.project.name);
    const store = `/s/${theme}-demo`;

    await capture(page, theme, "home", viewport, store);
    await capture(page, theme, "plp", viewport, `${store}/products`);
    await capture(page, theme, "pdp", viewport, `${store}/products/${PDP_SLUG}`);
    await capture(page, theme, "about", viewport, `${store}/about`);
    await capture(page, theme, "cart-empty", viewport, `${store}/cart`);

    if (CHECKOUT_THEMES.includes(theme)) {
      await page.goto(`${store}/products/${CART_ADD_SLUG}`);
      await waitForLiveView(page).catch(() => {});

      const addToCart = page
        .getByRole("button", { name: /add to (bag|cart)/i })
        .first();
      let added = false;
      if (await addToCart.isVisible().catch(() => false)) {
        await addToCart.click();
        await page.waitForTimeout(800);
        added = true;
      }

      const note = added ? undefined : "add-to-cart control not found on PDP";
      await capture(page, theme, "cart-filled", viewport, `${store}/cart`, note);
      await capture(page, theme, "checkout", viewport, `${store}/checkout`, note);
    }
  });
}
