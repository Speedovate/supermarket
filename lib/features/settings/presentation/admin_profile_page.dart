import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../app_state/app_controller.dart';

class AdminProfilePage extends ConsumerWidget {
  const AdminProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    final adminSession = appState.adminSession;
    final settings = appState.settings;

    final displayName = adminSession?.displayName.trim().isNotEmpty == true
        ? adminSession!.displayName.trim()
        : 'Arjie Lim';
    final email = adminSession?.email.trim().isNotEmpty == true
        ? adminSession!.email.trim()
        : 'admin@andrews.com';
    Future<void> handleEdit() async {
      final messenger = ScaffoldMessenger.of(context);
      final nameController = TextEditingController(text: displayName);
      final emailController = TextEditingController(text: email);
      final phoneController = TextEditingController(
        text: settings.storeContactNumber,
      );
      final facebookController = TextEditingController(
        text: settings.facebookMessengerUrl,
      );
      final minSoldController = TextEditingController(
        text: '${settings.bestSellerMinSoldUnits}',
      );
      final maxShowController = TextEditingController(
        text: '${settings.bestSellersLimit}',
      );
      var showBanners = settings.bestSellersEnabled;

      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          void submit() => Navigator.of(dialogContext).pop(true);

          return StatefulBuilder(
            builder: (dialogContext, setModalState) {
              return AppModalFrame(
                title: 'Edit Profile',
                onSubmit: submit,
                actions: [
                  AppModalButton(
                    label: 'Close',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                  const SizedBox(width: 10),
                  AppModalButton(
                    label: 'Save',
                    isPrimary: true,
                    onPressed: submit,
                  ),
                ],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(32),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: facebookController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'FB Link',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Banners',
                            style: TextStyle(
                              color: Color(0xFF172033),
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ),
                        Switch(
                          value: showBanners,
                          onChanged: (value) {
                            setModalState(() => showBanners = value);
                          },
                          activeTrackColor: const Color(0xFF34C759),
                          activeThumbColor: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minSoldController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Min sold',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: maxShowController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSubmitted: (_) => submit(),
                      decoration: const InputDecoration(
                        labelText: 'Max show',
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      final nextName = nameController.text.trim();
      final nextEmail = emailController.text.trim();
      final nextPhone = phoneController.text.trim();
      final nextFacebook = facebookController.text.trim();
      final minSold = int.tryParse(minSoldController.text.trim()) ?? 0;
      final maxShow = int.tryParse(maxShowController.text.trim()) ?? 0;
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
      facebookController.dispose();
      minSoldController.dispose();
      maxShowController.dispose();

      if (shouldSave != true || !context.mounted) {
        return;
      }

      if (nextName.isEmpty) {
        messenger.clearSnackBars();
        messenger.showSnackBar(errorSnackBar('Please enter your name.'));
        return;
      }
      if (nextEmail.isEmpty) {
        messenger.clearSnackBars();
        messenger.showSnackBar(errorSnackBar('Please enter your email.'));
        return;
      }
      if (minSold < 1) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          errorSnackBar('Minimum sold should be at least 1.'),
        );
        return;
      }
      if (maxShow < 1) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          errorSnackBar('Max show should be at least 1.'),
        );
        return;
      }

      await ref.read(appControllerProvider.notifier).updateAdminProfile(
        displayName: nextName,
        email: nextEmail,
        settings:
        settings.copyWith(
          bestSellersEnabled: showBanners,
          bestSellerMinSoldUnits: minSold,
          bestSellersLimit: maxShow,
          storeContactNumber: nextPhone,
          facebookMessengerUrl: nextFacebook,
        ),
      );

      if (!context.mounted) {
        return;
      }
      messenger.clearSnackBars();
      messenger.showSnackBar(successSnackBar('Profile updated.'));
    }

    return ListView(
      children: [
        SectionCard(
          showShadow: false,
          padding: EdgeInsets.zero,
          borderRadius: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProfileTable(
                    displayName: displayName,
                    email: email,
                    phoneNumber: settings.storeContactNumber.trim(),
                    facebookLink: settings.facebookMessengerUrl.trim(),
                    showBanners: settings.bestSellersEnabled,
                    minimumSold: settings.bestSellerMinSoldUnits,
                    bannerCount: settings.bestSellersLimit,
                    createdAt: adminSession?.createdAt,
                    updatedAt: adminSession?.updatedAt,
                    onEdit: handleEdit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileTable extends StatelessWidget {
  const _ProfileTable({
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    required this.facebookLink,
    required this.showBanners,
    required this.minimumSold,
    required this.bannerCount,
    required this.createdAt,
    required this.updatedAt,
    required this.onEdit,
  });

  final String displayName;
  final String email;
  final String phoneNumber;
  final String facebookLink;
  final bool showBanners;
  final int minimumSold;
  final int bannerCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = _computeProfileSummaryWidths(
          context: context,
          screenWidth: MediaQuery.of(context).size.width,
          phoneNumber: phoneNumber,
          facebookLink: facebookLink,
          showBanners: showBanners,
          minimumSold: minimumSold,
          bannerCount: bannerCount,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
        final contentWidth = widths.tableWidth;
        final effectiveWidth = constraints.maxWidth > contentWidth + 40
            ? constraints.maxWidth
            : contentWidth + 40;
        final trailingSpace = effectiveWidth - (contentWidth + 40);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: effectiveWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProfileIdentity(
                  displayName: displayName,
                  email: email,
                ),
                const Divider(
                  height: 0,
                  thickness: 0.6,
                  color: Color(0xFFE4E7EC),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.logoBlue.withValues(alpha: 0.10),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(0),
                      topRight: Radius.circular(0),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: _ProfileHeaderRow(
                    widths: widths,
                    trailingSpace: trailingSpace,
                  ),
                ),
                const Divider(
                  height: 0,
                  thickness: 0.6,
                  color: Color(0xFFE4E7EC),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: _ProfileContentRow(
                      widths: widths,
                      trailingSpace: trailingSpace,
                      phoneNumber: phoneNumber,
                      facebookLink: facebookLink,
                      showBanners: showBanners,
                      minimumSold: minimumSold,
                      bannerCount: bannerCount,
                      createdAt: createdAt,
                      updatedAt: updatedAt,
                      onEdit: onEdit,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({
    required this.displayName,
    required this.email,
  });

  final String displayName;
  final String email;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty
        ? 'A'
        : displayName.trim().characters.first.toUpperCase();
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF172033),
      height: 1.15,
    );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF667085),
      height: 1.15,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.logoBlue,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName.trim().isEmpty ? '-' : displayName.trim(),
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email.trim().isEmpty ? '-' : email.trim(),
                  style: subtitleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AdminStateBadge(
            label: 'Admin',
            color: AppColors.logoBlue.withValues(alpha: 0.10),
            textColor: AppColors.logoBlue,
            fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14,
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderRow extends StatelessWidget {
  const _ProfileHeaderRow({
    required this.widths,
    required this.trailingSpace,
  });

  final _ProfileSummaryWidths widths;
  final double trailingSpace;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.logoBlue,
      fontSize: 14 * _profileTextScaleForWidth(MediaQuery.of(context).size.width),
      height: 1.15,
    );
    return Row(
      children: [
        SizedBox(
          width: widths[0],
          child: Text(
            'ID',
            style: labelStyle,
            maxLines: 1,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.phone,
          child: Text(
            'Phone',
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.facebookLink,
          child: Text(
            'FB link',
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.showBanners,
          child: Text(
            'Banners',
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.minimumSold,
          child: Text(
            'Min sold',
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.bannerCount,
          child: Text(
            'Max show',
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.createdAt,
          child: Text(
            'Created at',
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.updatedAt,
          child: Text(
            'Updated at',
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap + trailingSpace),
        SizedBox(
          width: widths.actions,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Actions',
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileContentRow extends StatelessWidget {
  const _ProfileContentRow({
    required this.widths,
    required this.trailingSpace,
    required this.phoneNumber,
    required this.facebookLink,
    required this.showBanners,
    required this.minimumSold,
    required this.bannerCount,
    required this.createdAt,
    required this.updatedAt,
    required this.onEdit,
  });

  final _ProfileSummaryWidths widths;
  final double trailingSpace;
  final String phoneNumber;
  final String facebookLink;
  final bool showBanners;
  final int minimumSold;
  final int bannerCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final scale = _profileTextScaleForWidth(MediaQuery.of(context).size.width);
    final bodyStyle = DefaultTextStyle.of(context).style.copyWith(
      fontSize: (DefaultTextStyle.of(context).style.fontSize ?? 14) * scale,
      height: 1.15,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: widths.id,
          child: Text('1', style: bodyStyle),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.phone,
          child: Text(phoneNumber.isEmpty ? '-' : phoneNumber, style: bodyStyle),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.facebookLink,
          child: Text(
            facebookLink.isEmpty ? '-' : facebookLink,
            style: bodyStyle,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.showBanners,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AdminStateBadge(
              label: showBanners ? 'Active' : 'Inactive',
              color: showBanners
                  ? AppColors.statusActiveGreen
                  : const Color(0xFFE53935),
              fontSize: bodyStyle.fontSize ?? 14,
            ),
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.minimumSold,
          child: Text('$minimumSold', style: bodyStyle),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.bannerCount,
          child: Text('$bannerCount', style: bodyStyle),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.createdAt,
          child: Text(
            createdAt == null
                ? '-'
                : '${formatOrderDate(createdAt!)}\n${formatOrderTimeWithSeconds(createdAt!)}',
            style: bodyStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap),
        SizedBox(
          width: widths.updatedAt,
          child: Text(
            updatedAt == null
                ? '-'
                : '${formatOrderDate(updatedAt!)}\n${formatOrderTimeWithSeconds(updatedAt!)}',
            style: bodyStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: widths.gap + trailingSpace),
        SizedBox(
          width: widths.actions,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              MousePressable(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.logoBlue,
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

class _ProfileSummaryWidths {
  const _ProfileSummaryWidths({
    required this.gap,
    required this.id,
    required this.phone,
    required this.facebookLink,
    required this.showBanners,
    required this.minimumSold,
    required this.bannerCount,
    required this.createdAt,
    required this.updatedAt,
    required this.actions,
  });

  final double gap;
  final double id;
  final double phone;
  final double facebookLink;
  final double showBanners;
  final double minimumSold;
  final double bannerCount;
  final double createdAt;
  final double updatedAt;
  final double actions;

  double get tableWidth =>
      id +
      gap +
      phone +
      gap +
      facebookLink +
      gap +
      showBanners +
      gap +
      minimumSold +
      gap +
      bannerCount +
      gap +
      createdAt +
      gap +
      updatedAt +
      gap +
      actions;

  double operator [](int index) => switch (index) {
    0 => id,
    1 => phone,
    2 => facebookLink,
    3 => showBanners,
    4 => minimumSold,
    5 => bannerCount,
    6 => createdAt,
    7 => updatedAt,
    _ => actions,
  };
}

const double _profileSummaryColumnWidthAllowance = 8;
const double _profileSummaryActionHitSize = 34;
const double _profileSummaryStatusBadgeHorizontalPadding = 24;
double get _profileSummaryActionsWidth => _profileSummaryActionHitSize;

_ProfileSummaryWidths _computeProfileSummaryWidths(
  {
  required BuildContext context,
  required double screenWidth,
  required String phoneNumber,
  required String facebookLink,
  required bool showBanners,
  required int minimumSold,
  required int bannerCount,
  required DateTime? createdAt,
  required DateTime? updatedAt,
}
) {
  final headerStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontWeight: FontWeight.w700,
    color: AppColors.logoBlue,
    height: 1.15,
  );
  final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: const Color(0xFF172033),
    height: 1.15,
  );
  final painter = TextPainter(textDirection: TextDirection.ltr);
  final gap = 20.0;

  double maxWidth(String title, String value, {double? max}) {
    painter.text = TextSpan(text: title, style: headerStyle);
    painter.layout();
    var width =
        painter.width.ceilToDouble() + _profileSummaryColumnWidthAllowance;
    painter.text = TextSpan(text: value, style: bodyStyle);
    painter.layout(maxWidth: screenWidth);
    width = width > painter.width.ceilToDouble() + _profileSummaryColumnWidthAllowance
        ? width
        : painter.width.ceilToDouble() + _profileSummaryColumnWidthAllowance;
    if (max != null && width > max) {
      return max;
    }
    return width;
  }

  final createdAtValue = createdAt == null
      ? '-'
      : '${formatOrderDate(createdAt)}\n${formatOrderTimeWithSeconds(createdAt)}';
  final updatedAtValue = updatedAt == null
      ? '-'
      : '${formatOrderDate(updatedAt)}\n${formatOrderTimeWithSeconds(updatedAt)}';

  return _ProfileSummaryWidths(
    gap: gap,
    id: maxWidth('ID', '1'),
    phone: maxWidth('Phone', phoneNumber.isEmpty ? '-' : phoneNumber),
    facebookLink: maxWidth(
      'FB link',
      facebookLink.isEmpty ? '-' : facebookLink,
      max: screenWidth < 700 ? 160 : 220,
    ),
    showBanners:
        maxWidth(
          'Banners',
          showBanners ? 'Active' : 'Inactive',
          max: screenWidth < 700 ? 120 : 132,
        ) +
        _profileSummaryStatusBadgeHorizontalPadding,
    minimumSold: maxWidth('Min sold', '$minimumSold'),
    bannerCount: maxWidth('Max show', '$bannerCount'),
    createdAt: maxWidth('Created at', createdAtValue),
    updatedAt: maxWidth('Updated at', updatedAtValue),
    actions: maxWidth('Actions', '') > _profileSummaryActionsWidth
        ? maxWidth('Actions', '')
        : _profileSummaryActionsWidth,
  );
}

double _profileTextScaleForWidth(double width) {
  if (width <= 360) {
    return 0.82;
  }
  if (width < 700) {
    return 0.90;
  }
  return 1;
}
