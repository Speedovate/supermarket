{{flutter_js}}
{{flutter_build_config}}

const splash = document.getElementById('app-startup-splash');
let splashRemoved = false;
const userAgent = navigator.userAgent || "";
const isMetaInAppBrowser =
  /FBAN|FBAV|FB_IAB|Messenger|Instagram|Line|MicroMessenger|WeChat|Twitter|Telegram|Viber|Snapchat|LinkedInApp|Pinterest|wv\)|; wv|TikTok/i.test(userAgent);

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
    renderer: isMetaInAppBrowser ? "canvaskit" : undefined,
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
