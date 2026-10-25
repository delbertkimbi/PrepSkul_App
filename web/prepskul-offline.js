'use strict';
const CACHE = 'prepskul-static-v1';
const BASE = new URL('./', self.location.href);
const local = path => new URL(path, BASE).href;
const SHELL = ['index.html', 'flutter_bootstrap.js', 'main.dart.js',
  'assets/FontManifest.json', 'assets/AssetManifest.bin.json'];
self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // Cache fonts even if the learner hasn't visited every screen yet.
    const manifestResponse = await fetch(local('assets/FontManifest.json'));
    if (!manifestResponse.ok) throw new Error('Font manifest unavailable');
    const manifest = await manifestResponse.clone().json();
    const fonts = manifest.flatMap(family => family.fonts.map(font => 'assets/' + font.asset));
    await cache.addAll([...SHELL, ...fonts].map(local));
    await self.skipWaiting();
  })());
});
self.addEventListener('activate', event => {
  event.waitUntil(self.clients.claim());
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== BASE.origin) return;
  const path = url.pathname.slice(BASE.pathname.length);
  const navigation = event.request.mode === 'navigate';
  // Never persist authentication, API requests, or private profile responses.
  const staticAsset = /^(assets\/|canvaskit\/|icons\/)/.test(path) ||
    ['main.dart.js', 'flutter_bootstrap.js', 'index.html'].includes(path);
  if (!navigation && !staticAsset) return;
  const key = navigation ? local('index.html') : local(path);
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    // Network-first keeps rebuilds fresh; cache is immediate when disconnected.
    try {
      const cached = await cache.match(key);
      const controller = new AbortController();
      const timer = cached ? setTimeout(() => controller.abort(), 2500) : null;
      let response;
      try { response = await fetch(event.request, {signal: controller.signal}); }
      finally { if (timer) clearTimeout(timer); }
      if (response.ok && response.type !== 'opaque') await cache.put(key, response.clone());
      return response;
    } catch (error) {
      const cached = await cache.match(key);
      if (cached) return cached;
      throw error;
    }
  })());
});
