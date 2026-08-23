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
        final appChild = child ?? const SizedBox.shrink();

        // Keep the app globally selectable on web without mounting
        // SelectionArea above MaterialApp's internal Overlay.
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => SelectionArea(child: appChild),
            ),
          ],
        );
      },
    );
  }
}
