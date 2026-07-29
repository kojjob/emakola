import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  timeout: 30_000,
  retries: 1,
  workers: 2,
  use: {
    // Overridable so a git-worktree checkout can run its own server on
    // another port without fighting the shared :4000 instance.
    baseURL: process.env.BASE_URL ?? "http://localhost:4000",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
  },
  projects: [
    // Signs in once and saves storage state. LoginLive rate-limits logins to
    // 10/min per IP, so the suite must not authenticate per spec.
    { name: "setup", testMatch: /auth\.setup\.ts/ },
    {
      name: "desktop-chrome",
      use: { browserName: "chromium", viewport: { width: 1280, height: 800 } },
      dependencies: ["setup"],
    },
    {
      name: "mobile-safari",
      use: {
        browserName: "webkit",
        viewport: { width: 375, height: 812 },
        isMobile: true,
      },
      dependencies: ["setup"],
    },
  ],
});
