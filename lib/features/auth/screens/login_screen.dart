import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/grab_widgets.dart';
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
              child: Column(children: [
                _InputField(
                  controller: _phoneCtrl,
                  label: 'Số điện thoại',
                  hint: 'Nhập số điện thoại',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập số điện thoại';
                    }
                    if (v.trim().length < 9) {
                      return 'Số điện thoại không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _InputField(
                  controller: _passCtrl,
                  label: 'Mật khẩu',
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
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
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    if (v.length < 6) {
                      return 'Mật khẩu tối thiểu 6 ký tự';
                    }
                    return null;
                  },
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 16),
                  GrabErrorBox(auth.error!),
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

// ── Input field ───────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: AppColors.textSecondary, fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(icon, size: 20, color: AppColors.textSecondary),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixIcon)
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          filled: true,
          fillColor: const Color(0xFFF8F8F8),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.danger, width: 1.5),
          ),
        ),
      ),
    ]);
  }
}
