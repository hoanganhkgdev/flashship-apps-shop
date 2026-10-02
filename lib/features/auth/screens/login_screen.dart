import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_decor_widgets.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/glass_decor.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(authProvider.notifier).clearError());
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
          phone: _phoneCtrl.text.trim(),
          password: _passCtrl.text,
        );
    if (!ok && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;
    final c = context.colors;
    const overlap = 36.0;
    final headerHeight = top + 250;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(bottom: bottom + AppSpacing.xl2),
        child: Stack(children: [
          _LoginHeader(height: headerHeight, topInset: top),
          Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg, headerHeight - overlap, AppSpacing.lg, 0),
            child: Form(
              key: _formKey,
              child: Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    // Thẻ đè lên mép dưới header nên phải đặc: kính trong sẽ để
                    // lộ đường cong cam của header xuyên qua.
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: c.glassBorder, width: 1.2),
                    boxShadow: context.isDark ? null : AppShadows.raised,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        AppIconBadge(
                            icon: Icons.person_rounded,
                            color: c.primary,
                            size: 48),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Đăng nhập',
                                  style: AppTextStyles.screenTitle.copyWith(
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: AppSpacing.xxs),
                              Text('Tạo đơn nhanh · Quản lý giao hàng dễ dàng',
                                  style: AppTextStyles.label
                                      .copyWith(color: c.textSecondary)),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.xl),
                      PhoneField(
                        controller: _phoneCtrl,
                        hint: '0912 345 678',
                        fillColor: c.surfaceAlt,
                        outlined: true,
                        textInputAction: TextInputAction.next,
                        validator: Validators.phone,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppField(
                        controller: _passCtrl,
                        hint: 'Mật khẩu',
                        fillColor: c.surfaceAlt,
                        outlined: true,
                        prefixIcon: Icon(Icons.lock_outline_rounded,
                            size: AppSize.iconMd, color: c.textSecondary),
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: AppSize.iconMd,
                            color: c.textSecondary,
                          ),
                        ),
                        validator: Validators.password,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          child: const Text('Quên mật khẩu?'),
                        ),
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        AppErrorBox(auth.error!),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppButton(
                        label: 'Đăng nhập',
                        isLoading: auth.isLoading,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Chưa có tài khoản? ',
                        style: AppTextStyles.body
                            .copyWith(color: c.textSecondary)),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Đăng ký ngay'),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Phần đầu trang: nền gradient cam bo cong phía dưới, đốm sáng mềm phía sau và
/// logo đặt trên tấm kính mờ — cùng ngôn ngữ với màn splash.
class _LoginHeader extends StatelessWidget {
  final double height;
  final double topInset;
  const _LoginHeader({required this.height, required this.topInset});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
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
      child: Stack(children: [
        // Đốm sáng để kính có thứ "khúc xạ".
        const Positioned(
          top: -40,
          left: -90,
          child: SoftGlow(
              color: Color(0xFFFFE08A), diameter: 280, alpha: 0.55),
        ),
        const Positioned(
          bottom: -30,
          right: -80,
          child: SoftGlow(
              color: Color(0xFFFF5A2A), diameter: 300, alpha: 0.50),
        ),
        const Positioned(
          top: 30,
          right: -50,
          child: SoftGlow(
              color: Color(0xFF3DBE6B), diameter: 190, alpha: 0.40),
        ),

        // Vài viên kính nhỏ nổi xung quanh.
        Positioned(top: topInset + 34, left: 26, child: const GlassOrb(size: 44)),
        Positioned(
            top: topInset + 96, right: 30, child: const GlassOrb(size: 26)),
        const Positioned(bottom: 62, left: 40, child: GlassOrb(size: 30)),
        const Positioned(bottom: 50, right: 52, child: GlassOrb(size: 48)),

        // Logo trên tấm kính mờ.
        Padding(
          padding: EdgeInsets.only(top: topInset, bottom: 36),
          child: Center(
            child: GlassPanel(
              radius: 30,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                // Ảnh logo có viền trong suốt rộng: cắt bớt để logo to hơn mà
                // tấm kính vẫn gọn.
                child: ClipRect(
                  child: Align(
                    alignment: const Alignment(0.13, -0.02),
                    widthFactor: 0.78,
                    heightFactor: 0.68,
                    child: Image.asset('assets/images/logo-vertical.png',
                        width: 210, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
