import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_route.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/otp_input.dart';
import '../providers/auth_provider.dart';
import 'reset_password_screen.dart';

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
    final error = await ref
        .read(authProvider.notifier)
        .sendForgotPasswordOtp(_phoneCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
    if (error == null && mounted) {
      await Navigator.of(context).push(
        appRoute(ResetPasswordScreen(phone: _phoneCtrl.text.trim())),
      );
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
    final error = await ref
        .read(authProvider.notifier)
        .sendForgotPasswordOtp(_phoneCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
    if (error == null) _startCountdown();
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
    final error = await ref.read(authProvider.notifier).resetPassword(
          phone: _phoneCtrl.text.trim(),
          otp: _otpInputCtl.otp,
          password: _passCtrl.text,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
    if (error == null) {
      AppSnackbar.success(context, 'Đặt lại mật khẩu thành công!');
      context.go('/login');
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
          tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          onPressed: onTap,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: AppSize.iconMd,
            color: c.textSecondary,
          ),
        );

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          _ForgotHeader(step2: _step2, onBack: _back),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppDuration.normal,
              child: _step2
                  ? ListView(
                      key: const ValueKey('reset-step'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        _ForgotPhoneCard(phone: displayPhone),
                        const SizedBox(height: 14),
                        _ForgotCard(
                          title: 'Xác nhận và tạo mật khẩu',
                          icon: Icons.lock_reset_rounded,
                          child: Form(
                            key: _resetKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppLabel('Mã OTP'),
                                const SizedBox(height: 10),
                                OtpInput(
                                  controller: _otpInputCtl,
                                  onChanged: (_) {
                                    if (_error != null) {
                                      setState(() => _error = null);
                                    } else {
                                      setState(() {});
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${_otpInputCtl.otp.length}/6 chữ số',
                                    style: AppTextStyles.caption.copyWith(
                                      color: _otpInputCtl.otp.length == 6
                                          ? c.success
                                          : c.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const AppLabel('Mật khẩu mới'),
                                const SizedBox(height: 7),
                                AppField(
                                  controller: _passCtrl,
                                  hint: 'Tối thiểu 6 ký tự',
                                  fillColor: c.surfaceAlt,
                                  outlined: true,
                                  prefixIcon: Icon(Icons.lock_outline_rounded,
                                      size: AppSize.iconMd,
                                      color: c.textSecondary),
                                  obscureText: _obscure1,
                                  textInputAction: TextInputAction.next,
                                  suffixIcon: eye(
                                    _obscure1,
                                    () =>
                                        setState(() => _obscure1 = !_obscure1),
                                  ),
                                  validator: Validators.password,
                                ),
                                const SizedBox(height: 14),
                                const AppLabel('Xác nhận mật khẩu'),
                                const SizedBox(height: 7),
                                AppField(
                                  controller: _confCtrl,
                                  hint: 'Nhập lại mật khẩu mới',
                                  fillColor: c.surfaceAlt,
                                  outlined: true,
                                  prefixIcon: Icon(Icons.lock_outline_rounded,
                                      size: AppSize.iconMd,
                                      color: c.textSecondary),
                                  obscureText: _obscure2,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _resetPassword(),
                                  suffixIcon: eye(
                                    _obscure2,
                                    () =>
                                        setState(() => _obscure2 = !_obscure2),
                                  ),
                                  validator: (value) => value != _passCtrl.text
                                      ? 'Mật khẩu không khớp'
                                      : null,
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  AppErrorBox(_error!),
                                ],
                                const SizedBox(height: 18),
                                _ForgotActionButton(
                                  label: 'Đặt lại mật khẩu',
                                  loadingLabel: 'Đang cập nhật...',
                                  loading: _loading,
                                  icon: Icons.check_rounded,
                                  onPressed: _resetPassword,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ForgotResendCard(
                          countdown: _countdown,
                          busy: _loading,
                          onResend: _resendOtp,
                        ),
                        const SizedBox(height: 14),
                        const _ForgotSecurityNote(),
                      ],
                    )
                  : ListView(
                      key: const ValueKey('phone-step'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        const _ForgotIntro(),
                        const SizedBox(height: 14),
                        _ForgotCard(
                          title: 'Tìm tài khoản',
                          icon: Icons.phone_iphone_rounded,
                          child: Form(
                            key: _phoneKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppLabel('Số điện thoại'),
                                const SizedBox(height: 7),
                                PhoneField(
                                  controller: _phoneCtrl,
                                  hint: '912 345 678',
                                  fillColor: c.surfaceAlt,
                                  outlined: true,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _sendOtp(),
                                  validator: Validators.phone,
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  AppErrorBox(_error!),
                                ],
                                const SizedBox(height: 18),
                                _ForgotActionButton(
                                  label: 'Gửi mã OTP',
                                  loadingLabel: 'Đang gửi mã...',
                                  loading: _loading,
                                  icon: Icons.arrow_forward_rounded,
                                  onPressed: _sendOtp,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const _ForgotSecurityNote(),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _back() {
    if (_step2) {
      setState(() {
        _step2 = false;
        _error = null;
      });
    } else {
      context.pop();
    }
  }
}

class _ForgotHeader extends StatelessWidget {
  final bool step2;
  final VoidCallback onBack;

  const _ForgotHeader({required this.step2, required this.onBack});

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
              onPressed: onBack,
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
                      TextSpan(text: step2 ? 'Đặt lại ' : 'Quên '),
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
                    step2
                        ? 'Xác nhận OTP và tạo mật khẩu mới'
                        : 'Khôi phục quyền truy cập tài khoản',
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
                step2 ? '2/2' : '1/2',
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

class _ForgotIntro extends StatelessWidget {
  const _ForgotIntro();

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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.lock_reset_rounded, size: 22, color: c.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bạn không thể đăng nhập?',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Nhập số điện thoại đã đăng ký. Flash Ship sẽ gửi mã OTP để xác nhận tài khoản.',
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ForgotPhoneCard extends StatelessWidget {
  final String phone;

  const _ForgotPhoneCard({required this.phone});

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
              Text('Mã OTP đã gửi đến',
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

class _ForgotCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ForgotCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: c.primary),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ForgotActionButton extends StatelessWidget {
  final String label;
  final String loadingLabel;
  final bool loading;
  final IconData icon;
  final VoidCallback onPressed;

  const _ForgotActionButton({
    required this.label,
    required this.loadingLabel,
    required this.loading,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.primary.withValues(alpha: .5),
          disabledForegroundColor: c.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: loading
            ? const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          loading ? loadingLabel : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ForgotResendCard extends StatelessWidget {
  final int countdown;
  final bool busy;
  final VoidCallback onResend;

  const _ForgotResendCard({
    required this.countdown,
    required this.busy,
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
            onPressed: busy ? null : onResend,
            style: TextButton.styleFrom(
              foregroundColor: c.primary,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Gửi lại',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ]),
    );
  }
}

class _ForgotSecurityNote extends StatelessWidget {
  const _ForgotSecurityNote();

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
