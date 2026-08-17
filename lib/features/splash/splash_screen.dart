import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../version/providers/app_version_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  bool _dialogShown = false;

  // Logo: scale (overshoot nhẹ) + fade khi vào màn hình.
  late final AnimationController _logoCtrl;
  late final Animation<double>    _logoScale;
  late final Animation<double>    _logoFade;

  // Brand text: fade + trượt lên nhẹ, chạy sau logo một nhịp.
  late final Animation<double> _textFade;
  late final Animation<double> _textSlide;

  // Progress bar: chạy đúng 3s khớp với Future.delayed thật bên dưới.
  late final AnimationController _progressCtrl;

  // Chấm sáng chạy dọc tuyến đường, lặp vô hạn.
  late final AnimationController _routeCtrl;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
    _logoFade = CurvedAnimation(
        parent: _logoCtrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut));
    _textFade = CurvedAnimation(
        parent: _logoCtrl, curve: const Interval(0.35, 1.0, curve: Curves.easeOut));
    _textSlide = Tween<double>(begin: 14, end: 0).animate(CurvedAnimation(
        parent: _logoCtrl, curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic)));
    _logoCtrl.forward();

    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3));
    _progressCtrl.forward();

    _routeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appVersionProvider.notifier).check();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) ref.read(splashReadyProvider.notifier).state = true;
      });
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _progressCtrl.dispose();
    _routeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(appVersionProvider);

    if (version.isChecked && !_dialogShown) {
      if (version.needsForceUpdate) {
        _dialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showForceUpdateDialog(context, version);
        });
      }
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative route + moving dot ──────────────────────────────
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _RoutePainter(progress: _routeCtrl),
          ),

          // ── Content ──────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                Center(
                  child: AnimatedBuilder(
                    animation: _logoCtrl,
                    builder: (_, __) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo trên khối tròn nền trắng translucent
                        Transform.scale(
                          scale: _logoScale.value,
                          child: Opacity(
                            opacity: _logoFade.value,
                            child: Container(
                              padding: const EdgeInsets.all(AppSpace.lg),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                              child: Image.asset(
                                  'assets/images/logo-splash.png', width: 140),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.xl + AppSpace.xs),

                        // Brand name + tagline
                        Opacity(
                          opacity: _textFade.value,
                          child: Transform.translate(
                            offset: Offset(0, _textSlide.value),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'FLASH SHIP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: AppSpace.sm),
                                Text(
                                  'GIAO HÀNG NHANH NHƯ CHỚP',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.80),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // Loading progress — đo lường được, khớp 3s delay thật
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: AppSpace.xxl + AppSpace.lg),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 140,
                        height: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: AnimatedBuilder(
                            animation: _progressCtrl,
                            builder: (_, __) => LinearProgressIndicator(
                              value: _progressCtrl.value,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.20),
                              valueColor: AlwaysStoppedAnimation(
                                  Colors.white.withValues(alpha: 0.85)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text('Đang khởi động...',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showForceUpdateDialog(BuildContext context, AppVersionState v) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Cập nhật bắt buộc',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Text(v.message,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5)),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openStore(v.storeUrl),
                child: const Text('Cập nhật ngay'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStore(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Decorative background painter: tuyến giao hàng + điểm sáng di chuyển ─────
//
// Vẽ một tuyến đường nét đứt uốn lượn (giống route trên bản đồ), có 2 điểm
// dừng (pickup/dropoff) ở đầu-cuối, và một chấm sáng chạy dọc theo tuyến để
// gợi hình ảnh đơn hàng đang trên đường di chuyển.
class _RoutePainter extends CustomPainter {
  final Animation<double> progress;
  _RoutePainter({required this.progress}) : super(repaint: progress);

  Path _buildRoute(Size size) {
    return Path()
      ..moveTo(size.width * 0.14, size.height * 0.10)
      ..cubicTo(
        size.width * 0.02, size.height * 0.24,
        size.width * 0.92, size.height * 0.20,
        size.width * 0.82, size.height * 0.40,
      )
      ..cubicTo(
        size.width * 0.74, size.height * 0.55,
        size.width * 0.08, size.height * 0.58,
        size.width * 0.16, size.height * 0.74,
      )
      ..cubicTo(
        size.width * 0.20, size.height * 0.82,
        size.width * 0.70, size.height * 0.84,
        size.width * 0.80, size.height * 0.92,
      );
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashWidth,
    required double dashGap,
  }) {
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildRoute(size);

    // Tuyến đường nét đứt
    final routePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    _drawDashedPath(canvas, path, routePaint, dashWidth: 7.0, dashGap: 6.0);

    // Điểm dừng đầu (lấy hàng) và cuối (giao hàng)
    final Offset startPoint =
        Offset(size.width * 0.14, size.height * 0.10);
    final Offset endPoint = Offset(size.width * 0.80, size.height * 0.92);

    final waypointRing = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final waypointCore = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (final point in [startPoint, endPoint]) {
      canvas.drawCircle(point, 5, waypointRing);
      canvas.drawCircle(point, 2, waypointCore);
    }

    // Chấm sáng chạy dọc tuyến, vị trí theo [progress] (0.0 → 1.0)
    final metrics = path.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final PathMetric metric = metrics.first;
      final double total = metric.length;
      if (total > 0) {
        final double dist = math.min(progress.value * total, total);
        final Tangent? tangent = metric.getTangentForOffset(dist);
        if (tangent != null) {
          final Offset pos = tangent.position;

          final glowPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawCircle(pos, 9, glowPaint);

          final corePaint = Paint()..color = Colors.white;
          canvas.drawCircle(pos, 3.2, corePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
