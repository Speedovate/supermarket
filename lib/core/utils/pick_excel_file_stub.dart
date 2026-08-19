import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'pick_excel_file.dart';

Future<PickedExcelFile?> pickExcelFile() async {
  final picked = await FilePicker.platform.pickFiles(
    dialogTitle: 'Select Products Excel File',
    type: FileType.custom,
    allowedExtensions: const [
      'xlsx',
      'xls',
      'xlsm',
      'xltx',
      'xltm',
    ],
    withData: true,
  );
  final file = picked?.files.singleOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) {
    return null;
  }
  return PickedExcelFile(
    name: file.name,
    bytes: Uint8List.fromList(bytes),
  );
}
