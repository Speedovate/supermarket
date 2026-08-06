import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  late bool bestSellersEnabled;
  late TextEditingController limitController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appControllerProvider).settings;
    bestSellersEnabled = settings.bestSellersEnabled;
    limitController = TextEditingController(
      text: '${settings.bestSellersLimit}',
    );
  }

  @override
  void dispose() {
    limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(
      appControllerProvider.select((state) => state.settings),
    );
    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              width: 132,
              child: AppModalButton(
                label: 'Save',
                isPrimary: true,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final nextSettings = AppSettings(
                    id: settings.id,
                    bestSellersEnabled: bestSellersEnabled,
                    bestSellersLimit:
                        int.tryParse(limitController.text.trim()) ?? 6,
                    createdAt: settings.createdAt,
                    updatedAt: settings.updatedAt,
                  );
                  await ref
                      .read(appControllerProvider.notifier)
                      .saveSettings(nextSettings);
                  if (!mounted) {
                    return;
                  }
                  messenger.clearSnackBars();
                  messenger.showSnackBar(successSnackBar('Settings saved.'));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          showShadow: false,
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Public Catalog Settings',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.logoBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ID',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.logoBlue,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Created at',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.logoBlue,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Updated at',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.logoBlue,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${settings.id}',
                        style: const TextStyle(height: 1.15),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        settings.createdAt == null
                            ? '-'
                            : '${formatOrderDate(settings.createdAt!)}\n${formatOrderTimeWithSeconds(settings.createdAt!)}',
                        style: const TextStyle(height: 1.15),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        settings.updatedAt == null
                            ? '-'
                            : '${formatOrderDate(settings.updatedAt!)}\n${formatOrderTimeWithSeconds(settings.updatedAt!)}',
                        style: const TextStyle(height: 1.15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -4),
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Best Sellers'),
                subtitle: const Text(
                  'Hidden by default during initial deployment.',
                ),
                value: bestSellersEnabled,
                onChanged: (value) =>
                    setState(() => bestSellersEnabled = value),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: limitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Best Sellers limit',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
