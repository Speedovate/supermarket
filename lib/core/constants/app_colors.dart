import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const logoBlue = Color(0xFF2439B8);
  static const logoBlueDark = Color(0xFF1B2C90);
  static const logoBlueSoft = Color(0xFFF4F7FF);
  static const statusActiveGreen = Color(0xFF16A34A);
  static const homeScrollableBackground = Color(0xFFF6F7FB);
  static const logoBlueShadow = Color(0x122439B8);
  static const logoBlueShadowStrong = Color(0x1A2439B8);
  static const logoBlueGlow = Color(0x332439B8);

  static const brandingBlueHoverOverlayAlpha = 0.46;
  static const brandingBluePressedOverlayAlpha = 0.62;
  static const brandingBlueFocusOverlayAlpha = 0.52;

  static const neutralHoverOverlayAlpha = 0.08;
  static const neutralPressedOverlayAlpha = 0.14;
  static const neutralFocusOverlayAlpha = 0.10;

  static Color darken(Color color, double alpha) {
    return Color.alphaBlend(
      Colors.black.withValues(alpha: alpha),
      color,
    );
  }

  static Color brandingBlueInteractiveBackground(
    Set<WidgetState> states, {
    Color baseColor = logoBlue,
  }) {
    if (states.contains(WidgetState.pressed)) {
      return darken(baseColor, brandingBluePressedOverlayAlpha);
    }
    if (states.contains(WidgetState.hovered)) {
      return darken(baseColor, brandingBlueHoverOverlayAlpha);
    }
    if (states.contains(WidgetState.focused)) {
      return darken(baseColor, brandingBlueFocusOverlayAlpha);
    }
    return baseColor;
  }
}
