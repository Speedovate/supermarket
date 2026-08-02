import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/app_state/app_controller.dart';
import 'router.dart';
import 'theme.dart';

class AndrewsSupermarketApp extends ConsumerWidget {
  const AndrewsSupermarketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return child ?? const SizedBox.shrink();
      },
    );
  }
}
