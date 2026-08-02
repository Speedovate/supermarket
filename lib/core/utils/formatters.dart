import 'package:intl/intl.dart';

import '../models/app_models.dart';

final _currency = NumberFormat.currency(
  locale: 'en_PH',
  symbol: 'PHP ',
  decimalDigits: 2,
);
final _shortDate = DateFormat('MMM d, yyyy');

String formatPesos(int centavos) =>
    _currency.format(centavos / 100).replaceFirst('PHP ', '₱');

String formatAsOfDate(DateTime date) => _shortDate.format(date);

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
    OrderStatus.newRequest => 'New Request',
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
