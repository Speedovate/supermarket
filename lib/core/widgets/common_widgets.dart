import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../models/app_models.dart';
import '../utils/formatters.dart';

const _snackbarSuccessColor = Color(0xFF2E7D32);
const _snackbarErrorColor = Color(0xFFE31E24);

SnackBar successSnackBar(String message) {
  return SnackBar(
    backgroundColor: _snackbarSuccessColor,
    content: Text(
      message,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
    ),
  );
}

SnackBar errorSnackBar(String message) {
  return SnackBar(
    backgroundColor: _snackbarErrorColor,
    content: Text(
      message,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
    ),
  );
}

class MousePressable extends StatefulWidget {
  const MousePressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.cursor = SystemMouseCursors.click,
    this.behavior = HitTestBehavior.opaque,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.hoverOverlayAlpha = AppColors.neutralHoverOverlayAlpha,
    this.pressedOverlayAlpha = AppColors.neutralPressedOverlayAlpha,
    this.stateBuilder,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final MouseCursor cursor;
  final HitTestBehavior behavior;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final double hoverOverlayAlpha;
  final double pressedOverlayAlpha;
  final Widget Function(
    BuildContext context,
    bool hovered,
    bool pressed,
    Widget child,
  )?
  stateBuilder;

  @override
  State<MousePressable> createState() => _MousePressableState();
}

class _MousePressableState extends State<MousePressable> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final overlayColor = !widget.enabled
        ? null
        : _pressed
        ? Colors.black.withValues(alpha: widget.pressedOverlayAlpha)
        : (_hovered
              ? Colors.black.withValues(alpha: widget.hoverOverlayAlpha)
              : null);

    Widget child = Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (overlayColor != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: overlayColor,
                  shape: widget.shape,
                  borderRadius: widget.shape == BoxShape.rectangle
                      ? widget.borderRadius
                      : null,
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.stateBuilder != null) {
      child = widget.stateBuilder!(
        context,
        widget.enabled && _hovered,
        widget.enabled && _pressed,
        widget.child,
      );
    }

    if (widget.shape == BoxShape.circle) {
      child = ClipOval(child: child);
    } else if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    return MouseRegion(
      cursor: widget.enabled && widget.onTap != null
          ? widget.cursor
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = widget.enabled),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = widget.enabled),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: GestureDetector(
          behavior: widget.behavior,
          onTap: widget.enabled ? widget.onTap : null,
          child: child,
        ),
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.compact = false, this.onDark = false});

  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final mainStyle = GoogleFonts.inter(
      textStyle: Theme.of(context).textTheme.titleLarge,
      fontWeight: FontWeight.w800,
      color: onDark ? Colors.white : AppColors.logoBlue,
      height: 1,
      fontSize: compact ? 20 : 24,
    );
    final subStyle = GoogleFonts.inter(
      textStyle: Theme.of(context).textTheme.titleMedium,
      fontWeight: FontWeight.w800,
      color: onDark ? const Color(0xFFFFB9BD) : const Color(0xFFE31E24),
      height: 1,
      fontSize: compact ? 13 : 17,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: compact ? 44 : 60,
          decoration: BoxDecoration(color: Colors.white),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            onDark
                ? 'assets/branding/as_logo_lite.png'
                : 'assets/branding/as_logo_dark.png',
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: compact ? 10 : 14),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("ANDREW'S", style: mainStyle),
              Text('SUPERMARKET', style: subStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class ProductPlaceholder extends StatelessWidget {
  const ProductPlaceholder({
    super.key,
    required this.label,
    this.height = 160,
    this.posterMode = false,
    this.fullRounded = false,
    this.backgroundColor = Colors.white,
    this.imageUrl,
    this.imageFit = BoxFit.cover,
  });

  final String label;
  final double height;
  final bool posterMode;
  final bool fullRounded;
  final Color backgroundColor;
  final String? imageUrl;
  final BoxFit imageFit;

  static const _webProductImageProxyPrefix = String.fromEnvironment(
    'PRODUCT_IMAGE_PROXY_PREFIX',
    defaultValue: '',
  );

  @override
  Widget build(BuildContext context) {
    final borderRadius = fullRounded
        ? BorderRadius.circular(24)
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          );

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(borderRadius: borderRadius, child: _buildImageContent()),
    );
  }

  Widget _buildImageContent() {
    final resolvedImageUrl = imageUrl?.trim() ?? '';
    if (resolvedImageUrl.isNotEmpty) {
      final bytes = _tryDecodeDataUrl(resolvedImageUrl);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: imageFit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
      }
      if (resolvedImageUrl.startsWith('assets/')) {
        return Image.asset(
          resolvedImageUrl,
          fit: imageFit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
      }
      if (resolvedImageUrl.startsWith('http://') ||
          resolvedImageUrl.startsWith('https://')) {
        final networkUrl =
            !kIsWeb ||
                _webProductImageProxyPrefix.isEmpty ||
                !(resolvedImageUrl.startsWith('http://') ||
                    resolvedImageUrl.startsWith('https://'))
            ? resolvedImageUrl
            : '$_webProductImageProxyPrefix${Uri.encodeComponent(resolvedImageUrl)}';
        return Image.network(
          networkUrl,
          fit: imageFit,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 500,
          cacheHeight: 500,
          webHtmlElementStrategy: kIsWeb
              ? WebHtmlElementStrategy.prefer
              : WebHtmlElementStrategy.never,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
      }
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Image.asset(
        'assets/branding/as_logo_dark.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

Uint8List? _tryDecodeDataUrl(String value) {
  final match = RegExp(r'^data:image/[^;]+;base64,(.+)$').firstMatch(value);
  if (match == null) {
    return null;
  }
  try {
    return base64Decode(match.group(1)!);
  } catch (_) {
    return null;
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.fontSize = 14});

  final OrderStatus status;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.waiting => const Color(0xFFFFA726),
      OrderStatus.checking => const Color(0xFFFFA726),
      OrderStatus.ready => AppColors.logoBlue,
      OrderStatus.completed => const Color(0xFF2E7D32),
      OrderStatus.cancelled => const Color(0xFFE53935),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          displayStatus(status),
          softWrap: false,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class AdminStateBadge extends StatelessWidget {
  const AdminStateBadge({
    super.key,
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    this.fontSize = 14,
  });

  final String label;
  final Color color;
  final Color textColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          softWrap: false,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.showBorder = true,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: showBorder ? Border.all(color: const Color(0xFFE4E7EC)) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 42,
              color: AppColors.logoBlue,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.15),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.logoBlue,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(0, 36),
                    maximumSize: const Size(double.infinity, 36),
                    fixedSize: const Size(double.infinity, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.showShadow = true,
    this.borderColor = const Color(0xFFE4E7EC),
    this.borderRadius = 24,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool showShadow;
  final Color borderColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
        boxShadow: showShadow
            ? const [BoxShadow(color: AppColors.logoBlueShadow, blurRadius: 18)]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppModalFrame extends StatelessWidget {
  const AppModalFrame({
    super.key,
    required this.title,
    required this.child,
    this.maxWidth = 332,
    this.trailing,
    this.actions,
    this.onSubmit,
  });

  final String title;
  final Widget child;
  final double maxWidth;
  final Widget? trailing;
  final List<Widget>? actions;
  final VoidCallback? onSubmit;

  static const double borderRadius = 28;
  static const double contentPadding = 16;
  static const double actionHeight = 44;

  @override
  Widget build(BuildContext context) {
    final dialog = Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(contentPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                    ),
                  ),
                  ...switch (trailing) {
                    final widget? => <Widget>[widget],
                    null => const <Widget>[],
                  },
                ],
              ),
              const SizedBox(height: 12),
              child,
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(children: actions!),
              ],
            ],
          ),
        ),
      ),
    );

    if (onSubmit == null) {
      return dialog;
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): onSubmit!,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): onSubmit!,
      },
      child: dialog,
    );
  }
}

class AppModalBodyText extends StatelessWidget {
  const AppModalBodyText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: const Color(0xFF667085),
        height: 1.15,
      ),
    );
  }
}

class AppModalButton extends StatefulWidget {
  const AppModalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.expanded = true,
    this.isLoading = false,
  });

  final String label;
  final FutureOr<void> Function()? onPressed;
  final bool isPrimary;
  final bool expanded;
  final bool isLoading;

  @override
  State<AppModalButton> createState() => _AppModalButtonState();
}

class _AppModalButtonState extends State<AppModalButton> {
  bool _internalLoading = false;

  Future<void> _handlePressed() async {
    if (_internalLoading || widget.isLoading || widget.onPressed == null) {
      return;
    }
    setState(() => _internalLoading = true);
    try {
      await Future<void>.sync(widget.onPressed!);
    } finally {
      if (mounted) {
        setState(() => _internalLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLoading = widget.isLoading || _internalLoading;
    final button = SizedBox(
      height: AppModalFrame.actionHeight,
      width: widget.expanded ? double.infinity : null,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: widget.isPrimary
              ? (showLoading
                    ? AppColors.logoBlue
                    : AppColors.logoBlue.withValues(alpha: 0.10))
              : const Color(0x1AE31E24),
          foregroundColor: widget.isPrimary
              ? (showLoading ? Colors.white : AppColors.logoBlue)
              : const Color(0xFFE31E24),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
          minimumSize: const Size(0, AppModalFrame.actionHeight),
          maximumSize: const Size(double.infinity, AppModalFrame.actionHeight),
          fixedSize: widget.expanded
              ? const Size(double.infinity, AppModalFrame.actionHeight)
              : null,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ).copyWith(overlayColor: WidgetStateProperty.all(Colors.transparent)),
        onPressed: showLoading ? null : _handlePressed,
        child: showLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.isPrimary ? Colors.white : const Color(0xFFE31E24),
                  ),
                ),
              )
            : Text(widget.label),
      ),
    );

    return widget.expanded ? Expanded(child: button) : button;
  }
}

class CartFab extends StatelessWidget {
  const CartFab({
    super.key,
    required this.itemCount,
    required this.totalCentavos,
    required this.onTap,
    this.fullWidth = false,
    this.horizontalMargin = 0,
  });

  final int itemCount;
  final int totalCentavos;
  final bool fullWidth;
  final double horizontalMargin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    final button = SizedBox(
      height: 56,
      width: fullWidth ? double.infinity : null,
      child: MousePressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(1000),
        stateBuilder: (context, hovered, pressed, child) {
          final states = <WidgetState>{
            if (hovered) WidgetState.hovered,
            if (pressed) WidgetState.pressed,
          };
          return Container(
            height: 56,
            width: fullWidth ? double.infinity : null,
            decoration: BoxDecoration(
              color: AppColors.brandingBlueInteractiveBackground(states),
              borderRadius: BorderRadius.circular(1000),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_cart_checkout, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'} • ${formatPesos(totalCentavos)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          );
        },
        child: const SizedBox.shrink(),
      ),
    );

    if (!fullWidth) {
      final additionalRightInset = horizontalMargin > 16
          ? horizontalMargin - 16
          : 0.0;
      return Padding(
        padding: EdgeInsets.only(right: additionalRightInset),
        child: button,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
      child: button,
    );
  }
}
