import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form_widgets.dart';
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
    final size = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final safeB = MediaQuery.of(context).padding.bottom;
    final safeT = MediaQuery.of(context).padding.top;

    final headerHeight = size.height * 0.32;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header cam, bo cong cạnh dưới ────────────────────────
            ClipPath(
              clipper: const _HeaderClipper(),
              child: Container(
                height: headerHeight,
                padding: EdgeInsets.only(top: safeT),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpace.md),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                        child: Image.asset('assets/images/logo.png',
                            width: 32, height: 32, color: Colors.white),
                      ),
                      const SizedBox(height: AppSpace.md),
                      const Text(
                        'FLASH SHIP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Quản lý đơn giao hàng cho cửa hàng',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Khối trắng đè lên header ──────────────────────────────
            // Container không cho phép margin âm (assertion isNonNegative),
            // nên dùng Transform.translate để kéo khối lên đè vào header —
            // phần không gian layout bị "thừa" phía dưới sau khi dịch chỉ
            // lộ ra nền trắng của Scaffold nên không tạo khoảng hở nhìn thấy.
            Transform.translate(
              offset: const Offset(0, -AppSpace.xxl),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.xl),
                    topRight: Radius.circular(AppRadius.xl),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpace.xl + AppSpace.xs,
                  AppSpace.xxl,
                  AppSpace.xl + AppSpace.xs,
                  safeB + AppSpace.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Heading ─────────────────────────────────────────
                    const Text('Đăng nhập',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5)),
                    const SizedBox(height: AppSpace.xs),
                    const Text('Nhập thông tin để tiếp tục sử dụng',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpace.xxl),

                    // ── Form ────────────────────────────────────────────
                    Form(
                      key: _formKey,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppLabel('Số điện thoại'),
                            const SizedBox(height: AppSpace.sm),
                            AppField(
                              controller: _phoneCtrl,
                              hint: 'Nhập số điện thoại',
                              prefixIcon: Icon(Icons.phone_outlined,
                                  size: 20,
                                  color: context.colors.textSecondary),
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              validator: Validators.phone,
                            ),
                            const SizedBox(height: AppSpace.lg),
                            const AppLabel('Mật khẩu'),
                            const SizedBox(height: AppSpace.sm),
                            AppField(
                              controller: _passCtrl,
                              hint: '••••••••',
                              prefixIcon: Icon(Icons.lock_outline_rounded,
                                  size: 20,
                                  color: context.colors.textSecondary),
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              suffixIcon: GestureDetector(
                                onTap: () =>
                                    setState(() => _obscure = !_obscure),
                                child: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              validator: Validators.password,
                            ),
                            if (auth.error != null) ...[
                              const SizedBox(height: AppSpace.lg),
                              AppErrorBox(auth.error!),
                            ],
                          ]),
                    ),

                    const SizedBox(height: AppSpace.md),

                    // ── Forgot password ──────────────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => context.push('/forgot-password'),
                        child: const Text('Quên mật khẩu?',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ),

                    const SizedBox(height: AppSpace.lg + AppSpace.xs),

                    // ── Button ────────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: auth.isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md)),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Đăng nhập',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                      ),
                    ),

                    const SizedBox(height: AppSpace.xl),

                    // ── Register link ────────────────────────────────────
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('Chưa có tài khoản? ',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: const Text('Đăng ký ngay',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Clipper cho cạnh cong ở đáy header ────────────────────────────────────────
class _HeaderClipper extends CustomClipper<Path> {
  const _HeaderClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 32)
      ..quadraticBezierTo(
        size.width / 2,
        size.height + 24,
        size.width,
        size.height - 32,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
