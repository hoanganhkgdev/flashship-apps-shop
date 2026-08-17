import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/step_progress_bar.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _confCtrl  = TextEditingController();

  final _phoneKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();

  bool _step2    = false;
  bool _loading  = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_phoneKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).post('/shop/auth/forgot-password', data: {
        'phone': _phoneCtrl.text.trim(),
      });
      if (mounted) setState(() { _step2 = true; });
    } catch (e) {
      if (mounted) setState(() { _error = parseApiError(e, fallback: 'Đã xảy ra lỗi, vui lòng thử lại'); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).post('/shop/auth/reset-password', data: {
        'phone':                 _phoneCtrl.text.trim(),
        'otp':                   _otpCtrl.text.trim(),
        'password':              _passCtrl.text,
        'password_confirmation': _confCtrl.text,
      });
      if (mounted) {
        AppSnackbar.success(context, 'Đặt lại mật khẩu thành công!');
        context.go('/login');
      }
    } catch (e) {
      if (mounted) setState(() { _error = parseApiError(e, fallback: 'Đã xảy ra lỗi, vui lòng thử lại'); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeT  = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final safeB  = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, safeT + 24, 28, bottom + safeB + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Back ──────────────────────────────────────────────────
            GestureDetector(
              onTap: () => _step2
                  ? setState(() { _step2 = false; _error = null; })
                  : context.pop(),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 32),

            // ── Chỉ báo 2 bước ────────────────────────────────────────
            StepProgressBar(currentStep: _step2 ? 2 : 1, totalSteps: 2),
            const SizedBox(height: 24),

            // ── Icon ─────────────────────────────────────────────────
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.lock_reset_rounded,
                  size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 20),

            // ── Heading ──────────────────────────────────────────────
            Text(
              _step2 ? 'Nhập mã OTP' : 'Quên mật khẩu',
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, letterSpacing: -0.5),
            ),
            const SizedBox(height: 6),
            Text(
              _step2
                  ? 'Nhập mã 6 số vừa gửi tới ${_phoneCtrl.text.trim()} và đặt mật khẩu mới'
                  : 'Nhập số điện thoại để nhận mã xác nhận',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 32),

            // ── Step 1: Phone ─────────────────────────────────────────
            if (!_step2) ...[
              Form(
                key: _phoneKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const AppLabel('Số điện thoại'),
                  const SizedBox(height: 8),
                  AppField(
                    controller: _phoneCtrl,
                    hint: 'Nhập số điện thoại đã đăng ký',
                    prefixIcon: Icon(Icons.phone_outlined,
                        size: 20, color: context.colors.textSecondary),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _sendOtp(),
                    validator: Validators.phone,
                  ),
                ]),
              ),
            ],

            // ── Step 2: OTP + new password ────────────────────────────
            if (_step2) ...[
              Form(
                key: _resetKey,
                child: Column(children: [
                  const AppLabel('Mã OTP'),
                  const SizedBox(height: 8),
                  AppField(
                    controller: _otpCtrl,
                    hint: '6 chữ số',
                    prefixIcon: Icon(Icons.pin_outlined,
                        size: 20, color: context.colors.textSecondary),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().length != 6) {
                        return 'Mã OTP gồm 6 chữ số';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const AppLabel('Mật khẩu mới'),
                  const SizedBox(height: 8),
                  AppField(
                    controller: _passCtrl,
                    hint: 'Tối thiểu 6 ký tự',
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        size: 20, color: context.colors.textSecondary),
                    obscureText: _obscure1,
                    textInputAction: TextInputAction.next,
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscure1 = !_obscure1),
                      child: Icon(
                        _obscure1
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20, color: AppColors.textSecondary,
                      ),
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 16),
                  const AppLabel('Xác nhận mật khẩu'),
                  const SizedBox(height: 8),
                  AppField(
                    controller: _confCtrl,
                    hint: 'Nhập lại mật khẩu mới',
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        size: 20, color: context.colors.textSecondary),
                    obscureText: _obscure2,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _resetPassword(),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscure2 = !_obscure2),
                      child: Icon(
                        _obscure2
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20, color: AppColors.textSecondary,
                      ),
                    ),
                    validator: (v) {
                      if (v != _passCtrl.text) {
                        return 'Mật khẩu không khớp';
                      }
                      return null;
                    },
                  ),
                ]),
              ),
            ],

            // ── Error ─────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.danger)),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 32),

            // ── Button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _loading
                    ? null
                    : (_step2 ? _resetPassword : _sendOtp),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _step2 ? 'Đặt lại mật khẩu' : 'Gửi mã OTP',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),

            if (_step2) ...[
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _loading ? null : _sendOtp,
                  child: Text('Gửi lại mã OTP',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: _loading
                              ? AppColors.textSecondary
                              : AppColors.primary)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
