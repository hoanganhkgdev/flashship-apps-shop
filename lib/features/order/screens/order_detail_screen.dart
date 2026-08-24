import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import '../../../core/api/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/map_style.dart';
import '../../../core/utils/marker_icon_builder.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../data/order_repository.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

part '../widgets/detail/order_detail_body.dart';
part '../widgets/detail/order_status_card.dart';
part '../widgets/detail/order_driver_section.dart';
part '../widgets/detail/order_stops_card.dart';
part '../widgets/detail/order_route_card.dart';
part '../widgets/detail/order_info_sections.dart';
part '../widgets/detail/order_rating_sheet.dart';
part '../widgets/detail/order_detail_shared.dart';

const _activeStatuses = {'pending', 'assigned', 'processing', 'on_the_way'};

// ─── Screen ───────────────────────────────────────────────────────────────────

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderCode;
  const OrderDetailScreen({super.key, required this.orderCode});

  @override
  ConsumerState<OrderDetailScreen> createState() => _State();
}

class _State extends ConsumerState<OrderDetailScreen>
    with WidgetsBindingObserver {
  OrderModel? _order;
  bool _loading = true;
  bool _cancelling = false;
  String? _error;
  bool _ratingDone = false;
  bool _hasShownRatingPrompt = false;

  StreamSubscription? _fcmSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _locationSub;
  double? _realtimeLat;
  double? _realtimeLng;
  bool _rtdbInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchOrder();
    _listenFcm();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final status = _order?.status;
      if (status != null && _activeStatuses.contains(status)) {
        _fetchSilent();
      }
    }
  }

  // ── RTDB ─────────────────────────────────────────────────────────────────

  void _startRTDB() {
    _rtdbInitialized = false;
    _statusSub?.cancel();

    // Backend ghi status vào path: orders/{orderCode}
    // (giống customer app — RTDBService::updateOrderStatus)
    _statusSub = FirebaseDatabase.instance
        .ref('orders/${widget.orderCode}')
        .onValue
        .listen((event) {
      if (!mounted) return;
      try {
        final data = event.snapshot.value;
        if (data == null) {
          if (_rtdbInitialized) _fetchSilent();
          _rtdbInitialized = true;
          return;
        }
        _rtdbInitialized = true;
        final map = Map<String, dynamic>.from(data as Map);
        final newStatus = map['status'] as String?;
        if (newStatus == null || _order?.status == newStatus) return;

        final prevDriverId = _order?.driver?.id;
        setState(() {
          _order = _order?.copyWith(status: newStatus);
        });

        if (!_activeStatuses.contains(newStatus)) {
          _stopRTDB();
        } else if (newStatus == 'assigned' && prevDriverId == null) {
          // Driver vừa nhận đơn → fetch để lấy thông tin tài xế
          _fetchSilent();
        }
      } catch (_) {}
    });

    // Driver location — lấy từ tracking info
    final tracking = _order?.tracking;
    if (_order?.driver?.id != null && tracking != null) {
      _startLocationListener(_order!.driver!.id, tracking.firebaseDbUrl);
    }
  }

  void _startLocationListener(int driverId, String dbUrl) {
    _locationSub?.cancel();
    final db = FirebaseDatabase.instanceFor(
        app: FirebaseDatabase.instance.app, databaseURL: dbUrl);
    _locationSub = db.ref('locations/driver_$driverId').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null || !mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      final lat = (map['lat'] as num?)?.toDouble();
      final lng = (map['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        setState(() {
          _realtimeLat = lat;
          _realtimeLng = lng;
        });
      }
    });
  }

  void _stopRTDB() {
    _statusSub?.cancel();
    _locationSub?.cancel();
  }

  void _listenFcm() {
    _fcmSub = NotificationService.orderStatusStream.listen((code) {
      if (!mounted || code != widget.orderCode) return;
      _fetchSilent();
    });
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<void> _fetchOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order =
          await ref.read(orderRepositoryProvider).findByCode(widget.orderCode);
      setState(() {
        _order = order;
        _loading = false;
      });
      if (_activeStatuses.contains(order.status)) _startRTDB();
      if (order.canRate && !_ratingDone && !_hasShownRatingPrompt) {
        Future.delayed(const Duration(milliseconds: 600), _showRatingPrompt);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchSilent() async {
    try {
      final order =
          await ref.read(orderRepositoryProvider).findByCode(widget.orderCode);
      if (!mounted) return;

      final prevDriverId = _order?.driver?.id;
      setState(() {
        _order = order;
      });
      ref.read(orderListProvider.notifier).updateOrder(order);

      if (!_activeStatuses.contains(order.status)) {
        _stopRTDB();
      } else if (order.driver?.id != null &&
          order.driver?.id != prevDriverId &&
          order.tracking != null) {
        _startLocationListener(order.driver!.id, order.tracking!.firebaseDbUrl);
      }
      if (order.canRate && !_ratingDone && !_hasShownRatingPrompt) {
        Future.delayed(const Duration(milliseconds: 600), _showRatingPrompt);
      }
    } catch (_) {}
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> _cancelOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Huỷ đơn hàng?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text('Bạn có chắc muốn huỷ đơn này không?',
            style: TextStyle(fontSize: 14, color: ctx.colors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.danger),
            child: const Text('Huỷ đơn',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(orderRepositoryProvider).cancel(widget.orderCode);
      ref.read(orderListProvider.notifier).fetch(refresh: true);
      await _fetchOrder();
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context,
            parseApiError(e, fallback: 'Không thể huỷ đơn. Thử lại sau.'));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  // ── Rating ────────────────────────────────────────────────────────────────

  void _showRatingPrompt() {
    if (_order == null ||
        !_order!.canRate ||
        _ratingDone ||
        _hasShownRatingPrompt) {
      return;
    }
    _hasShownRatingPrompt = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final c = ctx.colors;
        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: c.warningSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.star_rounded, color: c.warning, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Đánh giá tài xế',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Đơn hàng đã hoàn thành!\nĐánh giá giúp ${_order!.driver?.name ?? 'tài xế'} cải thiện chất lượng dịch vụ.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: c.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.warning,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showRating();
                },
                child: const Text('Đánh giá ngay',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Để sau', style: TextStyle(color: c.textSecondary)),
              ),
            ]),
          ),
        );
      },
    );
  }

  void _showRating() {
    if (_order == null || !_order!.canRate || _ratingDone) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingSheet(
        orderCode: widget.orderCode,
        driverName: _order!.driver?.name ?? '',
        onDone: () {
          Navigator.pop(context);
          setState(() {
            _ratingDone = true;
          });
          _fetchSilent();
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fcmSub?.cancel();
    _statusSub?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  void _copyInfo() {
    final order = _order;
    if (order == null) return;
    final lines = [
      'Đơn #${order.code}',
      'Trạng thái: ${Fmt.orderStatus(order.status)}',
      if (order.receiverName?.isNotEmpty == true)
        'Người nhận: ${order.receiverName}',
      'SĐT: ${order.deliveryPhone}',
      'Địa chỉ: ${order.deliveryAddress}',
      'Phí ship: ${Fmt.currency(order.shippingFee)}',
      if (order.driver != null)
        'Tài xế: ${order.driver!.name} – ${order.driver!.phone}',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã copy thông tin đơn'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: c.cardShadow,
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 17, color: c.textPrimary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onLongPress: _order == null ? null : _copyInfo,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          widget.orderCode.startsWith('#')
                              ? widget.orderCode
                              : '#${widget.orderCode}',
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary)),
                      if (_order != null)
                        Text('Đặt lúc ${Fmt.dateTime(_order!.createdAt)}',
                            style: TextStyle(
                                fontSize: 11.5, color: c.textTertiary)),
                    ],
                  ),
                ),
              ),
              if (_order != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color:
                        Fmt.statusColor(_order!.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(Fmt.orderStatus(_order!.status),
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Fmt.statusColor(_order!.status))),
                ),
            ]),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.primary))
                : _error != null
                    ? _ErrorView(onRetry: _fetchOrder)
                    : _order == null
                        ? const Center(child: Text('Không tìm thấy đơn hàng'))
                        : _Body(
                            order: _order!,
                            realtimeLat: _realtimeLat,
                            realtimeLng: _realtimeLng,
                            cancelling: _cancelling,
                            ratingDone: _ratingDone,
                            onRefresh: _fetchSilent,
                            onCancel: _cancelOrder,
                            onRate: _showRating,
                          ),
          ),
        ]),
      ),
    );
  }
}
