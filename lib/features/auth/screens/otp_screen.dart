import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../../core/widgets/otp_input.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> regData;
  const OtpScreen({super.key, required this.regData});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _OtpHeader({required this.onBack});

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
                      const TextSpan(text: 'Xác nhận '),
                      TextSpan(
                        text: 'OTP',
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
                    'Bảo vệ tài khoản cửa hàng của bạn',
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

class _OtpIntro extends StatelessWidget {
  final String phone;

  const _OtpIntro({required this.phone});

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
          child: Icon(Icons.sms_outlined, size: 21, color: c.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mã đã được gửi đến',
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                phone,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Vui lòng kiểm tra tin nhắn SMS trên điện thoại.',
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

class _ResendCard extends StatelessWidget {
  final int countdown;
  final bool busy;
  final VoidCallback onResend;

  const _ResendCard({
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
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.refresh_rounded, size: 19, color: c.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            countdown > 0
                ? 'Bạn chưa nhận được mã?'
                : 'Bạn có thể yêu cầu gửi mã mới.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        if (countdown > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${countdown}s',
              style: AppTextStyles.caption.copyWith(
                color: c.primary,
                fontWeight: FontWeight.w600,
              ),
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

class _OtpSecurityNote extends StatelessWidget {
  const _OtpSecurityNote();

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
            'Không chia sẻ mã OTP với bất kỳ ai',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
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
        .resendCode(widget.regData['phone'] as String);
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
      body: Column(
        children: [
          _OtpHeader(onBack: _back),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _OtpIntro(phone: displayPhone),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhập mã xác nhận',
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mã OTP gồm 6 chữ số và có hiệu lực trong thời gian ngắn.',
                        style: AppTextStyles.caption.copyWith(
                          color: c.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      OtpInput(
                        controller: _otpCtl,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 9),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_otpCtl.otp.length}/6 chữ số',
                          style: AppTextStyles.caption.copyWith(
                            color: _otpCtl.otp.length == 6
                                ? c.success
                                : c.textSecondary,
                          ),
                        ),
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 10),
                        AppErrorBox(auth.error!),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: auth.isLoading ? null : _verify,
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
                          icon: auth.isLoading
                              ? const SizedBox.square(
                                  dimension: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 20),
                          label: Text(
                            auth.isLoading ? 'Đang xác nhận...' : 'Xác nhận mã',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ResendCard(
                  countdown: _countdown,
                  busy: auth.isLoading,
                  onResend: _resend,
                ),
                const SizedBox(height: 14),
                const _OtpSecurityNote(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _back() {
    ref.read(authProvider.notifier).clearError();
    context.pop();
  }
}
