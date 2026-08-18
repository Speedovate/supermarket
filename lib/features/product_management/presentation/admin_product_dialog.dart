import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/product_image_upload.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

String _formatEditablePrice(int priceCentavos) {
  final pesos = priceCentavos / 100;
  if (priceCentavos % 100 == 0) {
    return pesos.toStringAsFixed(0);
  }
  if (priceCentavos % 10 == 0) {
    return pesos.toStringAsFixed(1);
  }
  return pesos.toStringAsFixed(2);
}

Future<Product?> showAdminProductDialog(
  BuildContext context,
  WidgetRef ref, {
  Product? initial,
}) async {
  final state = ref.read(appControllerProvider);
  final categories = state.categories.toList();
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: initial?.name ?? '');
  final detailsController = TextEditingController(text: initial?.details ?? '');
  final priceController = TextEditingController(
    text: initial == null
        ? ''
        : _formatEditablePrice(initial.referencePriceCentavos),
  );
  final soldController = TextEditingController(
    text: initial == null ? '' : '${initial.sold}',
  );
  int? selectedCategory = initial?.categoryId;
  if (selectedCategory == null && categories.isNotEmpty) {
    selectedCategory = categories.first.id;
  }
  var isActive = initial?.isActive ?? true;
  var isSubmitting = false;
  var isPickingImage = false;
  String? photoUrl = initial?.photoUrl;

  Future<void> submit(BuildContext dialogContext) async {
    if (isSubmitting || isPickingImage) {
      return;
    }
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }
    isSubmitting = true;
    try {
      final parsedPrice =
          (double.tryParse(priceController.text.trim()) ?? 0) * 100;
      final parsedSold = int.tryParse(soldController.text.trim()) ?? 0;
      final product = Product(
        active: isActive,
        createdAt: initial?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        id:
            initial?.id ??
            ((state.products
                    .map((item) => item.id)
                    .fold<int>(0, (max, value) => value > max ? value : max)) +
                1),
        name: nameController.text.trim(),
        category: selectedCategory!,
        details: detailsController.text.trim(),
        price: parsedPrice.round(),
        sold: parsedSold,
        photoUrl: photoUrl,
        photoStoragePath: initial?.photoStoragePath,
      );
      await ref.read(appControllerProvider.notifier).saveProduct(product);
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop(product);
      }
    } finally {
      isSubmitting = false;
    }
  }

  final result = await showDialog<Product>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickImage() async {
            if (isSubmitting || isPickingImage) {
              return;
            }
            setState(() => isPickingImage = true);
            try {
              final pickedImage = await pickCompressedProductImageDataUrl();
              if (pickedImage == null) {
                return;
              }
              setState(() => photoUrl = pickedImage);
            } catch (_) {
              if (dialogContext.mounted) {
                final messenger = ScaffoldMessenger.of(dialogContext);
                messenger.clearSnackBars();
                messenger.showSnackBar(
                  errorSnackBar('Unable to upload image. Please try again.'),
                );
              }
            } finally {
              if (dialogContext.mounted) {
                setState(() => isPickingImage = false);
              } else {
                isPickingImage = false;
              }
            }
          }

          return AppModalFrame(
            title: initial == null ? 'New Product' : 'Edit Product',
            onSubmit: () {
              submit(dialogContext);
            },
            actions: [
              AppModalButton(
                label: 'Close',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              const SizedBox(width: 10),
              AppModalButton(
                label: 'Save',
                isPrimary: true,
                onPressed: () => submit(dialogContext),
              ),
            ],
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    Center(
                      child: SizedBox(
                        width: 136,
                        height: 136,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE4E7EC)),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: ProductPlaceholder(
                            label: nameController.text.trim().isEmpty
                                ? 'Product'
                                : nameController.text.trim(),
                            imageUrl: photoUrl,
                            fullRounded: true,
                            imageFit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    MousePressable(
                      onTap: isPickingImage ? null : pickImage,
                      borderRadius: BorderRadius.circular(16),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: const Icon(
                                  Icons.upload_rounded,
                                  size: 18,
                                  color: AppColors.logoBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: Text(
                          photoUrl == null ? 'Upload Image' : 'Change Image',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFF172033),
                                height: 1.15,
                              ),
                        ),
                      ),
                    ),
                    if (photoUrl != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tap the field to replace the image.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF667085),
                          height: 1.15,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => submit(dialogContext),
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) {
                          return 'Name is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: categories
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedCategory = value),
                      validator: (value) {
                        if (value == null) {
                          return 'Category is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: detailsController,
                      onFieldSubmitted: (_) => submit(dialogContext),
                      decoration: const InputDecoration(
                        labelText: 'Details',
                        hintText: '500mL bottle',
                      ),
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) {
                          return 'Details are required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceController,
                      onFieldSubmitted: (_) => submit(dialogContext),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        hintText: 'PHP',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Price is required.';
                        }
                        final parsed = double.tryParse(text);
                        if (parsed == null) {
                          return 'Enter a valid price.';
                        }
                        if (parsed <= 0) {
                          return 'Price must be greater than 0.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: soldController,
                      onFieldSubmitted: (_) => submit(dialogContext),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sold',
                        hintText: '0',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Sold is required.';
                        }
                        final parsed = int.tryParse(text);
                        if (parsed == null) {
                          return 'Enter a valid sold value.';
                        }
                        if (parsed < 0) {
                          return 'Sold cannot be negative.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -4),
                      contentPadding: EdgeInsets.zero,
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return null;
                      }),
                      trackColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.statusActiveGreen;
                        }
                        return null;
                      }),
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: (value) => setState(() => isActive = value),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    nameController.dispose();
    detailsController.dispose();
    priceController.dispose();
    soldController.dispose();
  });

  return result;
}
