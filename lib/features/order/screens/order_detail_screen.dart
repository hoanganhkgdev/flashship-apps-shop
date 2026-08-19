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
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/map_style.dart';
import '../../../core/utils/marker_icon_builder.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';

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
  bool   _loading    = true;
  bool   _cancelling = false;
  String? _error;
  bool   _ratingDone = false;
  bool   _hasShownRatingPrompt = false;

  StreamSubscription? _fcmSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _locationSub;
  double? _realtimeLat;
  double? _realtimeLng;
  bool   _rtdbInitialized = false;

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
        final map       = Map<String, dynamic>.from(data as Map);
        final newStatus = map['status'] as String?;
        if (newStatus == null || _order?.status == newStatus) return;

        final prevDriverId = _order?.driver?.id;
        setState(() { _order = _order?.copyWith(status: newStatus); });

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
    final db  = FirebaseDatabase.instanceFor(
        app: FirebaseDatabase.instance.app, databaseURL: dbUrl);
    _locationSub = db
        .ref('locations/driver_$driverId')
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      if (data == null || !mounted) return;
      final map = Map<String, dynamic>.from(data as Map);
      final lat = (map['lat'] as num?)?.toDouble();
      final lng = (map['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        setState(() { _realtimeLat = lat; _realtimeLng = lng; });
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
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(apiClientProvider)
          .get('/shop/orders/${widget.orderCode}');
      final order = OrderModel.fromJson(
          unwrap(res) as Map<String, dynamic>);
      setState(() { _order = order; _loading = false; });
      if (_activeStatuses.contains(order.status)) _startRTDB();
      if (order.canRate && !_ratingDone && !_hasShownRatingPrompt) {
        Future.delayed(const Duration(milliseconds: 600), _showRatingPrompt);
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _fetchSilent() async {
    try {
      final res = await ref.read(apiClientProvider)
          .get('/shop/orders/${widget.orderCode}');
      final order = OrderModel.fromJson(
          unwrap(res) as Map<String, dynamic>);
      if (!mounted) return;

      final prevDriverId = _order?.driver?.id;
      setState(() { _order = order; });
      ref.read(orderListProvider.notifier).updateOrder(order);

      if (!_activeStatuses.contains(order.status)) {
        _stopRTDB();
      } else if (order.driver?.id != null &&
          order.driver?.id != prevDriverId &&
          order.tracking != null) {
        _startLocationListener(
            order.driver!.id, order.tracking!.firebaseDbUrl);
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
          TextButton(onPressed: () => Navigator.pop(ctx, false),
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
      await ref.read(apiClientProvider)
          .post('/shop/orders/${widget.orderCode}/cancel');
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
    if (_order == null || !_order!.canRate ||
        _ratingDone || _hasShownRatingPrompt) { return; }
    _hasShownRatingPrompt = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final c = ctx.colors;
        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64, height: 64,
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
                style: TextStyle(fontSize: 13,
                    color: c.textSecondary, height: 1.5),
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
                onPressed: () { Navigator.pop(ctx); _showRating(); },
                child: const Text('Đánh giá ngay',
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Để sau',
                    style: TextStyle(color: c.textSecondary)),
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
          setState(() { _ratingDone = true; });
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
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Đơn #${widget.orderCode}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          if (_order != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 20),
              tooltip: 'Copy thông tin đơn',
              onPressed: _copyInfo,
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: context.colors.primary))
          : _error != null
              ? _ErrorView(onRetry: _fetchOrder)
              : _order == null
                  ? const Center(child: Text('Không tìm thấy đơn hàng'))
                  : _Body(
                      order:       _order!,
                      realtimeLat: _realtimeLat,
                      realtimeLng: _realtimeLng,
                      cancelling:  _cancelling,
                      ratingDone:  _ratingDone,
                      onRefresh:   _fetchSilent,
                      onCancel:    _cancelOrder,
                      onRate:      _showRating,
                    ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final OrderModel order;
  final double?    realtimeLat, realtimeLng;
  final bool       cancelling, ratingDone;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCancel;
  final VoidCallback onRate;

  const _Body({
    required this.order,
    this.realtimeLat, this.realtimeLng,
    required this.cancelling,
    required this.ratingDone,
    required this.onRefresh,
    required this.onCancel,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final c         = context.colors;
    final driverLat = realtimeLat ?? order.driver?.latitude;

    return RefreshIndicator(
      color: c.primary,
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 12),

          // ── Status ───────────────────────────────────────────────────
          _StatusCard(order: order),
          const SizedBox(height: 12),

          // ── Driver ───────────────────────────────────────────────────
          if (order.driver != null) ...[
            _DriverCard(order: order),
            const SizedBox(height: 12),
          ],

          // ── Map (driver location) ─────────────────────────────────────
          if (driverLat != null && order.isActive) ...[
            _DriverMapCard(
              order: order,
              realtimeLat: realtimeLat,
              realtimeLng: realtimeLng,
            ),
            const SizedBox(height: 12),
          ],

          // ── Route ─────────────────────────────────────────────────────
          // Batch: stops list / Single: route card
          if (order.isBatch && order.stops.isNotEmpty) ...[
            _StopsCard(order: order, onStopDelivered: onRefresh),
          ] else
            _RouteCard(order: order),
          const SizedBox(height: 12),

          // ── Order info ─────────────────────────────────────────────────
          _OrderInfoCard(order: order),

          // ── Note ───────────────────────────────────────────────────────
          if (order.orderNote?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _NoteCard(note: order.orderNote!),
          ],

          // ── Cancel button ──────────────────────────────────────────────
          if (order.canCancel) ...[
            const SizedBox(height: 12),
            _FlatCard(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: cancelling ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.danger,
                    side: BorderSide(color: c.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: cancelling
                      ? SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2,
                              color: c.danger))
                      : const Text('Huỷ đơn hàng',
                          style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],

          // ── Rate button ────────────────────────────────────────────────
          if (order.canRate && !ratingDone) ...[
            const SizedBox(height: 12),
            _FlatCard(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onRate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.warning,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Đánh giá tài xế',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],

          // Nút đánh giá bị ẩn do quá 24h (canRate == false) nhưng chưa từng
          // đánh giá — báo lý do thay vì im lặng không hiện gì, tránh shop
          // tưởng app thiếu tính năng.
          if (!order.canRate &&
              order.isCompleted &&
              order.driverRating == null &&
              order.completedAt != null &&
              DateTime.now().difference(order.completedAt!).inHours > 24) ...[
            const SizedBox(height: 12),
            Text('Đã quá thời hạn đánh giá (24 giờ sau khi hoàn thành)',
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ],

          if (order.driverRating != null) ...[
            const SizedBox(height: 12),
            _RatingDisplay(rating: order.driverRating!),
          ],

          // ── Đặt lại ──────────────────────────────────────────────────
          if (order.isCompleted || order.isCancelled) ...[
            const SizedBox(height: 12),
            _FlatCard(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => order.isBatch
                      ? context.push('/create-batch',
                          extra: _reorderBatchExtra(order))
                      : context.push('/create-order',
                          extra: _reorderExtra(order)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primary,
                    side: BorderSide(color: c.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Đặt lại đơn tương tự',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Tạo extra data để pre-fill CreateOrderScreen từ đơn cũ
  Map<String, dynamic> _reorderExtra(OrderModel o) {
    final isOutbound = o.shopServiceType != 'shop_pickup';
    return {
      'isOutbound':      isOutbound,
      'pickupAddr':      o.pickupAddress,
      'pickupLat':       o.pickupLat,
      'pickupLng':       o.pickupLng,
      'pickupPhone':     o.pickupPhone,
      'pickupName':      o.senderName,
      'deliveryAddr':    o.deliveryAddress,
      'deliveryLat':     o.deliveryLat,
      'deliveryLng':     o.deliveryLng,
      'deliveryPhone':   o.deliveryPhone,
      'deliveryName':    o.receiverName,
      'cargoType':       o.cargoType,
      'note':            o.orderNote,
    };
  }

  /// Tạo extra data để pre-fill CreateBatchOrderScreen từ 1 đơn gộp cũ — SĐT
  /// lấy hàng không đưa vào đây, CreateBatchOrderScreen tự điền lại từ hồ sơ
  /// shop giống luồng tạo đơn mới (batch luôn lấy tại chính shop).
  Map<String, dynamic> _reorderBatchExtra(OrderModel o) {
    return {
      'pickupAddr': o.pickupAddress,
      'pickupLat':  o.pickupLat,
      'pickupLng':  o.pickupLng,
      'cargoType':  o.cargoType,
      'stops': o.stops.map((s) => {
        'address':   s['address'] as String? ?? '',
        'lat':       (s['lat'] as num?)?.toDouble(),
        'lng':       (s['lng'] as num?)?.toDouble(),
        'phone':     s['phone'] as String? ?? '',
        'name':      s['name'] as String? ?? '',
        'codAmount': (s['cod_amount'] as num?)?.toInt(),
        'note':      s['note'] as String? ?? '',
      }).toList(),
    };
  }
}

// ─── Status Card ─────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final OrderModel order;
  const _StatusCard({required this.order});

  static (Color, IconData, String) _meta(String status, Palette c) {
    switch (status) {
      case 'pending':    return (c.warning,       Icons.access_time_rounded,   'Đang tìm tài xế phù hợp...');
      case 'assigned':   return (c.primary,       Icons.person_pin_rounded,    'Tài xế đang trên đường đến');
      case 'processing': return (c.primary,       Icons.inventory_2_outlined,  'Tài xế đang lấy hàng');
      case 'completed':  return (c.success,       Icons.check_circle_rounded,  'Giao hàng thành công!');
      case 'cancelled':  return (c.textSecondary, Icons.cancel_outlined,       'Đơn hàng đã bị huỷ');
      default:           return (c.textSecondary, Icons.info_outline_rounded,  status);
    }
  }

  static const _steps = [
    ('pending',    'Tìm tài xế', Icons.schedule_rounded),
    ('assigned',   'Đã nhận',    Icons.person_pin_rounded),
    ('processing', 'Lấy hàng',   Icons.inventory_2_outlined),
    ('completed',  'Hoàn thành', Icons.check_circle_rounded),
  ];

  static const _statusOrder = [
    'pending', 'assigned', 'processing', 'completed'
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, icon, subtitle) = _meta(order.status, c);
    final currentIdx  = _statusOrder.indexOf(order.status);
    final isCancelled = order.status == 'cancelled';

    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Current status
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: context.isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Fmt.orderStatus(order.status),
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(fontSize: 12,
                      color: color.withValues(alpha: 0.85))),
              if (order.status == 'pending') ...[
                const SizedBox(height: 8),
                _PendingDots(color: color),
              ],
            ],
          )),
        ]),

        // Horizontal stepper
        if (!isCancelled) ...[
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isEven) {
                final (key, label, stepIcon) = _steps[i ~/ 2];
                final stepIdx = _statusOrder.indexOf(key);
                final isDone  = currentIdx >= stepIdx && currentIdx != -1;
                return SizedBox(
                  width: 60,
                  child: Column(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: isDone ? color : c.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone ? color : c.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(stepIcon, size: 13,
                          color: isDone ? Colors.white : c.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isDone
                              ? FontWeight.w700 : FontWeight.w400,
                          color: isDone
                              ? c.textPrimary
                              : c.textSecondary,
                        )),
                  ]),
                );
              } else {
                final leftStepIdx = (i - 1) ~/ 2 + 1;
                final lineDone = currentIdx >= leftStepIdx && currentIdx != -1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(height: 2,
                        color: lineDone
                            ? color.withValues(alpha: 0.4)
                            : c.divider),
                  ),
                );
              }
            }),
          ),
        ],

        // Cancel reason
        if (isCancelled && order.cancelReason != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.dangerSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: c.danger.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: c.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(order.cancelReason!,
                  style: TextStyle(
                      fontSize: 12, color: c.danger))),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─── Pending animated dots ────────────────────────────────────────────────────

class _PendingDots extends StatefulWidget {
  final Color color;
  const _PendingDots({required this.color});

  @override
  State<_PendingDots> createState() => _PendingDotsState();
}

class _PendingDotsState extends State<_PendingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
          final opacity =
              (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.2, 1.0);
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Opacity(
              opacity: opacity,
              child: Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                      color: widget.color, shape: BoxShape.circle)),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Driver Card ──────────────────────────────────────────────────────────────

class _DriverCard extends StatelessWidget {
  final OrderModel order;
  const _DriverCard({required this.order});

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sms(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: order.code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã sao chép mã đơn'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final driver = order.driver!;
    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(icon: Icons.person_pin_rounded,
            label: 'Tài xế của bạn', iconColor: c.primary),
        const SizedBox(height: 14),

        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.primarySoft,
              border: Border.all(
                  color: c.primary.withValues(alpha: 0.3),
                  width: 1.5),
            ),
            child: ClipOval(
              child: driver.avatarUrl != null
                  ? Image.network(driver.avatarUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) => Icon(
                          Icons.person_rounded,
                          size: 26, color: c.primary))
                  : Icon(Icons.person_rounded,
                      size: 26, color: c.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(driver.name,
                  style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 16, color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(driver.phone,
                  style: TextStyle(fontSize: 13,
                      color: c.textSecondary)),
            ],
          )),
          _ActionBtn(icon: Icons.message_rounded, color: c.primary,
              onTap: () => _sms(driver.phone)),
          const SizedBox(width: 8),
          _ActionBtn(icon: Icons.call_rounded, color: c.success,
              onTap: () => _call(driver.phone)),
        ]),

        const SizedBox(height: 12),
        Divider(height: 1, color: c.divider),
        const SizedBox(height: 12),

        Row(children: [
          Icon(Icons.confirmation_number_rounded,
              size: 14, color: c.textSecondary),
          const SizedBox(width: 6),
          Text('Mã đơn',
              style: TextStyle(fontSize: 13, color: c.textSecondary)),
          const SizedBox(width: 8),
          Text('#${order.code}',
              style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w700, color: c.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: () => _copyCode(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Sao chép',
                  style: TextStyle(fontSize: 12, color: c.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: context.isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      );
}

// ─── Driver Map Card ──────────────────────────────────────────────────────────

class _DriverMapCard extends StatefulWidget {
  final OrderModel order;
  final double? realtimeLat, realtimeLng;
  const _DriverMapCard({
    required this.order,
    this.realtimeLat, this.realtimeLng,
  });

  @override
  State<_DriverMapCard> createState() => _DriverMapCardState();
}

class _DriverMapCardState extends State<_DriverMapCard> {
  gm.GoogleMapController? _ctrl;
  gm.BitmapDescriptor?    _shipperIcon;
  gm.BitmapDescriptor?    _pickupIcon;
  gm.BitmapDescriptor?    _deliveryIcon;
  double _heading  = 0.0;
  double? _prevLat, _prevLng;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildIcons());
    loadMapStyle().then((s) { if (mounted) setState(() => _mapStyle = s); });
  }

  Future<void> _buildIcons() async {
    if (!mounted) return;
    _shipperIcon = await buildDriverMarker(color: AppColors.info);
    _pickupIcon = await buildPinMarker(
        color: AppColors.primary, icon: Icons.storefront_rounded);
    _deliveryIcon = await buildPinMarker(
        color: AppColors.success, icon: Icons.person_rounded);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _DriverMapCard old) {
    super.didUpdateWidget(old);
    final newLat = widget.realtimeLat ?? widget.order.driver?.latitude;
    final newLng = widget.realtimeLng ?? widget.order.driver?.longitude;
    final oldLat = old.realtimeLat ?? old.order.driver?.latitude;
    final oldLng = old.realtimeLng ?? old.order.driver?.longitude;
    if (newLat != null && newLng != null &&
        (newLat != oldLat || newLng != oldLng)) {
      if (_prevLat != null && _prevLng != null) {
        setState(() => _heading =
            _bearing(_prevLat!, _prevLng!, newLat, newLng));
      }
      _prevLat = newLat;
      _prevLng = newLng;
      _fitCamera(newLat, newLng);
    }
  }

  double _bearing(double lat1, double lng1, double lat2, double lng2) {
    const toRad = pi / 180;
    final dLng  = (lng2 - lng1) * toRad;
    final lat1R = lat1 * toRad;
    final lat2R = lat2 * toRad;
    final y = sin(dLng) * cos(lat2R);
    final x = cos(lat1R) * sin(lat2R) -
        sin(lat1R) * cos(lat2R) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  void _fitCamera(double dLat, double dLng) {
    if (_ctrl == null) return;
    final destLat = widget.order.deliveryLat;
    final destLng = widget.order.deliveryLng;
    if (destLat != null && destLng != null) {
      final sw = gm.LatLng(
        dLat < destLat ? dLat : destLat,
        dLng < destLng ? dLng : destLng,
      );
      final ne = gm.LatLng(
        dLat > destLat ? dLat : destLat,
        dLng > destLng ? dLng : destLng,
      );
      _ctrl!.animateCamera(gm.CameraUpdate.newLatLngBounds(
          gm.LatLngBounds(southwest: sw, northeast: ne), 60));
    } else {
      _ctrl!.animateCamera(
          gm.CameraUpdate.newLatLngZoom(gm.LatLng(dLat, dLng), 15));
    }
  }

  Set<gm.Marker> get _markers {
    final s   = <gm.Marker>{};
    final dLat = widget.realtimeLat ?? widget.order.driver?.latitude;
    final dLng = widget.realtimeLng ?? widget.order.driver?.longitude;
    if (dLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('driver'),
        position: gm.LatLng(dLat, dLng!),
        icon: _shipperIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(
                gm.BitmapDescriptor.hueAzure),
        rotation: _heading,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        infoWindow: gm.InfoWindow(
            title: widget.order.driver?.name ?? 'Tài xế'),
      ));
    }
    if (widget.order.pickupLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('pickup'),
        position: gm.LatLng(
            widget.order.pickupLat!, widget.order.pickupLng!),
        icon: _pickupIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(
                gm.BitmapDescriptor.hueOrange),
        infoWindow: const gm.InfoWindow(title: 'Điểm lấy'),
      ));
    }
    if (widget.order.deliveryLat != null) {
      s.add(gm.Marker(
        markerId: const gm.MarkerId('delivery'),
        position: gm.LatLng(
            widget.order.deliveryLat!, widget.order.deliveryLng!),
        icon: _deliveryIcon ??
            gm.BitmapDescriptor.defaultMarkerWithHue(
                gm.BitmapDescriptor.hueRed),
        infoWindow: const gm.InfoWindow(title: 'Điểm giao'),
      ));
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final c    = context.colors;
    final dLat = widget.realtimeLat ?? widget.order.driver?.latitude ?? 10.0452;
    final dLng = widget.realtimeLng ?? widget.order.driver?.longitude ?? 105.7469;

    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(icon: Icons.location_on_rounded,
            label: 'Vị trí tài xế', iconColor: c.primary),
        const SizedBox(height: 12),

        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 180,
            child: gm.GoogleMap(
              style: _mapStyle,
              initialCameraPosition: gm.CameraPosition(
                target: gm.LatLng(dLat, dLng),
                zoom: 15,
              ),
              onMapCreated: (mapCtrl) => setState(() => _ctrl = mapCtrl),
              markers: _markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer()),
                Factory<ScaleGestureRecognizer>(
                    () => ScaleGestureRecognizer()),
              },
            ),
          ),
        ),

        const SizedBox(height: 10),
        Row(children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(
                  color: c.primary, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(widget.order.driver?.name ?? 'Tài xế',
              style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary)),
          const Spacer(),
          Icon(Icons.sync_rounded, size: 14,
              color: c.textSecondary),
          const SizedBox(width: 4),
          Text('Tự động cập nhật',
              style: TextStyle(fontSize: 11,
                  color: c.textSecondary)),
        ]),
      ]),
    );
  }
}

// ─── Stops Card (batch orders) ───────────────────────────────────────────────

class _StopsCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final Future<void> Function() onStopDelivered;
  const _StopsCard({required this.order, required this.onStopDelivered});

  @override
  ConsumerState<_StopsCard> createState() => _StopsCardState();
}

class _StopsCardState extends ConsumerState<_StopsCard> {
  // Seq đang gọi API deliver — cho phép nhiều điểm loading độc lập, chỉ hiện
  // spinner trên đúng nút vừa bấm thay vì che cả màn hình.
  final Set<int> _deliveringSeqs = {};

  Future<void> _markDelivered(int seq) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận giao hàng',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text('Xác nhận đã giao điểm $seq?',
            style: TextStyle(fontSize: 14, color: ctx.colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.primary),
            child: const Text('Xác nhận',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deliveringSeqs.add(seq));
    try {
      await ref.read(apiClientProvider).post(
          '/shop/orders/${widget.order.code}/stops/$seq/deliver');
      await widget.onStopDelivered();
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context,
            parseApiError(e, fallback: 'Không thể đánh dấu đã giao. Thử lại sau.'));
      }
    } finally {
      if (mounted) setState(() => _deliveringSeqs.remove(seq));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c         = context.colors;
    final order     = widget.order;
    final stops     = order.stops;
    final delivered = stops.where((s) => s['delivered_at'] != null).length;
    // Chỉ shop tự đánh dấu được khi đơn còn đang xử lý — đơn đã hoàn thành/
    // huỷ hoặc không phải đơn gộp thì không hiện nút (order.isBatch đã được
    // đảm bảo bởi nơi khởi tạo _StopsCard, kiểm tra lại ở đây cho chắc chắn).
    final canMarkDelivered =
        order.isBatch && _activeStatuses.contains(order.status);

    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
          icon: Icons.route_rounded,
          label: 'Đơn gộp — $delivered/${stops.length} điểm đã giao',
          iconColor: c.success,
        ),
        const SizedBox(height: 12),

        ...stops.asMap().entries.map((e) {
          final i    = e.key;
          final stop = e.value;
          final isDone = stop['delivered_at'] != null;
          final seq    = (stop['seq'] as num).toInt();
          final fee    = (stop['fee'] as num?)?.toInt();
          final phone  = stop['phone'] as String? ?? '';
          final addr   = stop['address'] as String? ?? '';
          final name   = stop['name'] as String? ?? '';

          return Column(children: [
            if (i > 0)
              Divider(height: 16, color: c.divider),

            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Sequence badge
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: isDone ? c.success : c.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : Text('${stop['seq']}',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: isDone ? Colors.white : c.primary)),
                ),
              ),
              const SizedBox(width: 10),

              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(
                      name.isNotEmpty ? name : 'Điểm ${stop['seq']}',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: isDone
                              ? c.textSecondary
                              : c.textPrimary,
                          decoration: isDone
                              ? TextDecoration.lineThrough : null),
                    )),
                    if (fee != null)
                      Text(Fmt.currency(fee),
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: isDone
                                  ? c.textSecondary
                                  : c.primary)),
                  ]),
                  const SizedBox(height: 2),
                  Text(addr,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: c.textSecondary)),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse('tel:$phone');
                        if (await canLaunchUrl(uri)) { launchUrl(uri); }
                      },
                      child: Row(children: [
                        Icon(Icons.phone_outlined,
                            size: 12, color: c.primary),
                        const SizedBox(width: 4),
                        Text(phone,
                            style: TextStyle(
                                fontSize: 12, color: c.primary,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ],
                  if (isDone) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Đã giao lúc ${_fmtTime(stop['delivered_at'] as String)}',
                      style: TextStyle(
                          fontSize: 11, color: c.success),
                    ),
                  ] else if (canMarkDelivered) ...[
                    const SizedBox(height: 8),
                    _MarkDeliveredButton(
                      loading: _deliveringSeqs.contains(seq),
                      onTap: () => _markDelivered(seq),
                    ),
                  ],
                ],
              )),
            ]),
          ]);
        }),

        // Progress bar tổng
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: stops.isEmpty ? 0 : delivered / stops.length,
            backgroundColor: c.surfaceAlt,
            color: c.success,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text('$delivered/${stops.length} điểm đã giao',
            style: TextStyle(
                fontSize: 11, color: c.textSecondary)),
      ]),
    );
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}

class _MarkDeliveredButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _MarkDeliveredButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: c.primary, width: 1.4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (loading)
            SizedBox(
              width: 13, height: 13,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
            )
          else
            Icon(Icons.check_rounded, size: 15, color: c.primary),
          const SizedBox(width: 6),
          Text('Đánh dấu đã giao',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: c.primary)),
        ]),
      ),
    );
  }
}

// ─── Route Card ───────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final OrderModel order;
  const _RouteCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _FlatCard(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.start, children: [
              Container(width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: c.primary, shape: BoxShape.circle)),
              Expanded(child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(1),
                ),
              )),
              Container(width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: c.success,
                      borderRadius: BorderRadius.circular(3))),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RouteStop(
                    label:   'Lấy hàng',
                    title:   order.pickupPlaceName?.isNotEmpty == true
                        ? order.pickupPlaceName
                        : order.senderName?.isNotEmpty == true
                            ? order.senderName
                            : null,
                    address: order.pickupAddress,
                    phone:   order.pickupPhone,
                  ),
                  const SizedBox(height: 16),
                  _RouteStop(
                    label:   'Giao đến',
                    title:   order.deliveryPlaceName?.isNotEmpty == true
                        ? order.deliveryPlaceName
                        : order.receiverName?.isNotEmpty == true
                            ? order.receiverName
                            : null,
                    address: order.deliveryAddress,
                    phone:   order.deliveryPhone,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  final String label;
  final String? title;
  final String address;
  final String? phone;

  const _RouteStop({
    required this.label,
    required this.address,
    this.title,
    this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textSecondary)),
      const SizedBox(height: 3),
      if (title != null && title!.isNotEmpty) ...[
        Text(title!,
            style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.textPrimary)),
        const SizedBox(height: 1),
      ],
      Text(address,
          style: TextStyle(fontSize: 14, color: c.textPrimary)),
      if (phone != null && phone!.isNotEmpty) ...[
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse('tel:$phone');
            if (await canLaunchUrl(uri)) { launchUrl(uri); }
          },
          child: Row(children: [
            Icon(Icons.phone_outlined,
                size: 13, color: c.primary),
            const SizedBox(width: 4),
            Text(phone!,
                style: TextStyle(fontSize: 13,
                    color: c.primary,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ],
    ]);
  }
}

// ─── Order Info Card ──────────────────────────────────────────────────────────

class _OrderInfoCard extends StatelessWidget {
  final OrderModel order;
  const _OrderInfoCard({required this.order});

  static const _cargoInfo = {
    'food':    (Icons.lunch_dining_rounded,  'Đồ ăn',          Color(0xFFF59E0B)),
    'flowers': (Icons.local_florist_rounded, 'Hoa / Trái cây', Color(0xFFEC4899)),
    'parcel':  (Icons.inventory_2_rounded,   'Bưu kiện',       Color(0xFF6B7280)),
  };

  @override
  Widget build(BuildContext context) {
    final c     = context.colors;
    final cargo = _cargoInfo[order.cargoType] ??
        (Icons.inventory_2_rounded, 'Bưu kiện', const Color(0xFF6B7280));

    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(icon: Icons.receipt_long_outlined,
            label: 'Thông tin đơn hàng', iconColor: c.primary),
        const SizedBox(height: 12),

        // Cargo badge + code
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cargo.$3.withValues(
                  alpha: context.isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(cargo.$1, color: cargo.$3, size: 14),
              const SizedBox(width: 6),
              Text(cargo.$2,
                  style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700, color: cargo.$3)),
              if (order.cargoWeight != null) ...[
                const SizedBox(width: 4),
                Text('• ${order.cargoWeight!.toStringAsFixed(order.cargoWeight! % 1 == 0 ? 0 : 1)}kg',
                    style: TextStyle(fontSize: 11, color: cargo.$3)),
              ],
            ]),
          ),
          const Spacer(),
          Text('#${order.code}',
              style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textSecondary)),
        ]),

        const SizedBox(height: 12),
        Divider(height: 1, color: c.divider),
        const SizedBox(height: 12),

        if (order.distanceKm != null) ...[
          _InfoRow(Icons.straighten_rounded, 'Khoảng cách',
              '${order.distanceKm!.toStringAsFixed(1)} km'),
          const SizedBox(height: 8),
        ],

        if (order.nightSurcharge > 0) ...[
          _InfoRow(Icons.nightlight_round, 'Phụ thu đêm',
              '+ ${Fmt.currency(order.nightSurcharge)}',
              valueColor: c.warning),
          const SizedBox(height: 8),
        ],

        // Fee highlight
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: c.primary.withValues(alpha: 0.18)),
          ),
          child: Row(children: [
            Icon(Icons.payments_outlined,
                size: 18, color: c.primary),
            const SizedBox(width: 10),
            Text('Phí vận chuyển',
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary)),
            const Spacer(),
            Text(Fmt.currency(order.shippingFee),
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.primary)),
          ]),
        ),

        if ((order.codAmount ?? 0) > 0) ...[
          const SizedBox(height: 8),
          _InfoRow(Icons.account_balance_wallet_outlined,
              'Thu hộ COD', Fmt.currency(order.codAmount!),
              valueColor: c.info),
        ],

        const SizedBox(height: 12),
        Divider(height: 1, color: c.divider),
        const SizedBox(height: 12),

        _InfoRow(Icons.credit_card_outlined, 'Thanh toán', 'Tiền mặt'),
        const SizedBox(height: 8),
        _InfoRow(Icons.access_time_outlined, 'Thời gian',
            Fmt.dateTime(order.createdAt)),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color?   valueColor;
  const _InfoRow(this.icon, this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Icon(icon, size: 15, color: c.textSecondary),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(fontSize: 13, color: c.textSecondary)),
      const Spacer(),
      Text(value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: valueColor ?? c.textPrimary)),
    ]);
  }
}

// ─── Note Card ────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final String note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(icon: Icons.notes_outlined,
            label: 'Ghi chú', iconColor: c.textSecondary),
        const SizedBox(height: 10),
        Text(note,
            style: TextStyle(fontSize: 13,
                color: c.textPrimary, height: 1.5)),
      ]),
    );
  }
}

// ─── Rating Display ───────────────────────────────────────────────────────────

class _RatingDisplay extends StatelessWidget {
  final int rating;
  const _RatingDisplay({required this.rating});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(icon: Icons.star_rounded,
            label: 'Đánh giá của bạn', iconColor: c.warning),
        const SizedBox(height: 10),
        Row(children: List.generate(5, (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: c.warning, size: 28,
        ))),
      ]),
    );
  }
}

// ─── Rating Sheet ─────────────────────────────────────────────────────────────

class _RatingSheet extends ConsumerStatefulWidget {
  final String orderCode, driverName;
  final VoidCallback onDone;
  const _RatingSheet({
    required this.orderCode,
    required this.driverName,
    required this.onDone,
  });

  @override
  ConsumerState<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<_RatingSheet> {
  int              _rating    = 5;
  bool             _submitting = false;
  final Set<String> _selectedTags = {};
  final _noteCtrl = TextEditingController();

  static const _positiveTags = [
    'Giao hàng nhanh',
    'Đúng giờ',
    'Thái độ lịch sự',
    'Cẩn thận hàng hóa',
    'Liên lạc dễ dàng',
    'Chuyên nghiệp',
  ];

  static const _negativeTags = [
    'Giao hàng chậm',
    'Trễ giờ',
    'Thái độ không tốt',
    'Làm hỏng hàng',
    'Khó liên lạc',
    'Không đúng địa chỉ',
  ];

  List<String> get _tags => _rating >= 4 ? _positiveTags : _negativeTags;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final parts = [
      ..._selectedTags,
      if (_noteCtrl.text.trim().isNotEmpty) _noteCtrl.text.trim(),
    ];
    final note = parts.join(', ');
    try {
      await ref.read(apiClientProvider).post(
        '/shop/orders/${widget.orderCode}/rate',
        data: {
          'rating': _rating,
          if (note.isNotEmpty) 'note': note,
        },
      );
      widget.onDone();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppSnackbar.error(context,
            parseApiError(e, fallback: 'Không thể gửi đánh giá. Thử lại sau.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: c.divider,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: c.warningSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.star_rounded, color: c.warning, size: 30),
            ),
            const SizedBox(height: 14),
            const Text('Đánh giá tài xế',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(widget.driverName,
                style: TextStyle(fontSize: 14, color: c.textSecondary)),
            const SizedBox(height: 20),

            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() {
                  _rating = i + 1;
                  _selectedTags.clear();
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: c.warning, size: 40,
                  ),
                ),
              )),
            ),
            const SizedBox(height: 20),

            // Preset tags
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _rating >= 4 ? 'Điều bạn thích' : 'Vấn đề gặp phải',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: c.textSecondary),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                final selected = _selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? (_rating >= 4
                              ? c.warning.withValues(alpha: 0.12)
                              : c.danger.withValues(alpha: 0.10))
                          : c.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? (_rating >= 4 ? c.warning : c.danger)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(tag,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? (_rating >= 4 ? c.warning : c.danger)
                                : c.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Custom note
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              minLines: 2,
              textInputAction: TextInputAction.newline,
              style: TextStyle(fontSize: 14, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nhận xét thêm (tuỳ chọn)...',
                hintStyle: TextStyle(fontSize: 13, color: c.textTertiary),
                filled: true,
                fillColor: c.surfaceAlt,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.warning,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Gửi đánh giá',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _FlatCard extends StatelessWidget {
  final Widget child;
  const _FlatCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: context.colors.cardShadow,
        ),
        child: child,
      );
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    iconColor;
  const _CardHeader({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: context.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 15, color: iconColor),
    ),
    const SizedBox(width: 10),
    Text(label,
        style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary)),
  ]);
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded,
            size: 48, color: c.textSecondary),
        const SizedBox(height: 12),
        Text('Không thể tải đơn hàng',
            style: TextStyle(fontSize: 14,
                color: c.textSecondary)),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ]),
    );
  }
}
