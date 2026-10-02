import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/otp_input.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_layout.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> regData;
  const OtpScreen({super.key, required this.regData});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpCtl = OtpInputController();

  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Xoá lỗi còn sót lại từ màn xác thực khác — authProvider.error dùng
    // chung cho mọi thao tác, không tự xoá khi chuyển màn.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(authProvider.notifier).clearError());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtl.dispose();
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

  Future<void> _verify() async {
    if (_otpCtl.otp.length < 6) {
      AppSnackbar.error(context, 'Vui lòng nhập đủ 6 chữ số');
      return;
    }
    final data = widget.regData;
    final ok = await ref.read(authProvider.notifier).verifyOtpAndRegister(
          phone: data['phone'] as String,
          otp: _otpCtl.otp,
          name: data['name'] as String,
          password: data['password'] as String,
          address: data['address'] as String?,
          cityId: data['city_id'] as int?,
          referralCode: data['referral_code'] as String?,
        );
    if (!ok && mounted) {
      setState(() {});
      _otpCtl.clear();
    }
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;
    final ok = await ref
        .read(authProvider.notifier)
        .sendOtp(widget.regData['phone'] as String);
    if (!mounted) return;
    if (ok) {
      _startCountdown();
    } else {
      setState(
          () {}); // hiện auth.error qua AppErrorBox đã có sẵn trong build()
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final phone = widget.regData['phone'] as String? ?? '';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final displayPhone = digits.length == 10
        ? '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}'
        : phone;

    return AuthPage(
      onBack: () {
        // Xoá lỗi trước khi quay lại — màn Đăng ký vẫn đang mounted phía dưới
        // (push không dispose), tự đọc lại authProvider.error ngay khi lộ ra
        // nếu không xoá ở đây.
        ref.read(authProvider.notifier).clearError();
        context.pop();
      },
      step: 2,
      icon: Icons.sms_rounded,
      title: 'Xác nhận OTP',
      subtitle: 'Nhập mã 6 số đã gửi tới ',
      highlight: displayPhone,
      children: [
        AuthCard(children: [
          OtpInput(
            controller: _otpCtl,
            onChanged: (_) => setState(() {}),
          ),
          if (auth.error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppErrorBox(auth.error!),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Xác nhận',
            onPressed: _verify,
            isLoading: auth.isLoading,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: ResendOtpRow(
              countdown: _countdown,
              busy: auth.isLoading,
              onResend: _resend,
            ),
          ),
        ]),
      ],
    );
  }
}
