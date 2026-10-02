import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Đốm sáng mềm (tròn, mờ dần ra ngoài) làm nền cho kính "khúc xạ". Không tự
/// định vị — bọc trong Positioned khi cần.
class SoftGlow extends StatelessWidget {
  final Color color;
  final double diameter;
  final double alpha;

  const SoftGlow({
    super.key,
    required this.color,
    required this.diameter,
    this.alpha = 0.5,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ]),
        ),
      );
}

/// Viên kính tròn nhỏ: làm mờ nền phía sau, viền trắng mảnh.
class GlassOrb extends StatelessWidget {
  final double size;
  const GlassOrb({super.key, required this.size});

  @override
  Widget build(BuildContext context) => ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: .38),
                  Colors.white.withValues(alpha: .08),
                ],
              ),
              border: Border.all(
                  color: Colors.white.withValues(alpha: .45), width: 1),
            ),
          ),
        ),
      );
}

/// Tấm kính mờ (glassmorphism) đặt trên nền màu: làm mờ nền, lớp phủ trắng
/// trong suốt chuyển sắc, viền sáng mảnh, bóng mềm và — nếu có [sheen] — một
/// vệt sáng quét chéo định kỳ.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final Animation<double>? sheen;
  final double radius;
  final EdgeInsetsGeometry margin;

  const GlassPanel({
    super.key,
    required this.child,
    this.sheen,
    this.radius = 36,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: .18),
              blurRadius: 56,
              spreadRadius: -10,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Stack(children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: .70),
                      Colors.white.withValues(alpha: .44),
                    ],
                  ),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: .75), width: 1.4),
                ),
                child: child,
              ),
              if (sheen != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: sheen!,
                      builder: (_, __) {
                        final t = sheen!.value;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-2.2 + 4.4 * t, -1),
                              end: Alignment(-1.2 + 4.4 * t, 1),
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: .32),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
