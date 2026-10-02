import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/otp_input.dart';
import '../data/auth_repository.dart';
import '../widgets/auth_layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpInputCtl = OtpInputController();
  final _passCtrl = TextEditingController();
  final _confCtrl = TextEditingController();

  final _phoneKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();

  bool _step2 = false;
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  int _countdown = 60;
  Timer? _timer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpInputCtl.dispose();
    _passCtrl.dispose();
    _confCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 0) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
    });
  }

  Future<void> _sendOtp() async {
    if (!_phoneKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendForgotPasswordOtp(_phoneCtrl.text.trim());
      if (mounted) {
        setState(() {
          _step2 = true;
        });
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              parseApiError(e, fallback: 'Đã xảy ra lỗi, vui lòng thử lại');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Dùng riêng cho nút "Gửi lại mã OTP" ở bước 2 — không gọi
  // _phoneKey.currentState!.validate() vì Form gắn với _phoneKey chỉ tồn tại
  // ở bước 1 (currentState null ở bước 2, gọi validate() sẽ crash null-check).
  // Số điện thoại đã khoá từ bước 1 nên không cần validate lại.
  Future<void> _resendOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendForgotPasswordOtp(_phoneCtrl.text.trim());
      if (mounted) _startCountdown();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              parseApiError(e, fallback: 'Đã xảy ra lỗi, vui lòng thử lại');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    // OtpInput không phải FormField nên không tự tham gia Form.validate() —
    // kiểm tra thủ công trước, giữ đúng thông báo cũ ("Mã OTP gồm 6 chữ số").
    if (_otpInputCtl.otp.length != 6) {
      setState(() {
        _error = 'Mã OTP gồm 6 chữ số';
      });
      return;
    }
    if (!_resetKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            _phoneCtrl.text.trim(),
            _otpInputCtl.otp,
            _passCtrl.text,
          );
      if (mounted) {
        AppSnackbar.success(context, 'Đặt lại mật khẩu thành công!');
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              parseApiError(e, fallback: 'Đã xảy ra lỗi, vui lòng thử lại');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final displayPhone = digits.length == 10
        ? '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}'
        : _phoneCtrl.text.trim();

    Widget eye(bool obscure, VoidCallback onTap) => IconButton(
          onPressed: onTap,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: AppSize.iconMd,
            color: c.textSecondary,
          ),
        );

    return AuthPage(
      onBack: () => _step2
          ? setState(() {
              _step2 = false;
              _error = null;
            })
          : context.pop(),
      step: _step2 ? 2 : 1,
      icon: Icons.lock_reset_rounded,
      title: _step2 ? 'Nhập mã OTP' : 'Quên mật khẩu',
      subtitle: _step2
          ? 'Nhập mã 6 số vừa gửi tới '
          : 'Nhập số điện thoại để nhận mã xác nhận',
      highlight: _step2 ? displayPhone : null,
      subtitleSuffix: _step2 ? ' và đặt mật khẩu mới' : null,
      children: [
        AuthCard(children: [
          if (!_step2)
            Form(
              key: _phoneKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppLabel('Số điện thoại'),
                    const SizedBox(height: AppSpacing.sm),
                    PhoneField(
                      controller: _phoneCtrl,
                      fillColor: c.surfaceAlt,
                      outlined: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _sendOtp(),
                      validator: Validators.phone,
                    ),
                  ]),
            )
          else
            Form(
              key: _resetKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppLabel('Mã OTP'),
                    const SizedBox(height: AppSpacing.md),
                    OtpInput(
                      controller: _otpInputCtl,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AppLabel('Mật khẩu mới'),
                    const SizedBox(height: AppSpacing.sm),
                    AppField(
                      controller: _passCtrl,
                      hint: 'Tối thiểu 6 ký tự',
                      fillColor: c.surfaceAlt,
                      outlined: true,
                      prefixIcon: Icon(Icons.lock_outline_rounded,
                          size: AppSize.iconMd, color: c.textSecondary),
                      obscureText: _obscure1,
                      textInputAction: TextInputAction.next,
                      suffixIcon: eye(_obscure1,
                          () => setState(() => _obscure1 = !_obscure1)),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AppLabel('Xác nhận mật khẩu'),
                    const SizedBox(height: AppSpacing.sm),
                    AppField(
                      controller: _confCtrl,
                      hint: 'Nhập lại mật khẩu mới',
                      fillColor: c.surfaceAlt,
                      outlined: true,
                      prefixIcon: Icon(Icons.lock_outline_rounded,
                          size: AppSize.iconMd, color: c.textSecondary),
                      obscureText: _obscure2,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _resetPassword(),
                      suffixIcon: eye(_obscure2,
                          () => setState(() => _obscure2 = !_obscure2)),
                      validator: (v) =>
                          v != _passCtrl.text ? 'Mật khẩu không khớp' : null,
                    ),
                  ]),
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppErrorBox(_error!),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: _step2 ? 'Đặt lại mật khẩu' : 'Gửi mã OTP',
            onPressed: _step2 ? _resetPassword : _sendOtp,
            isLoading: _loading,
          ),
          if (_step2) ...[
            const SizedBox(height: AppSpacing.md),
            Center(
              child: ResendOtpRow(
                  countdown: _countdown, busy: _loading, onResend: _resendOtp),
            ),
          ],
        ]),
      ],
    );
  }
}
