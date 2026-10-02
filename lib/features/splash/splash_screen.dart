import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_decor.dart';
import '../version/providers/app_version_provider.dart';

/// TẠM THỜI: true = giữ nguyên ở màn splash để chỉnh giao diện (không tự chuyển
/// sang đăng nhập/trang chủ). Nhớ đặt lại false trước khi phát hành.
const bool kHoldSplashForDesign = false;

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  bool _dialogShown = false;

  // Tấm kính + logo: scale (overshoot nhẹ) + fade khi vào màn hình.
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  // Nội dung phụ (thanh tải): fade sau logo một nhịp.
  late final Animation<double> _textFade;

  // Nhịp "thở" của tấm kính và các viên kính nổi, lặp vô hạn.
  late final AnimationController _pulseCtrl;

  // Các đốm sáng phía sau trôi chậm qua lại để kính có thứ để "khúc xạ".
  late final AnimationController _driftCtrl;

  // Vệt sáng quét chéo qua mặt kính.
  late final AnimationController _sheenCtrl;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
    _logoFade = CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut));
    _textFade = CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOut));
    _logoCtrl.forward();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat();
    _driftCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 9))
      ..repeat(reverse: true);
    _sheenCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3400))
      ..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    await ref.read(appVersionProvider.notifier).check();
    if (!mounted || kHoldSplashForDesign) return;
    ref.read(splashReadyProvider.notifier).state = true;
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _pulseCtrl.dispose();
    _driftCtrl.dispose();
    _sheenCtrl.dispose();
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            // ── Nền gradient cam thương hiệu ───────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryGradientStart,
                    AppColors.primaryGradientMiddle,
                    AppColors.primaryGradientEnd,
                  ],
                ),
              ),
            ),

            // ── Đốm sáng mềm phía sau, trôi chậm ───────────────────────────
            AnimatedBuilder(
              animation: _driftCtrl,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_driftCtrl.value);
                final size = MediaQuery.sizeOf(context);
                return Stack(children: [
                  _Glow(
                    color: const Color(0xFFFFE08A),
                    diameter: 360,
                    left: -120 + 70 * t,
                    top: size.height * 0.08 + 40 * t,
                    alpha: 0.55,
                  ),
                  _Glow(
                    color: const Color(0xFFFF5A2A),
                    diameter: 420,
                    right: -160 + 60 * (1 - t),
                    bottom: size.height * 0.04 + 30 * t,
                    alpha: 0.55,
                  ),
                  _Glow(
                    color: const Color(0xFF3DBE6B),
                    diameter: 260,
                    right: -50 + 50 * t,
                    top: size.height * 0.18 + 60 * (1 - t),
                    alpha: 0.45,
                  ),
                ]);
              },
            ),

            // ── Vài viên kính nhỏ nổi xung quanh ───────────────────────────
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                final breathe =
                    0.5 + 0.5 * math.sin(_pulseCtrl.value * 2 * math.pi);
                final size = MediaQuery.sizeOf(context);
                final top = MediaQuery.paddingOf(context).top;
                return Stack(children: [
                  Positioned(
                      top: top + 70 + 6 * breathe,
                      left: 34,
                      child: const GlassOrb(size: 54)),
                  Positioned(
                      top: size.height * 0.30 - 8 * breathe,
                      right: 26,
                      child: const GlassOrb(size: 34)),
                  Positioned(
                      bottom: size.height * 0.22 + 8 * breathe,
                      left: 28,
                      child: const GlassOrb(size: 40)),
                  Positioned(
                      bottom: size.height * 0.10 - 6 * breathe,
                      right: 52,
                      child: const GlassOrb(size: 64)),
                ]);
              },
            ),

            // ── Tấm kính mờ chứa logo + thanh tải ───────────────────────────
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_logoCtrl, _pulseCtrl]),
                    builder: (_, child) {
                      final breathe =
                          0.5 + 0.5 * math.sin(_pulseCtrl.value * 2 * math.pi);
                      return Opacity(
                        opacity: _logoFade.value,
                        child: Transform.translate(
                          offset: Offset(0, -4 * breathe),
                          child: Transform.scale(
                              scale: _logoScale.value, child: child),
                        ),
                      );
                    },
                    child: GlassPanel(
                      sheen: _sheenCtrl,
                      margin: const EdgeInsets.symmetric(horizontal: 36),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 34, 28, 30),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Image.asset(
                            'assets/images/logo-vertical.png',
                            width: 210,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: AppSpace.lg),
                          // Tải: phản ánh thời gian khởi tạo thật.
                          AnimatedBuilder(
                            animation: _textFade,
                            builder: (_, child) =>
                                Opacity(opacity: _textFade.value, child: child),
                            child: Column(children: [
                              SizedBox(
                                width: 150,
                                height: 5,
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                  child: LinearProgressIndicator(
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: .16),
                                    valueColor: const AlwaysStoppedAnimation(
                                        AppColors.primary),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpace.md),
                              Text('Đang khởi động...',
                                  style: AppTextStyles.label.copyWith(
                                      color: AppColors.textSecondary)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Text('Cập nhật bắt buộc',
              style: TextStyle(
                  fontSize: AppFontSize.xl, fontWeight: FontWeight.w800)),
          content: Text(v.message,
              style: const TextStyle(
                  fontSize: AppFontSize.md,
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

/// Đốm sáng nền có vị trí (bọc [SoftGlow] trong Positioned).
class _Glow extends StatelessWidget {
  final Color color;
  final double diameter;
  final double alpha;
  final double? left, right, top, bottom;

  const _Glow({
    required this.color,
    required this.diameter,
    required this.alpha,
    this.left,
    this.right,
    this.top,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) => Positioned(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        child: SoftGlow(color: color, diameter: diameter, alpha: alpha),
      );
}
