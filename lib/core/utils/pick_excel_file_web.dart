// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'pick_excel_file.dart';

Future<PickedExcelFile?> pickExcelFile() async {
  final completer = Completer<PickedExcelFile?>();
  final input = html.FileUploadInputElement()
    ..accept = '.xlsx,.xls,.xlsm,.xltx,.xltm'
    ..multiple = false;

  void completeNull() {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }

  input.onChange.first.then((_) {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      completeNull();
      return;
    }
    final reader = html.FileReader();
    reader.onLoad.first.then((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        if (!completer.isCompleted) {
          completer.complete(
            PickedExcelFile(
              name: file.name,
              bytes: Uint8List.view(result),
            ),
          );
        }
        return;
      }
      if (result is Uint8List) {
        if (!completer.isCompleted) {
          completer.complete(PickedExcelFile(name: file.name, bytes: result));
        }
        return;
      }
      completeNull();
    });
    reader.onError.first.then((_) => completeNull());
    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future.timeout(
    const Duration(minutes: 5),
    onTimeout: () => null,
  );
}
