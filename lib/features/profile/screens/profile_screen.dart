import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../stats/stats_repository.dart';
import '../../../core/widgets/address_picker_screen.dart';
import '../../../core/widgets/map_picker_screen.dart';
import '../../security/pin_setup_screen.dart';
import '../../security/providers/pin_provider.dart';
import 'devices_screen.dart';
import 'change_password_screen.dart';
import 'support_screen.dart';
import '../../../core/router/app_route.dart';

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
      onDevicesTap: () =>
          Navigator.push(context, appRoute(const DevicesScreen())),
      onPasswordTap: () =>
          Navigator.push(context, appRoute(const ChangePasswordScreen())),
      onSupportTap: () =>
          Navigator.push(context, appRoute(const SupportScreen())),
      onLogout: () => _logout(context, ref),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _showProfileSettings(
      BuildContext context, WidgetRef ref, ShopUserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .28),
      builder: (sheetContext) {
        void close(VoidCallback action) {
          Navigator.pop(sheetContext);
          action();
        }

        void legal(String slug, String title) => close(() => Navigator.push(
            context, appRoute(LegalPageScreen(slug: slug, title: title))));

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

          Widget group({
            required IconData icon,
            required String label,
            required String subtitle,
            required List<_SettingsRow> rows,
          }) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsGroupHeading(
                    icon: icon,
                    title: label,
                    subtitle: subtitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SettingsCard(rows: rows),
                  const SizedBox(height: AppSpacing.xl),
                ],
              );

          return AppSheet(
            icon: Icons.settings_rounded,
            title: 'Cài đặt',
            subtitle: 'Thiết lập cửa hàng và bảo mật',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              group(
                icon: Icons.storefront_outlined,
                label: 'Tài khoản cửa hàng',
                subtitle: 'Thông tin nhận diện và liên hệ',
                rows: [
                  _SettingsRow(
                    icon: Icons.storefront_rounded,
                    iconBg: c.primary,
                    label: 'Thông tin cửa hàng',
                    subtitle: 'Tên, địa chỉ và khu vực hoạt động',
                    onTap: () =>
                        close(() => _showEditSheet(context, ref, user)),
                  ),
                  _SettingsRow(
                    icon: Icons.phone_iphone_rounded,
                    iconBg: c.info,
                    label: 'Đổi số điện thoại',
                    subtitle: user.phone,
                    onTap: () => close(() => _showChangePhoneSheet(context)),
                  ),
                ],
              ),
              group(
                icon: Icons.tune_rounded,
                label: 'Trải nghiệm ứng dụng',
                subtitle: 'Giao diện và lớp bảo vệ khi mở app',
                rows: [
                  _SettingsRow(
                    icon: Icons.dark_mode_rounded,
                    iconBg: c.accent2,
                    label: 'Chế độ hiển thị',
                    subtitle: 'Đang dùng: ${_themeModeLabel(themeMode)}',
                    onTap: () => close(() => _showThemeModeSheet(context, ref)),
                  ),
                  _SettingsRow(
                    icon: Icons.pin_rounded,
                    iconBg: c.warning,
                    label: 'Khoá bằng mã PIN',
                    subtitle: pin.isEnabled
                        ? 'Đang bật bảo vệ khi mở ứng dụng'
                        : 'Chưa bật bảo vệ bằng mã PIN',
                    showChevron: false,
                    trailing:
                        Switch(value: pin.isEnabled, onChanged: togglePin),
                    onTap: () => togglePin(!pin.isEnabled),
                  ),
                ],
              ),
              group(
                icon: Icons.gavel_outlined,
                label: 'Pháp lý và quyền riêng tư',
                subtitle: 'Thông tin sử dụng dịch vụ Flash Ship',
                rows: [
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
                    onTap: () =>
                        legal('terms-of-service', 'Điều khoản sử dụng'),
                  ),
                ],
              ),
              const _SettingsGroupHeading(
                icon: Icons.warning_amber_rounded,
                title: 'Vùng nguy hiểm',
                subtitle: 'Thao tác này không thể hoàn tác',
                danger: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              _SettingsCard(
                backgroundColor: c.danger.withValues(alpha: .045),
                borderColor: c.danger.withValues(alpha: .18),
                rows: [
                  _SettingsRow(
                    icon: Icons.delete_forever_rounded,
                    iconBg: c.danger,
                    labelColor: c.danger,
                    label: 'Xóa tài khoản',
                    subtitle: 'Xoá vĩnh viễn dữ liệu cửa hàng',
                    showChevron: false,
                    onTap: () => close(() => _deleteAccount(context, ref)),
                  ),
                ],
              ),
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
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .28),
      builder: (ctx) => Consumer(builder: (_, sRef, __) {
        final current = sRef.watch(themeModeProvider);
        Widget option(ThemeMode mode, IconData icon, String label,
                String subtitle, List<Color> previewColors) =>
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ThemeModeOption(
                icon: icon,
                label: label,
                subtitle: subtitle,
                previewColors: previewColors,
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
          subtitle: 'Chọn giao diện phù hợp với bạn',
          child: Column(children: [
            _SettingsInfoBanner(
              icon: Icons.palette_outlined,
              color: ctx.colors.accent2,
              title: 'Cá nhân hóa trải nghiệm',
              subtitle:
                  'Bạn có thể thay đổi giao diện bất cứ lúc nào trong Cài đặt.',
            ),
            const SizedBox(height: AppSpacing.lg),
            option(
              ThemeMode.light,
              Icons.light_mode_outlined,
              'Giao diện sáng',
              'Sáng rõ và dễ nhìn ban ngày',
              const [Color(0xFFFFE9DE), Colors.white],
            ),
            option(
              ThemeMode.dark,
              Icons.dark_mode_outlined,
              'Giao diện tối',
              'Dịu mắt khi sử dụng ban đêm',
              const [Color(0xFF242A35), Color(0xFF141820)],
            ),
            option(
              ThemeMode.system,
              Icons.brightness_auto_outlined,
              'Theo hệ thống',
              'Tự động theo cài đặt của thiết bị',
              const [Color(0xFFFFE9DE), Color(0xFF242A35)],
            ),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .28),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsInfoBanner(
                  icon: Icons.storefront_outlined,
                  color: c.primary,
                  title: 'Hồ sơ cửa hàng',
                  subtitle:
                      'Thông tin chính xác giúp tài xế nhận và giao hàng thuận tiện hơn.',
                ),
                const SizedBox(height: AppSpacing.lg),
                const AppLabel('Tên cửa hàng'),
                const SizedBox(height: 7),
                AppField(
                  controller: nameCtrl,
                  hint: 'Nhập tên cửa hàng',
                  fillColor: c.surfaceAlt,
                  outlined: true,
                  textInputAction: TextInputAction.done,
                  prefixIcon: Icon(Icons.badge_outlined,
                      size: AppSize.iconMd, color: c.primary),
                ),
                const SizedBox(height: AppSpacing.lg),
                const AppLabel('Địa chỉ cửa hàng'),
                const SizedBox(height: 7),
                _SettingsPickerField(
                  icon: Icons.location_on_outlined,
                  value: addrCtrl.text,
                  hint: 'Chọn địa chỉ cửa hàng',
                  onTap: () async {
                    final result = await Navigator.of(ctx).push<MapPickResult>(
                      appRoute(
                        AddressPickerScreen(
                            title: 'Địa chỉ cửa hàng',
                            cityId: cityId,
                            cityName: cityName),
                      ),
                    );
                    if (result != null) {
                      setSt(() => addrCtrl.text = result.address);
                    }
                  },
                ),
                Consumer(builder: (_, cRef, __) {
                  final citiesAsync = cRef.watch(citiesProvider);
                  return citiesAsync.maybeWhen(
                      data: (cities) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.lg),
                            const AppLabel('Khu vực hoạt động'),
                            const SizedBox(height: 7),
                            _SettingsPickerField(
                              icon: Icons.location_city_rounded,
                              value: cityName ?? '',
                              hint: 'Chọn khu vực hoạt động',
                              onTap: () async {
                                final result = await showCityPicker(ctx,
                                    cities: cities, selectedId: cityId);
                                if (result != null) {
                                  setSt(() {
                                    cityId = result.id;
                                    cityName = result.name;
                                  });
                                }
                              },
                            ),
                          ],
                        );
                      },
                      orElse: () => const SizedBox.shrink());
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showChangePhoneSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .28),
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
      appRoute(const PinSetupScreen()),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteAccountDialog(
        title: 'Xóa tài khoản?',
        description: 'Dữ liệu của cửa hàng sẽ bị xóa khỏi hệ thống Flash Ship.',
        items: const [
          'Hồ sơ và thiết lập cửa hàng',
          'Lịch sử đơn hàng và thống kê',
          'Thiết bị và quyền truy cập',
        ],
        confirmLabel: 'Tôi hiểu, tiếp tục',
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirm1 != true || !context.mounted) return;

    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteAccountDialog(
        title: 'Xác nhận lần cuối',
        description:
            'Thao tác này không thể hoàn tác. Các đơn đang chờ cũng sẽ bị huỷ tự động.',
        items: const ['Tài khoản sẽ không thể khôi phục sau khi xóa'],
        confirmLabel: 'Xóa vĩnh viễn',
        finalStep: true,
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
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

    final header = DecoratedBox(
      decoration: BoxDecoration(
        color: context.isDark ? c.primarySoft : const Color(0xFFFFE9DE),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Tài '),
                  TextSpan(
                    text: 'khoản',
                    style: TextStyle(color: c.primary),
                  ),
                ]),
                style: AppTextStyles.screenTitle.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.storefront_rounded, size: 15, color: c.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Quản lý cửa hàng và thiết lập của bạn',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    const pad = EdgeInsets.symmetric(horizontal: AppSpacing.lg);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        header,
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            onRefresh: () async => ref.invalidate(_profileStatsProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppBottomNav.reservedHeight(context) + 16,
              ),
              children: [
                Padding(
                  padding: pad,
                  child: _ShopProfileCard(
                    user: user,
                    completed: completed,
                    onSettingsTap: onSettingsTap,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl2),
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
                      Icons.settings_suggest_rounded, 'Cài đặt'),
                ),
                Padding(
                  padding: pad,
                  child: _SettingsCard(rows: [
                    _SettingsRow(
                      icon: Icons.tune_rounded,
                      iconBg: c.primary,
                      label: 'Thiết lập tài khoản và ứng dụng',
                      subtitle: 'Thông tin cửa hàng, giao diện, PIN và pháp lý',
                      onTap: onSettingsTap,
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

class _ShopProfileCard extends StatelessWidget {
  final ShopUserModel user;
  final int completed;
  final VoidCallback onSettingsTap;

  const _ShopProfileCard({
    required this.user,
    required this.completed,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final contact = [
      user.phone,
      if (user.cityName?.trim().isNotEmpty == true) user.cityName!.trim(),
    ].where((item) => item.isNotEmpty).join(' · ');
    final address = user.address?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              user.initials,
              style: AppTextStyles.screenTitle.copyWith(
                color: c.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (contact.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    contact,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Cài đặt tài khoản',
            onPressed: onSettingsTap,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(42),
              foregroundColor: c.primary,
              backgroundColor: c.primarySoft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.settings_outlined, size: 19),
          ),
        ]),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.location_on_outlined, size: 17, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 15, color: c.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$completed đơn hoàn thành trong tháng',
                maxLines: 2,
                style: AppTextStyles.caption.copyWith(
                  color: c.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD1BF)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PHÍ SHIP THÁNG NÀY',
            style: AppTextStyles.caption
                .copyWith(color: c.textTertiary, letterSpacing: .6)),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(Fmt.currency(revenue),
              style: AppTextStyles.metricLarge.copyWith(
                color: c.primary,
                fontWeight: FontWeight.w700,
              )),
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
                  value: '$completed', label: 'Hoàn thành', color: c.success)),
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
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        _WeekBars(daily: daily),
      ]),
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
    final captionLineHeight =
        MediaQuery.textScalerOf(context).scale(AppFontSize.caption) *
            (AppTextStyles.caption.height ?? 1.3);
    final chartHeight = 68 + captionLineHeight * 2;

    return SizedBox(
      height: chartHeight,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
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
      Container(
        width: 4,
        height: 28,
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
    ]);
  }
}

class _SettingsInfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _SettingsInfoBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .075),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .15)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 11),
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
              const SizedBox(height: 3),
              Text(
                subtitle,
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

class _SettingsPickerField extends StatelessWidget {
  final IconData icon;
  final String value;
  final String hint;
  final VoidCallback onTap;

  const _SettingsPickerField({
    required this.icon,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasValue = value.trim().isNotEmpty;
    return Material(
      color: c.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.divider),
          ),
          child: Row(children: [
            Icon(icon, size: 20, color: c.primary),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                hasValue ? value : hint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: hasValue ? c.textPrimary : c.textTertiary,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              hasValue ? Icons.edit_outlined : Icons.chevron_right_rounded,
              size: 18,
              color: hasValue ? c.primary : c.textTertiary,
            ),
          ]),
        ),
      ),
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> previewColors;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.previewColors,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: AppDuration.fast,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? c.primary : c.divider,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(children: [
            Container(
              width: 54,
              height: 42,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: previewColors),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.divider),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  width: 27,
                  height: 5,
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon,
                        size: 17,
                        color: selected ? c.primary : c.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? c.primary : c.textTertiary,
              size: 21,
            ),
          ]),
        ),
      ),
    );
  }
}

class _SettingsStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _SettingsStepIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Expanded(
        child: Row(
          children: List.generate(totalSteps, (index) {
            final active = index < currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: AppDuration.fast,
                height: 4,
                margin: EdgeInsets.only(
                  right: index == totalSteps - 1 ? 0 : 6,
                ),
                decoration: BoxDecoration(
                  color: active ? c.primary : c.divider,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            );
          }),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        'Bước $currentStep/$totalSteps',
        style: AppTextStyles.caption.copyWith(
          color: c.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ]);
  }
}

class _DeleteAccountDialog extends StatelessWidget {
  final String title;
  final String description;
  final List<String> items;
  final String confirmLabel;
  final bool finalStep;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _DeleteAccountDialog({
    required this.title,
    required this.description,
    required this.items,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.finalStep = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.danger.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              finalStep
                  ? Icons.delete_forever_rounded
                  : Icons.warning_amber_rounded,
              size: 28,
              color: c.danger,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionTitle.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: c.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.danger.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.danger.withValues(alpha: .14)),
            ),
            child: Column(
              children: items
                  .map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.remove_circle_outline_rounded,
                                size: 16, color: c.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: AppTextStyles.caption.copyWith(
                                  color: c.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: c.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                confirmLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onCancel,
              child: Text(finalStep ? 'Quay lại' : 'Giữ tài khoản'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SettingsGroupHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;

  const _SettingsGroupHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = danger ? c.danger : c.primary;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.bodyStrong.copyWith(
                color: danger ? c.danger : c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

// ─── Settings card ────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<_SettingsRow> rows;
  final Color? backgroundColor;
  final Color? borderColor;

  const _SettingsCard({
    required this.rows,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? c.divider),
      ),
      clipBehavior: Clip.antiAlias,
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
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconBg),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: labelColor ?? c.textPrimary,
                        fontWeight: FontWeight.w600,
                      )),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle!,
                        style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w400,
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
    final ok = await ref.read(authProvider.notifier).resendCode(_lockedPhone);
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
        _SettingsStepIndicator(currentStep: _step, totalSteps: 2),
        const SizedBox(height: AppSpacing.lg),
        if (_step == 1) ...[
          _SettingsInfoBanner(
            icon: Icons.verified_user_outlined,
            color: c.info,
            title: 'Xác minh số điện thoại mới',
            subtitle:
                'Số mới sẽ được dùng để đăng nhập và nhận thông báo quan trọng.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppLabel('Số điện thoại mới'),
          const SizedBox(height: 7),
          PhoneField(
            controller: _phoneCtrl,
            hint: '912 345 678',
            fillColor: c.surfaceAlt,
            outlined: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendOtp(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: c.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mã OTP gồm 6 số sẽ được gửi tới số điện thoại này.',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w400,
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (auth.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppErrorBox(auth.error!),
          ],
        ] else ...[
          _SettingsInfoBanner(
            icon: Icons.sms_outlined,
            color: c.primary,
            title: 'Nhập mã xác nhận',
            subtitle: 'Mã 6 số đã được gửi tới $_lockedPhone',
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _backToPhone,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Đổi số điện thoại'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
