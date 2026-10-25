const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync('web/prepskul-offline.js', 'utf8');
function worker() {
  const events = {}, stored = new Map(), added = [];
  const cache = {addAll: async urls => added.push(...urls), put: async (key, value) => stored.set(key, value), match: async key => stored.get(key)};
  const context = {URL, AbortController, setTimeout, clearTimeout,
    self: {location: {href:'https://app.test/prepskul-offline.js'}, addEventListener: (name, fn) => events[name] = fn, skipWaiting: async () => {}, clients: {claim:async () => {}}},
    caches: {open: async () => cache}, fetch: async () => new Response(JSON.stringify([{fonts:[{asset:'fonts/MaterialIcons-Regular.otf'}]}]))};
  vm.runInNewContext(source, context);
  return {events, stored, added, context};
}
test('installation precaches bundled icon fonts', async () => {
  const w = worker(); let promise;
  w.events.install({waitUntil: p => promise = p}); await promise;
  assert(w.added.includes('https://app.test/assets/fonts/MaterialIcons-Regular.otf'));
  assert(w.added.includes('https://app.test/main.dart.js'));
});
test('offline requests use cached icon font', async () => {
  const w = worker(); const url = 'https://app.test/assets/fonts/icons.otf';
  w.stored.set(url, new Response('font')); w.context.fetch = async () => {throw Error('offline')};
  let promise; w.events.fetch({request: new Request(url), respondWith:p => promise=p});
  assert.equal(await (await promise).text(), 'font');
});
test('private API responses are never intercepted', () => {
  const w = worker(); let intercepted = false;
  w.events.fetch({request:new Request('https://app.test/api/profile'), respondWith:() => intercepted=true});
  assert.equal(intercepted, false);
});
