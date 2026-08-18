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
  String  _firstPin = '';
  String  _input    = '';
  int     _step     = 1;
  String? _error;

  void _onDigit(String d) {
    if (_input.length >= 4) return;
    setState(() {
      _input += d;
      _error  = null;
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
        _input    = '';
        _step     = 2;
      });
      return;
    }

    if (_input == _firstPin) {
      await ref.read(pinProvider.notifier).setPin(_input);
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _error    = 'Mã PIN không khớp, vui lòng thử lại';
        _input    = '';
        _firstPin = '';
        _step     = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(_step == 1 ? 'Tạo mã PIN' : 'Nhập lại mã PIN',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              _step == 1
                  ? 'Tạo mã PIN 4 số để khoá ứng dụng'
                  : 'Nhập lại mã PIN để xác nhận',
              style: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
            const SizedBox(height: 32),
            PinDots(length: 4, filled: _input.length),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: TextStyle(fontSize: 13, color: c.danger)),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PinKeypad(onDigit: _onDigit, onDelete: _onDelete),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
