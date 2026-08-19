{{flutter_js}}
{{flutter_build_config}}

const splash = document.getElementById('app-startup-splash');

function removeSplashWhenFirstFrameIsLikelyReady() {
  if (!splash) {
    return;
  }

  const remove = () => {
    splash.style.opacity = '0';
    splash.style.transition = 'opacity 120ms ease-out';
    window.setTimeout(() => splash.remove(), 120);
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
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    removeSplashWhenFirstFrameIsLikelyReady();
  }
});
