import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'providers/pin_provider.dart';
import 'widgets/pin_widgets.dart';

/// Thiết lập PIN lần đầu — bước 1 nhập PIN, bước 2 nhập lại để xác nhận
/// khớp rồi mới lưu (hash SHA-256, không lưu PIN thô).
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _firstPin = '';
  String _input = '';
  int _step = 1;
  String? _error;

  void _onDigit(String d) {
    if (_input.length >= 4) return;
    setState(() {
      _input += d;
      _error = null;
    });
    if (_input.length == 4) _onComplete();
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _onComplete() async {
    if (_step == 1) {
      final entered = _input;
      setState(() {
        _firstPin = entered;
        _input = '';
        _step = 2;
      });
      return;
    }

    if (_input == _firstPin) {
      await ref.read(pinProvider.notifier).setPin(_input);
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _error = 'Mã PIN không khớp, vui lòng thử lại';
        _input = '';
        _firstPin = '';
        _step = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        _PinSetupHeader(onBack: () => Navigator.pop(context, false)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              _PinStepProgress(currentStep: _step),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.divider),
                ),
                child: Column(children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _step == 1
                          ? Icons.lock_outline_rounded
                          : Icons.verified_user_outlined,
                      size: 29,
                      color: c.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _step == 1 ? 'Tạo mã PIN' : 'Xác nhận mã PIN',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.screenTitle.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _step == 1
                        ? 'Nhập 4 chữ số dễ nhớ để bảo vệ ứng dụng'
                        : 'Nhập lại mã PIN vừa tạo để hoàn tất',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PinDots(length: 4, filled: _input.length),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: c.danger.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline_rounded,
                            size: 18, color: c.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: AppTextStyles.caption.copyWith(
                              color: c.danger,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.divider),
                ),
                child: PinKeypad(
                  onDigit: _onDigit,
                  onDelete: _onDelete,
                  keyHeight: 60,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 15, color: c.textTertiary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Mã PIN được lưu an toàn trên thiết bị này',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PinSetupHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _PinSetupHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      color: context.isDark ? c.primarySoft : const Color(0xFFFFE9DE),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 14),
          child: Row(children: [
            IconButton(
              tooltip: 'Quay lại',
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: c.surface,
                foregroundColor: c.textPrimary,
                fixedSize: const Size.square(42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thiết lập mã PIN',
                    style: AppTextStyles.screenTitle.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Thêm một lớp bảo vệ cho tài khoản',
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PinStepProgress extends StatelessWidget {
  final int currentStep;
  const _PinStepProgress({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      for (var index = 1; index <= 2; index++) ...[
        Expanded(
          child: AnimatedContainer(
            duration: AppDuration.fast,
            height: 5,
            decoration: BoxDecoration(
              color: index <= currentStep ? c.primary : c.divider,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
        ),
        if (index == 1) const SizedBox(width: 7),
      ],
      const SizedBox(width: 12),
      Text(
        'Bước $currentStep/2',
        style: AppTextStyles.caption.copyWith(
          color: c.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ]);
  }
}
