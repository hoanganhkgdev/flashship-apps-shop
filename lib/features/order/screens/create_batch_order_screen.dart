import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/address_search_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/address_picker_screen.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/map_picker_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../voucher/widgets/voucher_sheet.dart';
import '../models/cargo_type.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

// ─── Stop model (local) ───────────────────────────────────────────────────────

class _Stop {
  // Id ổn định — dùng làm Key cho ReorderableListView và để theo dõi thẻ
  // đang mở rộng (_expandedStopId), KHÔNG dùng index vì index đổi khi kéo-thả.
  final String id;
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
      : id          = UniqueKey().toString(),
        addressCtrl = TextEditingController(),
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

  final _weightCtrl = TextEditingController();

  String? _voucherCode;
  String? _voucherLabel;
  int?    _voucherDiscount;

  final List<_Stop> _stops = [_Stop()];
  // Id của _Stop đang mở rộng để nhập liệu — null nghĩa là tất cả đang thu gọn.
  String? _expandedStopId;

  // Cân nặng chỉ áp dụng khi loại hàng hiện tại có hasWeight (bưu kiện) — nếu
  // người dùng từng gõ cân nặng rồi đổi sang loại khác, không để giá trị cũ
  // âm thầm lọt vào estimate/submit của loại hàng không liên quan.
  double? get _cargoWeight {
    if (!cargoTypeOf(_cargoType).hasWeight) return null;
    final t = _weightCtrl.text.trim();
    return t.isEmpty ? null : double.tryParse(t.replaceAll(',', '.'));
  }

  @override
  void initState() {
    super.initState();
    _expandedStopId = _stops.first.id;
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
    _weightCtrl.dispose();
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
    _estimateAll();
  }

  // ── Estimate ────────────────────────────────────────────────────────────

  // Gọi 1 lần /shop/pricing/estimate-batch cho toàn bộ điểm giao thay vì lặp
  // /shop/pricing/estimate cho từng điểm — khớp với cách OrderController::
  // storeBatch tính phí (1 lượt tính cho cả đơn), tránh N request rời rạc.
  Future<void> _estimateAll() async {
    final pickupAddr = _pickupAddrCtrl.text.trim();
    if (pickupAddr.isEmpty) return;
    final validStops = _stops.where((s) => s.addressCtrl.text.trim().isNotEmpty).toList();
    if (validStops.isEmpty) return;

    // Lưu tổng phí cũ TRƯỚC khi set fee = null cho trạng thái loading — dùng
    // so sánh xem phí có thực sự đổi để quyết định có cần gỡ voucher không.
    final oldTotalFee = _totalFee;

    setState(() {
      for (final s in validStops) { s.estimating = true; s.fee = null; }
    });

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/shop/pricing/estimate-batch', data: {
        'cargo_type': _cargoType,
        if (_pickupLat != null) 'pickup_lat': _pickupLat,
        if (_pickupLng != null) 'pickup_lng': _pickupLng,
        'pickup_address': pickupAddr,
        'stops': validStops.map((s) => {
          'address': s.addressCtrl.text.trim(),
          if (s.lat != null) 'lat': s.lat,
          if (s.lng != null) 'lng': s.lng,
          if (_cargoWeight != null) 'cargo_weight': _cargoWeight,
        }).toList(),
      });
      final data    = unwrap(res) as Map<String, dynamic>;
      final results = (data['stops'] as List).cast<Map<String, dynamic>>();

      if (mounted) {
        final newTotalFee = (data['total_fee'] as num).toInt();
        final shouldRemoveVoucher = _voucherCode != null && newTotalFee != oldTotalFee;

        setState(() {
          for (var i = 0; i < validStops.length && i < results.length; i++) {
            validStops[i].fee        = (results[i]['fee'] as num).toInt();
            validStops[i].distanceKm = (results[i]['distance_km'] as num?)?.toDouble();
            validStops[i].estimating = false;
          }
          if (shouldRemoveVoucher) _removeVoucher();
        });

        if (shouldRemoveVoucher) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Phí đơn đã thay đổi, mã giảm giá đã được gỡ — vui lòng áp lại nếu cần.'),
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          for (final s in validStops) { s.estimating = false; }
        });
      }
    }
  }

  // ── Manage stops ─────────────────────────────────────────────────────────

  void _addStop() {
    if (_stops.length >= 10) return;
    final stop = _Stop();
    setState(() {
      _stops.add(stop);
      _expandedStopId = stop.id; // mở luôn điểm vừa thêm để nhập
    });
  }

  void _removeStop(int index) {
    if (_stops.length <= 1) return;
    final removed = _stops[index];
    removed.dispose();
    setState(() {
      _stops.removeAt(index);
      if (_expandedStopId == removed.id) _expandedStopId = null;
    });
  }

  // onReorderItem (thay onReorder đã deprecated) tự điều chỉnh newIndex sau
  // khi phần tử ở oldIndex bị lấy ra, nên không cần trừ 1 thủ công nữa.
  void _onReorderStops(int oldIndex, int newIndex) {
    setState(() {
      final stop = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, stop);
    });
  }

  int get _totalFee => _stops.fold(0, (s, st) => s + (st.fee ?? 0));

  int get _finalFee =>
      (_totalFee - (_voucherDiscount ?? 0)).clamp(0, _totalFee);

  // ── Exit confirmation ────────────────────────────────────────────────────

  bool get _hasUnsavedData =>
      _stops.length > 1 ||
      _stops.any((s) =>
          s.addressCtrl.text.trim().isNotEmpty ||
          s.phoneCtrl.text.trim().isNotEmpty ||
          s.nameCtrl.text.trim().isNotEmpty ||
          s.codCtrl.text.trim().isNotEmpty ||
          s.noteCtrl.text.trim().isNotEmpty);

  // context.pop() ở nút back gọi Navigator.pop() trực tiếp, không đi qua
  // maybePop() nên PopScope không tự chặn được — dùng chung hàm này cho cả
  // PopScope lẫn nút back thủ công trong build().
  Future<void> _handleBackPress() async {
    if (!_hasUnsavedData) {
      if (mounted) context.pop();
      return;
    }
    final confirmed = await _confirmExitDialog();
    if (confirmed && mounted) context.pop();
  }

  Future<bool> _confirmExitDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Huỷ đặt đơn gộp?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
            'Toàn bộ ${_stops.length} điểm giao đã nhập sẽ không được lưu.',
            style: const TextStyle(fontSize: 14, height: 1.5)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Voucher ─────────────────────────────────────────────────────────────

  Future<void> _openVoucherSheet() async {
    if (_totalFee == 0) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => VoucherSheet(fee: _totalFee),
    );
    if (result != null && mounted) {
      setState(() {
        _voucherCode     = result['code'] as String;
        _voucherLabel    = result['discount_label'] as String?;
        _voucherDiscount = (result['discount'] as num).toInt();
      });
    }
  }

  void _removeVoucher() {
    _voucherCode     = null;
    _voucherLabel    = null;
    _voucherDiscount = null;
  }

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
        if (_pickupLat != null)   'pickup_lat':   _pickupLat,
        if (_pickupLng != null)   'pickup_lng':   _pickupLng,
        if (_cargoWeight != null) 'cargo_weight': _cargoWeight,
        if (_voucherCode != null) 'voucher_code': _voucherCode,
        'stops': stops,
      });

      final order = OrderModel.fromJson(
          unwrap(res) as Map<String, dynamic>);
      ref.read(orderListProvider.notifier).addOrder(order);

      if (mounted) {
        context.pushReplacement('/order/${order.code}');
      }
    } on DioException catch (e) {
      final msg = parseApiError(e, fallback: 'Có lỗi xảy ra');
      if (mounted) AppSnackbar.error(context, msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedData,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đơn gộp nhiều điểm'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _handleBackPress,
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
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
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
                    AppField(
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
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: cargoTypes.map((c) {
                      final key = c.key, label = c.label;
                      final icon = c.icon, color = c.color;
                      final selected = _cargoType == key;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: key != cargoTypes.last.key ? 8 : 0,
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
                              decoration: cargoChipDecoration(selected, color),
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

                // Cân nặng chung — chỉ hiện khi loại hàng có hasWeight (bưu kiện)
                if (cargoTypeOf(_cargoType).hasWeight) ...[
                  const SizedBox(height: 1),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: AppField(
                      controller: _weightCtrl,
                      hint: 'Khối lượng cả đơn (ước lượng)',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: const Icon(Icons.scale_outlined,
                          size: 18, color: AppColors.textSecondary),
                      suffix: const Text('kg',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _estimateAll(),
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // ── Stops ──────────────────────────────────────────────
                _sectionHeader('Các điểm giao hàng'),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: _stops.length,
                  onReorderItem: _onReorderStops,
                  itemBuilder: (context, i) {
                    final stop = _stops[i];
                    return _StopCard(
                      key: ValueKey(stop.id),
                      index:     i,
                      stop:      stop,
                      canRemove: _stops.length > 1,
                      isExpanded: stop.id == _expandedStopId,
                      onToggle: () => setState(() {
                        _expandedStopId =
                            _expandedStopId == stop.id ? null : stop.id;
                      }),
                      onPickAddress: () => _pickStopAddress(i),
                      onAddressChanged: (_) => _estimateAll(),
                      onRemove: () => _removeStop(i),
                    );
                  },
                ),

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
                        // Giữ bo góc vừa phải (không bo tròn hoàn toàn như các
                        // nút khác) — dạng viên thuốc dễ mất cảm giác "thêm mới"
                        // cho một nút dài toàn chiều ngang.
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.xl)),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Ghi chú chung
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: AppField(
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
              // ── Voucher ─────────────────────────────────────────────
              if (_voucherCode != null)
                GestureDetector(
                  onTap: _totalFee == 0 ? null : _openVoucherSheet,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.local_offer_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_voucherCode${_voucherLabel != null ? ' • $_voucherLabel' : ''}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(_removeVoucher),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textSecondary),
                      ),
                    ]),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: _totalFee == 0 ? null : _openVoucherSheet,
                    behavior: HitTestBehavior.opaque,
                    child: const Row(children: [
                      Icon(Icons.local_offer_outlined,
                          size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('Bạn có mã giảm giá?',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ]),
                  ),
                ),

              // Total + button
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tổng phí',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  if (_voucherDiscount != null && _voucherDiscount! > 0 && _totalFee > 0)
                    Text(
                      Fmt.currency(_totalFee),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.lineThrough),
                    ),
                  Text(
                    _stops.any((s) => s.fee != null)
                        ? Fmt.currency(_finalFee)
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
                            borderRadius: BorderRadius.circular(AppRadius.pill)),
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
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onPickAddress;
  final ValueChanged<String> onAddressChanged;
  final VoidCallback onRemove;

  const _StopCard({
    super.key,
    required this.index,
    required this.stop,
    required this.canRemove,
    required this.isExpanded,
    required this.onToggle,
    required this.onPickAddress,
    required this.onAddressChanged,
    required this.onRemove,
  });

  Widget _dragHandle() => ReorderableDragStartListener(
        index: index,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Icon(Icons.drag_handle_rounded,
              size: 18, color: AppColors.textSecondary),
        ),
      );

  Widget _indexBadge() => Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text('${index + 1}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
      );

  @override
  Widget build(BuildContext context) =>
      isExpanded ? _buildExpanded() : _buildCollapsed();

  // ── Thu gọn: 1 hàng ~50px ───────────────────────────────────────────────
  Widget _buildCollapsed() {
    final hasAddress = stop.addressCtrl.text.isNotEmpty;
    final subParts = [
      if (stop.phoneCtrl.text.isNotEmpty) stop.phoneCtrl.text,
      if (stop.codCtrl.text.isNotEmpty) 'COD ${stop.codCtrl.text}',
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(children: [
            _dragHandle(),
            const SizedBox(width: 6),
            _indexBadge(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasAddress ? stop.addressCtrl.text : 'Chưa nhập địa chỉ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          hasAddress ? FontStyle.normal : FontStyle.italic,
                      color: hasAddress
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (subParts.isNotEmpty)
                    Text(subParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (stop.estimating)
              const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.primary))
            else
              Text(
                stop.fee != null ? Fmt.currency(stop.fee!) : '—',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: stop.fee != null
                        ? AppColors.primary
                        : AppColors.textSecondary),
              ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: AppColors.textSecondary),
          ]),
        ),
      ),
    );
  }

  // ── Mở rộng: header + đủ 5 field, viền primary nổi bật ──────────────────
  Widget _buildExpanded() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
              child: Row(children: [
                _dragHandle(),
                const SizedBox(width: 6),
                _indexBadge(),
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
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        color: AppColors.danger, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    onPressed: onRemove,
                  ),
                ],
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_up_rounded,
                    size: 20, color: AppColors.textSecondary),
              ]),
            ),
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
                Expanded(child: AppField(
                  controller: stop.phoneCtrl,
                  hint: 'SĐT người nhận *',
                  keyboardType: TextInputType.phone,
                )),
                const SizedBox(width: 8),
                Expanded(child: AppField(
                  controller: stop.nameCtrl,
                  hint: 'Tên người nhận',
                )),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: AppField(
                  controller: stop.codCtrl,
                  hint: 'COD',
                  keyboardType: TextInputType.number,
                  prefix: const Text('đ ',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15)),
                )),
                const SizedBox(width: 8),
                Expanded(child: AppField(
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
