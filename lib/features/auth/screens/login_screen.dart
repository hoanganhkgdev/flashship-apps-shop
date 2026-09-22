import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _otpCtrl = TextEditingController();
  bool _obscure = true;
  bool _passwordMode = true;
  bool _otpSent = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Xoá lỗi còn sót lại từ màn xác thực khác (vd Đăng ký) — authProvider.error
    // dùng chung cho mọi thao tác, không tự xoá khi chuyển màn.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(authProvider.notifier).clearError());
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = _passwordMode
        ? await ref.read(authProvider.notifier).login(
              phone: _phoneCtrl.text.trim(),
              password: _passCtrl.text,
            )
        : await ref.read(authProvider.notifier).loginWithOtp(
              phone: _phoneCtrl.text.trim(),
              otp: _otpCtrl.text.trim(),
            );
    if (!ok && mounted) setState(() {});
  }

  Future<void> _sendLoginOtp() async {
    final phoneError = Validators.phone(_phoneCtrl.text);
    if (phoneError != null) {
      _formKey.currentState?.validate();
      return;
    }
    final ok = await ref
        .read(authProvider.notifier)
        .sendLoginOtp(_phoneCtrl.text.trim());
    if (!ok || !mounted) return;
    setState(() {
      _otpSent = true;
      _countdown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _countdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _switchMode(bool passwordMode) {
    if (_passwordMode == passwordMode) return;
    ref.read(authProvider.notifier).clearError();
    setState(() {
      _passwordMode = passwordMode;
      _otpSent = false;
      _otpCtrl.clear();
    });
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.surface,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero ──────────────────────────────────────────────────
              _LoginHero(primary: c.primary),

              // ── Form sheet ────────────────────────────────────────────
              Transform.translate(
                offset: const Offset(0, -20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xl)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đăng nhập',
                          style: TextStyle(
                              fontSize: AppFontSize.display1,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Nhập số điện thoại và mật khẩu để tiếp tục',
                          style: TextStyle(
                              fontSize: AppFontSize.md,
                              color: c.textSecondary)),
                      const SizedBox(height: 20),

                      // Chuyển phương thức đăng nhập. Backend hiện xác thực
                      // OTP trong luồng khôi phục nên tab OTP dẫn vào đúng
                      // luồng gửi/nhập mã thay vì giả lập đăng nhập cục bộ.
                      Container(
                        height: 44,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: c.background,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: c.divider),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _switchMode(true),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _passwordMode
                                      ? c.surface
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                  border: _passwordMode
                                      ? Border.all(color: c.divider)
                                      : null,
                                ),
                                child: Text('Mật khẩu',
                                    style: TextStyle(
                                        fontSize: AppFontSize.base,
                                        fontWeight: FontWeight.w700,
                                        color: _passwordMode
                                            ? c.textPrimary
                                            : c.textTertiary)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _switchMode(false),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !_passwordMode
                                      ? c.surface
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                  border: !_passwordMode
                                      ? Border.all(color: c.divider)
                                      : null,
                                ),
                                child: Text('Mã OTP',
                                    style: TextStyle(
                                        fontSize: AppFontSize.base,
                                        fontWeight: FontWeight.w700,
                                        color: !_passwordMode
                                            ? c.textPrimary
                                            : c.textTertiary)),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      // ── Form ──────────────────────────────────────────
                      Form(
                        key: _formKey,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppLabel('Số điện thoại'),
                              const SizedBox(height: 6),
                              PhoneField(
                                controller: _phoneCtrl,
                                hint: '0912 345 678',
                                fillColor: c.surface,
                                outlined: true,
                                textInputAction: TextInputAction.next,
                                validator: Validators.phone,
                              ),
                              if (_passwordMode) ...[
                                const SizedBox(height: AppSpace.lg),
                                AppLabel('Mật khẩu'),
                                const SizedBox(height: 6),
                                AppField(
                                  controller: _passCtrl,
                                  hint: '••••••••',
                                  fillColor: c.surface,
                                  outlined: true,
                                  prefixIcon: Icon(Icons.lock_outline_rounded,
                                      size: 20, color: c.textSecondary),
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
                                      color: c.textSecondary,
                                    ),
                                  ),
                                  validator: Validators.password,
                                ),
                              ] else if (_otpSent) ...[
                                const SizedBox(height: AppSpace.lg),
                                AppLabel('Mã OTP'),
                                const SizedBox(height: 6),
                                AppField(
                                  controller: _otpCtrl,
                                  hint: 'Nhập mã gồm 6 chữ số',
                                  fillColor: c.surface,
                                  outlined: true,
                                  prefixIcon: Icon(Icons.sms_outlined,
                                      size: 20, color: c.textSecondary),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: (value) => value?.length == 6
                                      ? null
                                      : 'Mã OTP gồm 6 chữ số',
                                ),
                              ],
                              if (auth.error != null) ...[
                                const SizedBox(height: AppSpace.lg),
                                AppErrorBox(auth.error!),
                              ],
                            ]),
                      ),
                      const SizedBox(height: AppSpace.md),

                      // ── Forgot password ─────────────────────────────────
                      if (_passwordMode)
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => context.push('/forgot-password'),
                            child: Text('Quên mật khẩu?',
                                style: TextStyle(
                                    fontSize: AppFontSize.md,
                                    fontWeight: FontWeight.w600,
                                    color: c.primary)),
                          ),
                        ),
                      SizedBox(
                          height: _passwordMode
                              ? AppSpace.lg + AppSpace.xs
                              : AppSpace.lg),

                      // ── Button ───────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: auth.isLoading
                              ? null
                              : _passwordMode
                                  ? _submit
                                  : _otpSent
                                      ? _submit
                                      : _sendLoginOtp,
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(!_passwordMode && !_otpSent
                                  ? 'Gửi mã OTP'
                                  : 'Đăng nhập'),
                        ),
                      ),
                      if (!_passwordMode && _otpSent) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: _countdown == 0 && !auth.isLoading
                                ? _sendLoginOtp
                                : null,
                            child: Text(_countdown > 0
                                ? 'Gửi lại mã sau ${_countdown}s'
                                : 'Gửi lại mã OTP'),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpace.xl),

                      // ── Divider ──────────────────────────────────────────
                      Row(children: [
                        Expanded(child: Divider(color: c.divider)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('hoặc',
                              style: TextStyle(
                                  fontSize: AppFontSize.base,
                                  color: c.textTertiary)),
                        ),
                        Expanded(child: Divider(color: c.divider)),
                      ]),
                      const SizedBox(height: AppSpace.xl),

                      // ── Register link ────────────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: () => context.push('/register'),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('Chưa có tài khoản? ',
                                style: TextStyle(
                                    fontSize: AppFontSize.md,
                                    color: c.textSecondary)),
                            Text('Đăng ký cửa hàng mới',
                                style: TextStyle(
                                    fontSize: AppFontSize.md,
                                    fontWeight: FontWeight.w700,
                                    color: c.primary)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Khối thương hiệu ────────────────────────────────────────────────────────

class _LoginHero extends StatelessWidget {
  final Color primary;
  const _LoginHero({required this.primary});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      height: top + 220,
      decoration: BoxDecoration(
        color: context.colors.surface,
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: 24,
            bottom: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.layers_rounded, color: primary, size: 24),
                ),
                const SizedBox(height: 8),
                const Text('FlashShip Shop',
                    style: TextStyle(
                        fontSize: AppFontSize.xxxl,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Quản lý đơn giao hàng cho cửa hàng của bạn',
                    style: TextStyle(
                        fontSize: AppFontSize.md,
                        color: context.colors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
