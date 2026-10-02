import 'package:flutter/material.dart';

import '../../../core/widgets/app_decor_widgets.dart';
import '../../../core/widgets/glass_decor.dart';
import '../../../core/theme/app_theme.dart';

/// Khung chung cho các màn xác thực con (đăng ký, OTP, quên mật khẩu): nút
/// quay lại, chỉ báo bước, phần tiêu đề (icon + tiêu đề + mô tả) rồi nội dung
/// dạng card và liên kết ở chân trang.
class AuthPage extends StatelessWidget {
  final VoidCallback onBack;
  final int? step;
  final int totalSteps;
  final IconData icon;
  final String title;
  final String subtitle;

  /// Phần in đậm nối sau [subtitle] (vd số điện thoại), rồi tới [subtitleSuffix].
  final String? highlight;
  final String? subtitleSuffix;
  final List<Widget> children;
  final Widget? footer;

  const AuthPage({
    super.key,
    required this.onBack,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.step,
    this.totalSteps = 2,
    this.highlight,
    this.subtitleSuffix,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;
    const overlap = 32.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(bottom: bottom + AppSpacing.xl2 + overlap),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header gradient: quay lại + icon + tiêu đề ────────────────────
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, top + AppSpacing.md,
                AppSpacing.lg, overlap + 20),
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            // clipBehavior.none: đốm sáng tràn ra ngoài vùng đệm, chỉ bị cắt ở mép
            // header (Container có Clip.antiAlias) thay vì thành hình chữ nhật.
            child: Stack(clipBehavior: Clip.none, children: [
              const Positioned(
                  top: -50,
                  left: -90,
                  child: SoftGlow(
                      color: Color(0xFFFFE08A), diameter: 260, alpha: 0.5)),
              const Positioned(
                  bottom: -50,
                  right: -80,
                  child: SoftGlow(
                      color: Color(0xFFFF5A2A), diameter: 260, alpha: 0.45)),
              const Positioned(
                  top: 6, right: -40,
                  child: SoftGlow(
                      color: Color(0xFF3DBE6B), diameter: 170, alpha: 0.38)),
              const Positioned(top: 56, right: 34, child: GlassOrb(size: 26)),
              const Positioned(
                  bottom: 18, left: 30, child: GlassOrb(size: 34)),
              const Positioned(
                  bottom: 6, right: 64, child: GlassOrb(size: 22)),
              Column(children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GlassIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    iconSize: 18,
                    color: Colors.white,
                    tooltip: 'Quay lại',
                    onPressed: onBack,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                GlassPanel(
                  radius: 22,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(icon, color: AppColors.primary, size: 30),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.screenTitle.copyWith(
                        fontSize: AppFontSize.xxl,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const SizedBox(height: AppSpacing.xs),
                Text.rich(
                  TextSpan(
                    style: AppTextStyles.body.copyWith(
                        color: Colors.white.withValues(alpha: .9), height: 1.5),
                    children: [
                      TextSpan(text: subtitle),
                      if (highlight != null)
                        TextSpan(
                          text: highlight,
                          style: AppTextStyles.bodyStrong
                              .copyWith(color: Colors.white),
                        ),
                      if (subtitleSuffix != null)
                        TextSpan(text: subtitleSuffix),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (step != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(children: [
                    for (var i = 0; i < totalSteps; i++) ...[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withValues(alpha: i < step! ? 1 : .3),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                      ),
                      if (i < totalSteps - 1) const SizedBox(width: 6),
                    ],
                  ]),
                ],
              ]),
            ]),
          ),

          // ── Nội dung: đè lên mép header ───────────────────────────────────
          Transform.translate(
            offset: const Offset(0, -overlap),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(children: [
                ...children,
                if (footer != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Center(child: footer),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Card chứa một nhóm trường nhập, cùng kiểu với card của màn đăng nhập.
class AuthCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const AuthCard({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        // Thẻ đầu tiên đè lên mép dưới header nên phải đặc: kính trong sẽ để lộ
        // đường cong cam của header xuyên qua.
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.glassBorder, width: 1.2),
        boxShadow: context.isDark ? null : AppShadows.soft,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Text(title!,
              style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: AppSpacing.lg),
        ],
        ...children,
      ]),
    );
  }
}

/// Dòng đếm ngược / gửi lại mã OTP dùng chung.
class ResendOtpRow extends StatelessWidget {
  final int countdown;
  final bool busy;
  final VoidCallback onResend;

  const ResendOtpRow({
    super.key,
    required this.countdown,
    required this.onResend,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (countdown > 0) {
      return Text('Gửi lại sau $countdown giây',
          style: AppTextStyles.label.copyWith(color: c.textSecondary));
    }
    return TextButton(
      onPressed: busy ? null : onResend,
      child: const Text('Gửi lại mã OTP'),
    );
  }
}
