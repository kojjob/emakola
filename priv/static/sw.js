// Emakola Service Worker
// Cache-first for static assets, network-first for HTML/API

const CACHE_VERSION = "emakola-v1";
const STATIC_CACHE = `${CACHE_VERSION}-static`;
const DYNAMIC_CACHE = `${CACHE_VERSION}-dynamic`;
const IMAGE_CACHE = `${CACHE_VERSION}-images`;

const OFFLINE_URL = "/offline.html";

// Static assets to pre-cache on install
const PRECACHE_URLS = [
  OFFLINE_URL,
  "/manifest.json"
];

// --- Install ---
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => {
      return cache.addAll(PRECACHE_URLS);
    })
  );
  self.skipWaiting();
});

// --- Activate ---
// Clean up old caches when a new version is deployed
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name.startsWith("emakola-") && name !== STATIC_CACHE && name !== DYNAMIC_CACHE && name !== IMAGE_CACHE)
          .map((name) => caches.delete(name))
      );
    })
  );
  self.clients.claim();
});

// --- Fetch ---
self.addEventListener("fetch", (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== "GET") return;

  // Skip WebSocket and LiveView long-poll requests
  if (url.pathname.startsWith("/live") || url.pathname.startsWith("/phoenix")) return;

  // Skip API and webhook endpoints
  if (url.pathname.startsWith("/api") || url.pathname.startsWith("/webhooks")) return;

  // Strategy: Cache-first for static assets (CSS, JS, fonts)
  if (isStaticAsset(url.pathname)) {
    event.respondWith(cacheFirst(request, STATIC_CACHE));
    return;
  }

  // Strategy: Cache-first for product images (cache as they're viewed)
  if (isImageRequest(url.pathname, request)) {
    event.respondWith(cacheFirst(request, IMAGE_CACHE));
    return;
  }

  // Strategy: Network-first for HTML pages
  if (request.headers.get("accept")?.includes("text/html")) {
    event.respondWith(networkFirstWithOfflineFallback(request));
    return;
  }

  // Default: Network-first for everything else
  event.respondWith(networkFirst(request, DYNAMIC_CACHE));
});

// --- Helpers ---

function isStaticAsset(pathname) {
  return /\.(css|js|woff2?|ttf|eot)(\?.*)?$/.test(pathname) ||
         pathname.startsWith("/assets/");
}

function isImageRequest(pathname, request) {
  return /\.(png|jpg|jpeg|gif|webp|svg|ico)(\?.*)?$/.test(pathname) ||
         pathname.startsWith("/images/") ||
         pathname.startsWith("/uploads/") ||
         (request.destination && request.destination === "image");
}

// Cache-first: try cache, fall back to network (and update cache)
async function cacheFirst(request, cacheName) {
  const cached = await caches.match(request);
  if (cached) return cached;

  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(cacheName);
      cache.put(request, response.clone());
    }
    return response;
  } catch (_error) {
    return new Response("", { status: 408, statusText: "Offline" });
  }
}

// Network-first: try network, fall back to cache
async function networkFirst(request, cacheName) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(cacheName);
      cache.put(request, response.clone());
    }
    return response;
  } catch (_error) {
    const cached = await caches.match(request);
    return cached || new Response("", { status: 408, statusText: "Offline" });
  }
}

// Network-first with offline fallback page for HTML requests
async function networkFirstWithOfflineFallback(request) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, response.clone());
    }
    return response;
  } catch (_error) {
    const cached = await caches.match(request);
    if (cached) return cached;

    // Return the offline fallback page
    const offlinePage = await caches.match(OFFLINE_URL);
    return offlinePage || new Response("You are offline", {
      status: 503,
      headers: { "Content-Type": "text/html" }
    });
  }
}
