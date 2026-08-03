import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';
import 'cart_view_model.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _barangayController;
  late final TextEditingController _addressController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(appControllerProvider).customerDraft;
    _nameController = TextEditingController(text: draft.name);
    _mobileController = TextEditingController(text: draft.mobileNumber);
    _barangayController = TextEditingController(text: draft.barangay);
    _addressController = TextEditingController(text: draft.addressLandmark);
    _noteController = TextEditingController(text: draft.note);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _barangayController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(cartViewModelProvider);
    final draft = vm.customerDraft;
    final isDesktop = MediaQuery.of(context).size.width >= 1040;

    return Scaffold(
      appBar: AppBar(title: const Text('Cart & Order Request')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: vm.cart.isEmpty
            ? Center(
                child: EmptyStateCard(
                  title: 'Your cart is empty',
                  message:
                      'Browse products and add items to build your order request.',
                  actionLabel: 'Continue shopping',
                  onAction: () => context.go('/'),
                ),
              )
            : Form(
                key: _formKey,
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _CustomerForm(
                              draft: draft,
                              controllers: _controllers,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: _CartSummary(
                              cart: vm.cart,
                              totalCentavos: vm.totalCentavos,
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        children: [
                          _CustomerForm(
                            draft: draft,
                            controllers: _controllers,
                          ),
                          const SizedBox(height: 20),
                          _CartSummary(
                            cart: vm.cart,
                            totalCentavos: vm.totalCentavos,
                          ),
                        ],
                      ),
              ),
      ),
      bottomNavigationBar: vm.cart.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: vm.submitting
                    ? null
                    : () async {
                        final current = _buildDraft(draft.fulfillmentMethod);
                        await ref
                            .read(appControllerProvider.notifier)
                            .updateCustomerDraft(current);
                        if (!context.mounted) {
                          return;
                        }
                        final error = ref
                            .read(appControllerProvider.notifier)
                            .validateCheckoutDraft(current);
                        if (error != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                          return;
                        }
                        context.push('/order-review');
                      },
                child: const Text('Review Order Request'),
              ),
            ),
    );
  }

  ({
    TextEditingController name,
    TextEditingController mobile,
    TextEditingController barangay,
    TextEditingController address,
    TextEditingController note,
  })
  get _controllers => (
    name: _nameController,
    mobile: _mobileController,
    barangay: _barangayController,
    address: _addressController,
    note: _noteController,
  );

  CustomerDraft _buildDraft(FulfillmentMethod method) {
    return CustomerDraft(
      name: _nameController.text,
      mobileNumber: _mobileController.text,
      normalizedMobileNumber: normalizePhoneNumber(_mobileController.text),
      barangay: _barangayController.text,
      addressLandmark: _addressController.text,
      note: _noteController.text,
      fulfillmentMethod: method,
    );
  }
}

class _CustomerForm extends ConsumerWidget {
  const _CustomerForm({required this.draft, required this.controllers});

  final CustomerDraft draft;
  final ({
    TextEditingController name,
    TextEditingController mobile,
    TextEditingController barangay,
    TextEditingController address,
    TextEditingController note,
  })
  controllers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Details',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: controllers.name,
            decoration: const InputDecoration(labelText: 'Customer name'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controllers.mobile,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Mobile number'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controllers.barangay,
            decoration: const InputDecoration(labelText: 'Barangay'),
          ),
          const SizedBox(height: 14),
          SegmentedButton<FulfillmentMethod>(
            segments: const [
              ButtonSegment(
                value: FulfillmentMethod.pickup,
                label: Text('Pickup'),
                icon: Icon(Icons.storefront_outlined),
              ),
              ButtonSegment(
                value: FulfillmentMethod.delivery,
                label: Text('Delivery'),
                icon: Icon(Icons.local_shipping_outlined),
              ),
            ],
            selected: {draft.fulfillmentMethod},
            onSelectionChanged: (selection) async {
              final method = selection.first;
              final current = ref
                  .read(appControllerProvider)
                  .customerDraft
                  .copyWith(fulfillmentMethod: method);
              await ref
                  .read(appControllerProvider.notifier)
                  .updateCustomerDraft(current);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controllers.address,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: draft.fulfillmentMethod == FulfillmentMethod.delivery
                  ? 'Address / landmark'
                  : 'Additional address / landmark (optional)',
              helperText: draft.fulfillmentMethod == FulfillmentMethod.delivery
                  ? 'Delivery availability and fee will be confirmed by the admin.'
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controllers.note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Customer note (optional)',
            ),
          ),
        ],
      ),
    );
  }
}

class _CartSummary extends ConsumerWidget {
  const _CartSummary({required this.cart, required this.totalCentavos});

  final List<CartItem> cart;
  final int totalCentavos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated Cart',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          for (final item in cart) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 72,
                  child: ProductPlaceholder(label: 'Product', height: 72),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(item.unit),
                      Text(formatPesos(item.referenceUnitPriceCentavos)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Decrease quantity',
                      onPressed: item.quantity > 1
                          ? () => ref
                                .read(appControllerProvider.notifier)
                                .updateCartQuantity(
                                  item.productId,
                                  item.quantity - 1,
                                )
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${item.quantity}'),
                    IconButton(
                      tooltip: 'Increase quantity',
                      onPressed: () => ref
                          .read(appControllerProvider.notifier)
                          .updateCartQuantity(
                            item.productId,
                            item.quantity + 1,
                          ),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'Remove item',
                      onPressed: () => ref
                          .read(appControllerProvider.notifier)
                          .removeFromCart(item.productId),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 28),
          ],
          Text(
            'Estimated total only. Availability and final quotation are subject to admin confirmation.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Estimated total',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                formatPesos(totalCentavos),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.logoBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
