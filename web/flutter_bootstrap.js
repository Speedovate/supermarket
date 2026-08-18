{{flutter_js}}
{{flutter_build_config}}

const splash = document.getElementById('app-startup-splash');

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    if (splash) {
      splash.remove();
    }
  }
});
