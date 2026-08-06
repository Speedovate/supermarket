import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class AdminProfilePage extends ConsumerWidget {
  const AdminProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminSession = ref.watch(
      appControllerProvider.select((state) => state.adminSession),
    );

    final displayName = adminSession?.displayName.trim().isNotEmpty == true
        ? adminSession!.displayName.trim()
        : 'Admin User';
    final email = adminSession?.email.trim().isNotEmpty == true
        ? adminSession!.email.trim()
        : 'admin@andrewssupermarket.com';
    final uid = adminSession?.uid.trim().isNotEmpty == true
        ? adminSession!.uid.trim()
        : 'N/A';
    final sessionId = adminSession?.id ?? 1;
    final initial = displayName.characters.first.toUpperCase();

    return ListView(
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F6FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE4E7EC)),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFF1538DD),
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF172033),
                                height: 1.15,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.logoBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ID',
                        style: TextStyle(
                          color: AppColors.logoBlue,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Created at',
                        style: TextStyle(
                          color: AppColors.logoBlue,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Updated at',
                        style: TextStyle(
                          color: AppColors.logoBlue,
                          fontWeight: FontWeight.w700,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$sessionId',
                        style: const TextStyle(height: 1.15),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        adminSession?.createdAt == null
                            ? '-'
                            : '${formatOrderDate(adminSession!.createdAt!)}\n${formatOrderTimeWithSeconds(adminSession.createdAt!)}',
                        style: const TextStyle(height: 1.15),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        adminSession?.updatedAt == null
                            ? '-'
                            : '${formatOrderDate(adminSession!.updatedAt!)}\n${formatOrderTimeWithSeconds(adminSession.updatedAt!)}',
                        style: const TextStyle(height: 1.15),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Column(
                  children: [
                    _ProfileInfoRow(label: 'Name', value: displayName),
                    const Divider(height: 1),
                    _ProfileInfoRow(label: 'Email', value: email),
                    const Divider(height: 1),
                    _ProfileInfoRow(label: 'User ID', value: uid),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF172033),
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
