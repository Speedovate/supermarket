import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/app_state/app_controller.dart';
import 'router.dart';
import 'theme.dart';

class AndrewsSupermarketApp extends ConsumerStatefulWidget {
  const AndrewsSupermarketApp({super.key});

  @override
  ConsumerState<AndrewsSupermarketApp> createState() =>
      _AndrewsSupermarketAppState();
}

class _AndrewsSupermarketAppState
    extends ConsumerState<AndrewsSupermarketApp> {
  AppLifecycleListener? _appLifecycleListener;

  Set<PointerDeviceKind> get _dragDevices {
    if (kIsWeb) {
      return const {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
    }

    return const {
      PointerDeviceKind.touch,
      PointerDeviceKind.mouse,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.unknown,
    };
  }

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      onResume: () {
        ref.read(appControllerProvider.notifier).refreshFromFirebase();
      },
    );
  }

  @override
  void dispose() {
    _appLifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: "Andrew's Supermarket",
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: _dragDevices,
      ),
      routerConfig: router,
      builder: (context, child) {
        final initialized = ref.watch(
          appControllerProvider.select((state) => state.initialized),
        );
        final currentPath = router.routeInformationProvider.value.uri.path;
        final showingAdminRoute = currentPath.startsWith('/admin');

        if (!initialized && showingAdminRoute) {
          return Scaffold(
            backgroundColor: Color(0xFF2F3DBF),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const logoWidth = 150.0;
                  const footerWidth = logoWidth;
                  const footerBottomPadding = 36.0;
                  const footerReservedHeight = 110.0;

                  return Stack(
                    children: [
                      Positioned.fill(
                        bottom: footerReservedHeight,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 25),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/branding/as_logo_lite.png',
                                  width: logoWidth,
                                  filterQuality: FilterQuality.high,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: footerBottomPadding,
                        child: Center(
                          child: Image.asset(
                            'assets/branding/sdv_footer_lite.png',
                            width: footerWidth,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        }

        return SelectionArea(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
