import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/common_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      onResume: () {
        ref.read(appControllerProvider.notifier).reloadFromStore();
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
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.unknown,
        },
      ),
      routerConfig: router,
      builder: (context, child) {
        final initialized = ref.watch(
          appControllerProvider.select((state) => state.initialized),
        );

        if (!initialized) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandLogo(),
                  SizedBox(height: 20),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                ],
              ),
            ),
          );
        }

        return child ?? const SizedBox.shrink();
      },
    );
  }
}
