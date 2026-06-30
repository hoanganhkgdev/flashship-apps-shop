import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/address_search_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/address_picker_screen.dart';
import '../../../core/widgets/grab_widgets.dart';
import '../../../core/widgets/map_picker_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

// ─── Stop model (local) ───────────────────────────────────────────────────────

class _Stop {
  final TextEditingController addressCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController codCtrl;
  final TextEditingController noteCtrl;
  double? lat, lng;
  int?    fee;
  double? distanceKm;
  bool    estimating = false;

  _Stop()
      : addressCtrl = TextEditingController(),
        phoneCtrl   = TextEditingController(),
        nameCtrl    = TextEditingController(),
        codCtrl     = TextEditingController(),
        noteCtrl    = TextEditingController();

  void dispose() {
    addressCtrl.dispose();
    phoneCtrl.dispose();
    nameCtrl.dispose();
    codCtrl.dispose();
    noteCtrl.dispose();
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CreateBatchOrderScreen extends ConsumerStatefulWidget {
  const CreateBatchOrderScreen({super.key});

  @override
  ConsumerState<CreateBatchOrderScreen> createState() =>
      _CreateBatchOrderScreenState();
}

class _CreateBatchOrderScreenState
    extends ConsumerState<CreateBatchOrderScreen> {
  final _pickupAddrCtrl  = TextEditingController();
  final _pickupPhoneCtrl = TextEditingController();
  final _noteCtrl        = TextEditingController();

  double? _pickupLat, _pickupLng;
  String  _cargoType = 'food';
  bool    _submitting = false;

  final List<_Stop> _stops = [_Stop()];

  static const _cargos = [
    ('food',    'Đồ ăn',     Icons.lunch_dining_rounded,  Color(0xFFF59E0B)),
    ('flowers', 'Hoa',       Icons.local_florist_rounded, Color(0xFFEC4899)),
    ('parcel',  'Bưu kiện',  Icons.inventory_2_rounded,   Color(0xFF6B7280)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  void _prefill() {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    _pickupPhoneCtrl.text = user.phone;
    if (user.address?.isNotEmpty == true) {
      _pickupAddrCtrl.text = user.address!;
      _geocodePickup(user.address!);
    }
  }

  Future<void> _geocodePickup(String address) async {
    final result = await AddressSearchService.getDetail(
      AddressResult(
          display: address, mainText: address,
          secondaryText: '', placeId: ''),
    );
    if (!mounted || result == null) return;
    setState(() { _pickupLat = result.lat; _pickupLng = result.lng; });
    _estimateAll();
  }

  @override
  void dispose() {
    _pickupAddrCtrl.dispose();
    _pickupPhoneCtrl.dispose();
    _noteCtrl.dispose();
    for (final s in _stops) { s.dispose(); }
    super.dispose();
  }

  // ── Pickup address picker ────────────────────────────────────────────────

  Future<void> _pickPickupAddress() async {
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(
        builder: (_) => const AddressPickerScreen(title: 'Địa chỉ cửa hàng'),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _pickupAddrCtrl.text = result.address;
      _pickupLat = result.lat;
      _pickupLng = result.lng;
    });
    _estimateAll();
  }

  // ── Stop address picker ─────────────────────────────────────────────────

  Future<void> _pickStopAddress(int index) async {
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(title: 'Địa chỉ điểm ${index + 1}'),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _stops[index].addressCtrl.text = result.address;
      _stops[index].lat = result.lat;
      _stops[index].lng = result.lng;
    });
    _estimateStop(index);
  }

  // ── Estimate ────────────────────────────────────────────────────────────

  Future<void> _estimateAll() async {
    await Future.wait([
      for (var i = 0; i < _stops.length; i++) _estimateStop(i),
    ]);
  }

  Future<void> _estimateStop(int index) async {
    final stop = _stops[index];
    if (_pickupAddrCtrl.text.isEmpty || stop.addressCtrl.text.isEmpty) return;

    setState(() { stop.estimating = true; stop.fee = null; });

    try {
      final api    = ref.read(apiClientProvider);
      final params = <String, dynamic>{'cargo_type': _cargoType};

      if (_pickupLat != null && stop.lat != null) {
        params['pickup_lat']   = _pickupLat;
        params['pickup_lng']   = _pickupLng;
        params['delivery_lat'] = stop.lat;
        params['delivery_lng'] = stop.lng;
      } else {
        params['pickup_address']   = _pickupAddrCtrl.text;
        params['delivery_address'] = stop.addressCtrl.text;
      }

      final res  = await api.get('/shop/pricing/estimate', params: params);
      final data = (res.data['data'] ?? res.data) as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          stop.fee        = (data['fee'] as num).toInt();
          stop.distanceKm = (data['distance_km'] as num?)?.toDouble();
          stop.estimating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { stop.estimating = false; });
    }
  }

  // ── Manage stops ─────────────────────────────────────────────────────────

  void _addStop() {
    if (_stops.length >= 10) return;
    setState(() => _stops.add(_Stop()));
  }

  void _removeStop(int index) {
    if (_stops.length <= 1) return;
    _stops[index].dispose();
    setState(() => _stops.removeAt(index));
  }

  int get _totalFee => _stops.fold(0, (s, st) => s + (st.fee ?? 0));

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final pickupAddr = _pickupAddrCtrl.text.trim();
    if (pickupAddr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ cửa hàng')),
      );
      return;
    }
    if (_pickupLat == null || _pickupLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn địa chỉ cửa hàng từ gợi ý hoặc bản đồ')),
      );
      return;
    }
    for (var i = 0; i < _stops.length; i++) {
      final s = _stops[i];
      if (s.addressCtrl.text.trim().isEmpty || s.phoneCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Điểm ${i + 1}: cần nhập địa chỉ và SĐT')),
        );
        return;
      }
      if (s.lat == null || s.lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Điểm ${i + 1}: vui lòng chọn địa chỉ từ gợi ý hoặc bản đồ')),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final api   = ref.read(apiClientProvider);
      final stops = _stops.asMap().entries.map((e) {
        final s   = e.value;
        final cod = s.codCtrl.text.trim().replaceAll(',', '').replaceAll('.', '');
        return {
          'address':    s.addressCtrl.text.trim(),
          'phone':      s.phoneCtrl.text.trim(),
          'name':       s.nameCtrl.text.trim(),
          'note':       s.noteCtrl.text.trim(),
          if (s.lat != null) 'lat': s.lat,
          if (s.lng != null) 'lng': s.lng,
          if (cod.isNotEmpty) 'cod_amount': int.tryParse(cod),
        };
      }).toList();

      final res   = await api.post('/shop/orders/batch', data: {
        'pickup_address': pickupAddr,
        'pickup_phone':   _pickupPhoneCtrl.text.trim(),
        'order_note':     _noteCtrl.text.trim(),
        'cargo_type':     _cargoType,
        if (_pickupLat != null) 'pickup_lat': _pickupLat,
        if (_pickupLng != null) 'pickup_lng': _pickupLng,
        'stops': stops,
      });

      final order = OrderModel.fromJson(
          (res.data['data'] ?? res.data) as Map<String, dynamic>);
      ref.read(orderListProvider.notifier).addOrder(order);

      if (mounted) {
        context.pop();
        context.push('/order/${order.code}');
      }
    } on DioException catch (e) {
      final msg = (e.response?.data?['message'] as String?) ?? 'Có lỗi xảy ra';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đơn gộp nhiều điểm'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(0),
              children: [

                // ── Pickup ─────────────────────────────────────────────
                _sectionHeader('Lấy hàng tại cửa hàng'),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    GestureDetector(
                      onTap: _pickPickupAddress,
                      child: _addressField(
                        ctrl: _pickupAddrCtrl,
                        hint: 'Địa chỉ cửa hàng',
                        icon: Icons.storefront_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GrabField(
                      controller: _pickupPhoneCtrl,
                      hint: 'SĐT lấy hàng',
                      keyboardType: TextInputType.phone,
                    ),
                  ]),
                ),

                const SizedBox(height: 8),

                // ── Cargo type ─────────────────────────────────────────
                _sectionHeader('Loại hàng'),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: _cargos.map((c) {
                      final (key, label, icon, color) = c;
                      final selected = _cargoType == key;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: key != _cargos.last.$1 ? 8 : 0,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              setState(() { _cargoType = key; });
                              _estimateAll();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 6),
                              decoration: BoxDecoration(
                                color: selected
                                    ? color.withValues(alpha: 0.08)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(10),
                                border: selected
                                    ? Border.all(color: color, width: 1.5)
                                    : null,
                              ),
                              child: Column(children: [
                                Icon(icon, size: 20,
                                    color: selected
                                        ? color : AppColors.textSecondary),
                                const SizedBox(height: 4),
                                Text(label,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected
                                            ? color
                                            : AppColors.textSecondary)),
                              ]),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Stops ──────────────────────────────────────────────
                _sectionHeader('Các điểm giao hàng'),
                ..._stops.asMap().entries.map((e) {
                  final i    = e.key;
                  final stop = e.value;
                  return _StopCard(
                    index:     i,
                    stop:      stop,
                    canRemove: _stops.length > 1,
                    onPickAddress: () => _pickStopAddress(i),
                    onAddressChanged: (_) => _estimateStop(i),
                    onRemove: () => _removeStop(i),
                  );
                }),

                // Thêm điểm
                if (_stops.length < 10)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: OutlinedButton.icon(
                      onPressed: _addStop,
                      icon: const Icon(Icons.add_location_rounded, size: 18),
                      label: const Text('Thêm điểm giao'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Ghi chú chung
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: GrabField(
                    controller: _noteCtrl,
                    hint: 'Ghi chú cho tài xế...',
                    maxLines: 2,
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),

          // ── Bottom: tổng phí + book ────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Per-stop summary
              ..._stops.asMap().entries.map((e) {
                final i    = e.key;
                final stop = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stop.addressCtrl.text.isEmpty
                            ? 'Chưa có địa chỉ'
                            : stop.addressCtrl.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (stop.estimating)
                      const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.primary))
                    else if (stop.fee != null)
                      Text(Fmt.currency(stop.fee!),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppColors.primary))
                    else
                      const Text('—',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                  ]),
                );
              }),

              const Divider(height: 16, color: Color(0xFFF0F0F0)),

              // Total + button
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tổng phí',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  Text(
                    _stops.any((s) => s.fee != null)
                        ? Fmt.currency(_totalFee)
                        : '—',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: AppColors.primary),
                  ),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              'Đặt ${_stops.length} điểm giao',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
      );

  Widget _addressField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ctrl.text.isEmpty ? hint : ctrl.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              color: ctrl.text.isEmpty
                  ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ),
        const Icon(Icons.keyboard_arrow_right_rounded,
            size: 18, color: AppColors.textSecondary),
      ]),
    );
  }
}

// ─── Stop Card ────────────────────────────────────────────────────────────────

class _StopCard extends StatelessWidget {
  final int index;
  final _Stop stop;
  final bool canRemove;
  final VoidCallback onPickAddress;
  final ValueChanged<String> onAddressChanged;
  final VoidCallback onRemove;

  const _StopCard({
    required this.index,
    required this.stop,
    required this.canRemove,
    required this.onPickAddress,
    required this.onAddressChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              Text('Điểm ${index + 1}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              if (stop.distanceKm != null) ...[
                const SizedBox(width: 8),
                Text('${stop.distanceKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
              const Spacer(),
              if (stop.fee != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(Fmt.currency(stop.fee!),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                )
              else if (stop.estimating)
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
              if (canRemove) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      color: AppColors.danger, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                  onPressed: onRemove,
                ),
              ],
            ]),
          ),

          // Fields
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(children: [
              GestureDetector(
                onTap: onPickAddress,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.location_on_rounded,
                        size: 18, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stop.addressCtrl.text.isEmpty
                            ? 'Chọn địa chỉ giao hàng'
                            : stop.addressCtrl.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: stop.addressCtrl.text.isEmpty
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_right_rounded,
                        size: 18, color: AppColors.textSecondary),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: GrabField(
                  controller: stop.phoneCtrl,
                  hint: 'SĐT người nhận *',
                  keyboardType: TextInputType.phone,
                )),
                const SizedBox(width: 8),
                Expanded(child: GrabField(
                  controller: stop.nameCtrl,
                  hint: 'Tên người nhận',
                )),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: GrabField(
                  controller: stop.codCtrl,
                  hint: 'COD',
                  keyboardType: TextInputType.number,
                  prefix: const Text('đ ',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15)),
                )),
                const SizedBox(width: 8),
                Expanded(child: GrabField(
                  controller: stop.noteCtrl,
                  hint: 'Ghi chú',
                )),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
