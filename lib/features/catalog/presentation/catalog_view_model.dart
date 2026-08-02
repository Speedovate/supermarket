import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../app_state/app_controller.dart';

class CatalogViewModelState {
  const CatalogViewModelState({
    required this.categories,
    required this.bestSellers,
    required this.cartCount,
    required this.cartTotalCentavos,
    required this.publicNotice,
  });

  final List<Category> categories;
  final List<Product> bestSellers;
  final int cartCount;
  final int cartTotalCentavos;
  final String publicNotice;
}

final catalogViewModelProvider = Provider<CatalogViewModelState>((ref) {
  final app = ref.watch(appControllerProvider);
  final controller = ref.watch(appControllerProvider.notifier);
  return CatalogViewModelState(
    categories: controller.publicCategories,
    bestSellers: controller.bestSellerProducts,
    cartCount: app.cartCount,
    cartTotalCentavos: app.cartTotalCentavos,
    publicNotice:
        'Product availability and final prices will be confirmed by Andrew\'s Supermarket.',
  );
});
