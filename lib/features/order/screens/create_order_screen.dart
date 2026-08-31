import 'dart:async';

import 'package:flutter/services.dart'
    show
        FilteringTextInputFormatter,
        SystemUiOverlayStyle,
        TextInputFormatter,
        TextInputType;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/services/address_search_service.dart';
import '../../../core/widgets/address_picker_screen.dart';
import '../../../core/widgets/map_picker_screen.dart';
import '../../address/models/address_entry.dart';
import '../../address/providers/address_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../voucher/widgets/voucher_sheet.dart';
import '../models/cargo_type.dart';
import '../models/shop_order_type.dart';
import '../data/order_repository.dart';
import '../providers/order_provider.dart';
import '../utils/pricing_request.dart';
import '../utils/create_order_validator.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class CreateOrderScreen extends ConsumerStatefulWidget {
  final ShopOrderType orderType;
  final Map<String, dynamic>? reorderFrom;
  // Pre-fill địa chỉ giao hàng từ sổ địa chỉ đã lưu (vd: chip "Địa chỉ thường
  // dùng" ở trang chủ) — khác reorderFrom ở chỗ vẫn giữ auto-fill pickup từ
  // hồ sơ shop (_prefillFromProfile) thay vì thay thế toàn bộ.
  final AddressEntry? prefillDelivery;
  const CreateOrderScreen({
    super.key,
    this.orderType = ShopOrderType.delivery,
    this.reorderFrom,
    this.prefillDelivery,
  });

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  // Addresses
  String? _pickupAddr, _deliveryAddr;
  String? _pickupPlaceName, _deliveryPlaceName;
  double? _pickupLat, _pickupLng, _deliveryLat, _deliveryLng;

  // Cargo
  String _cargoType = 'food';

  // Thông tin đơn được nhập trực tiếp trên màn hình.
  String _receiverPhone = '';
  String _receiverName = '';
  String _senderName = '';
  String _senderPhone = '';
  String _note = '';
  double? _cargoWeight;
  int? _codAmount;

  // True khi người dùng đã tự tay chọn địa chỉ hoặc nhập thông tin đơn (xem
  // _pickAddress()) — KHÔNG bật khi dữ liệu chỉ tới từ
  // _prefillFromProfile()/_prefillFromReorder()/_applyDeliveryPrefill(), vì
  // lúc đó người dùng chưa mất công nhập gì thực sự. Dùng làm điều kiện
  // cảnh báo thoát màn (xem PopScope trong build()).
  bool _userEdited = false;

  // Fee
  int? _fee;
  int _nightSurcharge = 0;
  double? _distanceKm;
  bool _loadingFee = false;
  bool _submitting = false;
  bool _submitAttempted = false;
  String? _error;

  // Voucher
  String? _voucherCode;
  String? _voucherLabel;
  int? _voucherDiscount;
  Timer? _weightEstimateDebounce;

  // Giao hàng/Lấy hàng chuyển đổi được ngay trên màn (tab ở đầu trang)
  // thay vì phải thoát ra chọn lại — xem _switchOrderType().
  bool _isOutbound = true;

  ShopOrderType get _currentOrderType =>
      _isOutbound ? ShopOrderType.delivery : ShopOrderType.pickup;

  @override
  void initState() {
    super.initState();
    _isOutbound = widget.orderType.isOutbound;
    if (widget.reorderFrom != null) {
      _prefillFromReorder(widget.reorderFrom!);
    } else {
      _prefillFromProfile();
      if (widget.prefillDelivery != null) {
        _applyDeliveryPrefill(widget.prefillDelivery!);
      }
    }
  }

  // Điền sẵn phía giao hàng từ 1 địa chỉ đã lưu — pickup vẫn do
  // _prefillFromProfile() phụ trách (chạy trước lệnh này) nên không cần lặp lại.
  void _applyDeliveryPrefill(AddressEntry entry) {
    _deliveryAddr = entry.address;
    _deliveryPlaceName = entry.displayName;
    _receiverName = entry.name;
    _receiverPhone = entry.phone;
    // Chỉ gán tọa độ theo cặp — địa chỉ sổ lưu có thể chỉ có 1 trong 2 (nhập
    // tay không chọn bản đồ), gán lẻ 1 chiều sẽ khiến các nơi cần cả cặp
    // toạ độ (ước tính phí) hiểu sai là đã đủ dữ liệu.
    if (entry.lat != null && entry.lng != null) {
      _deliveryLat = entry.lat;
      _deliveryLng = entry.lng;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _estimate());
  }

  // Đổi Giao hàng ⇄ Lấy hàng = shop đổi vai trò gửi/nhận — hoán đổi
  // điểm lấy/giao và người gửi/nhận cho đúng vai trò mới (chính là phép
  // _swapAddresses() đã có sẵn, vì shop luôn đứng ở phía vừa prefill).
  void _switchOrderType(bool outbound) {
    if (outbound == _isOutbound) return;
    setState(() => _isOutbound = outbound);
    if (_pickupAddr != null || _deliveryAddr != null) _swapAddresses();
  }

  void _prefillFromReorder(Map<String, dynamic> r) {
    _pickupAddr = r['pickupAddr'] as String?;
    _pickupLat = r['pickupLat'] as double?;
    _pickupLng = r['pickupLng'] as double?;
    _deliveryAddr = r['deliveryAddr'] as String?;
    _deliveryLat = r['deliveryLat'] as double?;
    _deliveryLng = r['deliveryLng'] as double?;
    _cargoType = r['cargoType'] as String? ?? 'food';

    _receiverPhone = r['deliveryPhone'] as String? ?? '';
    _receiverName = r['deliveryName'] as String? ?? '';
    _senderName = r['pickupName'] as String? ?? '';
    _senderPhone = r['pickupPhone'] as String? ?? '';
    _note = r['note'] as String? ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) => _estimate());
  }

  void _prefillFromProfile() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (_isOutbound) {
      // Giao đơn: pickup = shop → sender là shop
      _senderName = user.name;
      _senderPhone = user.phone;
      final addr = user.address;
      if (addr != null && addr.isNotEmpty) {
        _pickupAddr = addr;
        _pickupPlaceName = user.name.isNotEmpty ? user.name : null;
        _geocodeShopAddress(addr, isPickup: true);
      }
    } else {
      // Lấy hộ: delivery = shop → receiver là shop, sender để trống (người ở điểm lấy)
      _receiverName = user.name;
      _receiverPhone = user.phone;
      final addr = user.address;
      if (addr != null && addr.isNotEmpty) {
        _deliveryAddr = addr;
        _deliveryPlaceName = user.name.isNotEmpty ? user.name : null;
        _geocodeShopAddress(addr, isPickup: false);
      }
    }
  }

  Future<void> _geocodeShopAddress(String address,
      {required bool isPickup}) async {
    try {
      final result = await AddressSearchService.getDetail(
        AddressResult(
          display: address,
          mainText: address,
          secondaryText: '',
          placeId: '',
        ),
      );
      if (!mounted || result == null) return;
      // Bỏ qua nếu user đã chọn địa chỉ khác trong lúc geocode đang chạy
      if (isPickup && _pickupAddr != address) return;
      if (!isPickup && _deliveryAddr != address) return;

      if (isPickup) {
        setState(() {
          _pickupLat = result.lat;
          _pickupLng = result.lng;
        });
      } else {
        setState(() {
          _deliveryLat = result.lat;
          _deliveryLng = result.lng;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _weightEstimateDebounce?.cancel();
    super.dispose();
  }

  // ── Address picker ──────────────────────────────────────────────────────────

  Future<void> _pickAddress({required bool isPickup}) async {
    final title = isPickup
        ? (_isOutbound ? 'Địa chỉ lấy hàng' : 'Địa điểm lấy')
        : (_isOutbound ? 'Địa chỉ giao hàng' : 'Địa chỉ cửa hàng');

    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(title: title),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _userEdited = true;
      if (isPickup) {
        _pickupAddr = result.address;
        _pickupPlaceName = result.placeName;
        _pickupLat = result.lat;
        _pickupLng = result.lng;
        if (result.contactName?.isNotEmpty == true) {
          _senderName = result.contactName!;
        }
        if (result.contactPhone?.isNotEmpty == true) {
          _senderPhone = result.contactPhone!;
        }
      } else {
        _deliveryAddr = result.address;
        _deliveryPlaceName = result.placeName;
        _deliveryLat = result.lat;
        _deliveryLng = result.lng;
        if (result.contactName?.isNotEmpty == true) {
          _receiverName = result.contactName!;
        }
        if (result.contactPhone?.isNotEmpty == true) {
          _receiverPhone = result.contactPhone!;
        }
      }
      _error = null;
    });
    await _estimate();
  }

  void _swapAddresses() {
    setState(() {
      final tA = _pickupAddr;
      _pickupAddr = _deliveryAddr;
      _deliveryAddr = tA;
      final tPN = _pickupPlaceName;
      _pickupPlaceName = _deliveryPlaceName;
      _deliveryPlaceName = tPN;
      final tLa = _pickupLat;
      _pickupLat = _deliveryLat;
      _deliveryLat = tLa;
      final tLo = _pickupLng;
      _pickupLng = _deliveryLng;
      _deliveryLng = tLo;
      final tN = _senderName;
      _senderName = _receiverName;
      _receiverName = tN;
      final tP = _senderPhone;
      _senderPhone = _receiverPhone;
      _receiverPhone = tP;
    });
    _estimate();
  }

  // ── Estimate ────────────────────────────────────────────────────────────────

  Future<void> _estimate() async {
    if (_pickupAddr == null || _deliveryAddr == null) return;
    // Lưu lại phí cũ TRƯỚC khi setState() dưới đây ghi đè _fee = null cho
    // trạng thái loading — dùng để so sánh xem phí có thực sự đổi không.
    final oldFee = _fee;
    setState(() {
      _loadingFee = true;
      _fee = null;
    });
    try {
      final p = buildPricingParams(
        cargoType: _cargoType,
        cargoWeight: _cargoWeight,
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        deliveryLat: _deliveryLat,
        deliveryLng: _deliveryLng,
        pickupAddress: _pickupAddr ?? '',
        deliveryAddress: _deliveryAddr ?? '',
      );
      final estimate = await ref.read(orderRepositoryProvider).estimate(p);
      if (mounted) {
        final newFee = estimate.fee;
        // Chỉ gỡ voucher khi ĐANG áp VÀ phí thực sự đổi — tránh gỡ oan mỗi
        // lần gọi lại _estimate() (vd đổi cân nặng nhưng phí không đổi).
        final shouldRemoveVoucher = _voucherCode != null && newFee != oldFee;
        setState(() {
          _fee = newFee;
          _nightSurcharge = estimate.nightSurcharge;
          _distanceKm = estimate.distanceKm;
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
    } finally {
      if (mounted) setState(() => _loadingFee = false);
    }
  }

  // ── Voucher ─────────────────────────────────────────────────────────────────

  int get _finalFee {
    if (_fee == null) return 0;
    final discountedDeliveryFee =
        (_fee! - (_voucherDiscount ?? 0)).clamp(0, _fee!);
    return discountedDeliveryFee + _nightSurcharge;
  }

  Future<void> _openVoucherSheet() async {
    if (_fee == null) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => VoucherSheet(fee: _fee!),
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

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _submitAttempted = true);
    final locationError = CreateOrderValidator.locations(
      pickupAddress: _pickupAddr,
      deliveryAddress: _deliveryAddr,
      pickupLat: _pickupLat,
      pickupLng: _pickupLng,
      deliveryLat: _deliveryLat,
      deliveryLng: _deliveryLng,
    );
    if (locationError != null) {
      setState(() => _error = locationError);
      return;
    }

    if (_receiverPhone.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập số điện thoại người nhận');
      return;
    }
    if (!_isOutbound && _senderPhone.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập số điện thoại người giao');
      return;
    }
    final contactError = CreateOrderValidator.contacts(
      orderType: _currentOrderType,
      receiverPhone: _receiverPhone,
      senderPhone: _senderPhone,
    );
    if (contactError != null) {
      setState(() => _error = contactError);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final order = await ref.read(orderRepositoryProvider).create(
            CreateOrderRequest(
              isOutbound: _isOutbound,
              pickupAddress: _pickupAddr!,
              deliveryAddress: _deliveryAddr!,
              deliveryPhone: _receiverPhone.trim(),
              deliveryName: _receiverName.trim(),
              pickupName: _senderName.trim(),
              pickupPhone: _senderPhone.trim(),
              orderNote: _note,
              cargoType: _cargoType,
              cargoWeight: _cargoWeight,
              codAmount: _codAmount,
              pickupPlaceName: _pickupPlaceName,
              deliveryPlaceName: _deliveryPlaceName,
              pickupLat: _pickupLat,
              pickupLng: _pickupLng,
              deliveryLat: _deliveryLat,
              deliveryLng: _deliveryLng,
              voucherCode: _voucherCode,
            ),
          );
      ref.read(orderListProvider.notifier).addOrder(order);
      // Gợi ý lưu địa chỉ nếu có tên + SĐT người nhận và chưa có trong sổ
      if (mounted &&
          _isOutbound &&
          _receiverPhone.isNotEmpty &&
          _deliveryAddr != null) {
        final existing = ref.read(addressProvider).valueOrNull ?? [];
        final alreadySaved =
            existing.any((e) => e.phone == _receiverPhone.trim());
        if (!alreadySaved) {
          final addressNotifier = ref.read(addressProvider.notifier);
          final displayName =
              _receiverName.isNotEmpty ? _receiverName : _receiverPhone;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              title: const Row(children: [
                Icon(Icons.bookmark_add_outlined,
                    color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text('Lưu địa chỉ?',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ]),
              content: Text(
                'Lưu "$displayName" vào sổ địa chỉ để dùng lại lần sau.',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Huỷ'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    addressNotifier.add(
                      name: displayName,
                      phone: _receiverPhone.trim(),
                      address: _deliveryAddr!,
                      lat: _deliveryLat,
                      lng: _deliveryLng,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Lưu'),
                ),
              ],
            ),
          );
        }
      }
      if (mounted) context.pushReplacement('/order/${order.code}');
    } catch (e) {
      final msg =
          parseApiError(e, fallback: 'Không thể đặt đơn, vui lòng thử lại');
      if (mounted) {
        setState(() {
          _error = msg;
          _submitting = false;
        });
      }
    }
  }

  Future<void> _openReceiverPhonePopup() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhoneInputSheet(
        initialValue: _receiverPhone,
        title: _isOutbound
            ? 'Số điện thoại người nhận'
            : 'Số điện thoại cửa hàng nhận',
        description: 'Nhập số điện thoại để tài xế liên hệ khi giao hàng.',
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      _receiverPhone = value;
      _userEdited = true;
      _error = null;
    });
  }

  Future<void> _openSenderPhonePopup() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhoneInputSheet(
        initialValue: _senderPhone,
        title: 'Số điện thoại người giao',
        description: 'Nhập số điện thoại để tài xế liên hệ tại điểm lấy.',
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      _senderPhone = value;
      _userEdited = true;
      _error = null;
    });
  }

  // ── Exit confirmation ────────────────────────────────────────────────────

  // Dùng cho cả PopScope (back gesture/nút cứng) lẫn nút back thủ công trong
  // build() — context.pop() ở nút back gọi Navigator.pop() trực tiếp, không
  // đi qua maybePop() nên PopScope không tự chặn được, phải tự kiểm tra ở đây.
  Future<void> _handleBackPress() async {
    if (!_userEdited) {
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
        title: const Text('Huỷ đặt đơn?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: const Text('Thông tin bạn đã nhập sẽ không được lưu.',
            style: TextStyle(fontSize: 14, height: 1.5)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  bool get _needsPhone => _receiverPhone.trim().isEmpty;

  bool get _showPhoneWarning => _submitAttempted && _needsPhone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_userEdited,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: c.surface,
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(bottom: BorderSide(color: c.divider)),
                ),
                child: Row(children: [
                  GestureDetector(
                    onTap: _handleBackPress,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: c.divider),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 17, color: c.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Đặt đơn',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary)),
                ]),
              ),

              Expanded(
                child: ColoredBox(
                  color: c.background,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Toggle Giao hàng / Lấy hàng ──────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: c.background,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(color: c.divider),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(children: [
                            Expanded(
                              child: _OrderTypeTab(
                                label: 'Giao hàng',
                                selected: _isOutbound,
                                onTap: () => _switchOrderType(true),
                              ),
                            ),
                            Expanded(
                              child: _OrderTypeTab(
                                label: 'Lấy hàng',
                                selected: !_isOutbound,
                                onTap: () => _switchOrderType(false),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 16),

                        // ── Route card ────────────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: c.divider),
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                        color: c.primary,
                                        shape: BoxShape.circle),
                                  ),
                                  Container(
                                    width: 2,
                                    height: 44,
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    color: c.divider,
                                  ),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                        color: c.accent2,
                                        borderRadius: BorderRadius.circular(3)),
                                  ),
                                ]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _pickAddress(isPickup: true),
                                      child: _AddressRow(
                                        label: 'ĐIỂM LẤY HÀNG',
                                        address: _pickupAddr,
                                        placeName: _pickupPlaceName,
                                        placeholder: _isOutbound
                                            ? 'Chọn địa chỉ lấy hàng'
                                            : 'Chọn địa điểm lấy',
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () =>
                                          _pickAddress(isPickup: false),
                                      child: _AddressRow(
                                        label: 'ĐIỂM GIAO HÀNG',
                                        address: _deliveryAddr,
                                        placeName: _deliveryPlaceName,
                                        placeholder: _isOutbound
                                            ? 'Chọn địa chỉ giao hàng'
                                            : 'Chọn địa chỉ cửa hàng',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 38),
                                child: GestureDetector(
                                  onTap: _pickupAddr != null &&
                                          _deliveryAddr != null
                                      ? _swapAddresses
                                      : () => _pickAddress(isPickup: false),
                                  child: Icon(
                                    _pickupAddr != null && _deliveryAddr != null
                                        ? Icons.swap_vert_rounded
                                        : Icons.chevron_right_rounded,
                                    size: 20,
                                    color: c.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Liên hệ + COD ─────────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: c.divider),
                          ),
                          child: Column(children: [
                            _PopupInfoRow(
                              icon: _showPhoneWarning
                                  ? Icons.error_outline_rounded
                                  : Icons.phone_iphone_rounded,
                              label: _isOutbound
                                  ? 'SĐT người nhận'
                                  : 'SĐT cửa hàng nhận',
                              value: _receiverPhone,
                              placeholder: 'Bắt buộc',
                              warn: _showPhoneWarning,
                              onTap: _openReceiverPhonePopup,
                            ),
                            if (!_isOutbound) ...[
                              Divider(height: 1, indent: 16, color: c.divider),
                              _PopupInfoRow(
                                icon: Icons.call_outlined,
                                label: 'SĐT người giao',
                                value: _senderPhone,
                                placeholder: 'Bắt buộc',
                                warn: _submitAttempted &&
                                    _senderPhone.trim().isEmpty,
                                onTap: _openSenderPhonePopup,
                              ),
                            ],
                            Divider(height: 1, indent: 16, color: c.divider),
                            _InlineOrderField(
                              key: ValueKey(
                                  'cod-${_isOutbound ? 'delivery' : 'pickup'}'),
                              icon: Icons.payments_outlined,
                              label: 'Tiền thu hộ (COD)',
                              initialValue: _codAmount == null
                                  ? ''
                                  : NumberFormat('#,###', 'vi_VN')
                                      .format(_codAmount)
                                      .replaceAll(',', '.'),
                              hint: 'Không bắt buộc',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _ThousandsFormatter(),
                              ],
                              suffixText: 'đ',
                              onChanged: (value) {
                                final digits = value.replaceAll('.', '').trim();
                                _codAmount = digits.isEmpty
                                    ? null
                                    : int.tryParse(digits);
                                _userEdited = true;
                              },
                            ),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // ── Loại hàng ──────────────────────────────────────────
                        Row(children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 17, color: c.textSecondary),
                          const SizedBox(width: 7),
                          Text('Loại hàng',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          for (final cargo in cargoTypes) ...[
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _cargoType = cargo.key;
                                    if (!cargo.hasWeight) _cargoWeight = null;
                                    _fee = null;
                                  });
                                  _estimate();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: _cargoType == cargo.key
                                        ? c.primarySoft
                                        : c.surface,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    border: Border.all(
                                      color: _cargoType == cargo.key
                                          ? c.primary
                                          : c.divider,
                                      width: _cargoType == cargo.key ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(cargo.icon,
                                          size: 22,
                                          color: _cargoType == cargo.key
                                              ? c.primary
                                              : c.textSecondary),
                                      const SizedBox(height: 6),
                                      Text(cargo.label,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight:
                                                  _cargoType == cargo.key
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                              color: _cargoType == cargo.key
                                                  ? c.primary
                                                  : c.textSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (cargo.key != cargoTypes.last.key)
                              const SizedBox(width: 10),
                          ],
                        ]),
                        if (cargoTypes
                            .firstWhere((cargo) => cargo.key == _cargoType)
                            .hasWeight) ...[
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: c.divider),
                            ),
                            child: _InlineOrderField(
                              key: ValueKey('weight-$_cargoType'),
                              icon: Icons.scale_outlined,
                              label: 'Khối lượng',
                              initialValue: _cargoWeight?.toString() ?? '',
                              hint: 'Nhập số ký',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              suffixText: 'kg',
                              onChanged: (value) {
                                _cargoWeight = double.tryParse(
                                    value.trim().replaceAll(',', '.'));
                                _userEdited = true;
                                _weightEstimateDebounce?.cancel();
                                _weightEstimateDebounce = Timer(
                                  const Duration(milliseconds: 500),
                                  _estimate,
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        Container(
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: c.divider),
                          ),
                          child: TextFormField(
                            key: ValueKey('note-${widget.reorderFrom != null}'),
                            initialValue: _note,
                            minLines: 1,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (value) {
                              _note = value;
                              _userEdited = true;
                            },
                            style:
                                TextStyle(fontSize: 13.5, color: c.textPrimary),
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.notes_rounded,
                                  size: 19, color: c.textSecondary),
                              hintText: 'Ghi chú cho tài xế (không bắt buộc)',
                              hintStyle: TextStyle(
                                  fontSize: 13.5, color: c.textTertiary),
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Ước tính phí ───────────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: c.divider),
                          ),
                          padding: const EdgeInsets.all(18),
                          child: _loadingFee
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Center(
                                      child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_distanceKm != null) ...[
                                      _FeeRow(
                                        label: 'Khoảng cách ước tính',
                                        value:
                                            '${_distanceKm!.toStringAsFixed(1)} km',
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    _FeeRow(
                                      label: 'Phí giao hàng',
                                      value: _fee == null
                                          ? '—'
                                          : Fmt.currency(_fee!),
                                    ),
                                    if (_nightSurcharge > 0) ...[
                                      const SizedBox(height: 8),
                                      Row(children: [
                                        Icon(Icons.nightlight_round,
                                            size: 13, color: c.warning),
                                        const SizedBox(width: 6),
                                        Text('Phụ phí đêm',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: c.warning)),
                                        const Spacer(),
                                        Text(
                                            '+${Fmt.currency(_nightSurcharge)}',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: c.warning)),
                                      ]),
                                    ],
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: _fee == null
                                          ? null
                                          : _openVoucherSheet,
                                      child: _voucherCode != null
                                          ? Row(children: [
                                              Icon(Icons.local_offer_rounded,
                                                  size: 15, color: c.accent2),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                    'Voucher $_voucherCode${_voucherLabel != null ? ' · $_voucherLabel' : ''}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: c.accent2)),
                                              ),
                                              Text(
                                                  '-${Fmt.currency(_voucherDiscount ?? 0)}',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: c.accent2)),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () =>
                                                    setState(_removeVoucher),
                                                child: Icon(Icons.close_rounded,
                                                    size: 16,
                                                    color: c.textTertiary),
                                              ),
                                            ])
                                          : Row(children: [
                                              Icon(Icons.local_offer_outlined,
                                                  size: 15, color: c.accent2),
                                              const SizedBox(width: 6),
                                              Text('Bạn có mã giảm giá?',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: c.accent2)),
                                            ]),
                                    ),
                                    const SizedBox(height: 4),
                                    Divider(height: 17, color: c.divider),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Tổng cộng',
                                            style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: c.textPrimary)),
                                        Text(
                                            _fee == null
                                                ? '—'
                                                : Fmt.currency(_finalFee),
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: c.primary)),
                                      ],
                                    ),
                                  ],
                                ),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Row(children: [
                            Icon(Icons.error_outline_rounded,
                                color: c.danger, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(_error!,
                                  style:
                                      TextStyle(color: c.danger, fontSize: 12)),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.divider)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tổng cộng',
                          style:
                              TextStyle(fontSize: 11.5, color: c.textTertiary)),
                      Text(_fee == null ? '—' : Fmt.currency(_finalFee),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: c.primary)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Đặt đơn'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Toggle tab (Giao hàng / Lấy hàng) ───────────────────────────────────────

class _OrderTypeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OrderTypeTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? c.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : c.textSecondary)),
      ),
    );
  }
}

// ─── Dòng điểm lấy/giao trong route card ─────────────────────────────────────

class _AddressRow extends StatelessWidget {
  final String label;
  final String? address;
  final String? placeName;
  final String placeholder;
  const _AddressRow({
    required this.label,
    required this.address,
    required this.placeName,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: c.textTertiary)),
        const SizedBox(height: 3),
        if (address != null) ...[
          Text(placeName ?? address!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary)),
          if (placeName != null) ...[
            const SizedBox(height: 2),
            Text(address!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
          ],
        ] else
          Text(placeholder,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: c.textTertiary)),
      ],
    );
  }
}

// ─── Ô nhập nhanh thông tin đơn ──────────────────────────────────────────────

class _PhoneInputSheet extends StatefulWidget {
  final String initialValue;
  final String title;
  final String description;

  const _PhoneInputSheet({
    required this.initialValue,
    required this.title,
    required this.description,
  });

  @override
  State<_PhoneInputSheet> createState() => _PhoneInputSheetState();
}

class _PhoneInputSheetState extends State<_PhoneInputSheet> {
  late final TextEditingController _controller;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final phone = _controller.text.trim();
    if (phone.isEmpty) {
      setState(() => _validationMessage = 'Vui lòng nhập SĐT');
      return;
    }
    Navigator.pop(context, phone);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.divider,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.title,
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(widget.description,
                    style: TextStyle(fontSize: 13.5, color: c.textSecondary)),
                const SizedBox(height: 18),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _confirm(),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.phone_iphone_rounded,
                        color: _validationMessage == null
                            ? c.textSecondary
                            : c.danger),
                    hintText: 'Nhập số điện thoại',
                    errorText: _validationMessage,
                    filled: true,
                    fillColor: c.background,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: c.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: c.primary, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: c.danger),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: c.danger, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: c.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Xác nhận',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodAmountSheet extends StatefulWidget {
  const _CodAmountSheet();

  @override
  State<_CodAmountSheet> createState() => _CodAmountSheetState();
}

class _CodAmountSheetState extends State<_CodAmountSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final digits = _controller.text.replaceAll('.', '').trim();
    Navigator.pop(context, digits.isEmpty ? 0 : int.parse(digits));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.divider,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Tiền thu hộ (COD)',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
                const SizedBox(height: 6),
                Text('Nhập số tiền tài xế cần thu từ người nhận.',
                    style: TextStyle(fontSize: 13.5, color: c.textSecondary)),
                const SizedBox(height: 18),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ThousandsFormatter(),
                  ],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _confirm(),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary),
                  decoration: InputDecoration(
                    prefixIcon:
                        Icon(Icons.payments_outlined, color: c.textSecondary),
                    hintText: '0',
                    suffixText: 'đ',
                    filled: true,
                    fillColor: c.background,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: c.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: c.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: c.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Xác nhận',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderNoteSheet extends StatefulWidget {
  final String initialValue;

  const _OrderNoteSheet({required this.initialValue});

  @override
  State<_OrderNoteSheet> createState() => _OrderNoteSheetState();
}

class _OrderNoteSheetState extends State<_OrderNoteSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.divider,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Ghi chú cho tài xế',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
                const SizedBox(height: 6),
                Text('Thêm hướng dẫn về hàng hóa hoặc điểm giao nhận.',
                    style: TextStyle(fontSize: 13.5, color: c.textSecondary)),
                const SizedBox(height: 18),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Nhập ghi chú (không bắt buộc)',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: c.background,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: c.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: c.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: c.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Xác nhận',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PopupInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String placeholder;
  final bool warn;
  final VoidCallback onTap;

  const _PopupInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(children: [
          Icon(icon, size: 19, color: warn ? c.danger : c.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: warn ? c.danger : c.textPrimary)),
          ),
          SizedBox(
            width: 120,
            child: Text(
              value.isEmpty ? placeholder : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: value.isEmpty ? FontWeight.w500 : FontWeight.w700,
                  color: value.isEmpty
                      ? (warn ? c.danger : c.textTertiary)
                      : c.textPrimary),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: c.textTertiary),
        ]),
      ),
    );
  }
}

class _InlineOrderField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String initialValue;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffixText;
  final ValueChanged<String> onChanged;
  const _InlineOrderField({
    super.key,
    required this.icon,
    required this.label,
    required this.initialValue,
    required this.hint,
    required this.keyboardType,
    required this.onChanged,
    this.inputFormatters,
    this.suffixText,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Icon(icon, size: 19, color: c.textSecondary),
        const SizedBox(width: 12),
        SizedBox(
          width: 142,
          child: Text(label,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary)),
        ),
        Expanded(
          child: TextFormField(
            initialValue: initialValue,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textAlign: TextAlign.right,
            onChanged: onChanged,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: c.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              suffixText: suffixText,
              filled: false,
              fillColor: Colors.transparent,
              hintStyle: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: c.textTertiary),
              suffixStyle: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Dòng trong thẻ ước tính phí ──────────────────────────────────────────────

class _FeeRow extends StatelessWidget {
  final String label;
  final String value;
  const _FeeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textPrimary)),
      ],
    );
  }
}

// ─── Detail Result ────────────────────────────────────────────────────────────

class _DetailResult {
  final String receiverPhone, receiverName, senderName, senderPhone;
  final String note;
  final double? cargoWeight;
  final int? codAmount;

  const _DetailResult({
    required this.receiverPhone,
    required this.receiverName,
    required this.senderName,
    required this.senderPhone,
    required this.note,
    required this.cargoWeight,
    required this.codAmount,
  });
}

// ─── Detail Sheet ─────────────────────────────────────────────────────────────

class _DetailSheet extends StatefulWidget {
  final CargoType cargo;
  final bool isOutbound;
  final String receiverPhone, receiverName, senderName, senderPhone;
  final String note;
  final double? cargoWeight;
  final int? codAmount;
  final void Function(_DetailResult) onSave;

  const _DetailSheet({
    required this.cargo,
    required this.isOutbound,
    required this.receiverPhone,
    required this.receiverName,
    required this.senderName,
    required this.senderPhone,
    required this.note,
    required this.cargoWeight,
    required this.codAmount,
    required this.onSave,
  });

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  late final TextEditingController _receiverPhoneCtrl;
  late final TextEditingController _receiverNameCtrl;
  late final TextEditingController _senderNameCtrl;
  late final TextEditingController _senderPhoneCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _codCtrl;

  @override
  void initState() {
    super.initState();
    _receiverPhoneCtrl = TextEditingController(text: widget.receiverPhone);
    _receiverNameCtrl = TextEditingController(text: widget.receiverName);
    _senderNameCtrl = TextEditingController(text: widget.senderName);
    _senderPhoneCtrl = TextEditingController(text: widget.senderPhone);
    _noteCtrl = TextEditingController(text: widget.note);
    _weightCtrl =
        TextEditingController(text: widget.cargoWeight?.toString() ?? '');
    _codCtrl = TextEditingController(
        text: widget.codAmount != null
            ? NumberFormat('#,###', 'vi_VN')
                .format(widget.codAmount)
                .replaceAll(',', '.')
            : '');
  }

  @override
  void dispose() {
    for (final c in [
      _receiverPhoneCtrl,
      _receiverNameCtrl,
      _senderNameCtrl,
      _senderPhoneCtrl,
      _noteCtrl,
      _weightCtrl,
      _codCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    widget.onSave(_DetailResult(
      receiverPhone: _receiverPhoneCtrl.text.trim(),
      receiverName: _receiverNameCtrl.text.trim(),
      senderName: _senderNameCtrl.text.trim(),
      senderPhone: _senderPhoneCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      cargoWeight: _weightCtrl.text.trim().isNotEmpty
          ? double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.'))
          : null,
      codAmount: _codCtrl.text.trim().isNotEmpty
          ? int.tryParse(
              _codCtrl.text.trim().replaceAll(',', '').replaceAll('.', ''))
          : null,
    ));
    Navigator.pop(context);
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color? iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: iconColor ?? AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Row(children: [
              const Text('Chi tiết đơn',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textSecondary),
              ),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Người nhận / Cửa hàng nhận về ──────────────────
                  _section(
                    icon: Icons.person_pin_circle_rounded,
                    title:
                        widget.isOutbound ? 'Người nhận' : 'Cửa hàng nhận về',
                    children: [
                      AppField(
                        controller: _receiverPhoneCtrl,
                        hint: widget.isOutbound
                            ? 'SĐT người nhận *'
                            : 'SĐT cửa hàng *',
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        prefixIcon: const Icon(Icons.call_rounded,
                            size: 18, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      AppField(
                        controller: _receiverNameCtrl,
                        hint: widget.isOutbound
                            ? 'Tên người nhận (tuỳ chọn)'
                            : 'Tên cửa hàng (tuỳ chọn)',
                        textInputAction: TextInputAction.next,
                        prefixIcon: const Icon(Icons.badge_outlined,
                            size: 18, color: AppColors.textSecondary),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Người gửi / Điểm lấy ────────────────────────────
                  _section(
                    icon: Icons.storefront_rounded,
                    title: widget.isOutbound
                        ? 'Cửa hàng'
                        : 'Người giao tại điểm lấy',
                    children: [
                      Row(children: [
                        Expanded(
                          child: AppField(
                            controller: _senderNameCtrl,
                            hint: widget.isOutbound
                                ? 'Tên cửa hàng'
                                : 'Tên người giao',
                            textInputAction: TextInputAction.next,
                            prefixIcon: const Icon(Icons.badge_outlined,
                                size: 18, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppField(
                            controller: _senderPhoneCtrl,
                            hint: widget.isOutbound
                                ? 'SĐT lấy hàng'
                                : 'SĐT liên hệ *',
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            prefixIcon: const Icon(Icons.call_rounded,
                                size: 18, color: AppColors.textSecondary),
                          ),
                        ),
                      ]),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Hàng hóa ────────────────────────────────────────
                  if (widget.cargo.hasWeight) ...[
                    _section(
                      icon: widget.cargo.icon,
                      iconColor: widget.cargo.color,
                      title: 'Hàng hóa · ${widget.cargo.label}',
                      children: [
                        AppField(
                          controller: _weightCtrl,
                          hint: 'Số kg (ước lượng)',
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: const Icon(Icons.scale_outlined,
                              size: 18, color: AppColors.textSecondary),
                          suffix: const Text('kg',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Khác: Ghi chú + COD ──────────────────────────────
                  _section(
                    icon: Icons.more_horiz_rounded,
                    title: 'Khác',
                    children: [
                      AppField(
                        controller: _noteCtrl,
                        hint: 'Ghi chú (về hàng hóa, dặn dò tài xế...)',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),

                      // COD row
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          const Icon(Icons.payments_outlined,
                              size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          const Text('Thu hộ COD',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary)),
                          const Spacer(),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _codCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _ThousandsFormatter(),
                              ],
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15),
                                suffixText: ' đ',
                                suffixStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  AppButton(label: 'Xác nhận', onPressed: _save),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Định dạng số COD theo dấu chấm (1.500.000) ────────────────────────────────

class _ThousandsFormatter extends TextInputFormatter {
  static final _format = NumberFormat('#,###', 'vi_VN');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final formatted = _format.format(int.parse(digits)).replaceAll(',', '.');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
