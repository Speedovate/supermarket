{{flutter_js}}
{{flutter_build_config}}

(function () {
  const builds = _flutter.buildConfig?.builds;
  if (Array.isArray(builds)) {
    for (const build of builds) {
      if (build && typeof build === 'object') {
        build.renderer = 'skwasm';
      }
    }
  }

  _flutter.loader.load();
}());
