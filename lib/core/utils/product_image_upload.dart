import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

const _maxProductImageDimension = 360;
const _initialProductImageQuality = 55;
const _minimumProductImageQuality = 28;
const _maxProductImageBytes = 120 * 1024;

Future<String?> pickCompressedProductImageDataUrl() async {
  final picker = ImagePicker();
  final file = await picker.pickImage(source: ImageSource.gallery);
  if (file == null) {
    return null;
  }

  final sourceBytes = await file.readAsBytes();
  final convertedBytes = _compressProductImage(sourceBytes);
  return 'data:image/jpeg;base64,${base64Encode(convertedBytes)}';
}

Uint8List _compressProductImage(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    return sourceBytes;
  }

  final needsResize =
      decoded.width > _maxProductImageDimension ||
      decoded.height > _maxProductImageDimension;
  final normalized = needsResize
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height
              ? _maxProductImageDimension
              : null,
          height: decoded.height > decoded.width
              ? _maxProductImageDimension
              : null,
          interpolation: img.Interpolation.average,
        )
      : decoded;

  var quality = _initialProductImageQuality;
  var encoded = Uint8List.fromList(img.encodeJpg(normalized, quality: quality));
  while (encoded.length > _maxProductImageBytes &&
      quality > _minimumProductImageQuality) {
    quality -= 6;
    encoded = Uint8List.fromList(img.encodeJpg(normalized, quality: quality));
  }

  return encoded;
}
