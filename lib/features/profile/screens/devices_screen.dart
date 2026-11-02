import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../auth/data/auth_repository.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

typedef _DeviceEntry = LoginDevice;

// ─── Provider ─────────────────────────────────────────────────────────────────

final _devicesProvider =
    FutureProvider.autoDispose<List<_DeviceEntry>>((ref) async {
  return ref.read(authRepositoryProvider).devices();
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(_devicesProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const _DevicesHeader(),
        Expanded(
          child: async.when(
            loading: () => Center(
              child:
                  CircularProgressIndicator(color: c.primary, strokeWidth: 2),
            ),
            error: (_, __) => _DevicesMessage(
              icon: Icons.wifi_off_rounded,
              title: 'Không tải được danh sách thiết bị',
              subtitle: 'Kiểm tra kết nối rồi thử lại.',
              onRetry: () => ref.invalidate(_devicesProvider),
            ),
            data: (devices) {
              if (devices.isEmpty) {
                return const _DevicesMessage(
                  icon: Icons.devices_other_rounded,
                  title: 'Chưa có thông tin thiết bị',
                  subtitle: 'Các phiên đăng nhập sẽ xuất hiện tại đây.',
                );
              }
              final sorted = [...devices]
                ..sort((a, b) => a.isCurrent == b.isCurrent
                    ? 0
                    : a.isCurrent
                        ? -1
                        : 1);
              return RefreshIndicator(
                color: c.primary,
                onRefresh: () async => ref.invalidate(_devicesProvider),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    _SecurityNote(deviceCount: devices.length),
                    const SizedBox(height: 20),
                    _SectionTitle(
                      devices.length == 1
                          ? 'Thiết bị đang đăng nhập'
                          : '${devices.length} thiết bị đang đăng nhập',
                    ),
                    for (final device in sorted) ...[
                      _DeviceCard(
                        device: device,
                        onRevoke: () => _revoke(context, ref, device.id),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (devices.length > 1) ...[
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => _revokeOthers(context, ref),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.danger,
                          backgroundColor: c.danger.withValues(alpha: .06),
                          side: BorderSide(
                              color: c.danger.withValues(alpha: 0.35)),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text(
                          'Đăng xuất tất cả thiết bị khác',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(authRepositoryProvider).revokeDevice(id);
      ref.invalidate(_devicesProvider);
      if (context.mounted) {
        AppSnackbar.success(context, 'Đã đăng xuất thiết bị');
      }
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, parseApiError(e));
    }
  }

  Future<void> _revokeOthers(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất thiết bị khác?',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text(
          'Tất cả thiết bị khác (trừ thiết bị này) sẽ bị đăng xuất ngay lập tức.',
          style: TextStyle(color: ctx.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.danger),
            child: const Text('Đăng xuất',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(authRepositoryProvider).revokeOtherDevices();
      ref.invalidate(_devicesProvider);
      if (context.mounted) {
        AppSnackbar.success(context, 'Đã đăng xuất các thiết bị khác');
      }
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, parseApiError(e));
    }
  }
}

class _DevicesHeader extends StatelessWidget {
  const _DevicesHeader();

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
          child: Row(children: [
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
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: c.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Thiết bị '),
                      TextSpan(
                        text: 'đăng nhập',
                        style: TextStyle(color: c.primary),
                      ),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Theo dõi và bảo vệ các phiên đăng nhập',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  final int deviceCount;
  const _SecurityNote({required this.deviceCount});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFFFD1BF)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.shield_outlined, size: 21, color: c.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bảo mật tài khoản',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                deviceCount > 1
                    ? 'Kiểm tra $deviceCount thiết bị bên dưới và đăng xuất phiên lạ.'
                    : 'Tài khoản hiện chỉ đăng nhập trên một thiết bị.',
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 4,
          height: 26,
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.sectionTitle.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
    );
  }
}

class _DevicesMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const _DevicesMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppEmptyState(
          icon: icon,
          iconColor: c.primary,
          boxColor: c.primarySoft,
          title: title,
          titleColor: c.textPrimary,
          subtitle: subtitle,
          action: onRetry == null
              ? null
              : TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                ),
        ),
      ),
    );
  }
}

// ─── Device card ────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  final _DeviceEntry device;
  final VoidCallback onRevoke;

  const _DeviceCard({required this.device, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = device.isCurrent ? c.primary : c.textSecondary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: device.isCurrent ? c.primarySoft : c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: device.isCurrent ? const Color(0xFFFFD1BF) : c.divider,
        ),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(12) > 16;
        final detail = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                device.isTablet
                    ? Icons.tablet_mac_rounded
                    : Icons.smartphone_rounded,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName ?? 'Thiết bị không xác định',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (device.isCurrent) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'Thiết bị này',
                          style: AppTextStyles.caption.copyWith(
                            color: c.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.schedule_rounded,
                        size: 14, color: c.textTertiary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        device.lastActiveAt != null
                            ? 'Hoạt động ${Fmt.timeAgo(device.lastActiveAt!)}'
                            : 'Chưa rõ thời gian hoạt động',
                        style: AppTextStyles.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ]),
                  if (device.location?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: c.textTertiary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          device.location!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        );
        if (device.isCurrent) return detail;
        final button = TextButton.icon(
          onPressed: onRevoke,
          style: TextButton.styleFrom(
            foregroundColor: c.danger,
            backgroundColor: c.danger.withValues(alpha: .07),
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.logout_rounded, size: 16),
          label: const Text('Đăng xuất'),
        );
        if (compact) {
          return Column(children: [
            detail,
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: button),
          ]);
        }
        return Row(children: [
          Expanded(child: detail),
          const SizedBox(width: 8),
          button,
        ]);
      }),
    );
  }
}
