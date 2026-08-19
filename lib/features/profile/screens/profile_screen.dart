import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../legal/legal_page_screen.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/otp_input.dart';
import '../../../core/widgets/step_progress_bar.dart';
import '../../auth/models/shop_user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/cities_provider.dart';
import '../../auth/widgets/city_picker_sheet.dart';
import '../providers/support_config_provider.dart';
import '../../order/providers/order_provider.dart';
import '../../../core/widgets/address_picker_screen.dart';
import '../../../core/widgets/map_picker_screen.dart';
import '../../security/pin_setup_screen.dart';
import '../../security/providers/pin_provider.dart';
import 'devices_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user   = ref.watch(authProvider).user;
    final orders = ref.watch(orderListProvider).orders;
    if (user == null) return const SizedBox.shrink();

    final c         = context.colors;
    final completed = orders.where((o) => o.isCompleted).length;
    final active    = orders.where((o) => o.isActive).length;
    final themeMode = ref.watch(themeModeProvider);
    final topPad    = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: c.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPad + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Hero header — nền trung tính, không gradient ───────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 24),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(bottom: BorderSide(color: c.divider)),
              ),
              child: Column(children: [
                // Edit avatar
                GestureDetector(
                  onTap: () => _pickAvatar(context, ref),
                  child: Stack(alignment: Alignment.bottomRight, children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.surfaceAlt,
                        border: Border.all(color: c.divider, width: 1.5),
                        image: user.avatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(user.avatarUrl!),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: user.avatarUrl == null
                          ? Center(
                              child: Text(user.initials,
                                  style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800)))
                          : null,
                    ),
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: c.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.divider, width: 1),
                      ),
                      child: Icon(Icons.camera_alt_rounded,
                          size: 12, color: c.primary),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(user.name,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.phone_rounded,
                      size: 12, color: c.textTertiary),
                  const SizedBox(width: 4),
                  Text(user.phone,
                      style: TextStyle(
                          fontSize: 13, color: c.textSecondary)),
                  if (user.cityName?.isNotEmpty == true) ...[
                    Text('  ·  ',
                        style: TextStyle(color: c.textTertiary)),
                    Icon(Icons.location_on_rounded,
                        size: 12, color: c.textTertiary),
                    const SizedBox(width: 2),
                    Text(user.cityName!,
                        style: TextStyle(
                            fontSize: 13, color: c.textSecondary)),
                  ],
                ]),

                const SizedBox(height: 20),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HeroStat(label: 'Tổng đơn',
                        value: orders.length.toString()),
                    _HeroDivider(),
                    _HeroStat(label: 'Hoàn thành',
                        value: completed.toString()),
                    _HeroDivider(),
                    _HeroStat(label: 'Đang chạy',
                        value: active.toString()),
                  ],
                ),
              ]),
            ),

            const SizedBox(height: 20),

            // ── Section: Cửa hàng ────────────────────────────────────────
            _SectionLabel('CỬA HÀNG'),
            _SettingsCard(rows: [
              _SettingsRow(
                icon: Icons.edit_outlined,
                iconBg: c.primary,
                label: 'Chỉnh sửa thông tin',
                onTap: () => _showEditSheet(context, ref, user),
              ),
              _SettingsRow(
                icon: Icons.contacts_outlined,
                iconBg: const Color(0xFF5856D6),
                label: 'Địa chỉ thường giao',
                onTap: () => context.push('/address-book'),
              ),
              _SettingsRow(
                icon: Icons.lock_outline_rounded,
                iconBg: const Color(0xFF636366),
                label: 'Đổi mật khẩu',
                onTap: () => _showPasswordSheet(context, ref),
              ),
              _SettingsRow(
                icon: Icons.phone_iphone_rounded,
                iconBg: const Color(0xFF34C759),
                label: 'Đổi số điện thoại',
                onTap: () => _showChangePhoneSheet(context),
              ),
              _SettingsRow(
                icon: Icons.pin_rounded,
                iconBg: const Color(0xFFFF9500),
                label: 'Khoá bằng mã PIN',
                showChevron: false,
                trailing: Switch(
                  value: ref.watch(pinProvider).isEnabled,
                  onChanged: (v) => _togglePinLock(context, ref, v),
                ),
                onTap: () => _togglePinLock(context, ref, !ref.read(pinProvider).isEnabled),
              ),
              _SettingsRow(
                icon: Icons.devices_rounded,
                iconBg: const Color(0xFF5AC8FA),
                label: 'Thiết bị đăng nhập',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const DevicesScreen())),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Section: Giao diện ───────────────────────────────────────
            _SectionLabel('GIAO DIỆN'),
            _SettingsCard(rows: [
              _SettingsRow(
                icon: Icons.dark_mode_outlined,
                iconBg: const Color(0xFF1C1C1E),
                label: 'Chế độ hiển thị',
                trailing: Text(
                  _themeModeLabel(themeMode),
                  style: TextStyle(fontSize: 14, color: c.textSecondary),
                ),
                onTap: () => _showThemeModeSheet(context, ref),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Section: Hỗ trợ ─────────────────────────────────────────
            _SectionLabel('HỖ TRỢ'),
            _SupportSection(),

            const SizedBox(height: 20),

            // ── Section: Pháp lý ─────────────────────────────────────────
            _SectionLabel('PHÁP LÝ'),
            _SettingsCard(rows: [
              _SettingsRow(
                icon: Icons.shield_outlined,
                iconBg: const Color(0xFF007AFF),
                label: 'Chính sách quyền riêng tư',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LegalPageScreen(
                      slug:  'privacy-policy',
                      title: 'Chính sách quyền riêng tư',
                    ))),
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                iconBg: const Color(0xFF5856D6),
                label: 'Điều khoản sử dụng',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LegalPageScreen(
                      slug:  'terms-of-service',
                      title: 'Điều khoản sử dụng',
                    ))),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Section: Tài khoản ───────────────────────────────────────
            _SectionLabel('TÀI KHOẢN'),
            _SettingsCard(rows: [
              _SettingsRow(
                icon: Icons.logout_rounded,
                iconBg: AppColors.danger,
                label: 'Đăng xuất',
                labelColor: context.colors.danger,
                showChevron: false,
                onTap: () => _logout(context, ref),
              ),
              _SettingsRow(
                icon: Icons.delete_forever_outlined,
                iconBg: AppColors.danger,
                label: 'Xóa tài khoản',
                labelColor: context.colors.danger,
                showChevron: false,
                onTap: () => _deleteAccount(context, ref),
              ),
            ]),

            const SizedBox(height: 28),
            Center(
              child: Text('FlashShip Shop',
                  style: TextStyle(fontSize: 12,
                      color: context.colors.textTertiary)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static String _themeModeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light  => 'Sáng',
        ThemeMode.dark   => 'Tối',
        ThemeMode.system => 'Hệ thống',
      };

  void _showThemeModeSheet(BuildContext context, WidgetRef ref) {
    final current = ref.read(themeModeProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        Widget option(ThemeMode mode, IconData icon, String label) =>
            ListTile(
              leading: Icon(icon, color: c.textSecondary),
              title: Text(label,
                  style: TextStyle(fontSize: 15, color: c.textPrimary)),
              trailing: mode == current
                  ? Icon(Icons.check_rounded, color: c.primary, size: 20)
                  : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).set(mode);
                Navigator.pop(ctx);
              },
            );
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Chế độ hiển thị',
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
              ),
            ),
            const Divider(height: 1),
            option(ThemeMode.light, Icons.light_mode_outlined, 'Sáng'),
            option(ThemeMode.dark, Icons.dark_mode_outlined, 'Tối'),
            option(ThemeMode.system, Icons.brightness_auto_outlined,
                'Theo hệ thống'),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    final err =
        await ref.read(authProvider.notifier).uploadAvatar(img.path);
    if (err != null && context.mounted) {
      AppSnackbar.error(context, err);
    }
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, ShopUserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final addrCtrl = TextEditingController(text: user.address ?? '');
    int?    cityId   = user.cityId;
    String? cityName = user.cityName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final c = ctx.colors;
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const SizedBox(height: 16),
              const Text('Chỉnh sửa thông tin',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              const AppLabel('Tên cửa hàng'),
              const SizedBox(height: 8),
              AppField(controller: nameCtrl, hint: 'Tên cửa hàng'),
              const SizedBox(height: 14),
              const AppLabel('Địa chỉ'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.of(ctx).push<MapPickResult>(
                    MaterialPageRoute(
                      builder: (_) => const AddressPickerScreen(
                          title: 'Địa chỉ cửa hàng'),
                    ),
                  );
                  if (result != null) {
                    setSt(() {
                      addrCtrl.text = result.address;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        addrCtrl.text.isNotEmpty
                            ? addrCtrl.text
                            : 'Chọn địa chỉ...',
                        style: TextStyle(
                            fontSize: 15,
                            color: addrCtrl.text.isNotEmpty
                                ? c.textPrimary
                                : c.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.location_on_outlined,
                        size: 18, color: c.primary),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Consumer(builder: (_, cRef, __) {
                final citiesAsync = cRef.watch(citiesProvider);
                return citiesAsync.maybeWhen(
                  data: (cities) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppLabel('Khu vực'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final result = await showCityPicker(
                            ctx,
                            cities: cities,
                            selectedId: cityId,
                          );
                          if (result != null) {
                            setSt(() {
                              cityId   = result.id;
                              cityName = result.name;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 15),
                          decoration: BoxDecoration(
                            color: c.surfaceAlt,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(children: [
                            Expanded(child: Text(
                                cityName ?? 'Chọn khu vực...',
                                style: TextStyle(
                                    fontSize: 15,
                                    color: cityName != null
                                        ? c.textPrimary
                                        : c.textSecondary))),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                size: 20, color: c.textSecondary),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  orElse: () => const SizedBox.shrink(),
                );
              }),
              const SizedBox(height: 24),
              AppButton(
                label: 'Lưu thay đổi',
                onPressed: () async {
                  Navigator.pop(ctx);
                  final err =
                      await ref.read(authProvider.notifier).updateProfile(
                    name:    nameCtrl.text.trim(),
                    address: addrCtrl.text.trim(),
                    cityId:  cityId,
                  );
                  if (err != null && context.mounted) {
                    AppSnackbar.error(context, err);
                  }
                },
              ),
            ]),
          );
        },
      ),
    );
  }

  void _showPasswordSheet(BuildContext context, WidgetRef ref) {
    final currCtrl = TextEditingController();
    final newCtrl  = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: ctx.colors.divider,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Đổi mật khẩu',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          const AppLabel('Mật khẩu hiện tại'),
          const SizedBox(height: 8),
          AppField(
              controller: currCtrl,
              hint: '••••••••',
              obscureText: true),
          const SizedBox(height: 14),
          const AppLabel('Mật khẩu mới'),
          const SizedBox(height: 8),
          AppField(
              controller: newCtrl,
              hint: '••••••••',
              obscureText: true),
          const SizedBox(height: 24),
          AppButton(
            label: 'Xác nhận',
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await ref
                  .read(authProvider.notifier)
                  .changePassword(
                      current: currCtrl.text, next: newCtrl.text);
              if (context.mounted) {
                if (err == null) {
                  AppSnackbar.success(context, 'Đổi mật khẩu thành công');
                } else {
                  AppSnackbar.error(context, err);
                }
              }
            },
          ),
        ]),
      ),
    );
  }

  void _showChangePhoneSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChangePhoneSheet(
        onSuccess: () {
          if (context.mounted) {
            AppSnackbar.success(context, 'Đổi số điện thoại thành công');
          }
        },
      ),
    );
  }

  Future<void> _togglePinLock(BuildContext context, WidgetRef ref, bool enable) async {
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
          style:
              TextStyle(color: ctx.colors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: ctx.colors.danger),
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
          style:
              TextStyle(color: ctx.colors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: ctx.colors.danger),
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
            style:
                TextStyle(color: ctx.colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: ctx.colors.danger),
            child: const Text('Đăng xuất',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authProvider.notifier).logout();
  }
}

// ─── Hero stat item ───────────────────────────────────────────────────────────

class _HeroStat extends StatelessWidget {
  final String label, value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: c.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 11, color: c.textSecondary)),
      ]),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1, height: 32,
        color: context.colors.divider);
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.colors.textTertiary,
                letterSpacing: 0.6)),
      );
}

// ─── Settings card ────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<_SettingsRow> rows;
  const _SettingsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: c.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(
          children: rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            return Column(children: [
              e.value,
              if (!isLast)
                Divider(height: 1, indent: 58, color: c.divider),
            ]);
          }).toList(),
        ),
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

    return async.when(
      loading: () => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 56,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: c.cardShadow,
        ),
        child: Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return _SettingsCard(
          rows: items.map((item) => _SettingsRow(
            icon:      item.materialIcon ?? Icons.link_rounded,
            assetIcon: item.assetIcon,
            iconBg:    item.displayColor,
            label:     item.title,
            onTap: () => launchUrl(item.uri, mode: LaunchMode.externalApplication),
          )).toList(),
        );
      },
    );
  }
}

// ─── Settings row ─────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData   icon;
  final String?    assetIcon;
  final Color      iconBg;
  final String     label;
  final Color?     labelColor;
  final bool       showChevron;
  final Widget?    trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    this.assetIcon,
    required this.iconBg,
    required this.label,
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
              horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: assetIcon != null ? const Color(0xFFFFF0E6) : iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: assetIcon != null
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(assetIcon!),
                    )
                  : Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: labelColor ?? c.textPrimary)),
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
  final _otpCtl    = OtpInputController();

  int    _step        = 1;
  String _lockedPhone  = '';
  int    _countdown   = 60;
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
      if (_countdown <= 0) { t.cancel(); return; }
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
        _step        = 2;
      });
      _startCountdown();
    } else {
      setState(() {});
    }
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;
    final ok = await ref.read(authProvider.notifier).sendChangePhoneOtp(_lockedPhone);
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
    final c    = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: c.divider,
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Đổi số điện thoại',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        StepProgressBar(currentStep: _step, totalSteps: 2),
        const SizedBox(height: 20),

        if (_step == 1) ...[
          const AppLabel('Số điện thoại mới'),
          const SizedBox(height: 8),
          AppField(
            controller: _phoneCtrl,
            hint: '09xxxxxxxx',
            keyboardType: TextInputType.phone,
          ),
          if (auth.error != null) ...[
            const SizedBox(height: 14),
            AppErrorBox(auth.error!),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'Gửi mã OTP',
            onPressed: _sendOtp,
            isLoading: auth.isLoading,
          ),
        ] else ...[
          Text.rich(TextSpan(
            style: TextStyle(fontSize: 14, color: c.textSecondary),
            children: [
              const TextSpan(text: 'Nhập mã 6 số đã gửi tới '),
              TextSpan(
                text: _lockedPhone,
                style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
            ],
          )),
          const SizedBox(height: 20),
          OtpInput(
            controller: _otpCtl,
            onChanged: (otp) {
              if (otp.length == 6) _verify();
            },
          ),
          if (auth.error != null) ...[
            const SizedBox(height: 14),
            AppErrorBox(auth.error!),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'Xác nhận',
            onPressed: _otpCtl.otp.length == 6 ? _verify : null,
            isLoading: auth.isLoading,
          ),
          const SizedBox(height: 16),
          Center(
            child: _countdown > 0
                ? Text(
                    'Gửi lại sau $_countdown giây',
                    style: TextStyle(fontSize: 14, color: c.textSecondary),
                  )
                : GestureDetector(
                    onTap: _resend,
                    child: const Text(
                      'Gửi lại mã OTP',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
          ),
        ],
      ]),
    );
  }
}
