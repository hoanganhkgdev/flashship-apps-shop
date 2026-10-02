import '../../../core/widgets/app_decor_widgets.dart';
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
import '../data/order_repository.dart';
import '../providers/order_provider.dart';
import '../utils/create_batch_order_validator.dart';

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
  int? fee;
  double? distanceKm;
  bool estimating = false;

  _Stop()
      : id = UniqueKey().toString(),
        addressCtrl = TextEditingController(),
        phoneCtrl = TextEditingController(),
        nameCtrl = TextEditingController(),
        codCtrl = TextEditingController(),
        noteCtrl = TextEditingController();

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
  final Map<String, dynamic>? reorderFrom;
  const CreateBatchOrderScreen({super.key, this.reorderFrom});

  @override
  ConsumerState<CreateBatchOrderScreen> createState() =>
      _CreateBatchOrderScreenState();
}

class _CreateBatchOrderScreenState
    extends ConsumerState<CreateBatchOrderScreen> {
  final _pickupAddrCtrl = TextEditingController();
  final _pickupPhoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  double? _pickupLat, _pickupLng;
  String _cargoType = 'food';
  bool _submitting = false;

  final _weightCtrl = TextEditingController();

  String? _voucherCode;
  String? _voucherLabel;
  int? _voucherDiscount;

  final List<_Stop> _stops = [_Stop()];
  // Id của _Stop đang mở rộng để nhập liệu — null nghĩa là tất cả đang thu gọn.
  String? _expandedStopId;

  // Cân nặng chỉ áp dụng khi loại hàng hiện tại có hasWeight (kiện hàng) — nếu
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.reorderFrom != null) {
        _prefillFromReorder(widget.reorderFrom!);
      } else {
        _prefill();
      }
    });
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

  // Điền lại toàn bộ màn từ 1 đơn gộp cũ (nút "Đặt lại đơn tương tự" ở màn
  // chi tiết đơn) — xem _reorderBatchExtra() trong order_detail_screen.dart.
  void _prefillFromReorder(Map<String, dynamic> r) {
    final user = ref.read(authProvider).user;

    // Dựng danh sách _Stop mới TRƯỚC (ngoài setState) — mỗi _Stop tự sinh id
    // mới qua constructor hiện có, KHÔNG copy id cũ từ đơn gốc để tránh trùng
    // key với ReorderableListView.
    final stopsData = (r['stops'] as List?) ?? [];
    final newStops = <_Stop>[];
    for (final raw in stopsData) {
      final data = raw as Map<String, dynamic>;
      final stop = _Stop();
      stop.addressCtrl.text = data['address'] as String? ?? '';
      stop.phoneCtrl.text = data['phone'] as String? ?? '';
      stop.nameCtrl.text = data['name'] as String? ?? '';
      final cod = data['codAmount'] as num?;
      if (cod != null) stop.codCtrl.text = cod.toInt().toString();
      stop.noteCtrl.text = data['note'] as String? ?? '';
      stop.lat = (data['lat'] as num?)?.toDouble();
      stop.lng = (data['lng'] as num?)?.toDouble();
      newStops.add(stop);
    }

    if (!mounted) return;
    setState(() {
      // SĐT lấy hàng không có trong dữ liệu reorder (batch luôn lấy tại
      // chính shop) — điền lại từ hồ sơ giống _prefill().
      if (user != null) _pickupPhoneCtrl.text = user.phone;
      _pickupAddrCtrl.text = r['pickupAddr'] as String? ?? '';
      _pickupLat = (r['pickupLat'] as num?)?.toDouble();
      _pickupLng = (r['pickupLng'] as num?)?.toDouble();
      _cargoType = r['cargoType'] as String? ?? 'food';
      if (newStops.isNotEmpty) {
        for (final s in _stops) {
          s.dispose();
        }
        _stops
          ..clear()
          ..addAll(newStops);
        _expandedStopId = null;
      }
    });

    _estimateAll();
  }

  Future<void> _geocodePickup(String address) async {
    final result = await AddressSearchService.getDetail(
      AddressResult(
          display: address, mainText: address, secondaryText: '', placeId: ''),
    );
    if (!mounted || result == null) return;
    setState(() {
      _pickupLat = result.lat;
      _pickupLng = result.lng;
    });
    _estimateAll();
  }

  @override
  void dispose() {
    _pickupAddrCtrl.dispose();
    _pickupPhoneCtrl.dispose();
    _noteCtrl.dispose();
    _weightCtrl.dispose();
    for (final s in _stops) {
      s.dispose();
    }
    super.dispose();
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
    final validStops =
        _stops.where((s) => s.addressCtrl.text.trim().isNotEmpty).toList();
    if (validStops.isEmpty) return;

    // Lưu tổng phí cũ TRƯỚC khi set fee = null cho trạng thái loading — dùng
    // so sánh xem phí có thực sự đổi để quyết định có cần gỡ voucher không.
    final oldTotalFee = _totalFee;

    setState(() {
      for (final s in validStops) {
        s.estimating = true;
        s.fee = null;
      }
    });

    try {
      final estimate = await ref.read(orderRepositoryProvider).estimateBatch(
            cargoType: _cargoType,
            pickupAddress: pickupAddr,
            pickupLat: _pickupLat,
            pickupLng: _pickupLng,
            stops: validStops
                .map((stop) => BatchPricingStop(
                      address: stop.addressCtrl.text.trim(),
                      lat: stop.lat,
                      lng: stop.lng,
                      cargoWeight: _cargoWeight,
                    ))
                .toList(growable: false),
          );

      if (mounted) {
        final newTotalFee = estimate.totalFee;
        final shouldRemoveVoucher =
            _voucherCode != null && newTotalFee != oldTotalFee;

        setState(() {
          for (var i = 0;
              i < validStops.length && i < estimate.stops.length;
              i++) {
            validStops[i].fee = estimate.stops[i].fee;
            validStops[i].distanceKm = estimate.stops[i].distanceKm;
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
          for (final s in validStops) {
            s.estimating = false;
          }
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Huỷ đặt đơn gộp?',
            style: TextStyle(
                fontSize: AppFontSize.xl, fontWeight: FontWeight.w700)),
        content: Text(
            'Toàn bộ ${_stops.length} điểm giao đã nhập sẽ không được lưu.',
            style: const TextStyle(fontSize: AppFontSize.md, height: 1.5)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
      useSafeArea: true,
      builder: (_) => VoucherSheet(fee: _totalFee),
    );
    if (result != null && mounted) {
      setState(() {
        _voucherCode = result['code'] as String;
        _voucherLabel = result['discount_label'] as String?;
        _voucherDiscount = (result['discount'] as num).toInt();
      });
    }
  }

  void _removeVoucher() {
    _voucherCode = null;
    _voucherLabel = null;
    _voucherDiscount = null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final pickupAddr = _pickupAddrCtrl.text.trim();
    final validationError = CreateBatchOrderValidator.validate(
      pickupAddress: pickupAddr,
      pickupLat: _pickupLat,
      pickupLng: _pickupLng,
      stops: _stops
          .map((stop) => BatchStopValidationInput(
                address: stop.addressCtrl.text,
                phone: stop.phoneCtrl.text,
                lat: stop.lat,
                lng: stop.lng,
              ))
          .toList(growable: false),
    );
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final stops = _stops.asMap().entries.map((e) {
        final s = e.value;
        final cod =
            s.codCtrl.text.trim().replaceAll(',', '').replaceAll('.', '');
        return CreateBatchStopRequest(
          address: s.addressCtrl.text.trim(),
          phone: s.phoneCtrl.text.trim(),
          name: s.nameCtrl.text.trim(),
          note: s.noteCtrl.text.trim(),
          lat: s.lat!,
          lng: s.lng!,
          codAmount: cod.isEmpty ? null : int.tryParse(cod),
        );
      }).toList(growable: false);

      final order = await ref.read(orderRepositoryProvider).createBatch(
            CreateBatchOrderRequest(
              pickupAddress: pickupAddr,
              pickupPhone: _pickupPhoneCtrl.text.trim(),
              orderNote: _noteCtrl.text.trim(),
              cargoType: _cargoType,
              pickupLat: _pickupLat!,
              pickupLng: _pickupLng!,
              cargoWeight: _cargoWeight,
              voucherCode: _voucherCode,
              stops: stops,
            ),
          );
      ref.read(orderListProvider.notifier).addOrder(order);

      if (mounted) {
        context.pushReplacement('/order/${order.code}');
      }
    } catch (e) {
      final msg = parseApiError(e, fallback: 'Có lỗi xảy ra');
      if (mounted) AppSnackbar.error(context, msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;
    final hasFee = _stops.any((s) => s.fee != null);
    final shop = ref.watch(authProvider).user;
    BoxDecoration cardDeco() => BoxDecoration(
          color: c.glass,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.glassBorder, width: 1.2),
          boxShadow: isDark ? null : AppShadows.soft,
        );

    return PopScope(
      canPop: !_hasUnsavedData,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppPageHeader(
          title: 'Đơn gộp nhiều điểm',
          subtitle: 'Một tài xế giao nhiều điểm trong một đơn',
          onBack: _handleBackPress,
          backIcon: Icons.close_rounded,
        ),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl2),
          children: [
            // ── 01 Điểm lấy hàng (mặc định theo cửa hàng) ──────────────
            const AppSectionHeading(
              number: '01',
              title: 'Điểm lấy hàng',
              subtitle: 'Mặc định là cửa hàng của bạn',
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: cardDeco(),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShopLine(
                      icon: Icons.storefront_rounded,
                      text: shop?.name ?? 'Cửa hàng',
                      style: AppTextStyles.bodyStrong
                          .copyWith(color: c.textPrimary),
                      iconColor: c.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ShopLine(
                      icon: Icons.location_on_outlined,
                      text: _pickupAddrCtrl.text.isEmpty
                          ? 'Chưa có địa chỉ cửa hàng — cập nhật trong Hồ sơ'
                          : _pickupAddrCtrl.text,
                      style: AppTextStyles.body.copyWith(
                          color: _pickupAddrCtrl.text.isEmpty
                              ? c.danger
                              : c.textSecondary),
                      iconColor: _pickupAddrCtrl.text.isEmpty
                          ? c.danger
                          : c.textTertiary,
                    ),
                    if (_pickupPhoneCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _ShopLine(
                        icon: Icons.phone_outlined,
                        text: _pickupPhoneCtrl.text,
                        style:
                            AppTextStyles.body.copyWith(color: c.textSecondary),
                        iconColor: c.textTertiary,
                      ),
                    ],
                  ]),
            ),
            const SizedBox(height: AppSpacing.xl2 - AppSpacing.xs),

            // ── 02 Loại hàng ───────────────────────────────────────────
            const AppSectionHeading(
              number: '02',
              title: 'Loại hàng',
              subtitle: 'Áp dụng chung cho cả đơn, thêm dặn dò cho tài xế',
            ),
            Container(
              decoration: cardDeco(),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(children: [
                    for (final cargo in cargoTypes) ...[
                      Expanded(
                        child: CargoTile(
                          cargo: cargo,
                          selected: _cargoType == cargo.key,
                          onTap: () {
                            setState(() => _cargoType = cargo.key);
                            _estimateAll();
                          },
                        ),
                      ),
                      if (cargo.key != cargoTypes.last.key)
                        const SizedBox(width: AppSpacing.sm),
                    ],
                  ]),
                ),
                if (cargoTypeOf(_cargoType).hasWeight) ...[
                  Divider(height: 1, color: c.divider),
                  _BareField(
                    controller: _weightCtrl,
                    icon: Icons.scale_outlined,
                    hint: 'Khối lượng cả đơn (ước lượng)',
                    suffixText: 'kg',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _estimateAll(),
                  ),
                ],
                Divider(height: 1, color: c.divider),
                _BareField(
                  controller: _noteCtrl,
                  icon: Icons.notes_rounded,
                  hint: 'Ghi chú cho tài xế (không bắt buộc)',
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.xl2 - AppSpacing.xs),

            // ── 03 Các điểm giao ───────────────────────────────────────
            AppSectionHeading(
              number: '03',
              title: 'Các điểm giao hàng',
              subtitle: '${_stops.length}/10 điểm · kéo để đổi thứ tự giao',
            ),
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
                  index: i,
                  stop: stop,
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
            if (_stops.length < 10)
              FilledButton.tonalIcon(
                onPressed: _addStop,
                icon: const Icon(Icons.add_rounded, size: AppSize.iconMd),
                label: const Text('Thêm điểm giao'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.primarySoft,
                  foregroundColor: c.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  minimumSize:
                      const Size(double.infinity, AppSize.buttonHeight),
                ),
              ),
            const SizedBox(height: AppSpacing.xl2 - AppSpacing.xs),

            // ── 04 Chi phí ─────────────────────────────────────────────
            AppSectionHeading(
              number: '04',
              title: 'Chi phí ước tính',
              subtitle: _stops.any((s) => s.estimating)
                  ? 'Đang tính phí…'
                  : 'Tổng phí của tất cả điểm giao',
            ),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: cardDeco(),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(children: [
                    _SummaryRow(
                        icon: Icons.pin_drop_outlined,
                        label: 'Số điểm giao',
                        value: '${_stops.length}'),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryRow(
                        icon: Icons.two_wheeler_rounded,
                        label: 'Phí giao hàng',
                        value: hasFee ? Fmt.currency(_totalFee) : '—'),
                    if (_voucherCode != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _SummaryRow(
                        icon: Icons.local_activity_rounded,
                        label:
                            'Voucher $_voucherCode${_voucherLabel != null ? ' · $_voucherLabel' : ''}',
                        value: '-${Fmt.currency(_voucherDiscount ?? 0)}',
                        color: c.accent2,
                      ),
                    ],
                  ]),
                ),
                Divider(height: 1, color: c.divider),
                InkWell(
                  onTap: _totalFee == 0
                      ? null
                      : (_voucherCode != null
                          ? () => setState(_removeVoucher)
                          : _openVoucherSheet),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    child: Row(children: [
                      Icon(
                          _voucherCode != null
                              ? Icons.close_rounded
                              : Icons.local_activity_outlined,
                          size: AppSize.iconMd,
                          color: _voucherCode != null
                              ? c.textSecondary
                              : c.accent2),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                            _voucherCode != null
                                ? 'Bỏ mã giảm giá'
                                : 'Bạn có mã giảm giá?',
                            style: AppTextStyles.bodyStrong.copyWith(
                                color: _voucherCode != null
                                    ? c.textSecondary
                                    : c.accent2)),
                      ),
                      if (_voucherCode == null)
                        Icon(Icons.chevron_right_rounded,
                            size: AppSize.iconMd, color: c.accent2),
                    ]),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: c.primarySoft,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: Row(children: [
                    Text('Tổng cộng',
                        style: AppTextStyles.bodyStrong
                            .copyWith(color: c.textPrimary)),
                    const Spacer(),
                    Text(hasFee ? Fmt.currency(_finalFee) : '—',
                        style: AppTextStyles.metric.copyWith(color: c.primary)),
                  ]),
                ),
              ]),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: c.glassStrong,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            boxShadow: isDark ? null : AppShadows.raised,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
              child: Row(children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tổng cộng',
                        style: AppTextStyles.caption
                            .copyWith(color: c.textTertiary)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(hasFee ? Fmt.currency(_finalFee) : '—',
                        style: AppTextStyles.metric.copyWith(color: c.primary)),
                  ],
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(AppSize.buttonHeight)),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Đặt ${_stops.length} điểm giao'),
                              const SizedBox(width: AppSpacing.sm),
                              const Icon(Icons.arrow_forward_rounded,
                                  size: AppSize.iconMd),
                            ],
                          ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Thành phần dùng chung trong màn ──────────────────────────────────────────

class _ShopLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final TextStyle style;
  final Color iconColor;
  const _ShopLine({
    required this.icon,
    required this.text,
    required this.style,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: AppSize.iconSm + 2, color: iconColor),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
      ]);
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: color, width: 3),
        ),
      );
}

/// Ô nhập gọn không viền: icon cam ở trái, nhãn nằm trong ô (hint).
class _BareField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final String? suffixText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _BareField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.suffixText,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction ?? TextInputAction.next,
        onSubmitted: onSubmitted,
        style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.body.copyWith(color: c.textTertiary),
          prefixIcon: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Icon(icon, size: AppSize.iconMd, color: c.primary)),
          prefixIconConstraints: const BoxConstraints(),
          suffixText: suffixText,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Icon(icon, size: AppSize.iconMd, color: color ?? c.textTertiary),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                AppTextStyles.body.copyWith(color: color ?? c.textSecondary)),
      ),
      const SizedBox(width: AppSpacing.sm),
      Text(value,
          style:
              AppTextStyles.bodyStrong.copyWith(color: color ?? c.textPrimary)),
    ]);
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

  Widget _dragHandle(BuildContext context) => ReorderableDragStartListener(
        index: index,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Icon(Icons.drag_indicator_rounded,
              size: AppSize.iconMd, color: context.colors.textTertiary),
        ),
      );

  bool get _complete =>
      stop.addressCtrl.text.trim().isNotEmpty &&
      stop.phoneCtrl.text.trim().isNotEmpty;

  Widget _indexBadge(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _complete ? c.success : c.primarySoft,
        shape: BoxShape.circle,
      ),
      child: _complete
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : Text('${index + 1}',
              style: AppTextStyles.label
                  .copyWith(fontWeight: FontWeight.w800, color: c.primary)),
    );
  }

  BoxDecoration _deco(BuildContext context, {required bool active}) {
    final c = context.colors;
    return BoxDecoration(
      color: c.glass,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(
          color: active ? c.primary : c.divider, width: active ? 1.4 : 1),
      boxShadow: context.isDark ? null : AppShadows.soft,
    );
  }

  Widget _feeChip(BuildContext context) {
    final c = context.colors;
    if (stop.estimating) {
      return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.primary));
    }
    if (stop.fee == null) {
      return Text('—',
          style: AppTextStyles.label.copyWith(color: c.textTertiary));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(Fmt.currency(stop.fee!),
          style: AppTextStyles.label
              .copyWith(fontWeight: FontWeight.w800, color: c.primary)),
    );
  }

  @override
  Widget build(BuildContext context) =>
      isExpanded ? _buildExpanded(context) : _buildCollapsed(context);

  // ── Thu gọn: 1 hàng ─────────────────────────────────────────────────────
  Widget _buildCollapsed(BuildContext context) {
    final c = context.colors;
    final hasAddress = stop.addressCtrl.text.isNotEmpty;
    final subParts = [
      if (stop.nameCtrl.text.isNotEmpty) stop.nameCtrl.text,
      if (stop.phoneCtrl.text.isNotEmpty) stop.phoneCtrl.text,
      if (stop.codCtrl.text.isNotEmpty) 'Tiền lấy hàng ${stop.codCtrl.text}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: _deco(context, active: false),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: Row(children: [
            _dragHandle(context),
            const SizedBox(width: AppSpacing.xs),
            _indexBadge(context),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasAddress
                        ? stop.addressCtrl.text
                        : 'Điểm ${index + 1} · chưa nhập địa chỉ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                        fontWeight:
                            hasAddress ? FontWeight.w700 : FontWeight.w500,
                        color: hasAddress ? c.textPrimary : c.textTertiary),
                  ),
                  if (subParts.isNotEmpty)
                    Text(subParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption
                            .copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _feeChip(context),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: AppSize.iconMd, color: c.textTertiary),
          ]),
        ),
      ),
    );
  }

  // ── Mở rộng: header + các ô nhập gọn trong cùng một card ─────────────────
  Widget _buildExpanded(BuildContext context) {
    final c = context.colors;
    final hasAddress = stop.addressCtrl.text.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: _deco(context, active: true),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
            child: Row(children: [
              _dragHandle(context),
              const SizedBox(width: AppSpacing.xs),
              _indexBadge(context),
              const SizedBox(width: AppSpacing.md),
              Text('Điểm ${index + 1}',
                  style: AppTextStyles.sectionTitle
                      .copyWith(color: c.textPrimary)),
              if (stop.distanceKm != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text('${stop.distanceKm!.toStringAsFixed(1)} km',
                    style:
                        AppTextStyles.label.copyWith(color: c.textSecondary)),
              ],
              const Spacer(),
              _feeChip(context),
              if (canRemove)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: c.danger, size: AppSize.iconMd),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  tooltip: 'Xoá điểm này',
                  onPressed: onRemove,
                ),
              Icon(Icons.keyboard_arrow_up_rounded,
                  size: AppSize.iconMd, color: c.textTertiary),
            ]),
          ),
        ),
        Divider(height: 1, color: c.divider),
        InkWell(
          onTap: onPickAddress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
            child: Row(children: [
              _Dot(color: c.success),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  hasAddress ? stop.addressCtrl.text : 'Chọn địa chỉ giao hàng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                      fontWeight:
                          hasAddress ? FontWeight.w700 : FontWeight.w600,
                      color: hasAddress ? c.textPrimary : c.textTertiary),
                ),
              ),
              Icon(
                  hasAddress
                      ? Icons.edit_outlined
                      : Icons.chevron_right_rounded,
                  size: AppSize.iconSm + 2,
                  color: hasAddress ? c.primary : c.textTertiary),
            ]),
          ),
        ),
        Divider(height: 1, color: c.divider),
        _BareField(
          controller: stop.phoneCtrl,
          icon: Icons.phone_iphone_rounded,
          hint: 'SĐT người nhận (bắt buộc)',
          keyboardType: TextInputType.phone,
        ),
        Divider(height: 1, color: c.divider),
        _BareField(
          controller: stop.nameCtrl,
          icon: Icons.person_outline_rounded,
          hint: 'Tên người nhận (không bắt buộc)',
        ),
        Divider(height: 1, color: c.divider),
        _BareField(
          controller: stop.codCtrl,
          icon: Icons.payments_outlined,
          hint: 'Tiền lấy hàng (không bắt buộc)',
          suffixText: 'đ',
          keyboardType: TextInputType.number,
        ),
        Divider(height: 1, color: c.divider),
        _BareField(
          controller: stop.noteCtrl,
          icon: Icons.notes_rounded,
          hint: 'Ghi chú (không bắt buộc)',
          textInputAction: TextInputAction.done,
        ),
      ]),
    );
  }
}
