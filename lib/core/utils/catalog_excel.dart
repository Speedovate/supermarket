import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';

import '../models/app_models.dart';

class ImportedCatalogWorkbook {
  const ImportedCatalogWorkbook({required this.products});

  final List<ImportedCatalogProductRow> products;
}

class ImportedCatalogProductRow {
  const ImportedCatalogProductRow({
    required this.name,
    required this.details,
    required this.categoryName,
    required this.priceCentavos,
    this.createdAt,
    this.updatedAt,
  });

  final String name;
  final String details;
  final String categoryName;
  final int priceCentavos;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class CatalogWorkbookException implements Exception {
  const CatalogWorkbookException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _productsSheetName = 'Products';

Uint8List buildCatalogWorkbook({
  required List<Category> categories,
  required List<Product> products,
}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null && defaultSheet != _productsSheetName) {
    excel.rename(defaultSheet, _productsSheetName);
  }
  final productsSheet = excel[_productsSheetName];
  final categoriesById = {
    for (final category in categories) category.id: category.name,
  };

  productsSheet.appendRow(_textRow(const [
    'name',
    'details',
    'category',
    'price',
    'sold',
    'created at',
    'updated at',
  ]));

  for (final product in products) {
    productsSheet.appendRow(_textRow([
      product.name,
      product.details,
      product.categoryId == 0 ? '' : (categoriesById[product.categoryId] ?? ''),
      _formatPricePesos(product.referencePriceCentavos),
      '${product.sold}',
      product.createdAt.toIso8601String(),
      product.updatedAt.toIso8601String(),
    ]));
  }

  final encoded = excel.encode();
  if (encoded == null) {
    throw const CatalogWorkbookException('Unable to build the Excel file.');
  }
  return Uint8List.fromList(encoded);
}

ImportedCatalogWorkbook parseCatalogWorkbook(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final workbookFile = archive.files.firstWhere(
      (file) => file.name == 'xl/workbook.xml',
      orElse: () => throw const CatalogWorkbookException(
        'The file is missing workbook.xml.',
      ),
    );
    final workbook = XmlDocument.parse(
      _archiveText(workbookFile),
    );
    final workbookRelsFile = archive.files.firstWhere(
      (file) => file.name == 'xl/_rels/workbook.xml.rels',
      orElse: () => throw const CatalogWorkbookException(
        'The file is missing workbook relationships.',
      ),
    );
    final workbookRels = XmlDocument.parse(
      _archiveText(workbookRelsFile),
    );
    final sheetPath = _resolveProductsSheetPath(
      workbook: workbook,
      workbookRels: workbookRels,
    );
    final sheetFile = archive.files.firstWhere(
      (file) => file.name == sheetPath,
      orElse: () => throw CatalogWorkbookException(
        'The file is missing $sheetPath.',
      ),
    );
    final sheetDocument = XmlDocument.parse(
      _archiveText(sheetFile),
    );
    final rows = _sheetRows(sheetDocument);
    if (rows.isEmpty) {
      throw const CatalogWorkbookException(
        'The file must contain a Products sheet with product rows.',
      );
    }

    final header = _headerMap(rows.first);
    _requireHeaders(header, const [
      'name',
      'details',
      'category',
      'price',
      'created at',
      'updated at',
    ]);
    final now = DateTime.now();
    final products = <ImportedCatalogProductRow>[];

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (_rowIsBlank(row)) {
        continue;
      }
      final name = _requiredText(row, header, 'name', rowIndex);
      final details = _requiredText(row, header, 'details', rowIndex);
      final createdAt =
          _optionalDateTime(row, header, 'created at') ?? now;
      final updatedAt =
          _optionalDateTime(row, header, 'updated at') ?? createdAt;
      products.add(
        ImportedCatalogProductRow(
          name: name,
          details: details,
          categoryName: (_optionalText(row, header, 'category') ?? '').trim(),
          priceCentavos: _requiredPriceCentavos(row, header, rowIndex),
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );
    }

    if (products.isEmpty) {
      throw const CatalogWorkbookException(
        'No product rows were found in the file.',
      );
    }

    return ImportedCatalogWorkbook(products: products);
  } on CatalogWorkbookException {
    rethrow;
  } catch (error) {
    throw CatalogWorkbookException(
      'Unable to parse the Excel file. ${error.toString().replaceFirst('Exception: ', '')}',
    );
  }
}

String _archiveText(ArchiveFile file) {
  final content = file.content;
  if (content is List<int>) {
    return String.fromCharCodes(content);
  }
  if (content is Uint8List) {
    return String.fromCharCodes(content);
  }
  throw const CatalogWorkbookException('Unable to read the Excel file contents.');
}

String _resolveProductsSheetPath({
  required XmlDocument workbook,
  required XmlDocument workbookRels,
}) {
  final sheets = _findElementsByLocalName(workbook, 'sheet');
  XmlElement? targetSheet;
  for (final sheet in sheets) {
    if ((sheet.getAttribute('name') ?? '').trim() == _productsSheetName) {
      targetSheet = sheet;
      break;
    }
  }
  targetSheet ??= sheets.isEmpty ? null : sheets.first;
  if (targetSheet == null) {
    throw const CatalogWorkbookException('The file does not contain any sheets.');
  }
  final relationshipId = targetSheet.getAttribute(
    'id',
    namespace:
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
  );
  if (relationshipId == null || relationshipId.trim().isEmpty) {
    throw const CatalogWorkbookException(
      'The Products sheet is missing a worksheet relationship id.',
    );
  }
  for (final relationship in _findElementsByLocalName(
    workbookRels,
    'Relationship',
  )) {
    if ((relationship.getAttribute('Id') ?? '').trim() != relationshipId) {
      continue;
    }
    final target = (relationship.getAttribute('Target') ?? '').trim();
    if (target.isEmpty) {
      break;
    }
    final normalized = target.startsWith('/')
        ? target.substring(1)
        : target.startsWith('xl/')
        ? target
        : 'xl/$target';
    return normalized;
  }
  throw CatalogWorkbookException(
    'Unable to resolve the Products sheet path for relationship $relationshipId.',
  );
}

List<List<_SheetCell>> _sheetRows(XmlDocument sheetDocument) {
  final rows = <List<_SheetCell>>[];
  for (final row in _findElementsByLocalName(sheetDocument, 'row')) {
    final cells = <_SheetCell>[];
    for (final cell in _childElementsByLocalName(row, 'c')) {
      final reference = cell.getAttribute('r') ?? '';
      final columnIndex = _columnIndexFromCellReference(reference);
      final cellType = cell.getAttribute('t') ?? '';
      String value = '';
      if (cellType == 'inlineStr') {
        value = _findElementsByLocalName(cell, 't')
            .map((item) => item.innerText)
            .join()
            .trim();
      } else {
        value = (_firstChildByLocalName(cell, 'v')?.innerText ?? '').trim();
      }
      cells.add(_SheetCell(columnIndex: columnIndex, value: value));
    }
    rows.add(cells);
  }
  return rows;
}

Iterable<XmlElement> _findElementsByLocalName(XmlNode node, String localName) {
  return node.descendants.whereType<XmlElement>().where(
    (element) => element.name.local == localName,
  );
}

Iterable<XmlElement> _childElementsByLocalName(XmlElement node, String localName) {
  return node.childElements.where((element) => element.name.local == localName);
}

XmlElement? _firstChildByLocalName(XmlElement node, String localName) {
  for (final child in node.childElements) {
    if (child.name.local == localName) {
      return child;
    }
  }
  return null;
}

int _columnIndexFromCellReference(String reference) {
  var total = 0;
  for (final codeUnit in reference.codeUnits) {
    final isUppercase = codeUnit >= 65 && codeUnit <= 90;
    final isLowercase = codeUnit >= 97 && codeUnit <= 122;
    if (!isUppercase && !isLowercase) {
      break;
    }
    final uppercase = isLowercase ? codeUnit - 32 : codeUnit;
    total = (total * 26) + (uppercase - 64);
  }
  return total == 0 ? 0 : total - 1;
}

List<CellValue?> _textRow(List<String> values) {
  return values.map<CellValue?>((value) => TextCellValue(value)).toList();
}

String _formatPricePesos(int centavos) {
  final pesos = centavos / 100;
  if (centavos % 100 == 0) {
    return pesos.toStringAsFixed(0);
  }
  if (centavos % 10 == 0) {
    return pesos.toStringAsFixed(1);
  }
  return pesos.toStringAsFixed(2);
}

Map<String, int> _headerMap(List<_SheetCell> headerRow) {
  final map = <String, int>{};
  for (final cell in headerRow) {
    final key = _normalizeHeader(cell.value);
    if (key.isNotEmpty) {
      map[key] = cell.columnIndex;
    }
  }
  return map;
}

void _requireHeaders(Map<String, int> headers, List<String> requiredHeaders) {
  final missing = requiredHeaders
      .where((header) => !headers.containsKey(_normalizeHeader(header)))
      .toList();
  if (missing.isEmpty) {
    return;
  }
  throw CatalogWorkbookException(
    'Missing required column${missing.length == 1 ? '' : 's'}: ${missing.join(', ')}.',
  );
}

String _normalizeHeader(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool _rowIsBlank(List<_SheetCell> row) {
  for (final cell in row) {
    if (cell.value.trim().isNotEmpty) {
      return false;
    }
  }
  return true;
}

String _requiredText(
  List<_SheetCell> row,
  Map<String, int> headers,
  String column,
  int rowIndex,
) {
  final value = _optionalText(row, headers, column);
  if (value == null || value.trim().isEmpty) {
    throw CatalogWorkbookException(
      'Products row ${rowIndex + 1}: $column is required.',
    );
  }
  return value.trim();
}

String? _optionalText(
  List<_SheetCell> row,
  Map<String, int> headers,
  String column,
) {
  final index = headers[_normalizeHeader(column)];
  if (index == null || index < 0) {
    return null;
  }
  final value = row
      .where((cell) => cell.columnIndex == index)
      .map((cell) => cell.value)
      .firstWhere((_) => true, orElse: () => '')
      .trim();
  return value.isEmpty ? null : value;
}

int _requiredPriceCentavos(
  List<_SheetCell> row,
  Map<String, int> headers,
  int rowIndex,
) {
  final raw = _optionalText(row, headers, 'price');
  final value = double.tryParse(raw ?? '');
  if (value == null) {
    throw CatalogWorkbookException(
      'Products row ${rowIndex + 1}: price must be a valid number.',
    );
  }
  return (value * 100).round();
}

DateTime? _optionalDateTime(
  List<_SheetCell> row,
  Map<String, int> headers,
  String column,
) {
  final raw = _optionalText(row, headers, column);
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw);
}

class _SheetCell {
  const _SheetCell({
    required this.columnIndex,
    required this.value,
  });

  final int columnIndex;
  final String value;
}
