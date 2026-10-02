import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../legal/legal_page_screen.dart';
import '../../../core/widgets/app_decor_widgets.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/otp_input.dart';
import '../../auth/models/shop_user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/cities_provider.dart';
import '../../auth/widgets/city_picker_sheet.dart';
import '../models/support_config_item.dart';
import '../providers/support_config_provider.dart';
import '../../stats/stats_repository.dart';
import '../../../core/widgets/address_picker_screen.dart';
import '../../../core/widgets/map_picker_screen.dart';
import '../../security/pin_setup_screen.dart';
import '../../security/providers/pin_provider.dart';
import 'devices_screen.dart';

final _profileStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.read(statsRepositoryProvider).fetch(period: 'month');
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();
    return _ProfileOverview(
      user: user,
      onSettingsTap: () => _showProfileSettings(context, ref, user),
      onAddressTap: () => context.push('/address-book'),
      onVouchersTap: () => context.push('/vouchers'),
      onReferralTap: () => context.push('/referral'),
      onDevicesTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const DevicesScreen())),
      onPasswordTap: () => _showPasswordSheet(context, ref),
      onSupportTap: () => _showSupport(context),
      onLogout: () => _logout(context, ref),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _showSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AppSheet(
        icon: Icons.support_agent_rounded,
        color: context.colors.accent2,
        title: 'Hỗ trợ',
        subtitle: 'Liên hệ FlashShip khi cần giúp đỡ',
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _SupportSection(),
      ),
    );
  }

  void _showProfileSettings(
      BuildContext context, WidgetRef ref, ShopUserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        void close(VoidCallback action) {
          Navigator.pop(sheetContext);
          action();
        }

        void legal(String slug, String title) => close(() => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => LegalPageScreen(slug: slug, title: title))));

        return Consumer(builder: (_, sRef, __) {
          final c = sheetContext.colors;
          final themeMode = sRef.watch(themeModeProvider);
          final pin = sRef.watch(pinProvider);

          // Bật/tắt PIN ngay trong sheet; chỉ đóng sheet khi phải mở màn
          // thiết lập PIN mới.
          void togglePin(bool enable) {
            if (!enable || pin.hasPin) {
              _togglePinLock(context, ref, enable);
            } else {
              close(() => _togglePinLock(context, ref, true));
            }
          }

          Widget group(String label, List<_SettingsRow> rows) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        left: AppSpacing.xs, bottom: AppSpacing.sm),
                    child: Text(label.toUpperCase(),
                        style: AppTextStyles.caption.copyWith(
                            color: c.textTertiary, letterSpacing: .6)),
                  ),
                  _SettingsCard(rows: rows),
                  const SizedBox(height: AppSpacing.lg),
                ],
              );

          return AppSheet(
            icon: Icons.settings_rounded,
            title: 'Cài đặt',
            subtitle: 'Tài khoản và ứng dụng',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              group('Tài khoản', [
                _SettingsRow(
                  icon: Icons.storefront_rounded,
                  iconBg: c.primary,
                  label: 'Thông tin cửa hàng',
                  subtitle: 'Tên, địa chỉ và khu vực hoạt động',
                  onTap: () => close(() => _showEditSheet(context, ref, user)),
                ),
                _SettingsRow(
                  icon: Icons.phone_iphone_rounded,
                  iconBg: c.info,
                  label: 'Đổi số điện thoại',
                  subtitle: user.phone,
                  onTap: () => close(() => _showChangePhoneSheet(context)),
                ),
              ]),
              group('Ứng dụng', [
                _SettingsRow(
                  icon: Icons.dark_mode_rounded,
                  iconBg: c.accent2,
                  label: 'Chế độ hiển thị',
                  subtitle: _themeModeLabel(themeMode),
                  onTap: () => close(() => _showThemeModeSheet(context, ref)),
                ),
                _SettingsRow(
                  icon: Icons.pin_rounded,
                  iconBg: c.warning,
                  label: 'Khoá bằng mã PIN',
                  subtitle: pin.isEnabled
                      ? 'Đang bật — hỏi mã khi mở ứng dụng'
                      : 'Hỏi mã PIN mỗi khi mở ứng dụng',
                  showChevron: false,
                  trailing: Switch(value: pin.isEnabled, onChanged: togglePin),
                  onTap: () => togglePin(!pin.isEnabled),
                ),
              ]),
              group('Pháp lý', [
                _SettingsRow(
                  icon: Icons.shield_rounded,
                  iconBg: c.info,
                  label: 'Chính sách quyền riêng tư',
                  onTap: () =>
                      legal('privacy-policy', 'Chính sách quyền riêng tư'),
                ),
                _SettingsRow(
                  icon: Icons.description_rounded,
                  iconBg: c.textSecondary,
                  label: 'Điều khoản sử dụng',
                  onTap: () => legal('terms-of-service', 'Điều khoản sử dụng'),
                ),
              ]),
              _SettingsCard(rows: [
                _SettingsRow(
                  icon: Icons.delete_forever_rounded,
                  iconBg: c.danger,
                  labelColor: c.danger,
                  label: 'Xóa tài khoản',
                  subtitle: 'Xoá vĩnh viễn dữ liệu cửa hàng',
                  showChevron: false,
                  onTap: () => close(() => _deleteAccount(context, ref)),
                ),
              ]),
            ]),
          );
        });
      },
    );
  }

  static String _themeModeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Sáng',
        ThemeMode.dark => 'Tối',
        ThemeMode.system => 'Hệ thống',
      };

  void _showThemeModeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Consumer(builder: (_, sRef, __) {
        final current = sRef.watch(themeModeProvider);
        Widget option(ThemeMode mode, IconData icon, String label) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppSheetOption(
                icon: icon,
                label: label,
                selected: mode == current,
                onTap: () {
                  sRef.read(themeModeProvider.notifier).set(mode);
                  Navigator.pop(ctx);
                },
              ),
            );
        return AppSheet(
          icon: Icons.dark_mode_rounded,
          color: ctx.colors.accent2,
          title: 'Chế độ hiển thị',
          subtitle: 'Chọn giao diện sáng hoặc tối',
          child: Column(children: [
            option(ThemeMode.light, Icons.light_mode_outlined, 'Sáng'),
            option(ThemeMode.dark, Icons.dark_mode_outlined, 'Tối'),
            option(ThemeMode.system, Icons.brightness_auto_outlined,
                'Theo hệ thống'),
          ]),
        );
      }),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, ShopUserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final addrCtrl = TextEditingController(text: user.address ?? '');
    int? cityId = user.cityId;
    String? cityName = user.cityName;

    // Hàng chọn (địa chỉ / khu vực): icon cam, giá trị một dòng, mũi tên.
    Widget pickerRow(BuildContext ctx, IconData icon, String text, String hint,
        VoidCallback onTap) {
      final c = ctx.colors;
      final has = text.isNotEmpty;
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          child: Row(children: [
            Icon(icon, size: AppSize.iconMd, color: c.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(has ? text : hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: has
                      ? AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)
                      : AppTextStyles.body.copyWith(color: c.textTertiary)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(has ? Icons.edit_outlined : Icons.chevron_right_rounded,
                size: AppSize.iconSm + 2,
                color: has ? c.primary : c.textTertiary),
          ]),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final c = ctx.colors;
          return AppSheet(
            icon: Icons.storefront_rounded,
            title: 'Thông tin cửa hàng',
            subtitle: 'Tên, địa chỉ và khu vực hoạt động',
            footer: AppButton(
              label: 'Lưu thay đổi',
              onPressed: () async {
                Navigator.pop(ctx);
                final err = await ref.read(authProvider.notifier).updateProfile(
                      name: nameCtrl.text.trim(),
                      address: addrCtrl.text.trim(),
                      cityId: cityId,
                    );
                if (err != null && context.mounted) {
                  AppSnackbar.error(context, err);
                }
              },
            ),
            child: Container(
              decoration: BoxDecoration(
                color: c.glass,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: c.glassBorder, width: 1.2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: TextField(
                    controller: nameCtrl,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.words,
                    style:
                        AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Tên cửa hàng',
                      hintStyle:
                          AppTextStyles.body.copyWith(color: c.textTertiary),
                      prefixIcon: Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.md),
                          child: Icon(Icons.badge_outlined,
                              size: AppSize.iconMd, color: c.primary)),
                      prefixIconConstraints: const BoxConstraints(),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                Divider(height: 1, color: c.divider),
                pickerRow(ctx, Icons.location_on_outlined, addrCtrl.text,
                    'Chọn địa chỉ cửa hàng', () async {
                  final result = await Navigator.of(ctx).push<MapPickResult>(
                    MaterialPageRoute(
                      builder: (_) => AddressPickerScreen(
                          title: 'Địa chỉ cửa hàng',
                          cityId: cityId,
                          cityName: cityName),
                    ),
                  );
                  if (result != null) {
                    setSt(() => addrCtrl.text = result.address);
                  }
                }),
                Consumer(builder: (_, cRef, __) {
                  final citiesAsync = cRef.watch(citiesProvider);
                  return citiesAsync.maybeWhen(
                    data: (cities) => Column(children: [
                      Divider(height: 1, color: c.divider),
                      pickerRow(ctx, Icons.location_city_rounded,
                          cityName ?? '', 'Chọn khu vực hoạt động', () async {
                        final result = await showCityPicker(ctx,
                            cities: cities, selectedId: cityId);
                        if (result != null) {
                          setSt(() {
                            cityId = result.id;
                            cityName = result.name;
                          });
                        }
                      }),
                    ]),
                    orElse: () => const SizedBox.shrink(),
                  );
                }),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _showPasswordSheet(BuildContext context, WidgetRef ref) {
    final currCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => AppSheet(
        icon: Icons.lock_rounded,
        color: ctx.colors.warning,
        title: 'Đổi mật khẩu',
        subtitle: 'Dùng mật khẩu mạnh để bảo vệ cửa hàng',
        footer: AppButton(
          label: 'Xác nhận',
          onPressed: () async {
            Navigator.pop(ctx);
            final err = await ref
                .read(authProvider.notifier)
                .changePassword(current: currCtrl.text, next: newCtrl.text);
            if (context.mounted) {
              if (err == null) {
                AppSnackbar.success(context, 'Đổi mật khẩu thành công');
              } else {
                AppSnackbar.error(context, err);
              }
            }
          },
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AppLabel('Mật khẩu hiện tại'),
          const SizedBox(height: 8),
          AppField(controller: currCtrl, hint: '••••••••', obscureText: true),
          const SizedBox(height: 14),
          const AppLabel('Mật khẩu mới'),
          const SizedBox(height: 8),
          AppField(controller: newCtrl, hint: '••••••••', obscureText: true),
        ]),
      ),
    );
  }

  void _showChangePhoneSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ChangePhoneSheet(
        onSuccess: () {
          if (context.mounted) {
            AppSnackbar.success(context, 'Đổi số điện thoại thành công');
          }
        },
      ),
    );
  }

  Future<void> _togglePinLock(
      BuildContext context, WidgetRef ref, bool enable) async {
    final notifier = ref.read(pinProvider.notifier);
    if (!enable) {
      await notifier.setEnabled(false);
      return;
    }
    if (ref.read(pinProvider).hasPin) {
      await notifier.setEnabled(true);
      return;
    }
    // Chưa có PIN nào — mở màn thiết lập, bật khoá xảy ra bên trong đó
    // (pinProvider.setPin) khi người dùng nhập xong và xác nhận khớp.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài khoản?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Tất cả dữ liệu cửa hàng, lịch sử đơn hàng sẽ bị xóa vĩnh viễn. '
          'Hành động này không thể hoàn tác.',
          style: TextStyle(color: ctx.colors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.danger),
            child: const Text('Tiếp tục',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm1 != true || !context.mounted) return;

    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xác nhận xóa tài khoản',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: ctx.colors.danger)),
        content: Text(
          'Nhấn "Xóa vĩnh viễn" để xác nhận. '
          'Đơn hàng đang chờ sẽ bị huỷ tự động.',
          style: TextStyle(color: ctx.colors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.danger),
            child: const Text('Xóa vĩnh viễn',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm2 != true || !context.mounted) return;

    final err = await ref.read(authProvider.notifier).deleteAccount();
    if (err != null && context.mounted) {
      AppSnackbar.error(context, err);
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Bạn muốn đăng xuất khỏi tài khoản này?',
            style: TextStyle(color: ctx.colors.textSecondary)),
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
    if (ok == true) await ref.read(authProvider.notifier).logout();
  }
}

class _ProfileOverview extends ConsumerWidget {
  final ShopUserModel user;
  final VoidCallback onSettingsTap;
  final VoidCallback onAddressTap;
  final VoidCallback onVouchersTap;
  final VoidCallback onReferralTap;
  final VoidCallback onDevicesTap;
  final VoidCallback onPasswordTap;
  final VoidCallback onSupportTap;
  final VoidCallback onLogout;

  const _ProfileOverview({
    required this.user,
    required this.onSettingsTap,
    required this.onAddressTap,
    required this.onVouchersTap,
    required this.onReferralTap,
    required this.onDevicesTap,
    required this.onPasswordTap,
    required this.onSupportTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final stats = ref.watch(_profileStatsProvider).valueOrNull ?? const {};
    final revenue = Fmt.toInt(stats['revenue']);
    final total = Fmt.toInt(stats['total']);
    final completed = Fmt.toInt(stats['completed']);
    final cancelled = Fmt.toInt(stats['cancelled']);
    final daily = stats['daily'] is List
        ? (stats['daily'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    // Header cố định giống DashboardHeader / header Đơn hàng: nền surface,
    // bóng mềm, nhận diện tài khoản ở trái và hành động ở phải.
    final header = GlassHeader(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.paddingOf(context).top + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                      color: c.textPrimary, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                  [
                    user.phone,
                    if (user.cityName?.isNotEmpty == true) user.cityName!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GlassIconButton(
          icon: Icons.settings_outlined,
          color: c.primary,
          tooltip: 'Cài đặt',
          onPressed: onSettingsTap,
        ),
      ]),
    );

    const pad = EdgeInsets.symmetric(horizontal: AppSpacing.lg);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        header,
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            onRefresh: () async => ref.invalidate(_profileStatsProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                  top: AppSpacing.lg, bottom: AppSpacing.xl4),
              children: [
                const Padding(
                    padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    child: _ProfileSectionTitle(
                        Icons.insights_rounded, 'Hoạt động tháng này')),
                Padding(
                  padding: pad,
                  child: _MonthlyActivityCard(
                    revenue: revenue,
                    total: total,
                    completed: completed,
                    cancelled: cancelled,
                    daily: daily,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl2),
                const Padding(
                    padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    child: _ProfileSectionTitle(
                        Icons.person_rounded, 'Tài khoản')),
                Padding(
                  padding: pad,
                  child: _SettingsCard(rows: [
                    _SettingsRow(
                      icon: Icons.location_on_rounded,
                      iconBg: c.primary,
                      label: 'Sổ địa chỉ',
                      subtitle: 'Địa chỉ thường giao hàng',
                      onTap: onAddressTap,
                    ),
                    _SettingsRow(
                      icon: Icons.local_activity_rounded,
                      iconBg: c.accent2,
                      label: 'Mã giảm giá',
                      subtitle: 'Ưu đãi phí giao hàng của bạn',
                      onTap: onVouchersTap,
                    ),
                    _SettingsRow(
                      icon: Icons.card_giftcard_rounded,
                      iconBg: c.warning,
                      label: 'Giới thiệu & tích điểm',
                      subtitle: 'Mời shop bạn bè, nhận điểm đổi voucher',
                      onTap: onReferralTap,
                    ),
                    _SettingsRow(
                      icon: Icons.phone_iphone_rounded,
                      iconBg: c.info,
                      label: 'Thiết bị đăng nhập',
                      subtitle: 'Quản lý các thiết bị đang đăng nhập',
                      onTap: onDevicesTap,
                    ),
                    _SettingsRow(
                      icon: Icons.lock_rounded,
                      iconBg: c.warning,
                      label: 'Đổi mật khẩu',
                      subtitle: 'Bảo vệ tài khoản cửa hàng',
                      onTap: onPasswordTap,
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpacing.xl2),
                const Padding(
                    padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    child: _ProfileSectionTitle(
                        Icons.support_agent_rounded, 'Hỗ trợ')),
                Padding(
                  padding: pad,
                  child: _SettingsCard(rows: [
                    _SettingsRow(
                      icon: Icons.support_agent_rounded,
                      iconBg: c.accent2,
                      label: 'Liên hệ hỗ trợ',
                      onTap: onSupportTap,
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpacing.xl2),
                Padding(
                  padding: pad,
                  child: OutlinedButton.icon(
                    onPressed: onLogout,
                    icon:
                        const Icon(Icons.logout_rounded, size: AppSize.iconMd),
                    label: const Text('Đăng xuất'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.danger,
                      backgroundColor: c.danger.withValues(alpha: .08),
                      side: BorderSide(color: c.danger.withValues(alpha: .35)),
                      minimumSize:
                          const Size(double.infinity, AppSize.buttonHeight),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _MonthlyActivityCard extends StatelessWidget {
  final int revenue, total, completed, cancelled;
  final List<Map<String, dynamic>> daily;
  const _MonthlyActivityCard({
    required this.revenue,
    required this.total,
    required this.completed,
    required this.cancelled,
    required this.daily,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      child: GlassCard(
        blur: false,
        glow: c.success,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PHÍ SHIP THÁNG NÀY',
              style: AppTextStyles.caption
                  .copyWith(color: c.textTertiary, letterSpacing: .6)),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(Fmt.currency(revenue),
                style: AppTextStyles.metricLarge.copyWith(color: c.success)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Expanded(
                child: _MonthMetric(
                    value: '$total', label: 'Tổng đơn', color: c.primary)),
            SizedBox(
                height: 32, child: VerticalDivider(width: 1, color: c.divider)),
            Expanded(
                child: _MonthMetric(
                    value: '$completed',
                    label: 'Hoàn thành',
                    color: c.success)),
            SizedBox(
                height: 32, child: VerticalDivider(width: 1, color: c.divider)),
            Expanded(
                child: _MonthMetric(
                    value: '$cancelled', label: 'Đã huỷ', color: c.danger)),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, color: c.divider),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Expanded(
              child: Text('Đơn hàng 7 ngày qua',
                  style:
                      AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          _WeekBars(daily: daily),
        ]),
      ),
    );
  }
}

class _MonthMetric extends StatelessWidget {
  final String value, label;
  final Color color;
  const _MonthMetric(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: AppTextStyles.metric.copyWith(color: color)),
        const SizedBox(height: AppSpacing.xxs),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption
                .copyWith(color: context.colors.textSecondary)),
      ]);
}

class _WeekBars extends StatelessWidget {
  final List<Map<String, dynamic>> daily;
  const _WeekBars({required this.daily});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    final days = List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      Map<String, dynamic>? item;
      for (final entry in daily) {
        if (entry['date']?.toString() == key) {
          item = entry;
          break;
        }
      }
      return (day, Fmt.toInt(item?['count']));
    });
    final maxCount = days.fold<int>(
        1, (current, item) => item.$2 > current ? item.$2 : current);
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((item) {
          final isToday = item.$1.day == now.day &&
              item.$1.month == now.month &&
              item.$1.year == now.year;
          final height = 6 + (item.$2 / maxCount * 52);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child:
                  Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${item.$2}',
                    style: AppTextStyles.caption
                        .copyWith(color: isToday ? c.primary : c.textTertiary)),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: AppDuration.normal,
                  height: height,
                  decoration: BoxDecoration(
                    color: item.$2 == 0
                        ? c.surfaceAlt
                        : isToday
                            ? c.primary
                            : c.primary.withValues(alpha: 0.25),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xs)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(labels[item.$1.weekday - 1],
                    style: AppTextStyles.caption.copyWith(
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                        color: isToday ? c.primary : c.textTertiary)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProfileSectionTitle(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      AppIconBadge(icon: icon, color: c.primary, size: 28),
      const SizedBox(width: AppSpacing.sm),
      Text(text,
          style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
    ]);
  }
}

// ─── Settings card ────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<_SettingsRow> rows;
  const _SettingsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      blur: false,
      padding: EdgeInsets.zero,
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Column(children: [
            e.value,
            if (!isLast)
              Divider(
                  height: 1,
                  indent: AppSpacing.lg + 36 + AppSpacing.md,
                  color: c.divider),
          ]);
        }).toList(),
      ),
    );
  }
}

// ─── Support section (remote config) ─────────────────────────────────────────

class _SupportSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supportConfigProvider);
    final c = context.colors;

    Widget message(IconData icon, String title, String body,
            {VoidCallback? onRetry}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(children: [
            AppIconBadge(icon: icon, color: c.textSecondary, size: 64),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
            const SizedBox(height: AppSpacing.xs),
            Text(body,
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(color: c.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(140, AppSize.buttonHeight),
                  backgroundColor: c.primarySoft,
                  foregroundColor: c.primary,
                ),
                child: const Text('Thử lại'),
              ),
            ],
          ]),
        );

    return async.when(
      loading: () => Column(children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            height: 68,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          if (i < 2) const SizedBox(height: AppSpacing.md),
        ],
      ]),
      error: (_, __) => message(
        Icons.wifi_off_rounded,
        'Không tải được thông tin hỗ trợ',
        'Kiểm tra kết nối rồi thử lại',
        onRetry: () => ref.invalidate(supportConfigProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return message(
            Icons.support_agent_rounded,
            'Chưa có thông tin hỗ trợ',
            'Vui lòng quay lại sau hoặc liên hệ FlashShip qua kênh quen thuộc',
          );
        }
        return Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            _SupportTile(item: items[i]),
            if (i < items.length - 1) const SizedBox(height: AppSpacing.md),
          ],
        ]);
      },
    );
  }
}

class _SupportTile extends StatelessWidget {
  final SupportConfigItem item;
  const _SupportTile({required this.item});

  String get _hint {
    final v = item.value.trim();
    return switch (item.type) {
      'phone' => 'Gọi ${v.replaceFirst('tel:', '')}',
      'email' => v.replaceFirst('mailto:', ''),
      'zalo' => 'Nhắn tin qua Zalo',
      'facebook' => 'Mở trang Facebook',
      _ => Uri.tryParse(v)?.host.isNotEmpty == true
          ? Uri.parse(v).host
          : 'Mở liên kết',
    };
  }

  // Giá trị cấu hình từ server có thể sai định dạng hoặc máy không có ứng dụng
  // xử lý — báo cho người dùng thay vì im lặng.
  Future<void> _open(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(item.uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      AppSnackbar.error(
          context, 'Không thể mở "${item.title}" trên thiết bị này');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = item.displayColor;
    return Material(
      color: c.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: glassIconDecoration(context, tint),
              child: item.assetIcon != null
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.asset(item.assetIcon!),
                    )
                  : Icon(item.materialIcon ?? Icons.link_rounded,
                      size: 22, color: tint),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(_hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTextStyles.label.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: AppSize.iconMd, color: c.textTertiary),
          ]),
        ),
      ),
    );
  }
}

// ─── Settings row ─────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final bool showChevron;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.label,
    this.subtitle,
    this.labelColor,
    this.showChevron = true,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration:
                  glassIconDecoration(context, iconBg, radius: AppRadius.sm),
              child: Icon(icon, size: 18, color: iconBg),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: labelColor ?? c.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle!,
                        style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w500,
                            color: c.textSecondary)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 4),
            ],
            if (showChevron)
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: c.textTertiary),
          ]),
        ),
      ),
    );
  }
}

// ─── Change phone sheet ─────────────────────────────────────────────────────────

class _ChangePhoneSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _ChangePhoneSheet({required this.onSuccess});

  @override
  ConsumerState<_ChangePhoneSheet> createState() => _ChangePhoneSheetState();
}

class _ChangePhoneSheetState extends ConsumerState<_ChangePhoneSheet> {
  final _phoneCtrl = TextEditingController();
  final _otpCtl = OtpInputController();

  int _step = 1;
  String _lockedPhone = '';
  int _countdown = 60;
  Timer? _timer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 0) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    final ok = await ref.read(authProvider.notifier).sendChangePhoneOtp(phone);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _lockedPhone = phone;
        _step = 2;
      });
      _startCountdown();
    } else {
      setState(() {});
    }
  }

  void _backToPhone() {
    _timer?.cancel();
    _otpCtl.clear();
    setState(() => _step = 1);
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;
    final ok =
        await ref.read(authProvider.notifier).sendChangePhoneOtp(_lockedPhone);
    if (ok) _startCountdown();
    if (mounted) setState(() {});
  }

  Future<void> _verify() async {
    if (_otpCtl.otp.length < 6) return;
    final ok = await ref
        .read(authProvider.notifier)
        .verifyChangePhone(_lockedPhone, _otpCtl.otp);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      widget.onSuccess();
    } else {
      setState(() {});
      _otpCtl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final c = context.colors;

    return AppSheet(
      icon: Icons.phone_iphone_rounded,
      color: c.info,
      title: 'Đổi số điện thoại',
      subtitle:
          _step == 1 ? 'Bước 1/2 · Nhập số mới' : 'Bước 2/2 · Xác thực OTP',
      footer: _step == 1
          ? AppButton(
              label: 'Gửi mã OTP',
              onPressed: _sendOtp,
              isLoading: auth.isLoading,
            )
          : AppButton(
              label: 'Xác nhận',
              onPressed: _otpCtl.otp.length == 6 ? _verify : null,
              isLoading: auth.isLoading,
            ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_step == 1) ...[
          Container(
            decoration: BoxDecoration(
              color: c.glass,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: c.glassBorder, width: 1.2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _sendOtp(),
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Số điện thoại mới',
                hintStyle: AppTextStyles.body.copyWith(color: c.textTertiary),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Icon(Icons.phone_iphone_rounded,
                      size: AppSize.iconMd, color: c.primary),
                ),
                prefixIconConstraints: const BoxConstraints(),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text('Mã OTP sẽ được gửi tới số điện thoại này',
                style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w500, color: c.textTertiary)),
          ),
          if (auth.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppErrorBox(auth.error!),
          ],
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(children: [
              Icon(Icons.sms_outlined, size: AppSize.iconMd, color: c.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text.rich(TextSpan(
                  style: AppTextStyles.body.copyWith(color: c.textSecondary),
                  children: [
                    const TextSpan(text: 'Mã 6 số đã gửi tới '),
                    TextSpan(
                      text: _lockedPhone,
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: c.textPrimary),
                    ),
                  ],
                )),
              ),
              GestureDetector(
                onTap: _backToPhone,
                behavior: HitTestBehavior.opaque,
                child: Text('Đổi số',
                    style: AppTextStyles.label.copyWith(color: c.primary)),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl2),
          OtpInput(
            controller: _otpCtl,
            onChanged: (otp) {
              if (otp.length == 6) _verify();
            },
          ),
          if (auth.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppErrorBox(auth.error!),
          ],
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: _countdown > 0
                ? Text('Gửi lại sau $_countdown giây',
                    style: AppTextStyles.label.copyWith(color: c.textSecondary))
                : GestureDetector(
                    onTap: _resend,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs, horizontal: AppSpacing.md),
                      child: Text('Gửi lại mã OTP',
                          style:
                              AppTextStyles.label.copyWith(color: c.primary)),
                    ),
                  ),
          ),
        ],
      ]),
    );
  }
}
