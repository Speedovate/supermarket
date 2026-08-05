import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_models.dart';
import '../../../core/widgets/admin_scaffold.dart';
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
    return AdminScaffold(
      title: 'Settings',
      selectedRoute: '/admin/settings',
      actions: [
        TextButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final settings = AppSettings(
              bestSellersEnabled: bestSellersEnabled,
              bestSellersLimit: int.tryParse(limitController.text.trim()) ?? 6,
            );
            await ref
                .read(appControllerProvider.notifier)
                .saveSettings(settings);
            if (!mounted) {
              return;
            }
            messenger.clearSnackBars();
            messenger.showSnackBar(
              successSnackBar('Settings saved.'),
            );
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
      ],
      child: ListView(
        children: [
          SectionCard(
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
                SwitchListTile(
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
      ),
    );
  }
}
