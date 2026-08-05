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
final _orderThreadDateTime = DateFormat('MMM d, yyyy - h:mm a');
final _orderDate = DateFormat('MMM d, yyyy');
final _orderTime = DateFormat('h:mm a');

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
    OrderStatus.newRequest => 'Waiting',
    OrderStatus.underReview => 'Under Review',
    OrderStatus.awaitingCustomerConfirmation =>
      'Awaiting Customer Confirmation',
    OrderStatus.confirmed => 'Confirmed',
    OrderStatus.preparing => 'Preparing',
    OrderStatus.readyForPickup => 'Ready for Pickup',
    OrderStatus.outForDelivery => 'Out for Delivery',
    OrderStatus.completed => 'Completed',
    OrderStatus.cancelled => 'Cancelled',
    OrderStatus.rejected => 'Rejected',
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
