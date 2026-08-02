import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../app_state/app_controller.dart';

class CartViewModelState {
  const CartViewModelState({
    required this.cart,
    required this.totalCentavos,
    required this.customerDraft,
    required this.submitting,
  });

  final List<CartItem> cart;
  final int totalCentavos;
  final CustomerDraft customerDraft;
  final bool submitting;
}

final cartViewModelProvider = Provider<CartViewModelState>((ref) {
  final app = ref.watch(appControllerProvider);
  return CartViewModelState(
    cart: app.cart,
    totalCentavos: app.cartTotalCentavos,
    customerDraft: app.customerDraft,
    submitting: app.submittingOrder,
  );
});
