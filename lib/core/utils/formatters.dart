import 'package:intl/intl.dart';

import '../models/app_models.dart';

final _pesoValue = NumberFormat('#,##0.##', 'en_PH');
final _shortDate = DateFormat('MMM d, yyyy');
final _orderThreadDateTime = DateFormat('MMM d, yyyy - hh:mm:ss a');
final _orderDate = DateFormat('MMM d, yyyy');
final _orderTime = DateFormat('h:mm a');
final _orderTimeWithSeconds = DateFormat('hh:mm:ss a');
final _cutoffTime = DateFormat('hh:mm a');

/// Matches the forgiving product-style searches used throughout the app.
/// It accepts case, spacing, punctuation, common abbreviations, missing
/// characters, and small spelling mistakes without changing remote queries.
bool matchesLenientSearch(String query, Iterable<String> candidates) {
  final normalizedQuery = _normalizeSearchText(query);
  if (normalizedQuery.compact.isEmpty) {
    return true;
  }

  for (final candidate in candidates) {
    final normalizedCandidate = _normalizeSearchText(candidate);
    if (normalizedCandidate.compact.contains(normalizedQuery.compact)) {
      return true;
    }
    if (_containsFuzzySearchPhrase(
      normalizedQuery.compact,
      normalizedCandidate.compact,
    )) {
      return true;
    }
    if (normalizedQuery.tokens.isNotEmpty &&
        normalizedQuery.tokens.every(
          (queryToken) => normalizedCandidate.tokens.any(
            (candidateToken) => _matchesSearchToken(queryToken, candidateToken),
          ),
        )) {
      return true;
    }
  }
  return false;
}

({String compact, List<String> tokens}) _normalizeSearchText(String value) {
  const abbreviations = <String, String>{
    'sta': 'santa',
    'sto': 'santo',
    'pck': 'pack',
    'sk': 'sack',
    'sck': 'sack',
  };
  final tokens = value
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.isNotEmpty)
      .map((token) => abbreviations[token] ?? _expandPackagingShorthand(token))
      .toList();
  return (compact: tokens.join(), tokens: tokens);
}

String _expandPackagingShorthand(String token) {
  return token
      .replaceFirst(RegExp(r'^pck(?=\d|$)'), 'pack')
      .replaceFirst(RegExp(r'^(?:sck|sk)(?=\d|$)'), 'sack');
}

bool _matchesSearchToken(String queryToken, String candidateToken) {
  if (candidateToken.contains(queryToken) ||
      queryToken.contains(candidateToken)) {
    return true;
  }
  if (queryToken.length >= 3 &&
      candidateToken.length >= queryToken.length &&
      _isSubsequence(queryToken, candidateToken)) {
    return true;
  }
  if (queryToken.length < 3 || candidateToken.length < 3) {
    return false;
  }
  final allowedDistance = queryToken.length <= 5 ? 1 : 2;
  if ((queryToken.length - candidateToken.length).abs() > allowedDistance) {
    return false;
  }
  return _levenshteinDistance(queryToken, candidateToken) <= allowedDistance;
}

bool _isSubsequence(String query, String candidate) {
  var queryIndex = 0;
  for (
    var candidateIndex = 0;
    candidateIndex < candidate.length && queryIndex < query.length;
    candidateIndex++
  ) {
    if (query.codeUnitAt(queryIndex) == candidate.codeUnitAt(candidateIndex)) {
      queryIndex++;
    }
  }
  return queryIndex == query.length;
}

int _levenshteinDistance(String first, String second) {
  var previous = List<int>.generate(second.length + 1, (index) => index);
  for (var firstIndex = 0; firstIndex < first.length; firstIndex++) {
    final current = <int>[firstIndex + 1];
    for (var secondIndex = 0; secondIndex < second.length; secondIndex++) {
      final substitutionCost =
          first.codeUnitAt(firstIndex) == second.codeUnitAt(secondIndex)
          ? 0
          : 1;
      current.add(
        [
          current[secondIndex] + 1,
          previous[secondIndex + 1] + 1,
          previous[secondIndex] + substitutionCost,
        ].reduce((lowest, value) => lowest < value ? lowest : value),
      );
    }
    previous = current;
  }
  return previous.last;
}

bool _containsFuzzySearchPhrase(String query, String candidate) {
  if (query.length < 6 || candidate.length < 6) {
    return false;
  }
  final allowedDistance = query.length <= 5
      ? 1
      : query.length <= 9
      ? 2
      : 3;
  final minLength = (query.length - allowedDistance).clamp(1, candidate.length);
  final maxLength = (query.length + allowedDistance).clamp(1, candidate.length);
  for (var start = 0; start < candidate.length; start++) {
    for (var length = minLength; length <= maxLength; length++) {
      final end = start + length;
      if (end > candidate.length) {
        break;
      }
      if (_levenshteinDistance(query, candidate.substring(start, end)) <=
          allowedDistance) {
        return true;
      }
    }
  }
  return false;
}

String formatPesosValue(int centavos) {
  final pesos = centavos / 100;
  return _pesoValue.format(pesos);
}

int? parsePesosValueToCentavos(String input) {
  final normalized = input.trim().replaceAll(',', '');
  if (normalized.isEmpty) {
    return 0;
  }
  final value = double.tryParse(normalized);
  if (value == null) {
    return null;
  }
  return (value * 100).round();
}

String formatPesos(int centavos) {
  return '₱${formatPesosValue(centavos)}';
}

String formatAsOfDate(DateTime date) => _shortDate.format(date);

String formatOrderThreadDateTime(DateTime date) =>
    _orderThreadDateTime.format(date);

String formatOrderDate(DateTime date) => _orderDate.format(date);

String formatOrderTime(DateTime date) => _orderTime.format(date);

String formatOrderTimeWithSeconds(DateTime date) =>
    _orderTimeWithSeconds.format(date);

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
  return 'Cutoff on ${displayWeekday(barangay.cutoffWeekday, plural: true)} ${formatCutoffTimeFromMinutes(barangay.cutoffMinutes)}.';
}

String formatBarangayCutoffValue(Barangay barangay) {
  return '${displayWeekday(barangay.cutoffWeekday, plural: true)}\u00A0${formatCutoffTimeFromMinutes(barangay.cutoffMinutes)}';
}
