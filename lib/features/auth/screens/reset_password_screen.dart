import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/otp_input.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String phone;

  const ResetPasswordScreen({super.key, required this.phone});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _State();
}

class _State extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = OtpInputController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirm = false;
  bool _loading = false;
  String? _error;
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _countdown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 0) {
        timer.cancel();
        return;
      }
      if (mounted) setState(() => _countdown--);
    });
  }

  Future<void> _resend() async {
    if (_countdown > 0 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref
        .read(authProvider.notifier)
        .sendForgotPasswordOtp(widget.phone);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
    if (error == null) _startCountdown();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_otpController.otp.length != 6) {
      setState(() => _error = 'Mã OTP gồm 6 chữ số');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref.read(authProvider.notifier).resetPassword(
          phone: widget.phone,
          otp: _otpController.otp,
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
    if (error == null) {
      AppSnackbar.success(context, 'Đặt lại mật khẩu thành công');
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final digits = widget.phone.replaceAll(RegExp(r'\D'), '');
    final displayPhone = digits.length == 10
        ? '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}'
        : widget.phone;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const _ResetHeader(),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _PhoneBanner(phone: displayPhone),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.divider),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeading(
                        icon: Icons.sms_outlined,
                        title: 'Mã xác nhận',
                        color: c.primary,
                      ),
                      const SizedBox(height: 14),
                      OtpInput(
                        controller: _otpController,
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_otpController.otp.length}/6 chữ số',
                          style: AppTextStyles.caption.copyWith(
                            color: _otpController.otp.length == 6
                                ? c.success
                                : c.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Divider(height: 1, color: c.divider),
                      const SizedBox(height: 16),
                      _SectionHeading(
                        icon: Icons.lock_reset_rounded,
                        title: 'Mật khẩu mới',
                        color: c.primary,
                      ),
                      const SizedBox(height: 14),
                      const AppLabel('Mật khẩu mới'),
                      const SizedBox(height: 7),
                      AppField(
                        controller: _passwordController,
                        hint: 'Tối thiểu 6 ký tự',
                        fillColor: c.surfaceAlt,
                        outlined: true,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icon(Icons.lock_outline_rounded,
                            size: 20, color: c.textSecondary),
                        suffixIcon: IconButton(
                          tooltip:
                              _showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: c.textSecondary,
                          ),
                        ),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 14),
                      const AppLabel('Xác nhận mật khẩu mới'),
                      const SizedBox(height: 7),
                      AppField(
                        controller: _confirmController,
                        hint: 'Nhập lại mật khẩu mới',
                        fillColor: c.surfaceAlt,
                        outlined: true,
                        obscureText: !_showConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        prefixIcon: Icon(Icons.lock_outline_rounded,
                            size: 20, color: c.textSecondary),
                        suffixIcon: IconButton(
                          tooltip:
                              _showConfirm ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                          onPressed: () =>
                              setState(() => _showConfirm = !_showConfirm),
                          icon: Icon(
                            _showConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                            color: c.textSecondary,
                          ),
                        ),
                        validator: (value) => value != _passwordController.text
                            ? 'Mật khẩu không khớp'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        AppErrorBox(_error!),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: c.primary,
                            foregroundColor: c.onPrimary,
                            disabledBackgroundColor:
                                c.primary.withValues(alpha: .5),
                            disabledForegroundColor: c.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _loading
                              ? const SizedBox.square(
                                  dimension: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 20),
                          label: Text(
                            _loading ? 'Đang cập nhật...' : 'Đặt lại mật khẩu',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ResendRow(
                countdown: _countdown,
                loading: _loading,
                onResend: _resend,
              ),
              const SizedBox(height: 14),
              const _SecurityNote(),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ResetHeader extends StatelessWidget {
  const _ResetHeader();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.isDark ? c.primarySoft : const Color(0xFFFFE9DE),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            IconButton(
              tooltip: 'Quay lại',
              onPressed: () => Navigator.maybePop(context),
              style: IconButton.styleFrom(
                fixedSize: const Size.square(44),
                backgroundColor: c.surface,
                side: BorderSide(color: c.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: c.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Đặt lại '),
                      TextSpan(
                        text: 'mật khẩu',
                        style: TextStyle(color: c.primary),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Xác nhận OTP và tạo mật khẩu mới',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: .84),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '2/2',
                style: AppTextStyles.caption.copyWith(
                  color: c.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PhoneBanner extends StatelessWidget {
  final String phone;

  const _PhoneBanner({required this.phone});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withValues(alpha: .20)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.sms_outlined, size: 20, color: c.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mã OTP đã được gửi đến',
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                  )),
              const SizedBox(height: 2),
              Text(
                phone,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.bodyStrong.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]);
}

class _ResendRow extends StatelessWidget {
  final int countdown;
  final bool loading;
  final VoidCallback onResend;

  const _ResendRow({
    required this.countdown,
    required this.loading,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider),
      ),
      child: Row(children: [
        Icon(Icons.refresh_rounded, size: 19, color: c.textSecondary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            countdown > 0 ? 'Gửi lại mã sau' : 'Bạn chưa nhận được mã?',
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        if (countdown > 0)
          Text(
            '${countdown}s',
            style: AppTextStyles.caption.copyWith(
              color: c.primary,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          TextButton(
            onPressed: loading ? null : onResend,
            style: TextButton.styleFrom(
              foregroundColor: c.primary,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Gửi lại'),
          ),
      ]),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 16, color: c.success),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Không chia sẻ mật khẩu hoặc mã OTP',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}
