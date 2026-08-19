import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/firebase_paths.dart';

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);

final firebaseProductImageStorageServiceProvider =
    Provider<FirebaseProductImageStorageService>(
      (ref) => FirebaseProductImageStorageService(
        ref.read(firebaseStorageProvider),
      ),
    );

class FirebaseProductImageUploadResult {
  const FirebaseProductImageUploadResult({
    required this.storagePath,
    required this.downloadUrl,
  });

  final String storagePath;
  final String downloadUrl;
}

class FirebaseProductImageStorageService {
  FirebaseProductImageStorageService(this._storage);

  final FirebaseStorage _storage;

  Future<FirebaseProductImageUploadResult> uploadProductImageDataUrl({
    required int productId,
    required String dataUrl,
  }) async {
    final decoded = _decodeDataUrl(dataUrl);
    if (decoded == null) {
      throw const FormatException('Invalid image data URL.');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _fileExtensionForMime(decoded.mimeType);
    final storagePath =
        '${FirebasePaths.productImages}/$productId/product_$timestamp.$extension';
    final ref = _storage.ref(storagePath);

    await ref.putData(
      decoded.bytes,
      SettableMetadata(
        contentType: decoded.mimeType,
        cacheControl: 'public,max-age=31536000,immutable',
      ),
    );

    return FirebaseProductImageUploadResult(
      storagePath: storagePath,
      downloadUrl: await ref.getDownloadURL(),
    );
  }

  Future<void> deleteByPath(String? storagePath) async {
    final trimmed = storagePath?.trim() ?? '';
    if (trimmed.isEmpty) {
      return;
    }
    await _storage.ref(trimmed).delete();
  }

  _DecodedDataUrl? _decodeDataUrl(String value) {
    final match = RegExp(r'^data:(image/[^;]+);base64,(.+)$').firstMatch(value);
    if (match == null) {
      return null;
    }

    try {
      return _DecodedDataUrl(
        mimeType: match.group(1)!,
        bytes: base64Decode(match.group(2)!),
      );
    } catch (_) {
      return null;
    }
  }

  String _fileExtensionForMime(String mimeType) {
    return switch (mimeType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      _ => 'jpg',
    };
  }
}

class _DecodedDataUrl {
  const _DecodedDataUrl({
    required this.mimeType,
    required this.bytes,
  });

  final String mimeType;
  final Uint8List bytes;
}
