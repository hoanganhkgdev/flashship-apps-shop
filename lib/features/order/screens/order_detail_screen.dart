import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
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
        .ref('flashship_main/locations/driver_$driverId')
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
          (res.data['data'] ?? res.data) as Map<String, dynamic>);
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
          (res.data['data'] ?? res.data) as Map<String, dynamic>);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Huỷ đơn hàng?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: const Text('Bạn có chắc muốn huỷ đơn này không?',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseError(e)),
              backgroundColor: AppColors.danger),
        );
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
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.star_rounded,
                  color: AppColors.warning, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Đánh giá tài xế',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Đơn hàng đã hoàn thành!\nĐánh giá giúp ${_order!.driver?.name ?? 'tài xế'} cải thiện chất lượng dịch vụ.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13,
                  color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
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
              child: const Text('Để sau',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ]),
        ),
      ),
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

  String _parseError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) return data['message']?.toString() ?? 'Lỗi không xác định';
    } catch (_) {}
    return 'Không thể huỷ đơn. Thử lại sau.';
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
      backgroundColor: AppColors.background,
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
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
    final driverLat = realtimeLat ?? order.driver?.latitude;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 8),

          // ── Status ───────────────────────────────────────────────────
          _StatusCard(order: order),
          const SizedBox(height: 8),

          // ── Driver ───────────────────────────────────────────────────
          if (order.driver != null) ...[
            _DriverCard(order: order),
            const SizedBox(height: 8),
          ],

          // ── Map (driver location) ─────────────────────────────────────
          if (driverLat != null && order.isActive) ...[
            _DriverMapCard(
              order: order,
              realtimeLat: realtimeLat,
              realtimeLng: realtimeLng,
            ),
            const SizedBox(height: 8),
          ],

          // ── Route ─────────────────────────────────────────────────────
          // Batch: stops list / Single: route card
          if (order.isBatch && order.stops.isNotEmpty) ...[
            _StopsCard(order: order),
          ] else
            _RouteCard(order: order),
          const SizedBox(height: 8),

          // ── Order info ─────────────────────────────────────────────────
          _OrderInfoCard(order: order),

          // ── Note ───────────────────────────────────────────────────────
          if (order.orderNote?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _NoteCard(note: order.orderNote!),
          ],

          // ── Cancel button ──────────────────────────────────────────────
          if (order.canCancel) ...[
            const SizedBox(height: 8),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: cancelling ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: cancelling
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2,
                              color: AppColors.danger))
                      : const Text('Huỷ đơn hàng',
                          style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],

          // ── Rate button ────────────────────────────────────────────────
          if (order.canRate && !ratingDone) ...[
            const SizedBox(height: 8),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onRate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
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

          if (order.driverRating != null) ...[
            const SizedBox(height: 8),
            _RatingDisplay(rating: order.driverRating!),
          ],

          // ── Đặt lại ──────────────────────────────────────────────────
          if (order.isCompleted || order.isCancelled) ...[
            const SizedBox(height: 8),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/create-order',
                    extra: _reorderExtra(order),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
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
}

// ─── Status Card ─────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final OrderModel order;
  const _StatusCard({required this.order});

  static (Color, IconData, String) _meta(String status) {
    switch (status) {
      case 'pending':    return (AppColors.warning,       Icons.access_time_rounded,     'Đang tìm tài xế phù hợp...');
      case 'assigned':   return (AppColors.primary,       Icons.person_pin_rounded,       'Tài xế đang trên đường đến');
      case 'processing': return (AppColors.primary,       Icons.inventory_2_outlined,     'Tài xế đang lấy hàng');
      case 'completed':  return (AppColors.success,       Icons.check_circle_rounded,     'Giao hàng thành công!');
      case 'cancelled':  return (AppColors.textSecondary, Icons.cancel_outlined,          'Đơn hàng đã bị huỷ');
      default:           return (AppColors.textSecondary, Icons.info_outline_rounded,     status);
    }
  }

  static const _steps = [
    ('pending',    'Đang tìm tài xế', Icons.schedule_rounded),
    ('assigned',   'Tài xế đã nhận',  Icons.person_pin_rounded),
    ('processing', 'Đang lấy hàng',   Icons.inventory_2_outlined),
    ('completed',  'Hoàn thành',      Icons.check_circle_rounded),
  ];

  static const _statusOrder = [
    'pending', 'assigned', 'processing', 'completed'
  ];

  @override
  Widget build(BuildContext context) {
    final (color, icon, subtitle) = _meta(order.status);
    final currentIdx  = _statusOrder.indexOf(order.status);
    final isCancelled = order.status == 'cancelled';

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 3, color: color),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Current status
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Icon(icon, color: color, size: 28),
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

            // Timeline
            if (!isCancelled) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              ..._steps.asMap().entries.map((entry) {
                final i = entry.key;
                final (key, label, stepIcon) = entry.value;
                final stepIdx = _statusOrder.indexOf(key);
                final isDone  = currentIdx >= stepIdx && currentIdx != -1;
                final isLast  = i == _steps.length - 1;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Column(children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: isDone ? color : AppColors.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDone ? color : AppColors.divider,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(stepIcon, size: 11,
                              color: isDone ? Colors.white
                                  : AppColors.textSecondary),
                        ),
                        if (!isLast)
                          Container(
                            width: 1.5, height: 16,
                            color: isDone
                                ? color.withValues(alpha: 0.25)
                                : AppColors.divider,
                          ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isDone
                                ? FontWeight.w600 : FontWeight.w400,
                            color: isDone
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          )),
                    ),
                  ],
                );
              }),
            ],

            // Cancel reason
            if (isCancelled && order.cancelReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(child: Text(order.cancelReason!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.danger))),
                ]),
              ),
            ],
          ]),
        ),
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
      builder: (_, __) => Row(
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
    final driver = order.driver!;
    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(icon: Icons.person_pin_rounded,
            label: 'Tài xế của bạn', iconColor: AppColors.primary),
        const SizedBox(height: 14),

        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.5),
            ),
            child: ClipOval(
              child: driver.avatarUrl != null
                  ? Image.network(driver.avatarUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          size: 26, color: AppColors.primary))
                  : const Icon(Icons.person_rounded,
                      size: 26, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(driver.name,
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 16, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(driver.phone,
                  style: const TextStyle(fontSize: 13,
                      color: AppColors.textSecondary)),
            ],
          )),
          _ActionBtn(icon: Icons.message_rounded, color: AppColors.primary,
              onTap: () => _sms(driver.phone)),
          const SizedBox(width: 8),
          _ActionBtn(icon: Icons.call_rounded, color: AppColors.success,
              onTap: () => _call(driver.phone)),
        ]),

        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 12),

        Row(children: [
          const Icon(Icons.confirmation_number_rounded,
              size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          const Text('Mã đơn',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Text('#${order.code}',
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: () => _copyCode(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Sao chép',
                  style: TextStyle(fontSize: 12, color: AppColors.primary,
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
            color: color.withValues(alpha: 0.1),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildIcons());
  }

  Future<void> _buildIcons() async {
    if (!mounted) return;
    _shipperIcon  = await _loadMarkerIcon('assets/images/icon_shiper.png',   42);
    _pickupIcon   = await _loadMarkerIcon('assets/images/icon_pick.png',     56);
    _deliveryIcon = await _loadMarkerIcon('assets/images/icon_delivery.png', 56);
    if (mounted) setState(() {});
  }

  Future<gm.BitmapDescriptor?> _loadMarkerIcon(String path, int size) async {
    try {
      final data  = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(), targetWidth: size, targetHeight: size);
      final frame = await codec.getNextFrame();
      final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return null;
      return gm.BitmapDescriptor.bytes(bytes.buffer.asUint8List());
    } catch (_) { return null; }
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
    final dLat = widget.realtimeLat ?? widget.order.driver?.latitude ?? 10.0452;
    final dLng = widget.realtimeLng ?? widget.order.driver?.longitude ?? 105.7469;

    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(icon: Icons.location_on_rounded,
            label: 'Vị trí tài xế', iconColor: AppColors.primary),
        const SizedBox(height: 12),

        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 180,
            child: gm.GoogleMap(
              initialCameraPosition: gm.CameraPosition(
                target: gm.LatLng(dLat, dLng),
                zoom: 15,
              ),
              onMapCreated: (c) => setState(() => _ctrl = c),
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
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(widget.order.driver?.name ?? 'Tài xế',
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const Spacer(),
          const Icon(Icons.sync_rounded, size: 14,
              color: AppColors.textSecondary),
          const SizedBox(width: 4),
          const Text('Tự động cập nhật',
              style: TextStyle(fontSize: 11,
                  color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }
}

// ─── Stops Card (batch orders) ───────────────────────────────────────────────

class _StopsCard extends StatelessWidget {
  final OrderModel order;
  const _StopsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final stops     = order.stops;
    final delivered = stops.where((s) => s['delivered_at'] != null).length;

    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
          icon: Icons.route_rounded,
          label: 'Đơn gộp — $delivered/${stops.length} điểm đã giao',
          iconColor: AppColors.success,
        ),
        const SizedBox(height: 12),

        ...stops.asMap().entries.map((e) {
          final i    = e.key;
          final stop = e.value;
          final isDone = stop['delivered_at'] != null;
          final fee    = (stop['fee'] as num?)?.toInt();
          final phone  = stop['phone'] as String? ?? '';
          final addr   = stop['address'] as String? ?? '';
          final name   = stop['name'] as String? ?? '';

          return Column(children: [
            if (i > 0)
              const Divider(height: 16, color: Color(0xFFF5F5F5)),

            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Sequence badge
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.success
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : Text('${stop['seq']}',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: isDone ? Colors.white : AppColors.primary)),
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
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          decoration: isDone
                              ? TextDecoration.lineThrough : null),
                    )),
                    if (fee != null)
                      Text(Fmt.currency(fee),
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: isDone
                                  ? AppColors.textSecondary
                                  : AppColors.primary)),
                  ]),
                  const SizedBox(height: 2),
                  Text(addr,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse('tel:$phone');
                        if (await canLaunchUrl(uri)) { launchUrl(uri); }
                      },
                      child: Row(children: [
                        const Icon(Icons.phone_outlined,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(phone,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.primary,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ],
                  if (isDone) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Đã giao lúc ${_fmtTime(stop['delivered_at'] as String)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.success),
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
            backgroundColor: const Color(0xFFF0F0F0),
            color: AppColors.success,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text('$delivered/${stops.length} điểm đã giao',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
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

// ─── Route Card ───────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final OrderModel order;
  const _RouteCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(mainAxisAlignment: MainAxisAlignment.start, children: [
              Container(width: 12, height: 12,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle)),
              Expanded(child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(1),
                ),
              )),
              Container(width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(3))),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RouteStop(
                    label: 'Lấy hàng',
                    // Giao đơn: senderName = shop. Lấy hộ: senderName = contact ngoài (hoặc trống)
                    title:   order.senderName?.isNotEmpty == true
                        ? order.senderName
                        : null,
                    address: order.pickupAddress,
                    phone:   order.pickupPhone,
                  ),
                  const SizedBox(height: 16),
                  _RouteStop(
                    label: 'Giao đến',
                    title:   order.receiverName?.isNotEmpty == true
                        ? order.receiverName
                        : order.storeName,
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary)),
      const SizedBox(height: 3),
      if (title != null && title!.isNotEmpty) ...[
        Text(title!,
            style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 1),
      ],
      Text(address,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      if (phone != null && phone!.isNotEmpty) ...[
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse('tel:$phone');
            if (await canLaunchUrl(uri)) { launchUrl(uri); }
          },
          child: Row(children: [
            const Icon(Icons.phone_outlined,
                size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(phone!,
                style: const TextStyle(fontSize: 13,
                    color: AppColors.primary,
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
    final cargo = _cargoInfo[order.cargoType] ??
        (Icons.inventory_2_rounded, 'Bưu kiện', const Color(0xFF6B7280));

    return _FlatCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(icon: Icons.receipt_long_outlined,
            label: 'Thông tin đơn hàng', iconColor: AppColors.primary),
        const SizedBox(height: 12),

        // Cargo badge + code
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cargo.$3.withValues(alpha: 0.1),
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
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ]),

        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 12),

        if (order.distanceKm != null) ...[
          _InfoRow(Icons.straighten_rounded, 'Khoảng cách',
              '${order.distanceKm!.toStringAsFixed(1)} km'),
          const SizedBox(height: 8),
        ],

        if (order.nightSurcharge > 0) ...[
          _InfoRow(Icons.nightlight_round, 'Phụ thu đêm',
              '+ ${Fmt.currency(order.nightSurcharge)}',
              valueColor: AppColors.warning),
          const SizedBox(height: 8),
        ],

        // Fee highlight
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18)),
          ),
          child: Row(children: [
            const Icon(Icons.payments_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            const Text('Phí vận chuyển',
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Text(Fmt.currency(order.shippingFee),
                style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ]),
        ),

        if ((order.codAmount ?? 0) > 0) ...[
          const SizedBox(height: 8),
          _InfoRow(Icons.account_balance_wallet_outlined,
              'Thu hộ COD', Fmt.currency(order.codAmount!),
              valueColor: AppColors.info),
        ],

        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
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
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: AppColors.textSecondary),
    const SizedBox(width: 8),
    Text(label,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
    const Spacer(),
    Text(value,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary)),
  ]);
}

// ─── Note Card ────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final String note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) => _FlatCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _CardHeader(icon: Icons.notes_outlined,
              label: 'Ghi chú', iconColor: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(note,
              style: const TextStyle(fontSize: 13,
                  color: AppColors.textPrimary, height: 1.5)),
        ]),
      );
}

// ─── Rating Display ───────────────────────────────────────────────────────────

class _RatingDisplay extends StatelessWidget {
  final int rating;
  const _RatingDisplay({required this.rating});

  @override
  Widget build(BuildContext context) => _FlatCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _CardHeader(icon: Icons.star_rounded,
              label: 'Đánh giá của bạn', iconColor: AppColors.warning),
          const SizedBox(height: 10),
          Row(children: List.generate(5, (i) => Icon(
            i < rating ? Icons.star_rounded : Icons.star_border_rounded,
            color: AppColors.warning, size: 28,
          ))),
        ]),
      );
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
  int  _rating    = 5;
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(apiClientProvider).post(
        '/shop/orders/${widget.orderCode}/rate',
        data: {'rating': _rating},
      );
      widget.onDone();
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.star_rounded,
              color: AppColors.warning, size: 32),
        ),
        const SizedBox(height: 16),
        const Text('Đánh giá tài xế',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(widget.driverName,
            style: const TextStyle(fontSize: 14,
                color: AppColors.textSecondary)),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) => GestureDetector(
            onTap: () => setState(() => _rating = i + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                i < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                color: AppColors.warning, size: 40,
              ),
            ),
          )),
        ),

        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
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
        color: Colors.white,
        padding: const EdgeInsets.all(16),
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
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 15, color: iconColor),
    ),
    const SizedBox(width: 10),
    Text(label,
        style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
  ]);
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('Không thể tải đơn hàng',
              style: TextStyle(fontSize: 14,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ]),
      );
}
