import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/support_links.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../models/support_config_item.dart';
import '../providers/support_config_provider.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final support = ref.watch(supportConfigProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          const _SupportHeader(),
          Expanded(
            child: RefreshIndicator(
              color: c.primary,
              onRefresh: () async => ref.invalidate(supportConfigProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  const _WelcomeCard(),
                  const SizedBox(height: 20),
                  const _SectionTitle(
                    title: 'Kênh hỗ trợ',
                    subtitle: 'Chọn cách thuận tiện nhất để liên hệ',
                  ),
                  const SizedBox(height: 10),
                  support.when(
                    loading: () => const _SupportLoading(),
                    error: (_, __) => _SupportMessage(
                      icon: Icons.wifi_off_rounded,
                      title: 'Không tải được thông tin hỗ trợ',
                      subtitle: 'Kiểm tra kết nối rồi thử lại.',
                      action: FilledButton.tonal(
                        onPressed: () => ref.invalidate(supportConfigProvider),
                        child: const Text('Thử lại'),
                      ),
                    ),
                    data: (items) => items.isEmpty
                        ? const _SupportMessage(
                            icon: Icons.support_agent_rounded,
                            title: 'Chưa có kênh hỗ trợ',
                            subtitle:
                                'Thông tin liên hệ đang được cập nhật. Vui lòng quay lại sau.',
                          )
                        : _SupportChannels(items: items),
                  ),
                  const SizedBox(height: 16),
                  const _SafetyNote(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportHeader extends StatelessWidget {
  const _SupportHeader();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.isDark ? c.primarySoft : const Color(0xFFFFE9DE),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Quay lại',
                onPressed: () => Navigator.maybePop(context),
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(44),
                  backgroundColor: c.surface,
                  side: BorderSide(color: c.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Liên hệ '),
                          TextSpan(
                            text: 'hỗ trợ',
                            style: TextStyle(color: c.primary),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'FlashShip luôn đồng hành cùng cửa hàng',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: .85),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.support_agent_rounded,
              size: 24,
              color: c.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn cần hỗ trợ?',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chọn một kênh bên dưới, đội ngũ FlashShip sẽ hỗ trợ bạn sớm nhất có thể.',
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                    height: 1.4,
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 38,
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.touch_app_outlined,
                      size: 14, color: c.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupportChannels extends StatelessWidget {
  final List<SupportConfigItem> items;

  const _SupportChannels({required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _SupportChannelTile(item: items[index]),
            if (index < items.length - 1)
              Divider(
                height: 1,
                indent: 68,
                endIndent: 14,
                color: c.divider,
              ),
          ],
        ],
      ),
    );
  }
}

class _SupportChannelTile extends StatelessWidget {
  final SupportConfigItem item;

  const _SupportChannelTile({required this.item});

  IconData get _icon => switch (item.type) {
        'phone' => Icons.phone_outlined,
        'zalo' => Icons.chat_bubble_outline_rounded,
        'facebook' => Icons.forum_outlined,
        'email' => Icons.email_outlined,
        'website' => Icons.language_rounded,
        _ => Icons.link_rounded,
      };

  String get _hint {
    final value = item.value.trim();
    return switch (item.type) {
      'phone' => value.replaceFirst('tel:', ''),
      'email' => value.replaceFirst('mailto:', ''),
      'zalo' => 'Nhắn tin qua Zalo',
      'facebook' => 'Nhắn tin qua Facebook',
      'website' => 'Mở trang hỗ trợ',
      _ => 'Xem thông tin hỗ trợ',
    };
  }

  String get _action => switch (item.type) {
        'phone' => 'Gọi ngay',
        'email' => 'Gửi email',
        'zalo' || 'facebook' => 'Nhắn tin',
        _ => 'Mở liên kết',
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
    final tint = item.displayColor;
    final compact = MediaQuery.sizeOf(context).width < 360 ||
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
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon, size: 22, color: tint),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 3),
                      Text(
                        _hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!compact)
                  Text(
                    _action,
                    style: AppTextStyles.caption.copyWith(
                      color: tint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(width: 3),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: compact ? tint : c.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportLoading extends StatelessWidget {
  const _SupportLoading();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        children: [
          for (var index = 0; index < 3; index++) ...[
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LoadingBar(width: 120, color: c.surfaceAlt),
                      const SizedBox(height: 8),
                      _LoadingBar(width: 170, height: 8, color: c.surfaceAlt),
                    ],
                  ),
                ),
              ],
            ),
            if (index < 2) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _LoadingBar({
    required this.width,
    required this.color,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
}

class _SupportMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _SupportMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      child: AppEmptyState(
        icon: icon,
        title: title,
        subtitle: subtitle,
        action: action,
        boxSize: 58,
        iconSize: 28,
        boxColor: c.surfaceAlt,
        iconColor: c.textSecondary,
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent2Soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.shield_outlined, size: 18, color: c.accent2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lưu ý bảo mật',
                  style: AppTextStyles.label.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'FlashShip không yêu cầu bạn cung cấp mật khẩu hoặc mã OTP qua các kênh hỗ trợ.',
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                    height: 1.4,
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
