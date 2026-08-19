import 'pick_excel_file_stub.dart'
    if (dart.library.html) 'pick_excel_file_web.dart' as impl;

class PickedExcelFile {
  const PickedExcelFile({
    required this.name,
    required this.bytes,
  });

  final String name;
  final List<int> bytes;
}

Future<PickedExcelFile?> pickExcelFile() {
  return impl.pickExcelFile();
}
