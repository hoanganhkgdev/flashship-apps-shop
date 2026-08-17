import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/address_picker_screen.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/map_picker_screen.dart';
import '../models/address_entry.dart';
import '../providers/address_provider.dart';

class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Địa chỉ thường giao',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Không tải được danh sách',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => ref.read(addressProvider.notifier).fetch(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ]),
        ),
        data: (items) => items.isEmpty
            ? _EmptyState(onAdd: () => _showAddDialog(context, ref))
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => ref.read(addressProvider.notifier).fetch(),
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: 12, bottom: 32),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 68, color: Color(0xFFF5F5F5)),
                  itemBuilder: (ctx, i) => _AddressCard(
                    entry: items[i],
                    onEdit: () => _showEditDialog(context, ref, items[i]),
                    onDelete: () => _confirmDelete(context, ref, items[i]),
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm địa chỉ',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => const _AddAddressDialogScreen(),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref, AddressEntry entry) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => _AddAddressDialogScreen(initial: entry),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AddressEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xoá địa chỉ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text('Xoá "${entry.displayName}" khỏi sổ địa chỉ?',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xoá', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(addressProvider.notifier).delete(entry.id);
    }
  }
}

// ── Card ─────────────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final AddressEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AddressCard({required this.entry, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_outline_rounded,
              size: 22, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(
                child: Text(entry.displayName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (entry.label != null && entry.label!.isNotEmpty &&
                  entry.label != entry.name) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(entry.name,
                      style: const TextStyle(fontSize: 10,
                          color: AppColors.primary, fontWeight: FontWeight.w500)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(entry.phone,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(entry.address,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        )),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              size: 20, color: AppColors.textSecondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                  SizedBox(width: 10),
                  Text('Chỉnh sửa', style: TextStyle(fontSize: 14)),
                ])),
            PopupMenuItem(value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                  SizedBox(width: 10),
                  Text('Xoá', style: TextStyle(fontSize: 14, color: AppColors.danger)),
                ])),
          ],
        ),
      ]),
    ),
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: AppEmptyState(
      icon: Icons.contact_page_outlined,
      title: 'Chưa có địa chỉ nào',
      titleColor: AppColors.textPrimary,
      subtitle: 'Lưu địa chỉ để tạo đơn nhanh hơn',
      boxSize: 80,
      boxShape: BoxShape.circle,
      boxColor: AppColors.primary.withValues(alpha: 0.08),
      iconColor: AppColors.primary,
      iconSize: 40,
      action: ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Thêm địa chỉ đầu tiên'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  final _name  = TextEditingController();
  final _phone = TextEditingController();

  String  _pickedAddress = '';
  double? _pickedLat;
  double? _pickedLng;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _label.text    = widget.initial!.label ?? '';
      _name.text     = widget.initial!.name;
      _phone.text    = widget.initial!.phone;
      _pickedAddress = widget.initial!.address;
      _pickedLat     = widget.initial!.lat;
      _pickedLng     = widget.initial!.lng;
    }
  }

  @override
  void dispose() {
    _label.dispose(); _name.dispose(); _phone.dispose();
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.of(context, rootNavigator: true)
        .push<MapPickResult>(MaterialPageRoute(
      builder: (_) => AddressPickerScreen(
        title: 'Chọn địa chỉ giao',
        initialQuery: _pickedAddress.isNotEmpty ? _pickedAddress : null,
      ),
    ));
    if (result != null && mounted) {
      setState(() {
        _pickedAddress = result.address;
        _pickedLat     = result.lat;
        _pickedLng     = result.lng;
      });
    }
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty ||
        _pickedAddress.isEmpty) { return; }
    setState(() => _loading = true);
    bool ok;
    if (widget.initial != null) {
      ok = await ref.read(addressProvider.notifier).update(
        widget.initial!.id,
        label:   _label.text.trim(),
        name:    _name.text.trim(),
        phone:   _phone.text.trim(),
        address: _pickedAddress,
        lat:     _pickedLat,
        lng:     _pickedLng,
      );
    } else {
      final entry = await ref.read(addressProvider.notifier).add(
        label:   _label.text.trim(),
        name:    _name.text.trim(),
        phone:   _phone.text.trim(),
        address: _pickedAddress,
        lat:     _pickedLat,
        lng:     _pickedLng,
      );
      ok = entry != null;
    }
    if (mounted) { Navigator.of(context).pop(ok); }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Text(widget.initial == null ? 'Thêm địa chỉ' : 'Chỉnh sửa',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
    content: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(_label, 'Tên gợi nhớ (vd: Khách A)', required: false),
        const SizedBox(height: 10),
        _field(_name,  'Tên người nhận *'),
        const SizedBox(height: 10),
        _field(_phone, 'Số điện thoại *', keyboard: TextInputType.phone),
        const SizedBox(height: 10),
        _addressPickerRow(),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _loading
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Text('Lưu'),
      ),
    ],
  );

  Widget _addressPickerRow() => InkWell(
    onTap: _pickAddress,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            _pickedAddress.isNotEmpty ? _pickedAddress : 'Chọn địa chỉ giao *',
            style: TextStyle(
              fontSize: 14,
              color: _pickedAddress.isNotEmpty
                  ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
      ]),
    ),
  );

  Widget _field(TextEditingController ctrl, String hint, {
    bool required = true,
    TextInputType? keyboard,
    int maxLines = 1,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
        ),
      );
}
