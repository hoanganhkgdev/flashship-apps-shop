import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
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
  late final AnimationController _introController;
  late final AnimationController _pulseController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _fade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0, .72, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: .88, end: 1).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    await Future.wait([
      ref.read(appVersionProvider.notifier).check(),
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ]);
    if (!mounted || kHoldSplashForDesign) return;
    final version = ref.read(appVersionProvider);
    if (!version.needsForceUpdate) {
      ref.read(splashReadyProvider.notifier).state = true;
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(appVersionProvider);

    if (version.isChecked && version.needsForceUpdate && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showForceUpdateDialog(context, version);
      });
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _SplashPalette.peach,
        body: Stack(
          children: [
            const Positioned(
              top: -110,
              right: -82,
              child: _DecorativeCircle(
                size: 260,
                color: _SplashPalette.orange,
                opacity: .08,
              ),
            ),
            const Positioned(
              top: 126,
              right: 34,
              child: _DecorativeCircle(
                size: 28,
                color: _SplashPalette.green,
                opacity: .16,
              ),
            ),
            const Positioned(
              bottom: 72,
              left: -72,
              child: _DecorativeCircle(
                size: 184,
                color: _SplashPalette.orange,
                opacity: .07,
              ),
            ),
            Positioned(
              left: 32,
              top: MediaQuery.paddingOf(context).top + 72,
              child: const _Spark(size: 8),
            ),
            Positioned(
              right: 52,
              bottom: MediaQuery.paddingOf(context).bottom + 142,
              child: const _Spark(size: 11),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 650;
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          compact ? 18 : 30,
                          24,
                          compact ? 16 : 26,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _ShopBadge(),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: compact ? 22 : 36,
                              ),
                              child: FadeTransition(
                                opacity: _fade,
                                child: ScaleTransition(
                                  scale: _scale,
                                  child: _BrandContent(
                                    compact: compact,
                                    pulse: _pulseController,
                                  ),
                                ),
                              ),
                            ),
                            FadeTransition(
                              opacity: _fade,
                              child: _LoadingStatus(
                                animation: _pulseController,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForceUpdateDialog(BuildContext context, AppVersionState version) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: Row(children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _SplashPalette.peach,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Text(
                'Cập nhật bắt buộc',
                style: TextStyle(
                  fontSize: AppFontSize.bodyLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ]),
          content: Text(
            version.message,
            style: const TextStyle(
              fontSize: AppFontSize.body,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openStore(version.storeUrl),
                style: FilledButton.styleFrom(
                  backgroundColor: _SplashPalette.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cập nhật ngay',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

abstract final class _SplashPalette {
  static const peach = Color(0xFFFFEDE4);
  static const orange = AppColors.primary;
  static const green = Color(0xFF169447);
  static const ink = AppColors.textPrimary;
  static const muted = AppColors.textSecondary;
}

class _BrandContent extends StatelessWidget {
  const _BrandContent({required this.compact, required this.pulse});

  final bool compact;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 104.0 : 124.0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -2.5 * pulse.value),
              child: Transform.scale(
                scale: .99 + (.02 * pulse.value),
                child: child,
              ),
            ),
            child: Container(
              width: logoSize,
              height: logoSize,
              padding: EdgeInsets.all(compact ? 15 : 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(compact ? 30 : 36),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _SplashPalette.orange.withValues(alpha: .12),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                semanticLabel: 'Flash Ship',
              ),
            ),
          ),
          SizedBox(height: compact ? 20 : 26),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: compact ? 33 : 38,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: _SplashPalette.ink,
                ),
                children: const [
                  TextSpan(text: 'Flash '),
                  TextSpan(
                    text: 'Ship',
                    style: TextStyle(color: _SplashPalette.orange),
                  ),
                ],
              ),
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Giao hàng nhanh, vận hành cửa hàng nhẹ nhàng',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: AppFontSize.bodyLarge,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: _SplashPalette.muted,
            ),
          ),
          SizedBox(height: compact ? 16 : 22),
          const _FeatureLine(),
        ],
      ),
    );
  }
}

class _ShopBadge extends StatelessWidget {
  const _ShopBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: Colors.white),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 17,
              color: _SplashPalette.orange,
            ),
            SizedBox(width: 7),
            Expanded(
              child: Text(
                'Dành cho đối tác cửa hàng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w600,
                  color: _SplashPalette.ink,
                ),
              ),
            ),
          ],
        ),
      );
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine();

  @override
  Widget build(BuildContext context) => const Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _FeatureChip(icon: Icons.bolt_rounded, label: 'Tạo đơn nhanh'),
          _FeatureChip(icon: Icons.route_outlined, label: 'Theo dõi dễ'),
          _FeatureChip(icon: Icons.insights_rounded, label: 'Quản lý gọn'),
        ],
      );
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .74),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _SplashPalette.orange),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w600,
                  color: _SplashPalette.muted,
                ),
              ),
            ],
          ),
        ),
      );
}

class _LoadingStatus extends StatelessWidget {
  const _LoadingStatus({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 350),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .76),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final active = (animation.value * 2.99).floor();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 170),
                      width: index == active ? 15 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: _SplashPalette.orange.withValues(
                          alpha: index == active ? 1 : .2,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Đang chuẩn bị không gian bán hàng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: AppFontSize.caption,
                  fontWeight: FontWeight.w600,
                  color: _SplashPalette.muted,
                ),
              ),
            ),
          ],
        ),
      );
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      );
}

class _Spark extends StatelessWidget {
  const _Spark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: .78,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _SplashPalette.orange.withValues(alpha: .26),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}
