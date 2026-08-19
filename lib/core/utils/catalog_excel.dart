import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/app_models.dart';

class ImportedCatalogWorkbook {
  const ImportedCatalogWorkbook({
    required this.categories,
    required this.products,
  });

  final List<Category> categories;
  final List<Product> products;
}

class CatalogWorkbookException implements Exception {
  const CatalogWorkbookException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _categoriesSheetName = 'Categories';
const _productsSheetName = 'Products';

Uint8List buildCatalogWorkbook({
  required List<Category> categories,
  required List<Product> products,
}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null && defaultSheet != _categoriesSheetName) {
    excel.rename(defaultSheet, _categoriesSheetName);
  }
  final categoriesSheet = excel[_categoriesSheetName];
  final productsSheet = excel[_productsSheetName];

  categoriesSheet.appendRow(_textRow(const [
    'id',
    'name',
    'status',
    'created_at',
    'updated_at',
  ]));
  for (final category in categories) {
    categoriesSheet.appendRow(_textRow([
      '${category.id}',
      category.name,
      category.isActive ? 'Active' : 'Inactive',
      category.createdAt.toIso8601String(),
      category.updatedAt.toIso8601String(),
    ]));
  }

  final categoriesById = {
    for (final category in categories) category.id: category.name,
  };
  productsSheet.appendRow(_textRow(const [
    'id',
    'name',
    'details',
    'category_id',
    'category_name',
    'price_pesos',
    'sold',
    'status',
    'photo_url',
    'photo_storage_path',
    'created_at',
    'updated_at',
  ]));
  for (final product in products) {
    productsSheet.appendRow(_textRow([
      '${product.id}',
      product.name,
      product.details,
      '${product.categoryId}',
      product.categoryId == 0 ? '' : (categoriesById[product.categoryId] ?? ''),
      _formatPricePesos(product.referencePriceCentavos),
      '${product.sold}',
      product.isActive ? 'Active' : 'Inactive',
      product.photoUrl ?? '',
      product.photoStoragePath ?? '',
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
  final categoriesSheet = excel.tables[_categoriesSheetName];
  final productsSheet = excel.tables[_productsSheetName];
  if (categoriesSheet == null || productsSheet == null) {
    throw const CatalogWorkbookException(
      'The file must contain Categories and Products sheets.',
    );
  }

  final categoriesHeader = _headerMap(categoriesSheet.rows.isEmpty ? const [] : categoriesSheet.rows.first);
  final productsHeader = _headerMap(productsSheet.rows.isEmpty ? const [] : productsSheet.rows.first);

  final now = DateTime.now();
  final categories = <Category>[];
  final categoryNamesById = <int, String>{};
  final categoryIds = <int>{};

  for (var rowIndex = 1; rowIndex < categoriesSheet.rows.length; rowIndex++) {
    final row = categoriesSheet.rows[rowIndex];
    if (_rowIsBlank(row)) {
      continue;
    }
    final id = _requiredInt(row, categoriesHeader, 'id', rowIndex, _categoriesSheetName);
    if (id <= 0) {
      throw CatalogWorkbookException(
        'Categories row ${rowIndex + 1}: id must be greater than 0.',
      );
    }
    if (!categoryIds.add(id)) {
      throw CatalogWorkbookException(
        'Categories row ${rowIndex + 1}: duplicate id $id.',
      );
    }
    final name = _requiredText(row, categoriesHeader, 'name', rowIndex, _categoriesSheetName);
    final createdAt = _optionalDateTime(row, categoriesHeader, 'created_at') ?? now;
    final updatedAt = _optionalDateTime(row, categoriesHeader, 'updated_at') ?? createdAt;
    final category = Category(
      id: id,
      name: name,
      normalizedName: name.trim().toLowerCase(),
      isActive: _optionalBool(row, categoriesHeader, 'status') ?? true,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    categories.add(category);
    categoryNamesById[id] = category.name;
  }

  final products = <Product>[];
  final productIds = <int>{};
  for (var rowIndex = 1; rowIndex < productsSheet.rows.length; rowIndex++) {
    final row = productsSheet.rows[rowIndex];
    if (_rowIsBlank(row)) {
      continue;
    }
    final id = _requiredInt(row, productsHeader, 'id', rowIndex, _productsSheetName);
    if (id <= 0) {
      throw CatalogWorkbookException(
        'Products row ${rowIndex + 1}: id must be greater than 0.',
      );
    }
    if (!productIds.add(id)) {
      throw CatalogWorkbookException(
        'Products row ${rowIndex + 1}: duplicate id $id.',
      );
    }
    final name = _requiredText(row, productsHeader, 'name', rowIndex, _productsSheetName);
    final details = _requiredText(row, productsHeader, 'details', rowIndex, _productsSheetName);
    final sold = _requiredInt(row, productsHeader, 'sold', rowIndex, _productsSheetName);
    final categoryId = _resolveProductCategoryId(
      row: row,
      headers: productsHeader,
      rowIndex: rowIndex,
      categoryNamesById: categoryNamesById,
    );
    if (categoryId != 0 && !categoryNamesById.containsKey(categoryId)) {
      throw CatalogWorkbookException(
        'Products row ${rowIndex + 1}: category_id $categoryId does not exist in Categories.',
      );
    }
    final createdAt = _optionalDateTime(row, productsHeader, 'created_at') ?? now;
    final updatedAt = _optionalDateTime(row, productsHeader, 'updated_at') ?? createdAt;
    products.add(
      Product(
        id: id,
        active: _optionalBool(row, productsHeader, 'status') ?? true,
        createdAt: createdAt,
        updatedAt: updatedAt,
        name: name,
        category: categoryId,
        details: details,
        price: _requiredPriceCentavos(row, productsHeader, rowIndex),
        sold: sold,
        photoUrl: _optionalText(row, productsHeader, 'photo_url'),
        photoStoragePath: _optionalText(row, productsHeader, 'photo_storage_path'),
      ),
    );
  }

  _validateStartsAtOne(categories: categories, products: products);

  return ImportedCatalogWorkbook(categories: categories, products: products);
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
    final key = _cellText(headerRow[index]).trim().toLowerCase();
    if (key.isNotEmpty) {
      map[key] = index;
    }
  }
  return map;
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
  String sheet,
) {
  final value = _optionalText(row, headers, column);
  if (value == null || value.trim().isEmpty) {
    throw CatalogWorkbookException(
      '$sheet row ${rowIndex + 1}: $column is required.',
    );
  }
  return value.trim();
}

String? _optionalText(List<Data?> row, Map<String, int> headers, String column) {
  final index = headers[column];
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
  String sheet,
) {
  final raw = _optionalText(row, headers, column);
  final value = int.tryParse(raw ?? '');
  if (value == null) {
    throw CatalogWorkbookException(
      '$sheet row ${rowIndex + 1}: $column must be a whole number.',
    );
  }
  return value;
}

int _requiredPriceCentavos(
  List<Data?> row,
  Map<String, int> headers,
  int rowIndex,
) {
  final raw = _optionalText(row, headers, 'price_pesos');
  final value = double.tryParse(raw ?? '');
  if (value == null) {
    throw CatalogWorkbookException(
      'Products row ${rowIndex + 1}: price_pesos must be a valid number.',
    );
  }
  return (value * 100).round();
}

bool? _optionalBool(List<Data?> row, Map<String, int> headers, String column) {
  final raw = _optionalText(row, headers, column)?.toLowerCase();
  if (raw == null) {
    return null;
  }
  switch (raw) {
    case 'true':
    case 'active':
    case '1':
    case 'yes':
      return true;
    case 'false':
    case 'inactive':
    case '0':
    case 'no':
      return false;
  }
  return null;
}

DateTime? _optionalDateTime(List<Data?> row, Map<String, int> headers, String column) {
  final raw = _optionalText(row, headers, column);
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw);
}

int _resolveProductCategoryId({
  required List<Data?> row,
  required Map<String, int> headers,
  required int rowIndex,
  required Map<int, String> categoryNamesById,
}) {
  final categoryIdText = _optionalText(row, headers, 'category_id');
  if (categoryIdText != null && categoryIdText.trim().isNotEmpty) {
    final parsedId = int.tryParse(categoryIdText.trim());
    if (parsedId == null) {
      throw CatalogWorkbookException(
        'Products row ${rowIndex + 1}: category_id must be a whole number.',
      );
    }
    return parsedId;
  }
  final categoryName = _optionalText(row, headers, 'category_name');
  if (categoryName == null || categoryName.trim().isEmpty) {
    return 0;
  }
  final normalized = categoryName.trim().toLowerCase();
  for (final entry in categoryNamesById.entries) {
    if (entry.value.trim().toLowerCase() == normalized) {
      return entry.key;
    }
  }
  throw CatalogWorkbookException(
    'Products row ${rowIndex + 1}: category_name "$categoryName" does not exist in Categories.',
  );
}

void _validateStartsAtOne({
  required List<Category> categories,
  required List<Product> products,
}) {
  if (categories.isNotEmpty && categories.map((item) => item.id).reduce((a, b) => a < b ? a : b) != 1) {
    throw const CatalogWorkbookException('Categories ids must start at 1.');
  }
  if (products.isNotEmpty && products.map((item) => item.id).reduce((a, b) => a < b ? a : b) != 1) {
    throw const CatalogWorkbookException('Products ids must start at 1.');
  }
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
