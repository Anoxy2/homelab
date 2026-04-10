const CACHE_NAME = "openclaw-canvas-v2";
const CORE_ASSETS = [
  "/",
  "/index.html",
  "/manifest.json",
  "/icon-192.svg",
  "/icon-512.svg",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(CORE_ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

const isDynamicRequest = (url) => {
  const path = new URL(url).pathname;
  return path.startsWith("/api/") || path === "/action-log.latest.json" || path === "/ops-brief.latest.json" || path === "/state-brief.latest.json";
};

self.addEventListener("fetch", (event) => {
  const request = event.request;

  if (request.method !== "GET") {
    return;
  }

  // Network-first for dynamic API paths — bypass cache entirely.
  if (isDynamicRequest(request.url)) {
    event.respondWith(fetch(request));
    return;
  }

  // Prefer network for navigation, fallback to cached shell with an offline message.
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request).catch(async () => {
        const cache = await caches.open(CACHE_NAME);
        const shell = await cache.match("/index.html");
        if (shell) {
          return shell;
        }
        return new Response(
          "<h1>Verbindung zum Pi verloren</h1><p>Bitte Verbindung pruefen und neu laden.</p>",
          { headers: { "Content-Type": "text/html; charset=utf-8" } }
        );
      })
    );
    return;
  }

  // Cache-first for static assets.
  event.respondWith(
    caches.match(request).then((cached) => {
      if (cached) {
        return cached;
      }
      return fetch(request).then((response) => {
        if (!response || response.status !== 200 || response.type === "opaque") {
          return response;
        }
        const copy = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(request, copy));
        return response;
      });
    })
  );
});
