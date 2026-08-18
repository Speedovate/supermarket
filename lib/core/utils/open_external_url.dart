import 'package:url_launcher/url_launcher.dart';

Future<bool> openExternalUrl(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    return false;
  }

  final normalizedScheme = uri.scheme.toLowerCase();
  final supportedSchemes = {'http', 'https', 'sms', 'tel'};
  if (!supportedSchemes.contains(normalizedScheme)) {
    return false;
  }

  try {
    if (normalizedScheme == 'http' || normalizedScheme == 'https') {
      return await launchUrl(uri, webOnlyWindowName: '_blank');
    }

    return await launchUrl(uri);
  } catch (_) {
    return false;
  }
}
