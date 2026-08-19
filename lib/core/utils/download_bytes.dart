import 'download_bytes_stub.dart'
    if (dart.library.html) 'download_bytes_web.dart' as impl;

Future<void> downloadBytes({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) {
  return impl.downloadBytes(bytes: bytes, fileName: fileName, mimeType: mimeType);
}
