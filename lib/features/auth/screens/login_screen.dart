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
  final _formKey   = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
      phone:    _phoneCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!ok && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth   = ref.watch(authProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final safeB  = MediaQuery.of(context).padding.bottom;
    final safeT  = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, safeT + 48, 28, bottom + safeB + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            // ── Logo ────────────────────────────────────────────────
            Center(
              child: Image.asset(
                'assets/images/logo-login.png',
                width: 160,
              ),
            ),
            const SizedBox(height: 32),

            // ── Divider line ─────────────────────────────────────────
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 40, height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B1A), Color(0xFFE84D00)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Heading ─────────────────────────────────────────────
            const Text('Đăng nhập',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            const Text('Quản lý đơn giao hàng cho cửa hàng',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 32),

            // ── Form ────────────────────────────────────────────────
            Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const AppLabel('Số điện thoại'),
                const SizedBox(height: 8),
                AppField(
                  controller: _phoneCtrl,
                  hint: 'Nhập số điện thoại',
                  prefixIcon: Icon(Icons.phone_outlined,
                      size: 20, color: context.colors.textSecondary),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: Validators.phone,
                ),
                const SizedBox(height: 16),
                const AppLabel('Mật khẩu'),
                const SizedBox(height: 8),
                AppField(
                  controller: _passCtrl,
                  hint: '••••••••',
                  prefixIcon: Icon(Icons.lock_outline_rounded,
                      size: 20, color: context.colors.textSecondary),
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
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
                  const SizedBox(height: 16),
                  AppErrorBox(auth.error!),
                ],
              ]),
            ),

            const SizedBox(height: 12),

            // ── Forgot password ──────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => context.push('/forgot-password'),
                child: const Text('Quên mật khẩu?',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
            ),

            const SizedBox(height: 20),

            // ── Button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: auth.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Đăng nhập',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),

            const SizedBox(height: 24),

            // ── Register link ────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Chưa có tài khoản? ',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
              GestureDetector(
                onTap: () => context.push('/register'),
                child: const Text('Đăng ký ngay',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
