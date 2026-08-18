import '../constants/barangays.dart';
import '../models/app_models.dart';
import '../utils/formatters.dart';

const demoAdminEmail = 'admin@andrews.com';
const demoAdminPassword = 'password';
final _sampleCategoryBaseDate = DateTime(2026, 7, 24);
final _sampleProductBaseDate = DateTime(2026, 7, 26);
final _sampleBarangayBaseDate = DateTime(2026, 8, 1);
const sampleBestSellerProductIds = <int>[1, 2, 3, 4, 6, 9];

final sampleCategories = <Category>[
  Category(
    id: 1,
    name: 'Beverages',
    normalizedName: 'beverages',
    isActive: true,
    createdAt: _sampleCategoryBaseDate,
    updatedAt: _sampleCategoryBaseDate.add(const Duration(days: 1)),
  ),
  Category(
    id: 2,
    name: 'Snacks',
    normalizedName: 'snacks',
    isActive: true,
    createdAt: _sampleCategoryBaseDate.add(const Duration(days: 1)),
    updatedAt: _sampleCategoryBaseDate.add(const Duration(days: 2)),
  ),
  Category(
    id: 3,
    name: 'Canned Goods',
    normalizedName: 'canned goods',
    isActive: true,
    createdAt: _sampleCategoryBaseDate.add(const Duration(days: 2)),
    updatedAt: _sampleCategoryBaseDate.add(const Duration(days: 3)),
  ),
  Category(
    id: 4,
    name: 'Noodles',
    normalizedName: 'noodles',
    isActive: true,
    createdAt: _sampleCategoryBaseDate.add(const Duration(days: 3)),
    updatedAt: _sampleCategoryBaseDate.add(const Duration(days: 4)),
  ),
  Category(
    id: 5,
    name: 'Condiments',
    normalizedName: 'condiments',
    isActive: true,
    createdAt: _sampleCategoryBaseDate.add(const Duration(days: 4)),
    updatedAt: _sampleCategoryBaseDate.add(const Duration(days: 5)),
  ),
  Category(
    id: 6,
    name: 'Personal Care',
    normalizedName: 'personal care',
    isActive: true,
    createdAt: _sampleCategoryBaseDate.add(const Duration(days: 5)),
    updatedAt: _sampleCategoryBaseDate.add(const Duration(days: 6)),
  ),
  Category(
    id: 7,
    name: 'Household',
    normalizedName: 'household',
    isActive: true,
    createdAt: _sampleCategoryBaseDate.add(const Duration(days: 6)),
    updatedAt: _sampleCategoryBaseDate.add(const Duration(days: 7)),
  ),
];

final sampleProducts = <Product>[
  Product(
    id: 1,
    active: true,
    createdAt: _sampleProductBaseDate,
    updatedAt: _sampleProductBaseDate.add(const Duration(days: 1)),
    name: 'Purified Water',
    category: 1,
    details: '500mL bottle',
    price: 1200,
    sold: 0,
  ),
  Product(
    id: 2,
    active: true,
    createdAt: _sampleProductBaseDate.add(const Duration(days: 1)),
    updatedAt: _sampleProductBaseDate.add(const Duration(days: 2)),
    name: 'Corn Chips',
    category: 2,
    details: '100g pack',
    price: 1400,
    sold: 0,
  ),
  Product(
    id: 3,
    active: true,
    createdAt: _sampleProductBaseDate.add(const Duration(days: 2)),
    updatedAt: _sampleProductBaseDate.add(const Duration(days: 3)),
    name: 'Instant Coffee',
    category: 0,
    details: '50g pack',
    price: 2800,
    sold: 0,
  ),
  Product(
    id: 4,
    active: true,
    createdAt: _sampleProductBaseDate.add(const Duration(days: 3)),
    updatedAt: _sampleProductBaseDate.add(const Duration(days: 4)),
    name: 'Evaporated Milk',
    category: 3,
    details: '330g can',
    price: 3600,
    sold: 0,
  ),
  Product(
    id: 5,
    active: true,
    createdAt: _sampleProductBaseDate.add(const Duration(days: 4)),
    updatedAt: _sampleProductBaseDate.add(const Duration(days: 5)),
    name: 'Powdered Milk',
    category: 0,
    details: '1kg pack',
    price: 21500,
    sold: 0,
  ),
  Product(
    id: 6,
    active: true,
    createdAt: _sampleProductBaseDate.add(const Duration(days: 5)),
    updatedAt: _sampleProductBaseDate.add(const Duration(days: 6)),
    name: 'Pancit Canton',
    category: 4,
    details: '80g pack',
    price: 1850,
    sold: 0,
  ),
  Product(
    id: 7,
    active: true,
    createdAt: _sampleProductBaseDate.add(const Duration(days: 6)),
    updatedAt: _sampleProductBaseDate.add(const Duration(days: 7)),
    name: 'Toothpaste',
    category: 6,
    details: '150g tube',
    price: 9900,
    sold: 0,
  ),
  Product(
    id: 8,
    active: true,
    createdAt: _sampleProductBaseDate.add(const Duration(days: 7)),
    updatedAt: _sampleProductBaseDate.add(const Duration(days: 8)),
    name: 'Laundry Powder',
    category: 7,
    details: '1kg bag',
    price: 9200,
    sold: 0,
  ),
  Product(
    id: 9,
    active: true,
    createdAt: _sampleProductBaseDate.add(const Duration(days: 8)),
    updatedAt: _sampleProductBaseDate.add(const Duration(days: 9)),
    name: 'Cheese Puffs',
    category: 2,
    details: '180g pack',
    price: 2750,
    sold: 0,
  ),
  Product(
    id: 10,
    active: true,
    createdAt: _sampleProductBaseDate.add(const Duration(days: 9)),
    updatedAt: _sampleProductBaseDate.add(const Duration(days: 10)),
    name: 'Soy Sauce',
    category: 5,
    details: '1L bottle',
    price: 6500,
    sold: 0,
  ),
  Product(
    id: 11,
    active: true,
    createdAt: _sampleProductBaseDate.add(const Duration(days: 10)),
    updatedAt: _sampleProductBaseDate.add(const Duration(days: 11)),
    name: 'Dishwashing Liquid',
    category: 7,
    details: '500mL bottle',
    price: 8900,
    sold: 0,
  ),
  Product(
    id: 12,
    active: true,
    createdAt: _sampleProductBaseDate.add(const Duration(days: 11)),
    updatedAt: _sampleProductBaseDate.add(const Duration(days: 12)),
    name: 'Shampoo Sachet',
    category: 6,
    details: '12mL sachet',
    price: 750,
    sold: 0,
  ),
];

const sampleBanners = <AppBanner>[];

final sampleBarangays = List<Barangay>.generate(
  puertoPrincesaBarangays.length,
  (index) {
    final baseDate = _sampleBarangayBaseDate.add(Duration(days: index));
    return Barangay(
      id: index + 1,
      name: formatBarangayName(puertoPrincesaBarangays[index]),
      isActive: true,
      cutoffWeekday: DateTime.monday,
      cutoffMinutes: 5 * 60,
      createdAt: baseDate,
      updatedAt: baseDate,
    );
  },
);

const defaultPublicNotice =
    'Product availability and final prices will be confirmed by Andrew\'s Supermarket.';
