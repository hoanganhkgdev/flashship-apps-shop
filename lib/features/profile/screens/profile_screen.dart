import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:heroicons/heroicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../legal/legal_page_screen.dart';
import '../../../core/widgets/grab_widgets.dart';
import '../../auth/models/shop_user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/cities_provider.dart';
import '../providers/support_config_provider.dart';
import '../../order/providers/order_provider.dart';

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

            // ── Hero header ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.primary, const Color(0xFFCC5A08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2.5),
                        image: user.avatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(user.avatarUrl!),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: user.avatarUrl == null
                          ? Center(
                              child: Text(user.initials,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800)))
                          : null,
                    ),
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: c.primary.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Icon(Icons.camera_alt_rounded,
                          size: 12, color: c.primary),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(user.name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.phone_rounded,
                      size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(user.phone,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white70)),
                  if (user.cityName?.isNotEmpty == true) ...[
                    const Text('  ·  ',
                        style: TextStyle(color: Colors.white38)),
                    const Icon(Icons.location_on_rounded,
                        size: 12, color: Colors.white70),
                    const SizedBox(width: 2),
                    Text(user.cityName!,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.danger),
      );
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
              const GrabLabel('Tên cửa hàng'),
              const SizedBox(height: 8),
              GrabField(controller: nameCtrl, hint: 'Tên cửa hàng'),
              const SizedBox(height: 14),
              const GrabLabel('Địa chỉ'),
              const SizedBox(height: 8),
              GrabField(
                  controller: addrCtrl, hint: 'Địa chỉ', maxLines: 2),
              const SizedBox(height: 14),
              Consumer(builder: (_, cRef, __) {
                final citiesAsync = cRef.watch(citiesProvider);
                return citiesAsync.maybeWhen(
                  data: (cities) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GrabLabel('Khu vực'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final result =
                              await showModalBottomSheet<CityItem>(
                            context: ctx,
                            builder: (sheetCtx) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 12),
                                const Padding(
                                  padding:
                                      EdgeInsets.fromLTRB(20, 0, 20, 12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('Chọn khu vực',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                                FontWeight.w800)),
                                  ),
                                ),
                                const Divider(height: 1),
                                ...cities.map((city) => ListTile(
                                  title: Text(city.name),
                                  trailing: city.id == cityId
                                      ? Icon(Icons.check_rounded,
                                          color: sheetCtx.colors.primary,
                                          size: 18)
                                      : null,
                                  onTap: () =>
                                      Navigator.pop(sheetCtx, city),
                                )),
                                const SizedBox(height: 8),
                              ],
                            ),
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
              GrabButton(
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err),
                          backgroundColor: AppColors.danger),
                    );
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
          const GrabLabel('Mật khẩu hiện tại'),
          const SizedBox(height: 8),
          GrabField(
              controller: currCtrl,
              hint: '••••••••',
              obscureText: true),
          const SizedBox(height: 14),
          const GrabLabel('Mật khẩu mới'),
          const SizedBox(height: 8),
          GrabField(
              controller: newCtrl,
              hint: '••••••••',
              obscureText: true),
          const SizedBox(height: 24),
          GrabButton(
            label: 'Xác nhận',
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await ref
                  .read(authProvider.notifier)
                  .changePassword(
                      current: currCtrl.text, next: newCtrl.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  err == null
                      ? const SnackBar(
                          content: Text('Đổi mật khẩu thành công'),
                          backgroundColor: AppColors.success)
                      : SnackBar(content: Text(err),
                          backgroundColor: AppColors.danger),
                );
              }
            },
          ),
        ]),
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.danger),
      );
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.white70)),
        ]),
      );
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1, height: 32,
        color: Colors.white.withValues(alpha: 0.25));
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
            heroIcon: _heroIconFor(item.icon),
            icon: Icons.open_in_new_rounded,
            iconBg: _colorFor(item.color),
            label: item.title,
            subtitle: item.subtitle,
            onTap: () => launchUrl(
              Uri.parse(item.value),
              mode: LaunchMode.externalApplication,
            ),
          )).toList(),
        );
      },
    );
  }

  static HeroIcons? _heroIconFor(String name) =>
      HeroIcons.values.where((e) => e.name == name).firstOrNull;

  static Color _colorFor(String? hex) {
    if (hex == null || hex.length < 7) return const Color(0xFF6B7280);
    return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
  }
}

// ─── Settings row ─────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData   icon;
  final HeroIcons? heroIcon;
  final Color      iconBg;
  final String     label;
  final String?    subtitle;
  final Color?     labelColor;
  final bool       showChevron;
  final Widget?    trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    this.heroIcon,
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
              horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: heroIcon != null
                  ? HeroIcon(heroIcon!, size: 16, color: Colors.white,
                      style: HeroIconStyle.outline)
                  : Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: labelColor ?? c.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 11, color: c.textTertiary)),
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
