Future<void> downloadBytes({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('File download is only supported on web.');
}
