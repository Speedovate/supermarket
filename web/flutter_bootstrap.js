{{flutter_js}}
{{flutter_build_config}}

const userAgent = navigator.userAgent || "";
const isSocialInAppBrowser =
  /FBAN|FBAV|Messenger|Instagram|Line\/|Line |MicroMessenger|WeChat|Viber|Telegram|Twitter|X\/|Snapchat|LinkedInApp|Pinterest/i.test(
    userAgent,
  );

window.__ANDREWS_SOCIAL_INAPP__ = isSocialInAppBrowser;

if (isSocialInAppBrowser) {
  document.documentElement.setAttribute("data-social-inapp", "true");
}

const splash = document.getElementById("app-startup-splash");
let splashRemoved = false;

function removeSplashWhenFirstFrameIsLikelyReady() {
  if (!splash || splashRemoved) {
    return;
  }
  splashRemoved = true;

  const remove = () => {
    splash.style.opacity = "0";
    splash.style.transition = "opacity 120ms ease-out";
    window.setTimeout(() => {
      splash.remove();
      if (typeof window.__syncThemeColor === "function") {
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

async function loadFlutterApp() {
  await _flutter.loader.load({
    config: {
      canvasKitBaseUrl: "canvaskit/",
    },
    onEntrypointLoaded: async function (engineInitializer) {
      const fallbackRemovalTimer = window.setTimeout(
        removeSplashWhenFirstFrameIsLikelyReady,
        4000,
      );
      window.addEventListener(
        "flutter-first-frame",
        () => {
          window.clearTimeout(fallbackRemovalTimer);
          removeSplashWhenFirstFrameIsLikelyReady();
        },
        { once: true },
      );
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    },
  });
}

window.__ANDREWS_START_FLUTTER__ = loadFlutterApp;

if (!isSocialInAppBrowser) {
  window.__ANDREWS_START_FLUTTER__();
}
