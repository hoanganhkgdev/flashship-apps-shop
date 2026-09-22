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
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Thiết bị đăng nhập',
            style: TextStyle(
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.w800,
                color: c.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: c.divider),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Không tải được danh sách thiết bị',
                style: TextStyle(color: c.textSecondary)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => ref.invalidate(_devicesProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ]),
        ),
        data: (devices) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final d in devices) ...[
              _DeviceCard(
                  device: d, onRevoke: () => _revoke(context, ref, d.id)),
              const SizedBox(height: 12),
            ],
            if (devices.length > 1) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _revokeOthers(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.danger,
                  side: BorderSide(color: c.danger.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Đăng xuất tất cả thiết bị khác',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
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
            style: TextStyle(fontWeight: FontWeight.w700)),
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
                style: TextStyle(fontWeight: FontWeight.w700)),
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

// ─── Device card ────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  final _DeviceEntry device;
  final VoidCallback onRevoke;

  const _DeviceCard({required this.device, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: device.isCurrent ? AppColors.primary : c.divider,
          width: device.isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (device.isCurrent ? AppColors.primary : c.textSecondary)
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              device.isTablet
                  ? Icons.tablet_mac_rounded
                  : Icons.smartphone_rounded,
              size: 20,
              color: device.isCurrent ? AppColors.primary : c.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      device.deviceName ?? 'Thiết bị không xác định',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: AppFontSize.md,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary),
                    ),
                  ),
                  if (device.isCurrent) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Thiết bị này',
                          style: TextStyle(
                              fontSize: AppFontSize.xs,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(
                  device.lastActiveAt != null
                      ? 'Hoạt động ${Fmt.timeAgo(device.lastActiveAt!)}'
                      : 'Chưa rõ thời gian hoạt động',
                  style: TextStyle(
                      fontSize: AppFontSize.sm, color: c.textSecondary),
                ),
              ],
            ),
          ),
          if (!device.isCurrent)
            TextButton(
              onPressed: onRevoke,
              style: TextButton.styleFrom(foregroundColor: c.danger),
              child: const Text('Đăng xuất',
                  style: TextStyle(
                      fontSize: AppFontSize.base, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
