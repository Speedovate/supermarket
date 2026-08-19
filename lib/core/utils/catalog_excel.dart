import 'dart:typed_data';

import 'package:excel/excel.dart';

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
    required this.sold,
    this.createdAt,
    this.updatedAt,
  });

  final String name;
  final String details;
  final String categoryName;
  final int priceCentavos;
  final int sold;
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
  final excel = Excel.decodeBytes(bytes);
  final productsSheet = excel.tables[_productsSheetName] ??
      (excel.tables.isEmpty ? null : excel.tables.values.first);
  if (productsSheet == null || productsSheet.rows.isEmpty) {
    throw const CatalogWorkbookException(
      'The file must contain a Products sheet with product rows.',
    );
  }

  final header = _headerMap(productsSheet.rows.first);
  final now = DateTime.now();
  final products = <ImportedCatalogProductRow>[];

  for (var rowIndex = 1; rowIndex < productsSheet.rows.length; rowIndex++) {
    final row = productsSheet.rows[rowIndex];
    if (_rowIsBlank(row)) {
      continue;
    }
    final name = _requiredText(row, header, 'name', rowIndex);
    final details = _requiredText(row, header, 'details', rowIndex);
    final sold = _requiredInt(row, header, 'sold', rowIndex);
    final createdAt = _optionalDateTime(row, header, 'created at') ?? now;
    final updatedAt = _optionalDateTime(row, header, 'updated at') ?? createdAt;
    products.add(
      ImportedCatalogProductRow(
        name: name,
        details: details,
        categoryName: (_optionalText(row, header, 'category') ?? '').trim(),
        priceCentavos: _requiredPriceCentavos(row, header, rowIndex),
        sold: sold,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
  }

  if (products.isEmpty) {
    throw const CatalogWorkbookException('No product rows were found in the file.');
  }

  return ImportedCatalogWorkbook(products: products);
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

Map<String, int> _headerMap(List<Data?> headerRow) {
  final map = <String, int>{};
  for (var index = 0; index < headerRow.length; index++) {
    final key = _normalizeHeader(_cellText(headerRow[index]));
    if (key.isNotEmpty) {
      map[key] = index;
    }
  }
  return map;
}

String _normalizeHeader(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool _rowIsBlank(List<Data?> row) {
  for (final cell in row) {
    if (_cellText(cell).trim().isNotEmpty) {
      return false;
    }
  }
  return true;
}

String _requiredText(
  List<Data?> row,
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

String? _optionalText(List<Data?> row, Map<String, int> headers, String column) {
  final index = headers[_normalizeHeader(column)];
  if (index == null || index < 0 || index >= row.length) {
    return null;
  }
  final value = _cellText(row[index]).trim();
  return value.isEmpty ? null : value;
}

int _requiredInt(
  List<Data?> row,
  Map<String, int> headers,
  String column,
  int rowIndex,
) {
  final raw = _optionalText(row, headers, column);
  final value = int.tryParse(raw ?? '');
  if (value == null) {
    throw CatalogWorkbookException(
      'Products row ${rowIndex + 1}: $column must be a whole number.',
    );
  }
  return value;
}

int _requiredPriceCentavos(
  List<Data?> row,
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
  List<Data?> row,
  Map<String, int> headers,
  String column,
) {
  final raw = _optionalText(row, headers, column);
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw);
}

String _cellText(Data? cell) {
  final value = cell?.value;
  return switch (value) {
    null => '',
    TextCellValue() => value.value.text ?? '',
    IntCellValue() => '${value.value}',
    DoubleCellValue() => '${value.value}',
    BoolCellValue() => value.value ? 'true' : 'false',
    DateCellValue() => value.asDateTimeUtc().toIso8601String(),
    DateTimeCellValue() => value.asDateTimeUtc().toIso8601String(),
    TimeCellValue() => value.toString(),
    FormulaCellValue() => value.formula,
  };
}
