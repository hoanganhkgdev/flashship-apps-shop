import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/otp_input.dart';
import '../../../core/widgets/step_progress_bar.dart';
import '../providers/auth_provider.dart';

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
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: Container(
        color: c.surface,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () {
                      // Xoá lỗi trước khi quay lại — màn Đăng ký vẫn đang
                      // mounted phía dưới (push không dispose), tự đọc lại
                      // authProvider.error ngay khi lộ ra nếu không xoá ở đây.
                      ref.read(authProvider.notifier).clearError();
                      context.pop();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: c.divider),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 17, color: c.textPrimary),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const StepProgressBar(
                          currentStep: 2, totalSteps: 2, showLabel: false),
                      const SizedBox(height: AppSpace.xl),
                      const Text('Xác nhận OTP',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Text.rich(TextSpan(
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary),
                        children: [
                          const TextSpan(text: 'Nhập mã 6 số đã gửi tới '),
                          TextSpan(
                            text: displayPhone,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                        ],
                      )),
                      const SizedBox(height: 24),

                      // OTP boxes
                      OtpInput(
                        controller: _otpCtl,
                        onChanged: (_) => setState(() {}),
                      ),

                      if (auth.error != null) ...[
                        const SizedBox(height: 16),
                        AppErrorBox(auth.error!),
                      ],

                      const SizedBox(height: 28),
                      AppButton(
                        label: 'Xác nhận',
                        onPressed: _verify,
                        isLoading: auth.isLoading,
                      ),
                      const SizedBox(height: 20),

                      Center(
                        child: _countdown > 0
                            ? Text(
                                'Gửi lại sau $_countdown giây',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary),
                              )
                            : GestureDetector(
                                onTap: _resend,
                                child: const Text(
                                  'Gửi lại mã OTP',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary),
                                ),
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
