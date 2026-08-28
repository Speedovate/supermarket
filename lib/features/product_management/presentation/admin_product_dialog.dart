import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/firebase_firestore_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/product_image_upload.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

String _formatEditablePrice(int priceCentavos) {
  return formatPesosValue(priceCentavos);
}

Future<Product?> showAdminProductDialog(
  BuildContext context,
  WidgetRef ref, {
  Product? initial,
}) async {
  final state = ref.read(appControllerProvider);
  final categories = state.categories.toList()
    ..sort((a, b) {
      final nameCompare = a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      );
      if (nameCompare != 0) {
        return nameCompare;
      }
      return a.id.compareTo(b.id);
    });
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: initial?.name ?? '');
  final detailsController = TextEditingController(text: initial?.details ?? '');
  final priceController = TextEditingController(
    text: initial == null
        ? ''
        : _formatEditablePrice(initial.referencePriceCentavos),
  );
  int? selectedCategory = initial?.categoryId == 0 ? null : initial?.categoryId;
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
          parsePesosValueToCentavos(priceController.text.trim()) ?? 0;
      final fallbackNextProductId =
          (state.products
                  .map((item) => item.id)
                  .fold<int>(0, (max, value) => value > max ? value : max)) +
              1;
      final resolvedProductId =
          initial?.id ??
          await ref
              .read(firestoreCatalogServiceProvider)
              .reserveNextProductId(
                fallbackNextProductId: fallbackNextProductId,
              );
      final product = Product(
        active: isActive,
        createdAt: initial?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        id: resolvedProductId,
        name: nameController.text.trim(),
        category: selectedCategory ?? 0,
        details: detailsController.text.trim(),
        price: parsedPrice,
        sold: initial?.sold ?? 0,
        photoUrl: photoUrl,
        photoStoragePath: initial?.photoStoragePath,
      );
      await ref.read(appControllerProvider.notifier).saveProduct(product);
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop(product);
      }
    } catch (error) {
      if (dialogContext.mounted) {
        final messenger = ScaffoldMessenger.of(dialogContext);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          errorSnackBar(
            '$error'
                .replaceFirst('Bad state: ', '')
                .replaceFirst('Exception: ', ''),
          ),
        );
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
                            imageFit: BoxFit.cover,
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
                    DropdownButtonFormField<int?>(
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        hintText: 'Category',
                        suffixIcon: selectedCategory == null
                            ? null
                            : IconButton(
                                tooltip: 'Clear category',
                                onPressed: () =>
                                    setState(() => selectedCategory = null),
                                icon: const Icon(Icons.close),
                              ),
                      ),
                      items: categories.map(
                        (item) => DropdownMenuItem<int?>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ).toList(),
                      onChanged: (value) =>
                          setState(() => selectedCategory = value),
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
                        final parsedCentavos =
                            parsePesosValueToCentavos(text);
                        if (parsedCentavos == null) {
                          return 'Enter a valid price.';
                        }
                        if (parsedCentavos <= 0) {
                          return 'Price must be greater than 0.';
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
  });

  return result;
}
