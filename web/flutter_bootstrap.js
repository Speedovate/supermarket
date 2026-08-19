{{flutter_js}}
{{flutter_build_config}}

const splash = document.getElementById('app-startup-splash');
let splashRemoved = false;

function removeSplashWhenFirstFrameIsLikelyReady() {
  if (!splash || splashRemoved) {
    return;
  }
  splashRemoved = true;

  const remove = () => {
    splash.style.opacity = '0';
    splash.style.transition = 'opacity 120ms ease-out';
    window.setTimeout(() => {
      splash.remove();
      if (typeof window.__syncThemeColor === 'function') {
        window.__syncThemeColor();
      }
    }, 120);
  };

  window.requestAnimationFrame(() => {
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(remove);
    });
  });
}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit",
  },
  onEntrypointLoaded: async function(engineInitializer) {
    const fallbackRemovalTimer = window.setTimeout(
      removeSplashWhenFirstFrameIsLikelyReady,
      4000,
    );
    window.addEventListener(
      'flutter-first-frame',
      () => {
        window.clearTimeout(fallbackRemovalTimer);
        removeSplashWhenFirstFrameIsLikelyReady();
      },
      { once: true },
    );
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }
});
