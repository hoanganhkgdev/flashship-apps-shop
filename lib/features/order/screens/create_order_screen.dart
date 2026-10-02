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
import '../../../core/widgets/app_decor_widgets.dart';
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
  final _receiverPhoneCtrl = TextEditingController();
  final _senderPhoneCtrl = TextEditingController();

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

  // Loại đơn được cố định từ luồng đã chọn trước khi mở màn hình.
  bool get _isOutbound => widget.orderType.isOutbound;

  ShopOrderType get _currentOrderType => widget.orderType;

  @override
  void initState() {
    super.initState();
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
    _receiverPhoneCtrl.dispose();
    _senderPhoneCtrl.dispose();
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
      useSafeArea: true,
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
                    style: TextStyle(
                        fontSize: AppFontSize.xl, fontWeight: FontWeight.w700)),
              ]),
              content: Text(
                'Lưu "$displayName" vào sổ địa chỉ để dùng lại lần sau.',
                style: const TextStyle(fontSize: AppFontSize.md, height: 1.5),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
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
                        borderRadius: BorderRadius.circular(8)),
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

  // Số điện thoại có thể được điền từ nơi khác (địa chỉ đã lưu, đặt lại, chọn
  // địa chỉ…) nên đồng bộ chuỗi trạng thái vào ô nhập trước mỗi lần dựng.
  void _syncPhoneControllers() {
    void sync(TextEditingController ctrl, String value) {
      if (ctrl.text == value) return;
      ctrl.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }

    sync(_receiverPhoneCtrl, _receiverPhone);
    sync(_senderPhoneCtrl, _senderPhone);
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
            style: TextStyle(
                fontSize: AppFontSize.xl, fontWeight: FontWeight.w700)),
        content: const Text('Thông tin bạn đã nhập sẽ không được lưu.',
            style: TextStyle(fontSize: AppFontSize.md, height: 1.5)),
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

  bool get _needsPhone => _receiverPhone.trim().isEmpty;

  bool get _showPhoneWarning => _submitAttempted && _needsPhone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _syncPhoneControllers();

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
          backgroundColor: Colors.transparent,
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(children: [
              // ── Header ──────────────────────────────────────────────────
              AppPageHeader(
                title: 'Đặt đơn',
                subtitle: _isOutbound
                    ? 'Tài xế lấy hàng tại shop và giao tới khách'
                    : 'Tài xế lấy hàng tại điểm lấy và giao về shop',
                onBack: _handleBackPress,
              ),
              Expanded(
                child: ColoredBox(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.xl2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionHeading(
                          number: '01',
                          title: 'Hành trình giao hàng',
                          subtitle: 'Chọn điểm lấy và điểm giao của đơn',
                        ),
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: c.glass,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border:
                                Border.all(color: c.glassBorder, width: 1.2),
                            boxShadow: isDark ? null : AppShadows.soft,
                          ),
                          child: Column(children: [
                            _RouteStop(
                              isFirst: true,
                              color: c.danger,
                              icon: Icons.storefront_rounded,
                              label: 'ĐIỂM LẤY HÀNG',
                              address: _pickupAddr,
                              placeName: _pickupPlaceName,
                              placeholder: _isOutbound
                                  ? 'Chọn địa chỉ lấy hàng'
                                  : 'Chọn địa điểm lấy',
                              onTap: () => _pickAddress(isPickup: true),
                            ),
                            Divider(
                                height: 1,
                                indent: AppSpacing.lg + 14 + AppSpacing.md,
                                color: c.divider),
                            _RouteStop(
                              isFirst: false,
                              color: c.success,
                              icon: Icons.location_on_rounded,
                              label: 'ĐIỂM GIAO HÀNG',
                              address: _deliveryAddr,
                              placeName: _deliveryPlaceName,
                              placeholder: _isOutbound
                                  ? 'Chọn địa chỉ giao hàng'
                                  : 'Chọn địa chỉ cửa hàng',
                              onTap: () => _pickAddress(isPickup: false),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 24),
                        const AppSectionHeading(
                          number: '02',
                          title: 'Liên hệ & tiền lấy hàng',
                          subtitle:
                              'Để tài xế liên hệ và chuẩn bị tiền khi lấy hàng',
                        ),

                        // ── Liên hệ + tiền lấy hàng ─────────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: c.glass,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border:
                                Border.all(color: c.glassBorder, width: 1.2),
                            boxShadow: isDark ? null : AppShadows.soft,
                          ),
                          child: Column(children: [
                            _ContactPhoneField(
                              icon: Icons.phone_iphone_rounded,
                              label: _isOutbound
                                  ? 'SĐT người nhận (bắt buộc)'
                                  : 'SĐT cửa hàng nhận (bắt buộc)',
                              controller: _receiverPhoneCtrl,
                              warn: _showPhoneWarning,
                              onChanged: (v) => setState(() {
                                _receiverPhone = v;
                                _userEdited = true;
                                _error = null;
                              }),
                            ),
                            if (!_isOutbound) ...[
                              Divider(height: 1, indent: 16, color: c.divider),
                              _ContactPhoneField(
                                icon: Icons.call_outlined,
                                label: 'SĐT người giao (bắt buộc)',
                                controller: _senderPhoneCtrl,
                                warn: _submitAttempted &&
                                    _senderPhone.trim().isEmpty,
                                onChanged: (v) => setState(() {
                                  _senderPhone = v;
                                  _userEdited = true;
                                  _error = null;
                                }),
                              ),
                            ],
                            Divider(height: 1, indent: 16, color: c.divider),
                            _InlineOrderField(
                              key: ValueKey(
                                  'cod-${_isOutbound ? 'delivery' : 'pickup'}'),
                              icon: Icons.payments_outlined,
                              label: 'Tiền lấy hàng (không bắt buộc)',
                              initialValue: _codAmount == null
                                  ? ''
                                  : NumberFormat('#,###', 'vi_VN')
                                      .format(_codAmount)
                                      .replaceAll(',', '.'),
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
                        const AppSectionHeading(
                          number: '03',
                          title: 'Loại hàng',
                          subtitle: 'Chọn loại hàng và thêm dặn dò cho tài xế',
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: c.glass,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border:
                                Border.all(color: c.glassBorder, width: 1.2),
                            boxShadow: isDark ? null : AppShadows.soft,
                          ),
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
                                        setState(() {
                                          _userEdited = true;
                                          _cargoType = cargo.key;
                                          if (!cargo.hasWeight) {
                                            _cargoWeight = null;
                                          }
                                          _fee = null;
                                        });
                                        _estimate();
                                      },
                                    ),
                                  ),
                                  if (cargo.key != cargoTypes.last.key)
                                    const SizedBox(width: AppSpacing.sm),
                                ],
                              ]),
                            ),
                            if (cargoTypes
                                .firstWhere((cargo) => cargo.key == _cargoType)
                                .hasWeight) ...[
                              Divider(height: 1, color: c.divider),
                              _InlineOrderField(
                                key: ValueKey('weight-$_cargoType'),
                                icon: Icons.scale_outlined,
                                label: 'Khối lượng ước tính',
                                initialValue: _cargoWeight?.toString() ?? '',
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
                            ],
                            Divider(height: 1, color: c.divider),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg),
                              child: TextFormField(
                                key: ValueKey(
                                    'note-${widget.reorderFrom != null}'),
                                initialValue: _note,
                                minLines: 1,
                                maxLines: 3,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onChanged: (value) {
                                  _note = value;
                                  _userEdited = true;
                                },
                                style: AppTextStyles.body
                                    .copyWith(color: c.textPrimary),
                                decoration: InputDecoration(
                                  prefixIcon: Padding(
                                      padding: const EdgeInsets.only(
                                          right: AppSpacing.md),
                                      child: Icon(Icons.notes_rounded,
                                          size: AppSize.iconMd,
                                          color: c.primary)),
                                  prefixIconConstraints: const BoxConstraints(),
                                  hintText:
                                      'Ghi chú cho tài xế (không bắt buộc)',
                                  hintStyle: AppTextStyles.body
                                      .copyWith(color: c.textTertiary),
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // ── Ước tính phí ───────────────────────────────────────
                        AppSectionHeading(
                          number: '04',
                          title: 'Chi phí ước tính',
                          subtitle: _loadingFee
                              ? 'Đang tính phí…'
                              : 'Phí được tính theo quãng đường và loại hàng',
                        ),
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: c.glass,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border:
                                Border.all(color: c.glassBorder, width: 1.2),
                            boxShadow: isDark ? null : AppShadows.soft,
                          ),
                          child: Column(children: [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(children: [
                                if (_distanceKm != null) ...[
                                  _FeeRow(
                                    icon: Icons.straighten_rounded,
                                    label: 'Khoảng cách',
                                    value:
                                        '${_distanceKm!.toStringAsFixed(1)} km',
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                                _FeeRow(
                                  icon: Icons.two_wheeler_rounded,
                                  label: 'Phí giao hàng',
                                  value:
                                      _fee == null ? '—' : Fmt.currency(_fee!),
                                ),
                                if (_nightSurcharge > 0) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  _FeeRow(
                                    icon: Icons.nightlight_round,
                                    label: 'Phụ phí đêm',
                                    value: '+${Fmt.currency(_nightSurcharge)}',
                                    color: c.warning,
                                  ),
                                ],
                                if (_voucherCode != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  _FeeRow(
                                    icon: Icons.local_activity_rounded,
                                    label:
                                        'Voucher $_voucherCode${_voucherLabel != null ? ' · $_voucherLabel' : ''}',
                                    value:
                                        '-${Fmt.currency(_voucherDiscount ?? 0)}',
                                    color: c.accent2,
                                  ),
                                ],
                              ]),
                            ),
                            Divider(height: 1, color: c.divider),
                            InkWell(
                              onTap: _fee == null
                                  ? null
                                  : (_voucherCode != null
                                      ? () => setState(_removeVoucher)
                                      : _openVoucherSheet),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                    vertical: AppSpacing.md),
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
                                        style: AppTextStyles.bodyStrong
                                            .copyWith(
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
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.md),
                              child: Row(children: [
                                Text('Tổng cộng',
                                    style: AppTextStyles.bodyStrong
                                        .copyWith(color: c.textPrimary)),
                                const Spacer(),
                                Text(
                                    _fee == null
                                        ? '—'
                                        : Fmt.currency(_finalFee),
                                    style: AppTextStyles.metric
                                        .copyWith(color: c.primary)),
                              ]),
                            ),
                          ]),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md, vertical: 10),
                            decoration: BoxDecoration(
                              color: c.dangerSoft,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Row(children: [
                              Icon(Icons.error_outline_rounded,
                                  color: c.danger, size: 16),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(_error!,
                                    style: AppTextStyles.label
                                        .copyWith(color: c.danger)),
                              ),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: c.glassStrong,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl)),
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
                      Text(_fee == null ? '—' : Fmt.currency(_finalFee),
                          style:
                              AppTextStyles.metric.copyWith(color: c.primary)),
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
                              children: const [
                                Text('Đặt đơn'),
                                SizedBox(width: AppSpacing.sm),
                                Icon(Icons.arrow_forward_rounded,
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
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  final bool isFirst;
  final Color color;
  final IconData icon;
  final String label;
  final String? address;
  final String? placeName;
  final String placeholder;
  final VoidCallback onTap;
  const _RouteStop(
      {required this.isFirst,
      required this.color,
      required this.icon,
      required this.label,
      required this.address,
      required this.placeName,
      required this.placeholder,
      required this.onTap});

  // Điểm mốc nằm ngang hàng với dòng nhãn đầu tiên của ô địa chỉ.
  static const _dotTop = AppSpacing.lg + 1.0;
  static const _dot = 14.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filled = address != null;
    final lineBar = Container(width: 2, color: c.divider);
    final dot = Container(
      width: _dot,
      height: _dot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : c.surface,
        border: Border.all(color: color, width: 3),
      ),
    );
    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: _dot,
            child: Column(children: [
              if (isFirst) ...[
                const SizedBox(height: _dotTop),
                dot,
                Expanded(child: lineBar),
              ] else ...[
                SizedBox(height: _dotTop, child: lineBar),
                dot,
                const Spacer(),
              ],
            ]),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: _AddressRow(
                  label: label,
                  address: address,
                  placeName: placeName,
                  placeholder: placeholder),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Center(
            child: Icon(
                filled ? Icons.edit_outlined : Icons.chevron_right_rounded,
                color: filled ? c.primary : c.textTertiary,
                size: AppSize.iconSm + 2),
          ),
          const SizedBox(width: AppSpacing.lg),
        ]),
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
            style: AppTextStyles.caption
                .copyWith(color: c.textTertiary, letterSpacing: .6)),
        const SizedBox(height: 3),
        if (address != null) ...[
          Text(placeName ?? address!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
          if (placeName != null) ...[
            const SizedBox(height: 2),
            Text(address!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(color: c.textSecondary)),
          ],
        ] else
          Text(placeholder,
              style: AppTextStyles.bodyStrong.copyWith(
                  fontWeight: FontWeight.w600, color: c.textTertiary)),
      ],
    );
  }
}

// ─── Ô nhập nhanh thông tin đơn ──────────────────────────────────────────────

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
            color: c.glassStrong,
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
                Text('Tiền lấy hàng',
                    style: TextStyle(
                        fontSize: AppFontSize.xxl,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
                const SizedBox(height: 6),
                Text('Nhập số tiền tài xế cần thu từ người nhận.',
                    style: TextStyle(
                        fontSize: AppFontSize.md, color: c.textSecondary)),
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
                      fontSize: AppFontSize.xl,
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
                            fontSize: AppFontSize.xl,
                            fontWeight: FontWeight.w700)),
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
            color: c.glassStrong,
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
                        fontSize: AppFontSize.xxl,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
                const SizedBox(height: 6),
                Text('Thêm hướng dẫn về hàng hóa hoặc điểm giao nhận.',
                    style: TextStyle(
                        fontSize: AppFontSize.md, color: c.textSecondary)),
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
                            fontSize: AppFontSize.xl,
                            fontWeight: FontWeight.w700)),
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

class _ContactPhoneField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool warn;
  final ValueChanged<String> onChanged;
  const _ContactPhoneField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.warn,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: AppTextStyles.body
              .copyWith(color: warn ? c.danger : c.textTertiary),
          prefixIcon: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Icon(icon,
                  size: AppSize.iconMd, color: warn ? c.danger : c.primary)),
          prefixIconConstraints: const BoxConstraints(),
          errorText: warn ? 'Vui lòng nhập số điện thoại' : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _InlineOrderField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String initialValue;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffixText;
  final ValueChanged<String> onChanged;
  const _InlineOrderField({
    super.key,
    required this.icon,
    required this.label,
    required this.initialValue,
    required this.keyboardType,
    required this.onChanged,
    this.inputFormatters,
    this.suffixText,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFormField(
          initialValue: initialValue,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
          style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: label,
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
      ]),
    );
  }
}

// ─── Dòng trong thẻ ước tính phí ──────────────────────────────────────────────

class _FeeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _FeeRow({
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
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: iconColor ?? AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: AppFontSize.sm,
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
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                      fontSize: AppFontSize.xl,
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
          Divider(height: 1, color: context.colors.divider),

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
                                  fontSize: AppFontSize.base)),
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
                          Text('Tiền lấy hàng',
                              style: AppTextStyles.body
                                  .copyWith(color: AppColors.textSecondary)),
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
                                  fontSize: AppFontSize.lg,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: AppFontSize.lg),
                                suffixText: ' đ',
                                suffixStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: AppFontSize.base),
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
