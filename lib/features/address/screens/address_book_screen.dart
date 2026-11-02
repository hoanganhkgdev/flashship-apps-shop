import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/address_picker_screen.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/map_picker_screen.dart';
import '../models/address_entry.dart';
import '../providers/address_provider.dart';
import '../../../core/router/app_route.dart';

class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressProvider);
    final items = async.valueOrNull;
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      bottomNavigationBar: items?.isNotEmpty == true
          ? _AddAddressBar(onAdd: () => _showAddDialog(context, ref))
          : null,
      body: Column(children: [
        _AddressHeader(count: items?.length),
        Expanded(
          child: async.when(
            loading: () => Center(
              child:
                  CircularProgressIndicator(color: c.primary, strokeWidth: 2),
            ),
            error: (_, __) => _AddressError(
              onRetry: () => ref.read(addressProvider.notifier).fetch(),
            ),
            data: (items) => items.isEmpty
                ? _EmptyState(onAdd: () => _showAddDialog(context, ref))
                : RefreshIndicator(
                    color: c.primary,
                    onRefresh: () => ref.read(addressProvider.notifier).fetch(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _AddressCard(
                        entry: items[i],
                        onEdit: () => _showEditDialog(context, ref, items[i]),
                        onDelete: () => _confirmDelete(context, ref, items[i]),
                      ),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => const _AddAddressDialogScreen(),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, AddressEntry entry) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => _AddAddressDialogScreen(initial: entry),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AddressEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Xoá địa chỉ?',
            style: TextStyle(
                fontSize: AppFontSize.xl, fontWeight: FontWeight.w600)),
        content: Text('Xoá "${entry.displayName}" khỏi sổ địa chỉ?',
            style: const TextStyle(
                fontSize: AppFontSize.md, color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xoá',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final success = await ref.read(addressProvider.notifier).delete(entry.id);
      if (!success && context.mounted) {
        AppSnackbar.error(context, 'Không thể xoá địa chỉ. Vui lòng thử lại.');
      }
    }
  }
}

class _AddressHeader extends StatelessWidget {
  final int? count;
  const _AddressHeader({required this.count});

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
                    TextSpan(children: [
                      const TextSpan(text: 'Địa chỉ '),
                      TextSpan(
                        text: 'thường giao',
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
                    count == null
                        ? 'Quản lý các địa điểm giao quen thuộc'
                        : '$count địa chỉ · Chạm để chỉnh sửa',
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

class _AddAddressBar extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddAddressBar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: c.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 21),
            label: const Text(
              'Thêm địa chỉ mới',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressError extends StatelessWidget {
  final VoidCallback onRetry;
  const _AddressError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppEmptyState(
          icon: Icons.wifi_off_rounded,
          iconColor: c.textSecondary,
          title: 'Không tải được danh sách',
          subtitle: 'Kiểm tra kết nối rồi thử lại.',
          action: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ),
      ),
    );
  }
}

// ── Card ─────────────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final AddressEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AddressCard(
      {required this.entry, required this.onEdit, required this.onDelete});

  IconData get _icon => switch (entry.label?.trim().toLowerCase()) {
        'nhà' || 'nhà riêng' => Icons.home_rounded,
        'công ty' || 'cơ quan' => Icons.business_center_outlined,
        _ => Icons.location_on_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(_icon, size: 21, color: c.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Icons.person_outline_rounded,
                      size: 14, color: c.textTertiary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.phone_outlined, size: 14, color: c.textTertiary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      entry.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  entry.address,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            )),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Tùy chọn địa chỉ',
              icon: Icon(Icons.more_horiz_rounded,
                  size: 21, color: c.textSecondary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: c.surface,
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18, color: c.textPrimary),
                      const SizedBox(width: 10),
                      const Text('Chỉnh sửa'),
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppColors.danger),
                      SizedBox(width: 10),
                      Text('Xoá', style: TextStyle(color: AppColors.danger)),
                    ])),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppEmptyState(
            icon: Icons.location_on_outlined,
            title: 'Chưa có địa chỉ nào',
            titleColor: AppColors.textPrimary,
            subtitle: 'Lưu địa chỉ quen thuộc để tạo đơn nhanh hơn.',
            boxSize: 76,
            boxColor: AppColors.primary.withValues(alpha: 0.08),
            iconColor: AppColors.primary,
            iconSize: 34,
            action: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm địa chỉ đầu tiên'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      );
}

// ── Add/Edit dialog (screen-level, has access to ref) ────────────────────────

class _AddAddressDialogScreen extends ConsumerStatefulWidget {
  final AddressEntry? initial;
  const _AddAddressDialogScreen({this.initial});

  @override
  ConsumerState<_AddAddressDialogScreen> createState() =>
      _AddAddressDialogScreenState();
}

class _AddAddressDialogScreenState
    extends ConsumerState<_AddAddressDialogScreen> {
  final _label = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  String _pickedAddress = '';
  double? _pickedLat;
  double? _pickedLng;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _label.text = widget.initial!.label ?? '';
      _name.text = widget.initial!.name;
      _phone.text = widget.initial!.phone;
      _pickedAddress = widget.initial!.address;
      _pickedLat = widget.initial!.lat;
      _pickedLng = widget.initial!.lng;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.of(context, rootNavigator: true)
        .push<MapPickResult>(appRoute(
      AddressPickerScreen(
        title: 'Chọn địa chỉ giao',
        initialQuery: _pickedAddress.isNotEmpty ? _pickedAddress : null,
      ),
    ));
    if (result != null && mounted) {
      setState(() {
        _pickedAddress = result.address;
        _pickedLat = result.lat;
        _pickedLng = result.lng;
      });
    }
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _pickedAddress.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    bool ok;
    if (widget.initial != null) {
      ok = await ref.read(addressProvider.notifier).update(
            widget.initial!.id,
            label: _label.text.trim(),
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            address: _pickedAddress,
            lat: _pickedLat,
            lng: _pickedLng,
          );
    } else {
      final entry = await ref.read(addressProvider.notifier).add(
            label: _label.text.trim(),
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            address: _pickedAddress,
            lat: _pickedLat,
            lng: _pickedLng,
          );
      ok = entry != null;
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _loading = false;
        _error = 'Không thể lưu địa chỉ. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(widget.initial == null ? 'Thêm địa chỉ' : 'Chỉnh sửa',
            style: const TextStyle(
                fontSize: AppFontSize.xl, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(_label, 'Tên gợi nhớ (vd: Khách A)', required: false),
            const SizedBox(height: 10),
            _field(_name, 'Tên người nhận *'),
            const SizedBox(height: 10),
            _field(_phone, 'Số điện thoại *', keyboard: TextInputType.phone),
            const SizedBox(height: 10),
            _addressPickerRow(),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: AppFontSize.sm, color: AppColors.danger)),
            ],
          ]),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Lưu'),
          ),
        ],
      );

  Widget _addressPickerRow() => InkWell(
        onTap: _pickAddress,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.divider),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                _pickedAddress.isNotEmpty
                    ? _pickedAddress
                    : 'Chọn địa chỉ giao *',
                style: TextStyle(
                  fontSize: AppFontSize.md,
                  color: _pickedAddress.isNotEmpty
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.location_on_outlined,
                size: 18, color: AppColors.primary),
          ]),
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    bool required = true,
    TextInputType? keyboard,
    int maxLines = 1,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(fontSize: AppFontSize.md),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontSize: AppFontSize.base, color: AppColors.textSecondary),
          filled: true,
          fillColor: context.colors.surfaceAlt,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.colors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.colors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.colors.primary),
          ),
        ),
      );
}
