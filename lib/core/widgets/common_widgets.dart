import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_models.dart';
import '../utils/formatters.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.compact = false, this.onDark = false});

  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final mainStyle = GoogleFonts.inter(
      textStyle: Theme.of(context).textTheme.titleLarge,
      fontWeight: FontWeight.w800,
      color: onDark ? Colors.white : const Color(0xFF172A91),
      height: 1,
      fontSize: compact ? 20 : 28,
    );
    final subStyle = GoogleFonts.inter(
      textStyle: Theme.of(context).textTheme.titleMedium,
      fontWeight: FontWeight.w800,
      color: onDark ? const Color(0xFFFFB9BD) : const Color(0xFFE31E24),
      height: 1,
      fontSize: compact ? 13 : 19.5,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: compact ? 44 : 66,
          decoration: BoxDecoration(color: Colors.white),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/branding/andrews_logo.png',
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
  });

  final String label;
  final double height;
  final bool posterMode;
  final bool fullRounded;
  final Color backgroundColor;

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
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Image.asset(
            'assets/branding/andrews_logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.newRequest => const Color(0xFFFFA726),
      OrderStatus.underReview => const Color(0xFF42A5F5),
      OrderStatus.awaitingCustomerConfirmation => const Color(0xFF8E24AA),
      OrderStatus.confirmed => const Color(0xFF43A047),
      OrderStatus.preparing => const Color(0xFF1E88E5),
      OrderStatus.readyForPickup => const Color(0xFF00897B),
      OrderStatus.outForDelivery => const Color(0xFF5E35B1),
      OrderStatus.completed => const Color(0xFF2E7D32),
      OrderStatus.cancelled => const Color(0xFFE53935),
      OrderStatus.rejected => const Color(0xFFB71C1C),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          displayStatus(status),
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
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
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x12172A91), blurRadius: 18)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 42,
              color: Color(0xFF2439B8),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
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
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x12172A91), blurRadius: 18)],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class CartFab extends StatelessWidget {
  const CartFab({
    super.key,
    required this.itemCount,
    required this.totalCentavos,
  });

  final int itemCount;
  final int totalCentavos;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.extended(
      onPressed: () => context.push('/cart'),
      backgroundColor: const Color(0xFF2439B8),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.shopping_cart_checkout),
      label: Text(
        '$itemCount item${itemCount == 1 ? '' : 's'} • ${formatPesos(totalCentavos)}',
      ),
    );
  }
}
