import 'package:intl/intl.dart';

import '../models/app_models.dart';

final _currency = NumberFormat.currency(
  locale: 'en_PH',
  symbol: 'PHP ',
  decimalDigits: 1,
);
final _currencyWhole = NumberFormat.currency(
  locale: 'en_PH',
  symbol: 'PHP ',
  decimalDigits: 0,
);
final _shortDate = DateFormat('MMM d, yyyy');
final _orderThreadDateTime = DateFormat('MMM d, yyyy - hh:mm:ss a');
final _orderDate = DateFormat('MMM d, yyyy');
final _orderTime = DateFormat('h:mm a');
final _orderTimeWithSeconds = DateFormat('hh:mm:ss a');
final _cutoffTime = DateFormat('hh:mm a');

String formatPesos(int centavos) {
  final pesos = centavos / 100;
  final hasDecimal = centavos % 100 != 0;
  final formatted = (hasDecimal ? _currency : _currencyWhole).format(pesos);
  return formatted.replaceFirst('PHP ', '₱');
}

String formatAsOfDate(DateTime date) => _shortDate.format(date);

String formatOrderThreadDateTime(DateTime date) => _orderThreadDateTime.format(date);

String formatOrderDate(DateTime date) => _orderDate.format(date);

String formatOrderTime(DateTime date) => _orderTime.format(date);

String formatOrderTimeWithSeconds(DateTime date) => _orderTimeWithSeconds.format(date);

String formatCompactCount(int value) {
  if (value < 1000) {
    return '$value';
  }
  if (value < 1000000) {
    final compactTenths = ((value / 1000) * 10).floor() / 10;
    final hasSuffix = value % 1000 != 0;
    final hasDecimal = compactTenths % 1 != 0;
    final formatted = hasDecimal
        ? compactTenths.toStringAsFixed(1)
        : compactTenths.toStringAsFixed(0);
    return '${formatted.replaceAll(RegExp(r'\\.0$'), '')}K${hasSuffix ? '+' : ''}';
  }
  final compactTenths = ((value / 1000000) * 10).floor() / 10;
  final hasSuffix = value % 1000000 != 0;
  final hasDecimal = compactTenths % 1 != 0;
  final formatted = hasDecimal
      ? compactTenths.toStringAsFixed(1)
      : compactTenths.toStringAsFixed(0);
  return '${formatted.replaceAll(RegExp(r'\\.0$'), '')}M${hasSuffix ? '+' : ''}';
}

String normalizePhoneNumber(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+63')) {
    return '+63${digits.replaceFirst('+63', '').replaceAll(RegExp(r'[^0-9]'), '')}';
  }
  final numeric = digits.replaceAll(RegExp(r'[^0-9]'), '');
  if (numeric.startsWith('63')) {
    return '+$numeric';
  }
  if (numeric.startsWith('09') && numeric.length == 11) {
    return '+63${numeric.substring(1)}';
  }
  return input.trim();
}

bool isValidPhilippineMobile(String input) {
  final normalized = normalizePhoneNumber(input);
  return RegExp(r'^(\+639\d{9}|09\d{9})$').hasMatch(normalized) ||
      RegExp(r'^\+639\d{9}$').hasMatch(normalized);
}

String displayFulfillment(FulfillmentMethod method) {
  return switch (method) {
    FulfillmentMethod.pickup => 'Pickup',
    FulfillmentMethod.delivery => 'Delivery',
  };
}

String displayStatus(OrderStatus status) {
  return switch (status) {
    OrderStatus.waiting => 'Waiting',
    OrderStatus.checking => 'Checking',
    OrderStatus.ready => 'Ready',
    OrderStatus.completed => 'Completed',
    OrderStatus.cancelled => 'Cancelled',
  };
}

String displayAvailability(AvailabilityStatus status) {
  return switch (status) {
    AvailabilityStatus.pending => 'Pending',
    AvailabilityStatus.available => 'Available',
    AvailabilityStatus.partiallyAvailable => 'Partially Available',
    AvailabilityStatus.unavailable => 'Unavailable',
    AvailabilityStatus.substituted => 'Substituted',
  };
}

String displayBarangayStatus(bool isActive) => isActive ? 'Active' : 'Inactive';

String formatBarangayName(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(_capitalizeBarangayToken)
      .join(' ');
}

String _capitalizeBarangayToken(String token) {
  return token
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) {
        final lower = part.toLowerCase();
        if (lower.length == 1) {
          return lower.toUpperCase();
        }
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join('-');
}

String displayWeekday(int weekday, {bool plural = false}) {
  final label = switch (weekday) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    DateTime.sunday => 'Sunday',
    _ => 'Monday',
  };
  return plural ? '${label}s' : label;
}

String formatCutoffTimeFromMinutes(int minutes) {
  final normalized = minutes.clamp(0, 1439);
  final value = DateTime(2026, 8, 16).add(Duration(minutes: normalized));
  return _cutoffTime.format(value).replaceFirst(' ', '\u00A0');
}

String formatBarangayCutoffSchedule(Barangay barangay) {
  return 'Cutoff on ${displayWeekday(barangay.cutoffWeekday, plural: true)} ${formatCutoffTimeFromMinutes(barangay.cutoffMinutes)}';
}

String formatBarangayCutoffValue(Barangay barangay) {
  return '${displayWeekday(barangay.cutoffWeekday, plural: true)}\u00A0${formatCutoffTimeFromMinutes(barangay.cutoffMinutes)}';
}
