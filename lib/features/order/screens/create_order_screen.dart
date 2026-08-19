import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show TextInputFormatter, FilteringTextInputFormatter, TextInputType;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/map_style.dart';
import '../../../core/utils/marker_icon_builder.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/services/address_search_service.dart';
import '../../../core/widgets/address_picker_screen.dart';
import '../../../core/widgets/map_picker_screen.dart';
import '../../address/models/address_entry.dart';
import '../../address/providers/address_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../voucher/widgets/voucher_sheet.dart';
import '../models/cargo_type.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import '../utils/pricing_request.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class CreateOrderScreen extends ConsumerStatefulWidget {
  final bool isOutbound;
  final Map<String, dynamic>? reorderFrom;
  // Pre-fill địa chỉ giao hàng từ sổ địa chỉ đã lưu (vd: chip "Địa chỉ thường
  // dùng" ở trang chủ) — khác reorderFrom ở chỗ vẫn giữ auto-fill pickup từ
  // hồ sơ shop (_prefillFromProfile) thay vì thay thế toàn bộ.
  final AddressEntry? prefillDelivery;
  const CreateOrderScreen({
    super.key,
    this.isOutbound = true,
    this.reorderFrom,
    this.prefillDelivery,
  });

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  gm.GoogleMapController? _mapCtrl;
  String? _mapStyle;
  // Che bản đồ tới khi camera đã ở đúng vị trí (toạ độ shop thật hoặc hết
  // thời gian chờ) — tránh hiện bản đồ ở fallback rồi "giật" sang vị trí
  // đúng. Xem _geocodeShopAddress()/onMapCreated() và timeout trong initState.
  bool _mapReady = false;

  // Addresses
  String? _pickupAddr, _deliveryAddr;
  String? _pickupPlaceName, _deliveryPlaceName;
  double? _pickupLat, _pickupLng, _deliveryLat, _deliveryLng;

  // Cargo
  String _cargoType = 'food';

  // Detail info (filled via bottom sheet)
  String _receiverPhone = '';
  String _receiverName  = '';
  String _senderName    = '';
  String _senderPhone   = '';
  String _note          = '';
  double? _cargoWeight;
  int?   _codAmount;

  // True khi người dùng đã tự tay chọn địa chỉ hoặc lưu chi tiết đơn (xem
  // _pickAddress()/_openDetailSheet()) — KHÔNG bật khi dữ liệu chỉ tới từ
  // _prefillFromProfile()/_prefillFromReorder()/_applyDeliveryPrefill(), vì
  // lúc đó người dùng chưa mất công nhập gì thực sự. Dùng làm điều kiện
  // cảnh báo thoát màn (xem PopScope trong build()).
  bool _userEdited = false;

  // Fee
  int?   _fee;
  int    _nightSurcharge = 0;
  double? _distanceKm;
  bool   _loadingFee = false;
  bool   _submitting  = false;
  bool   _submitAttempted = false;
  String? _error;

  // Voucher
  String? _voucherCode;
  String? _voucherLabel;
  int?    _voucherDiscount;

  // Polyline
  Set<gm.Polyline> _polylines = {};

  gm.BitmapDescriptor? _pickupMarkerIcon;
  gm.BitmapDescriptor? _deliveryMarkerIcon;
  gm.BitmapDescriptor? _driverMarkerIcon;
  List<Map<String, dynamic>> _nearbyDrivers = [];

  late final bool _isOutbound;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _isOutbound = widget.isOutbound;
    _loadMarkers();
    _ensureLocationPermission();
    loadMapStyle().then((s) { if (mounted) setState(() => _mapStyle = s); });
    if (widget.reorderFrom != null) {
      _prefillFromReorder(widget.reorderFrom!);
    } else {
      _prefillFromProfile();
      if (widget.prefillDelivery != null) {
        _applyDeliveryPrefill(widget.prefillDelivery!);
      }
    }
    // Timeout: nếu geocode chậm/thất bại thì vẫn mở khoá bản đồ sau 600ms
    // thay vì chặn người dùng vô thời hạn — khi đó map hiện ở fallback.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && !_mapReady) setState(() => _mapReady = true);
    });
  }

  // Điền sẵn phía giao hàng từ 1 địa chỉ đã lưu — pickup vẫn do
  // _prefillFromProfile() phụ trách (chạy trước lệnh này) nên không cần lặp lại.
  void _applyDeliveryPrefill(AddressEntry entry) {
    _deliveryAddr      = entry.address;
    _deliveryPlaceName = entry.displayName;
    _receiverName      = entry.name;
    _receiverPhone     = entry.phone;
    // Chỉ gán tọa độ theo cặp — địa chỉ sổ lưu có thể chỉ có 1 trong 2 (nhập
    // tay không chọn bản đồ), gán lẻ 1 chiều sẽ khiến _fitCamera()/_markers
    // (vốn chỉ check null 1 trong 2 rồi unwrap "!" cả cặp) bị crash.
    if (entry.lat != null && entry.lng != null) {
      _deliveryLat = entry.lat;
      _deliveryLng = entry.lng;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _estimate();
      if (_deliveryLat != null && _deliveryLng != null) {
        _mapCtrl?.animateCamera(gm.CameraUpdate.newLatLngZoom(
            gm.LatLng(_deliveryLat!, _deliveryLng!), 14));
      }
      if (_pickupLat != null && _pickupLng != null &&
          _deliveryLat != null && _deliveryLng != null) {
        _fitCamera();
      }
    });
  }

  // GoogleMap(myLocationEnabled: true) crash nếu chưa có quyền vị trí — app
  // chưa từng chủ động xin quyền này trước khi vào màn đặt đơn (LocationService
  // chỉ được gọi từ map picker), nên phải tự xin ở đây trước khi build map.
  Future<void> _ensureLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (mounted && granted) setState(() => _hasLocationPermission = true);
    } catch (_) {}
  }

  Future<void> _loadMarkers() async {
    _pickupMarkerIcon = await buildPinMarker(
        color: AppColors.primary, icon: Icons.storefront_rounded);
    _deliveryMarkerIcon = await buildPinMarker(
        color: AppColors.success, icon: Icons.person_rounded);
    _driverMarkerIcon = await buildDriverMarker(color: AppColors.info);
    if (mounted) setState(() {});
  }

  Future<void> _fetchNearbyDrivers() async {
    // Dùng tọa độ pickup nếu có, fallback về delivery (shop) cho Lấy hộ
    final lat = _pickupLat ?? _deliveryLat;
    final lng = _pickupLng ?? _deliveryLng;
    if (lat == null || lng == null) return;
    try {
      final res = await ref.read(apiClientProvider).get(
        '/customer/drivers/nearby',
        params: {'lat': lat, 'lng': lng, 'radius': 5},
      );
      final list = (res.data['data'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (mounted) setState(() => _nearbyDrivers = list);
    } catch (_) {}
  }

  void _prefillFromReorder(Map<String, dynamic> r) {
    _pickupAddr  = r['pickupAddr']   as String?;
    _pickupLat   = r['pickupLat']   as double?;
    _pickupLng   = r['pickupLng']   as double?;
    _deliveryAddr = r['deliveryAddr'] as String?;
    _deliveryLat  = r['deliveryLat']  as double?;
    _deliveryLng  = r['deliveryLng']  as double?;
    _cargoType    = r['cargoType']    as String? ?? 'food';

    _receiverPhone = r['deliveryPhone'] as String? ?? '';
    _receiverName  = r['deliveryName']  as String? ?? '';
    _senderName    = r['pickupName']    as String? ?? '';
    _senderPhone   = r['pickupPhone']   as String? ?? '';
    _note          = r['note']          as String? ?? '';

    // Animate map nếu có tọa độ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pickupLat != null) {
        _mapCtrl?.animateCamera(gm.CameraUpdate.newLatLngZoom(
            gm.LatLng(_pickupLat!, _pickupLng!), 14));
      }
      if (_pickupLat != null && _deliveryLat != null) {
        _fitCamera();
      }
      _estimate();
      _fetchNearbyDrivers();
    });
  }

  void _prefillFromProfile() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (_isOutbound) {
      // Giao đơn: pickup = shop → sender là shop
      _senderName  = user.name;
      _senderPhone = user.phone;
      final addr = user.address;
      if (addr != null && addr.isNotEmpty) {
        _pickupAddr      = addr;
        _pickupPlaceName = user.name.isNotEmpty ? user.name : null;
        _geocodeShopAddress(addr, isPickup: true);
      }
    } else {
      // Lấy hộ: delivery = shop → receiver là shop, sender để trống (người ở điểm lấy)
      _receiverName  = user.name;
      _receiverPhone = user.phone;
      final addr = user.address;
      if (addr != null && addr.isNotEmpty) {
        _deliveryAddr      = addr;
        _deliveryPlaceName = user.name.isNotEmpty ? user.name : null;
        _geocodeShopAddress(addr, isPickup: false);
      }
    }
  }

  Future<void> _geocodeShopAddress(String address, {required bool isPickup}) async {
    try {
      final result = await AddressSearchService.getDetail(
        AddressResult(
          display: address, mainText: address,
          secondaryText: '', placeId: '',
        ),
      );
      if (!mounted || result == null) return;
      // Bỏ qua nếu user đã chọn địa chỉ khác trong lúc geocode đang chạy
      if (isPickup && _pickupAddr != address) return;
      if (!isPickup && _deliveryAddr != address) return;

      if (isPickup) {
        setState(() { _pickupLat = result.lat; _pickupLng = result.lng; });
      } else {
        setState(() { _deliveryLat = result.lat; _deliveryLng = result.lng; });
      }

      if (result.lat != null && result.lng != null) {
        // moveCamera (không animation) cho lần định vị đầu tiên khi màn hình
        // vừa mở — tránh hiệu ứng bay "giật/vèo" từ fallback sang vị trí
        // thật. _mapCtrl có thể vẫn null nếu GoogleMap chưa kịp tạo xong;
        // khi đó onMapCreated sẽ tự định vị + mở khoá bản đồ dựa theo
        // _pickupLat/_deliveryLat vừa set ở trên.
        if (_mapCtrl != null) {
          _mapCtrl!.moveCamera(gm.CameraUpdate.newLatLngZoom(
              gm.LatLng(result.lat!, result.lng!), 15));
          if (!_mapReady) setState(() => _mapReady = true);
        }
        _fetchNearbyDrivers();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
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
        _pickupAddr      = result.address;
        _pickupPlaceName = result.placeName;
        _pickupLat       = result.lat;
        _pickupLng       = result.lng;
        if (result.contactName?.isNotEmpty  == true) _senderName  = result.contactName!;
        if (result.contactPhone?.isNotEmpty == true) _senderPhone = result.contactPhone!;
      } else {
        _deliveryAddr      = result.address;
        _deliveryPlaceName = result.placeName;
        _deliveryLat       = result.lat;
        _deliveryLng       = result.lng;
        if (result.contactName?.isNotEmpty  == true) _receiverName  = result.contactName!;
        if (result.contactPhone?.isNotEmpty == true) _receiverPhone = result.contactPhone!;
      }
      _error = null;
    });
    await _estimate();
    if (isPickup) _fetchNearbyDrivers();
    if (_pickupLat != null && _deliveryLat != null) {
      _fitCamera();
      _fetchRoute();
    }
  }


  void _swapAddresses() {
    setState(() {
      final tA  = _pickupAddr;      _pickupAddr      = _deliveryAddr;      _deliveryAddr      = tA;
      final tPN = _pickupPlaceName; _pickupPlaceName = _deliveryPlaceName; _deliveryPlaceName = tPN;
      final tLa = _pickupLat;       _pickupLat       = _deliveryLat;       _deliveryLat       = tLa;
      final tLo = _pickupLng;       _pickupLng       = _deliveryLng;       _deliveryLng       = tLo;
      final tN  = _senderName;      _senderName      = _receiverName;      _receiverName      = tN;
      final tP  = _senderPhone;     _senderPhone     = _receiverPhone;     _receiverPhone     = tP;
    });
    _estimate();
    _fitCamera();
    _fetchRoute();
  }

  void _fitCamera() {
    if (_pickupLat == null || _deliveryLat == null) return;
    final sw = gm.LatLng(
      _pickupLat! < _deliveryLat! ? _pickupLat! : _deliveryLat!,
      _pickupLng! < _deliveryLng! ? _pickupLng! : _deliveryLng!,
    );
    final ne = gm.LatLng(
      _pickupLat! > _deliveryLat! ? _pickupLat! : _deliveryLat!,
      _pickupLng! > _deliveryLng! ? _pickupLng! : _deliveryLng!,
    );
    _mapCtrl?.animateCamera(
        gm.CameraUpdate.newLatLngBounds(
            gm.LatLngBounds(southwest: sw, northeast: ne), 80));
  }

  // ── Estimate ────────────────────────────────────────────────────────────────

  Future<void> _estimate() async {
    if (_pickupAddr == null || _deliveryAddr == null) return;
    // Lưu lại phí cũ TRƯỚC khi setState() dưới đây ghi đè _fee = null cho
    // trạng thái loading — dùng để so sánh xem phí có thực sự đổi không.
    final oldFee = _fee;
    setState(() { _loadingFee = true; _fee = null; });
    try {
      // weight từ detail sheet nếu đã điền
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
      final res = await ref.read(apiClientProvider)
          .get('/shop/pricing/estimate', params: p);
      final data = unwrap(res) as Map<String, dynamic>;
      if (mounted) {
        final newFee = (data['fee'] as num).toInt();
        // Chỉ gỡ voucher khi ĐANG áp VÀ phí thực sự đổi — tránh gỡ oan mỗi
        // lần gọi lại _estimate() (vd đổi cân nặng nhưng phí không đổi).
        final shouldRemoveVoucher = _voucherCode != null && newFee != oldFee;
        setState(() {
          _fee            = newFee;
          _nightSurcharge = (data['night_surcharge'] as num?)?.toInt() ?? 0;
          _distanceKm     = (data['distance_km'] as num?)?.toDouble();
          if (shouldRemoveVoucher) _removeVoucher();
        });
        if (shouldRemoveVoucher) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Phí đơn đã thay đổi, mã giảm giá đã được gỡ — vui lòng áp lại nếu cần.'),
          ));
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingFee = false);
    }
  }

  // ── Voucher ─────────────────────────────────────────────────────────────────

  int get _finalFee {
    if (_fee == null) return 0;
    return (_fee! - (_voucherDiscount ?? 0)).clamp(0, _fee!);
  }

  Future<void> _openVoucherSheet() async {
    if (_fee == null) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => VoucherSheet(fee: _fee!),
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

  // ── Route ───────────────────────────────────────────────────────────────────

  Future<void> _fetchRoute() async {
    if (_pickupLat == null || _deliveryLat == null) return;
    try {
      final res = await Dio().get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin':      '$_pickupLat,$_pickupLng',
          'destination': '$_deliveryLat,$_deliveryLng',
          'key':         AppConstants.googleMapsApiKey,
        },
      );
      final data = res.data as Map<String, dynamic>;
      if (data['status'] == 'OK') {
        final routes = data['routes'] as List;
        if (routes.isEmpty || !mounted) return;
        final encoded = routes[0]['overview_polyline']['points'] as String;
        setState(() {
          _polylines = {
            gm.Polyline(
              polylineId: const gm.PolylineId('route'),
              points: _decodePolyline(encoded),
              color: AppColors.primary,
              width: 4,
              startCap: gm.Cap.roundCap,
              endCap: gm.Cap.roundCap,
            ),
          };
        });
      }
    } catch (_) {}
  }

  static List<gm.LatLng> _decodePolyline(String encoded) {
    final pts = <gm.LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      pts.add(gm.LatLng(lat / 1e5, lng / 1e5));
    }
    return pts;
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _submitAttempted = true);
    if (_pickupAddr == null || _deliveryAddr == null) {
      setState(() => _error = 'Vui lòng chọn điểm lấy và điểm giao');
      return;
    }
    if (_pickupLat == null || _pickupLng == null || _deliveryLat == null || _deliveryLng == null) {
      setState(() => _error = 'Đang xác định toạ độ, vui lòng đợi vài giây rồi thử lại.');
      return;
    }
    if (_receiverPhone.trim().isEmpty) {
      await _openDetailSheet();
      if (_receiverPhone.trim().isEmpty) {
        setState(() => _error = _isOutbound
            ? 'Vui lòng nhập SĐT người nhận'
            : 'Vui lòng nhập SĐT cửa hàng');
      }
      return;
    }
    // Lấy hộ: bắt buộc SĐT tại điểm lấy
    if (!_isOutbound && _senderPhone.trim().isEmpty) {
      await _openDetailSheet();
      if (_senderPhone.trim().isEmpty) {
        setState(() => _error = 'Vui lòng nhập SĐT liên hệ tại điểm lấy');
      }
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider).post('/shop/orders', data: {
        'is_outbound':       _isOutbound ? 1 : 0,
        'pickup_address':    _pickupAddr,
        'delivery_address':  _deliveryAddr,
        'delivery_phone':    _receiverPhone.trim(),
        if (_receiverName.isNotEmpty)  'delivery_name': _receiverName.trim(),
        if (_senderName.isNotEmpty)    'pickup_name':   _senderName.trim(),
        if (_senderPhone.isNotEmpty)   'pickup_phone':  _senderPhone.trim(),
        if (_note.isNotEmpty)          'order_note':    _note,
        'cargo_type':                  _cargoType,
        if (_note.isNotEmpty)          'cargo_note':    _note,
        if (_cargoWeight != null)      'cargo_weight':  _cargoWeight,
        if (_codAmount != null)        'cod_amount':    _codAmount,
        if (_pickupPlaceName != null)   'pickup_place_name':   _pickupPlaceName,
        if (_deliveryPlaceName != null) 'delivery_place_name': _deliveryPlaceName,
        if (_pickupLat != null)        'pickup_lat':    _pickupLat,
        if (_pickupLng != null)        'pickup_lng':    _pickupLng,
        if (_deliveryLat != null)      'delivery_lat':  _deliveryLat,
        if (_deliveryLng != null)      'delivery_lng':  _deliveryLng,
        if (_voucherCode != null)      'voucher_code':  _voucherCode,
      });
      final order = OrderModel.fromJson(
          unwrap(res) as Map<String, dynamic>);
      ref.read(orderListProvider.notifier).addOrder(order);
      // Gợi ý lưu địa chỉ nếu có tên + SĐT người nhận và chưa có trong sổ
      if (mounted && _isOutbound && _receiverPhone.isNotEmpty && _deliveryAddr != null) {
        final existing = ref.read(addressProvider).valueOrNull ?? [];
        final alreadySaved = existing.any((e) => e.phone == _receiverPhone.trim());
        if (!alreadySaved) {
          final addressNotifier = ref.read(addressProvider.notifier);
          final displayName = _receiverName.isNotEmpty
              ? _receiverName
              : _receiverPhone;
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
                    style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ]),
              content: Text(
                'Lưu "$displayName" vào sổ địa chỉ để dùng lại lần sau.',
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 12),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(
                        color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Huỷ'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    addressNotifier.add(
                      name:    displayName,
                      phone:   _receiverPhone.trim(),
                      address: _deliveryAddr!,
                      lat:     _deliveryLat,
                      lng:     _deliveryLng,
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
      final msg = parseApiError(e, fallback: 'Không thể đặt đơn, vui lòng thử lại');
      if (mounted) setState(() { _error = msg; _submitting = false; });
    }
  }

  // ── Detail sheet ────────────────────────────────────────────────────────────

  Future<void> _openDetailSheet() async {
    final cargo = cargoTypes.firstWhere((c) => c.key == _cargoType);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => _DetailSheet(
        cargo:        cargo,
        isOutbound:   _isOutbound,
        receiverPhone: _receiverPhone,
        receiverName:  _receiverName,
        senderName:    _senderName,
        senderPhone:   _senderPhone,
        note:          _note,
        cargoWeight:   _cargoWeight,
        codAmount:     _codAmount,
        onSave: (result) {
          setState(() {
            _userEdited    = true;
            _receiverPhone = result.receiverPhone;
            _receiverName  = result.receiverName;
            _senderName    = result.senderName;
            _senderPhone   = result.senderPhone;
            _note          = result.note;
            _cargoWeight   = result.cargoWeight;
            _codAmount     = result.codAmount;
            _error         = null;
          });
          _estimate();
        },
      ),
    );
  }

  bool get _hasDetail =>
      _receiverPhone.isNotEmpty || _receiverName.isNotEmpty || _note.isNotEmpty;

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
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

  bool get _needsPhone => _receiverPhone.trim().isEmpty;

  bool get _showPhoneWarning => _submitAttempted && _needsPhone;

  Set<gm.Marker> get _markers {
    final s = <gm.Marker>{};
    if (_pickupLat != null) {
      s.add(gm.Marker(
        markerId: gm.MarkerId('pickup:$_pickupLat:$_pickupLng'),
        position: gm.LatLng(_pickupLat!, _pickupLng!),
        icon: _pickupMarkerIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(
                gm.BitmapDescriptor.hueOrange),
      ));
    }
    if (_deliveryLat != null) {
      s.add(gm.Marker(
        markerId: gm.MarkerId('delivery:$_deliveryLat:$_deliveryLng'),
        position: gm.LatLng(_deliveryLat!, _deliveryLng!),
        icon: _deliveryMarkerIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(
                gm.BitmapDescriptor.hueRed),
      ));
    }
    // Tài xế nearby
    for (final d in _nearbyDrivers) {
      s.add(gm.Marker(
        markerId: gm.MarkerId('driver_${d['id']}'),
        position: gm.LatLng(
            (d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()),
        icon: _driverMarkerIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(
                gm.BitmapDescriptor.hueAzure),
        rotation: (d['bearing'] as num?)?.toDouble() ?? 0,
        anchor: const Offset(0.5, 0.5),
        flat: true,
      ));
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    const fallbackLat = 10.0452;
    const fallbackLng = 105.7469;

    return PopScope(
      canPop: !_userEdited,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [

          // ── Full-screen map ─────────────────────────────────────────────
          gm.GoogleMap(
            style: _mapStyle,
            onMapCreated: (c) {
              _mapCtrl = c;
              // moveCamera (không animation) cho lần định vị đầu tiên — toạ
              // độ đã biết trước khi map tạo xong (reorder/địa chỉ đã lưu/
              // geocode xong sớm), nhảy thẳng tới thay vì bay từ fallback.
              if (_pickupLat != null && _pickupLng != null) {
                c.moveCamera(gm.CameraUpdate.newLatLngZoom(
                    gm.LatLng(_pickupLat!, _pickupLng!), 15));
                if (!_mapReady) setState(() => _mapReady = true);
              } else if (_deliveryLat != null && _deliveryLng != null) {
                c.moveCamera(gm.CameraUpdate.newLatLngZoom(
                    gm.LatLng(_deliveryLat!, _deliveryLng!), 15));
                if (!_mapReady) setState(() => _mapReady = true);
              }
            },
            initialCameraPosition: const gm.CameraPosition(
              target: gm.LatLng(fallbackLat, fallbackLng),
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: EdgeInsets.only(
              top: 130 + MediaQuery.of(context).padding.top,
              bottom: 300 + bottomPad,
            ),
          ),

          // ── Lớp phủ che bản đồ tới khi camera vào đúng vị trí ────────────
          if (!_mapReady)
            Positioned.fill(
              child: Container(
                color: context.colors.surfaceAlt,
                child: Center(
                  child: SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                ),
              ),
            ),

          // ── Floating address bar ────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: context.colors.cardShadow,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.textPrimary,
                      onPressed: _handleBackPress,
                    ),

                    // Address rows
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pickup
                          Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _pickAddress(isPickup: true),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(0, 16, 5, 8),
                                  child: Row(children: [
                                    const Icon(Icons.storefront_outlined,
                                        size: 18, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _pickupAddr != null
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _pickupPlaceName ?? _pickupAddr!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                if (_pickupPlaceName != null) ...[
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    _pickupAddr!,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            )
                                          : Text(
                                              _isOutbound ? 'Chọn cửa hàng / điểm lấy' : 'Chọn địa điểm lấy hàng',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                          ]),

                          const Divider(height: 1, color: Color(0xFFF0F0F0)),

                          // Delivery
                          Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _pickAddress(isPickup: false),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(0, 8, 5, 16),
                                  child: Row(children: [
                                    const Icon(Icons.location_on_rounded,
                                        size: 18, color: AppColors.danger),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _deliveryAddr != null
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _deliveryPlaceName ?? _deliveryAddr!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                if (_deliveryPlaceName != null) ...[
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    _deliveryAddr!,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            )
                                          : Text(
                                              _isOutbound ? 'Chọn địa chỉ giao hàng' : 'Chọn địa chỉ cửa hàng / giao về',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),

                    // Swap
                    if (_pickupAddr != null && _deliveryAddr != null) ...[
                      Container(width: 1, height: 36,
                          color: const Color(0xFFF0F0F0)),
                      GestureDetector(
                        onTap: _swapAddresses,
                        child: Container(
                          width: 44, height: 44,
                          color: Colors.transparent,
                          child: Center(
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.swap_vert_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),
                    ] else
                      const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),

          // ── Chip số tài xế gần đây ─────────────────────────────────────
          // Chỉ hiện khi đã có ít nhất 1 điểm (lấy/giao) có toạ độ — tức đã
          // từng gọi _fetchNearbyDrivers() ít nhất 1 lần. Đặt cao hơn bảng
          // điều khiển dưới cùng (bottom panel hiện ~350-400px tuỳ nội dung).
          if ((_pickupLat != null && _pickupLng != null) ||
              (_deliveryLat != null && _deliveryLng != null))
            Positioned(
              left: 0, right: 0,
              bottom: 320 + bottomPad,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md, vertical: AppSpace.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: context.colors.cardShadow,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: _nearbyDrivers.isNotEmpty
                            ? AppColors.success
                            : AppColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Text(
                      _nearbyDrivers.isNotEmpty
                          ? '${_nearbyDrivers.length} tài xế gần đây'
                          : 'Chưa có tài xế trực tuyến gần đây',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _nearbyDrivers.isNotEmpty
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ]),
                ),
              ),
            ),

          // ── My location button ──────────────────────────────────────────
          Positioned(
            right: 12,
            bottom: 290 + bottomPad,
            child: GestureDetector(
              onTap: () {
                final lat = _deliveryLat ?? _pickupLat ?? fallbackLat;
                final lng = _deliveryLng ?? _pickupLng ?? fallbackLng;
                _mapCtrl?.animateCamera(
                    gm.CameraUpdate.newLatLngZoom(gm.LatLng(lat, lng), 15));
              },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: context.colors.cardShadow,
                ),
                child: const Icon(Icons.my_location_rounded,
                    color: AppColors.primary, size: 20),
              ),
            ),
          ),

          // ── Bottom panel ────────────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Loại đơn + khoảng cách + giá ───────────────────────
                  Row(children: [
                    Icon(
                      _isOutbound ? Icons.arrow_outward_rounded : Icons.move_to_inbox_rounded,
                      color: _isOutbound ? AppColors.primary : AppColors.info,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isOutbound ? 'Giao đơn' : 'Lấy hộ',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                          if (_distanceKm != null)
                            Text('${_distanceKm!.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    // Giá
                    if (_loadingFee)
                      const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                    else
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (_voucherDiscount != null && _voucherDiscount! > 0 && _fee != null)
                          Text(
                            Fmt.currency(_fee!),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                decoration: TextDecoration.lineThrough),
                          ),
                        Text(
                          _fee == null ? '—' : Fmt.currency(_finalFee),
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800,
                              color: _fee != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary),
                        ),
                        if (_nightSurcharge > 0)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.nightlight_round,
                                size: 10, color: AppColors.warning),
                            const SizedBox(width: 3),
                            Text('+${Fmt.currency(_nightSurcharge)} đêm',
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.warning)),
                          ]),
                      ]),
                  ]),

                  const SizedBox(height: 12),

                  // ── Loại hàng ────────────────────────────────────────────
                  Row(children: [
                    for (final c in cargoTypes) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() { _cargoType = c.key; _fee = null; });
                            _estimate();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                vertical: 9, horizontal: 4),
                            decoration: cargoChipDecoration(
                                _cargoType == c.key, c.color),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(c.icon,
                                    size: 16,
                                    color: _cargoType == c.key
                                        ? c.color
                                        : AppColors.textSecondary),
                                const SizedBox(width: 5),
                                Text(c.label,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: _cargoType == c.key
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _cargoType == c.key
                                            ? c.color
                                            : AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (c.key != cargoTypes.last.key) const SizedBox(width: 6),
                    ],
                  ]),

                  const SizedBox(height: AppSpace.sm),

                  // ── Thông tin người nhận ──────────────────────────────────
                  GestureDetector(
                    onTap: _openDetailSheet,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.md, vertical: AppSpace.sm + 2),
                      decoration: BoxDecoration(
                        color: _showPhoneWarning
                            ? AppColors.danger.withValues(alpha: 0.08)
                            : _hasDetail
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: _showPhoneWarning
                            ? Border.all(
                                color: AppColors.danger.withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Row(children: [
                        Icon(
                          _showPhoneWarning
                              ? Icons.error_outline_rounded
                              : Icons.contact_phone_outlined,
                          size: 18,
                          color: _showPhoneWarning
                              ? AppColors.danger
                              : _hasDetail
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: _showPhoneWarning
                              // Ưu tiên cao nhất: dù đã có tên/note, thiếu SĐT
                              // vẫn luôn hiện cảnh báo thay vì trạng thái "đã điền".
                              ? const Text('Thiếu số điện thoại người nhận',
                                  style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: AppColors.danger))
                              : _hasDetail
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          [
                                            if (_receiverName.isNotEmpty) _receiverName,
                                            _receiverPhone,
                                          ].join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary),
                                        ),
                                        if (_note.isNotEmpty)
                                          Text(_note,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary)),
                                        if (_codAmount != null && _codAmount! > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: AppSpace.xs),
                                            child: Text(
                                                'COD: ${Fmt.currency(_codAmount!)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.primary)),
                                          ),
                                      ],
                                    )
                                  : Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Text('Thêm thông tin người nhận',
                                          style: TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary)),
                                      const SizedBox(width: 3),
                                      const Text('*',
                                          style: TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.w700,
                                              color: AppColors.danger)),
                                    ]),
                        ),
                        Icon(
                          _showPhoneWarning
                              ? Icons.chevron_right_rounded
                              : _hasDetail
                                  ? Icons.edit_rounded
                                  : Icons.chevron_right_rounded,
                          size: 18,
                          color: _showPhoneWarning
                              ? AppColors.danger
                              : _hasDetail
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF5F5F5)),
                  const SizedBox(height: 12),

                  // ── Voucher ───────────────────────────────────────────
                  if (_voucherCode != null)
                    GestureDetector(
                      onTap: _fee == null ? null : _openVoucherSheet,
                      child: Container(
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
                    GestureDetector(
                      onTap: _fee == null ? null : _openVoucherSheet,
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

                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 12)),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 12),

                  // ── Book button ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.5),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isOutbound ? 'Đặt giao đơn ngay' : 'Đặt lấy hộ ngay',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ─── Detail Result ────────────────────────────────────────────────────────────

class _DetailResult {
  final String  receiverPhone, receiverName, senderName, senderPhone;
  final String  note;
  final double? cargoWeight;
  final int?    codAmount;

  const _DetailResult({
    required this.receiverPhone, required this.receiverName,
    required this.senderName,   required this.senderPhone,
    required this.note,
    this.cargoWeight, this.codAmount,
  });
}

// ─── Detail Sheet ─────────────────────────────────────────────────────────────

class _DetailSheet extends StatefulWidget {
  final CargoType cargo;
  final bool     isOutbound;
  final String   receiverPhone, receiverName, senderName, senderPhone;
  final String   note;
  final double?  cargoWeight;
  final int?     codAmount;
  final void Function(_DetailResult) onSave;

  const _DetailSheet({
    required this.cargo,
    required this.isOutbound,
    required this.receiverPhone, required this.receiverName,
    required this.senderName,   required this.senderPhone,
    required this.note,
    this.cargoWeight, this.codAmount,
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
    _receiverNameCtrl  = TextEditingController(text: widget.receiverName);
    _senderNameCtrl    = TextEditingController(text: widget.senderName);
    _senderPhoneCtrl   = TextEditingController(text: widget.senderPhone);
    _noteCtrl          = TextEditingController(text: widget.note);
    _weightCtrl        = TextEditingController(
        text: widget.cargoWeight?.toString() ?? '');
    _codCtrl           = TextEditingController(
        text: widget.codAmount != null
            ? NumberFormat('#,###', 'vi_VN').format(widget.codAmount).replaceAll(',', '.')
            : '');
  }

  @override
  void dispose() {
    for (final c in [
      _receiverPhoneCtrl, _receiverNameCtrl, _senderNameCtrl, _senderPhoneCtrl,
      _noteCtrl, _weightCtrl, _codCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  void _save() {
    widget.onSave(_DetailResult(
      receiverPhone: _receiverPhoneCtrl.text.trim(),
      receiverName:  _receiverNameCtrl.text.trim(),
      senderName:    _senderNameCtrl.text.trim(),
      senderPhone:   _senderPhoneCtrl.text.trim(),
      note:          _noteCtrl.text.trim(),
      cargoWeight: _weightCtrl.text.trim().isNotEmpty
          ? double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.'))
          : null,
      codAmount: _codCtrl.text.trim().isNotEmpty
          ? int.tryParse(_codCtrl.text.trim().replaceAll(',', '').replaceAll('.', ''))
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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
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
                    title: widget.isOutbound ? 'Người nhận' : 'Cửa hàng nhận về',
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
                    title: widget.isOutbound ? 'Cửa hàng' : 'Người giao tại điểm lấy',
                    children: [
                      Row(children: [
                        Expanded(
                          child: AppField(
                            controller: _senderNameCtrl,
                            hint: widget.isOutbound ? 'Tên cửa hàng' : 'Tên người giao',
                            textInputAction: TextInputAction.next,
                            prefixIcon: const Icon(Icons.badge_outlined,
                                size: 18, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppField(
                            controller: _senderPhoneCtrl,
                            hint: widget.isOutbound ? 'SĐT lấy hàng' : 'SĐT liên hệ *',
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
                                  fontSize: 13, fontWeight: FontWeight.w500,
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
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 15),
                                suffixText: ' đ',
                                suffixStyle: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 13),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
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

