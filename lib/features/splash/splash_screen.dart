import 'dart:math' as math;
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
    with SingleTickerProviderStateMixin {
  bool _dialogShown = false;
  late final AnimationController _ctrl;
  late final Animation<double>    _fade;
  late final Animation<double>    _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 24, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appVersionProvider.notifier).check();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) ref.read(splashReadyProvider.notifier).state = true;
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
                colors: [Color(0xFFFF6B1A), Color(0xFFE84D00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative vector shapes ─────────────────────────────────
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _SplashPainter(),
          ),

          // ── Content ──────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo + text
                Center(child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, child) => Opacity(
                    opacity: _fade.value,
                    child: Transform.translate(
                      offset: Offset(0, _slide.value),
                      child: child,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Image.asset('assets/images/logo-splash.png', width: 140),
                      const SizedBox(height: 28),

                      // Brand name
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
                      const SizedBox(height: 8),
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
                )),

                const Spacer(flex: 3),

                // Loading indicator
                Padding(
                  padding: const EdgeInsets.only(bottom: 52),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white.withValues(alpha: 0.55),
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
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

// ── Decorative background painter ────────────────────────────────────────────

class _SplashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Top-right large circle
    paint.color = Colors.white.withValues(alpha: 0.06);
    canvas.drawCircle(
        Offset(size.width + 20, -30), 180, paint);

    // Top-right medium ring
    paint.color = Colors.white.withValues(alpha: 0.05);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawCircle(
        Offset(size.width - 10, 60), 120, paint);

    // Bottom-left blob
    paint.style = PaintingStyle.fill;
    paint.color = Colors.white.withValues(alpha: 0.05);
    final path = Path();
    path.moveTo(0, size.height * 0.72);
    path.cubicTo(
      size.width * 0.15, size.height * 0.65,
      size.width * 0.25, size.height * 0.80,
      0, size.height * 0.88,
    );
    path.close();
    canvas.drawPath(path, paint);

    // Bottom-left large circle
    paint.color = Colors.white.withValues(alpha: 0.07);
    canvas.drawCircle(
        Offset(-60, size.height + 40), 200, paint);

    // Bottom-left ring
    paint.color = Colors.white.withValues(alpha: 0.05);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    canvas.drawCircle(
        Offset(-20, size.height - 60), 130, paint);

    // Center decorative dots
    paint.style = PaintingStyle.fill;
    final dotPositions = [
      Offset(size.width * 0.12, size.height * 0.22),
      Offset(size.width * 0.88, size.height * 0.38),
      Offset(size.width * 0.08, size.height * 0.60),
      Offset(size.width * 0.92, size.height * 0.72),
    ];
    for (var i = 0; i < dotPositions.length; i++) {
      paint.color = Colors.white.withValues(
          alpha: i.isEven ? 0.12 : 0.08);
      canvas.drawCircle(dotPositions[i], i.isEven ? 5 : 3.5, paint);
    }

    // Speed lines (delivery theme)
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = size.height * 0.82 + i * 10.0;
      final len = 24.0 - i * 4;
      canvas.drawLine(
          Offset(size.width * 0.75, y),
          Offset(size.width * 0.75 + len, y),
          linePaint);
    }

    // Top arc decoration
    paint.color = Colors.white.withValues(alpha: 0.04);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 40;
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(size.width / 2, -size.height * 0.3),
          radius: size.height * 0.6),
      0,
      math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
