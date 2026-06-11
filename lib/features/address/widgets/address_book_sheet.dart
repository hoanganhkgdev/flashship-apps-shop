import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/address_picker_screen.dart';
import '../../../core/widgets/map_picker_screen.dart';
import '../models/address_entry.dart';
import '../providers/address_provider.dart';

class AddressBookSheet extends ConsumerStatefulWidget {
  const AddressBookSheet({super.key});

  @override
  ConsumerState<AddressBookSheet> createState() => _AddressBookSheetState();
}

class _AddressBookSheetState extends ConsumerState<AddressBookSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(addressProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      expand: false,
      builder: (context, scroll) => Column(children: [
        // ── Handle ──────────────────────────────────────────────────────
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Header ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Text('Sổ địa chỉ',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                final result = await _showAddDialog(context);
                if (result == true && context.mounted) {
                  ref.read(addressProvider.notifier).fetch();
                }
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ]),
        ),

        // ── Search ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, SĐT, địa chỉ...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, size: 20,
                  color: AppColors.textSecondary),
              suffixIcon: _query.isNotEmpty
                  ? GestureDetector(
                      onTap: () { _search.clear(); setState(() => _query = ''); },
                      child: const Icon(Icons.clear_rounded, size: 18,
                          color: AppColors.textSecondary))
                  : null,
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const Divider(height: 1, color: Color(0xFFF0F0F0)),

        // ── List ─────────────────────────────────────────────────────────
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:   (_, __) => Center(
              child: TextButton.icon(
                onPressed: () => ref.read(addressProvider.notifier).fetch(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ),
            data: (items) {
              final filtered = _query.isEmpty ? items : items.where((e) =>
                  e.displayName.toLowerCase().contains(_query) ||
                  e.phone.contains(_query) ||
                  e.address.toLowerCase().contains(_query)).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.contact_page_outlined, size: 48,
                        color: AppColors.textSecondary.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      items.isEmpty ? 'Chưa có địa chỉ nào' : 'Không tìm thấy',
                      style: const TextStyle(fontSize: 14,
                          color: AppColors.textSecondary),
                    ),
                  ]),
                );
              }

              return ListView.separated(
                controller:  scroll,
                padding:     const EdgeInsets.only(bottom: 24),
                itemCount:   filtered.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 68, color: Color(0xFFF5F5F5)),
                itemBuilder: (ctx, i) => _AddressRow(
                  entry: filtered[i],
                  onTap: () => Navigator.of(context).pop(filtered[i]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<bool?> _showAddDialog(BuildContext ctx) =>
      showDialog<bool>(context: ctx, builder: (_) => const _AddAddressDialog());
}

// ── Row ──────────────────────────────────────────────────────────────────────

class _AddressRow extends StatelessWidget {
  final AddressEntry entry;
  final VoidCallback onTap;
  const _AddressRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_outline_rounded,
              size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(entry.displayName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
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
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        )),
        const Icon(Icons.arrow_forward_ios_rounded, size: 14,
            color: AppColors.textSecondary),
      ]),
    ),
  );
}

// ── Add dialog ───────────────────────────────────────────────────────────────

class _AddAddressDialog extends ConsumerStatefulWidget {
  const _AddAddressDialog();

  @override
  ConsumerState<_AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends ConsumerState<_AddAddressDialog> {
  final _label = TextEditingController();
  final _name  = TextEditingController();
  final _phone = TextEditingController();

  String  _pickedAddress = '';
  double? _pickedLat;
  double? _pickedLng;
  bool _loading = false;

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
    final entry = await ref.read(addressProvider.notifier).add(
      label:   _label.text.trim(),
      name:    _name.text.trim(),
      phone:   _phone.text.trim(),
      address: _pickedAddress,
      lat:     _pickedLat,
      lng:     _pickedLng,
    );
    if (mounted) { Navigator.of(context).pop(entry != null); }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title:   const Text('Thêm địa chỉ',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
    content: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(_label, 'Tên gợi nhớ (vd: Khách quen A)', required: false),
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
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
  }) => TextField(
    controller:  ctrl,
    keyboardType: keyboard,
    maxLines:    maxLines,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(
      hintText:        hint,
      hintStyle:       const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      filled:          true,
      fillColor:       const Color(0xFFF5F5F5),
      contentPadding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border:          OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    ),
  );
}

// ── Public helper to show the sheet ─────────────────────────────────────────

Future<AddressEntry?> showAddressBookSheet(BuildContext context) =>
    showModalBottomSheet<AddressEntry>(
      context:       context,
      isScrollControlled: true,
      backgroundColor:    Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddressBookSheet(),
    );
