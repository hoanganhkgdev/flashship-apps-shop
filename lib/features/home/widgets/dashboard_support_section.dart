part of '../screens/home_screen.dart';

class _HomeSupportSection extends ConsumerWidget {
  const _HomeSupportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(supportConfigProvider);
    final items = support.valueOrNull ?? const <SupportConfigItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShopHomeSectionHeading(
          title: 'Bạn cần hỗ trợ?',
          highlight: 'hỗ trợ?',
          subtitle: 'Liên hệ với Flash Ship',
          subtitleIcon: Icons.headset_mic_rounded,
          actionLabel: items.length > 2 ? 'Xem thêm' : null,
          onAction: items.length > 2 ? () => context.push('/profile') : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: support.when(
              loading: () => const _HomeSupportSkeleton(),
              error: (_, __) => _SupportFallback(
                onTap: () => context.push('/profile'),
              ),
              data: (data) => data.isEmpty
                  ? _SupportFallback(onTap: () => context.push('/profile'))
                  : Column(
                      children: [
                        for (var i = 0; i < data.length.clamp(0, 2); i++) ...[
                          _HomeSupportRow(item: data[i]),
                          if (i < data.length.clamp(0, 2) - 1)
                            Divider(
                              height: 1,
                              indent: 60,
                              endIndent: 14,
                              color: context.colors.divider,
                            ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeSupportRow extends StatelessWidget {
  final SupportConfigItem item;

  const _HomeSupportRow({required this.item});

  IconData get _icon => switch (item.type) {
        'phone' => Icons.phone_outlined,
        'zalo' => Icons.chat_bubble_outline_rounded,
        'facebook' => Icons.forum_outlined,
        'email' => Icons.email_outlined,
        'website' => Icons.language_rounded,
        _ => Icons.support_agent_rounded,
      };

  String get _subtitle => switch (item.type) {
        'phone' => item.value.replaceFirst('tel:', ''),
        'zalo' => 'Nhắn tin với Flash Ship',
        'facebook' => 'Nhắn tin với Flash Ship',
        'email' => item.value.replaceFirst('mailto:', ''),
        _ => 'Xem thông tin hỗ trợ',
      };

  String get _action => switch (item.type) {
        'phone' => 'Gọi ngay',
        'zalo' || 'facebook' => 'Mở chat',
        'email' => 'Gửi email',
        _ => 'Mở trang',
      };

  Future<void> _open(BuildContext context) async {
    final opened = await openSupportChannel(
      type: item.type,
      value: item.value,
      link: item.link,
    );
    if (!opened && context.mounted) {
      AppSnackbar.error(
        context,
        'Không thể mở “${item.title}” trên thiết bị này',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final compactAction = MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(12) > 16;
    return Semantics(
      button: true,
      label: '$_action: ${item.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.displayColor.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, size: 20, color: item.displayColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: compactAction ? 36 : null,
                height: 36,
                alignment: Alignment.center,
                padding: compactAction
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: item.displayColor.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: compactAction
                    ? Icon(
                        Icons.chevron_right_rounded,
                        size: 19,
                        color: item.displayColor,
                      )
                    : Text(
                        '$_action  ›',
                        maxLines: 1,
                        style: AppTextStyles.caption.copyWith(
                          color: item.displayColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HomeSupportSkeleton extends StatelessWidget {
  const _HomeSupportSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 110,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    width: 150,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _SupportFallback extends StatelessWidget {
  final VoidCallback onTap;

  const _SupportFallback({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.support_agent_rounded,
                size: 19,
                color: c.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trung tâm hỗ trợ',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Xem các kênh liên hệ của Flash Ship',
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary),
          ]),
        ),
      ),
    );
  }
}
