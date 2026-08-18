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

  int    _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
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
      if (_countdown <= 0) { t.cancel(); return; }
      setState(() => _countdown--);
    });
  }

  Future<void> _verify() async {
    if (_otpCtl.otp.length < 6) return;
    final data = widget.regData;
    final ok   = await ref.read(authProvider.notifier).verifyOtpAndRegister(
      phone:    data['phone']    as String,
      otp:      _otpCtl.otp,
      name:     data['name']     as String,
      password: data['password'] as String,
      address:  data['address']  as String?,
      cityId:   data['city_id']  as int?,
    );
    if (!ok && mounted) {
      setState(() {});
      _otpCtl.clear();
    }
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;
    await ref.read(authProvider.notifier).sendOtp(widget.regData['phone'] as String);
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final auth  = ref.watch(authProvider);
    final phone = widget.regData['phone'] as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => context.pop(),
                ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpace.sm),
                    const StepProgressBar(currentStep: 2, totalSteps: 2),
                    const SizedBox(height: AppSpace.xl),
                    const Text('Xác nhận OTP',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 6),
                    Text.rich(TextSpan(
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      children: [
                        const TextSpan(text: 'Nhập mã 6 số đã gửi tới '),
                        TextSpan(
                          text: phone,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    )),
                    const SizedBox(height: 40),

                    // OTP boxes
                    OtpInput(
                      controller: _otpCtl,
                      onChanged: (otp) {
                        if (otp.length == 6) _verify();
                      },
                    ),

                    if (auth.error != null) ...[
                      const SizedBox(height: 16),
                      AppErrorBox(auth.error!),
                    ],

                    const SizedBox(height: 32),
                    AppButton(
                      label: 'Xác nhận',
                      onPressed: _otpCtl.otp.length == 6 ? _verify : null,
                      isLoading: auth.isLoading,
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: _countdown > 0
                          ? Text(
                              'Gửi lại sau $_countdown giây',
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.textSecondary),
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
    );
  }
}
