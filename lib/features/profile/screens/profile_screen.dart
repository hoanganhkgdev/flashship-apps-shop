import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../legal/legal_page_screen.dart';
import '../../../core/widgets/grab_widgets.dart';
import '../../auth/models/shop_user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/cities_provider.dart';
import '../../order/providers/order_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user   = ref.watch(authProvider).user;
    final orders = ref.watch(orderListProvider).orders;
    if (user == null) return const SizedBox.shrink();

    final completed = orders.where((o) => o.isCompleted).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS system grouped background
      body: CustomScrollView(
        slivers: [
          // ── Large title header (iOS pattern) ──────────────────────────
          SliverAppBar(
            backgroundColor: const Color(0xFFF2F2F7),
            elevation: 0,
            pinned: true,
            title: const Text('Cửa hàng',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: Color(0xFFD1D1D6)),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // ── Avatar + info card ─────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Row(children: [
                    // Avatar
                    GestureDetector(
                      onTap: () => _pickAvatar(context, ref),
                      child: Stack(children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          backgroundImage: user.avatarUrl != null
                              ? NetworkImage(user.avatarUrl!) as ImageProvider
                              : null,
                          child: user.avatarUrl == null
                              ? Text(user.initials,
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800))
                              : null,
                        ),
                        Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 11, color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 16),

                    // Info
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(user.phone,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary)),
                        if (user.cityName?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(user.cityName!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ],
                      ],
                    )),

                    // Completed count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(children: [
                        Text('$completed',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary)),
                        const Text('Đơn',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary)),
                      ]),
                    ),
                  ]),
                ),

                // Địa chỉ (nếu có)
                if (user.address?.isNotEmpty == true) ...[
                  const _SectionDivider(),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(user.address!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 28),

                // ── Section: Cửa hàng ──────────────────────────────────
                _SectionHeader('CỬA HÀNG'),
                _SettingsGroup(rows: [
                  _SettingsRow(
                    icon: Icons.edit_outlined,
                    iconBg: AppColors.primary,
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

                const SizedBox(height: 28),

                // ── Section: Hỗ trợ ───────────────────────────────────
                _SectionHeader('HỖ TRỢ'),
                _SettingsGroup(rows: [
                  _SettingsRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconBg: const Color(0xFF34C759),
                    label: 'Chat Zalo hỗ trợ',
                    onTap: () => launchUrl(
                        Uri.parse('https://zalo.me/flashship'),
                        mode: LaunchMode.externalApplication),
                  ),
                ]),

                const SizedBox(height: 28),

                const SizedBox(height: 28),

                // ── Section: Pháp lý ──────────────────────────────────
                _SectionHeader('PHÁP LÝ'),
                _SettingsGroup(rows: [
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

                const SizedBox(height: 28),

                // ── Section: Tài khoản ────────────────────────────────
                _SectionHeader('TÀI KHOẢN'),
                _SettingsGroup(rows: [
                  _SettingsRow(
                    icon: Icons.logout_rounded,
                    iconBg: AppColors.danger,
                    label: 'Đăng xuất',
                    labelColor: AppColors.danger,
                    showChevron: false,
                    onTap: () => _logout(context, ref),
                  ),
                  _SettingsRow(
                    icon: Icons.delete_forever_outlined,
                    iconBg: AppColors.danger,
                    label: 'Xóa tài khoản',
                    labelColor: AppColors.danger,
                    showChevron: false,
                    onTap: () => _deleteAccount(context, ref),
                  ),
                ]),

                const SizedBox(height: 40),

                // Version / info
                Text('FlashShip Shop',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.6))),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    final err = await ref.read(authProvider.notifier).uploadAvatar(img.path);
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
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
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 16),
            const Text('Chỉnh sửa thông tin',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            const GrabLabel('Tên cửa hàng'),
            const SizedBox(height: 8),
            GrabField(controller: nameCtrl, hint: 'Tên cửa hàng'),
            const SizedBox(height: 14),
            const GrabLabel('Địa chỉ'),
            const SizedBox(height: 8),
            GrabField(controller: addrCtrl, hint: 'Địa chỉ', maxLines: 2),
            const SizedBox(height: 14),
            // City
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
                        final result = await showModalBottomSheet<CityItem>(
                          context: ctx,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12))),
                          builder: (c) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 12),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                                child: Align(alignment: Alignment.centerLeft,
                                    child: Text('Chọn khu vực',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800))),
                              ),
                              const Divider(height: 1),
                              ...cities.map((city) => ListTile(
                                title: Text(city.name),
                                trailing: city.id == cityId
                                    ? const Icon(Icons.check_rounded,
                                        color: AppColors.primary, size: 18)
                                    : null,
                                onTap: () => Navigator.pop(c, city),
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
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Expanded(child: Text(
                              cityName ?? 'Chọn khu vực...',
                              style: TextStyle(fontSize: 15,
                                  color: cityName != null
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary))),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 20, color: AppColors.textSecondary),
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
                final err = await ref.read(authProvider.notifier).updateProfile(
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
        ),
      ),
    );
  }

  void _showPasswordSheet(BuildContext context, WidgetRef ref) {
    final currCtrl = TextEditingController();
    final newCtrl  = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 12,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Đổi mật khẩu',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          const GrabLabel('Mật khẩu hiện tại'),
          const SizedBox(height: 8),
          GrabField(controller: currCtrl, hint: '••••••••', obscureText: true),
          const SizedBox(height: 14),
          const GrabLabel('Mật khẩu mới'),
          const SizedBox(height: 8),
          GrabField(controller: newCtrl, hint: '••••••••', obscureText: true),
          const SizedBox(height: 24),
          GrabButton(
            label: 'Xác nhận',
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await ref.read(authProvider.notifier).changePassword(
                  current: currCtrl.text, next: newCtrl.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  err == null
                      ? const SnackBar(content: Text('Đổi mật khẩu thành công'),
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
    // Bước 1: cảnh báo
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Xóa tài khoản?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Tất cả dữ liệu cửa hàng, lịch sử đơn hàng sẽ bị xóa vĩnh viễn. '
          'Hành động này không thể hoàn tác.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Tiếp tục',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm1 != true || !context.mounted) return;

    // Bước 2: xác nhận lần 2
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Xác nhận xóa tài khoản',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
        content: const Text(
          'Nhấn "Xóa vĩnh viễn" để xác nhận. '
          'Đơn hàng đang chờ sẽ bị huỷ tự động.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Đăng xuất?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Bạn muốn đăng xuất khỏi tài khoản này?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Đăng xuất',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authProvider.notifier).logout();
  }
}

// ─── iOS-style grouped section header ─────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
                letterSpacing: 0.5)),
      );
}

// ─── Section divider ──────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 56, color: Color(0xFFF0F0F0));
}

// ─── Grouped settings card ────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final List<_SettingsRow> rows;
  const _SettingsGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Column(children: [
            e.value,
            if (!isLast)
              const Divider(height: 1, indent: 56, color: Color(0xFFF0F0F0)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ─── Single settings row (iOS standard cell) ──────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color    iconBg;
  final String   label;
  final Color?   labelColor;
  final bool     showChevron;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.label,
    this.labelColor,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            // iOS app icon style
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: labelColor ?? AppColors.textPrimary)),
            ),
            if (showChevron)
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: Color(0xFFC7C7CC)),
          ]),
        ),
      ),
    );
  }
}
