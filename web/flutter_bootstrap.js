{{flutter_js}}
{{flutter_build_config}}
// Own the offline cache explicitly; newer Flutter versions remove their worker.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('prepskul-offline.js').catch(console.warn);
}
_flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}});
