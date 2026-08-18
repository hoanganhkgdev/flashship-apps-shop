import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../auth/providers/auth_provider.dart';
import 'providers/pin_provider.dart';
import 'services/biometric_auth.dart';
import 'widgets/pin_widgets.dart';

/// Màn khoá full-screen — chặn thao tác cho đến khi nhập đúng PIN hoặc xác
/// thực vân tay/Face ID thành công. [onUnlocked] tuỳ biến hành vi sau khi mở
/// khoá: mặc định tự pop (dùng khi push overlay lúc resume); route
/// /pin-lock ở cold-start truyền callback riêng để báo router chuyển màn
/// thay vì pop (không có route nào bên dưới để pop về).
class PinLockScreen extends ConsumerStatefulWidget {
  final VoidCallback? onUnlocked;
  const PinLockScreen({super.key, this.onUnlocked});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String  _input               = '';
  String? _error;
  bool    _biometricAvailable  = false;
  bool    _biometricInProgress = false;

  @override
  void initState() {
    super.initState();
    pinLockScreenVisible = true;
    _checkBiometric();
  }

  @override
  void dispose() {
    pinLockScreenVisible = false;
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricAuth.isAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
    if (available) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (_biometricInProgress) return;
    _biometricInProgress = true;
    final ok = await BiometricAuth.authenticate();
    _biometricInProgress = false;
    if (ok && mounted) _unlock();
  }

  void _onDigit(String d) {
    if (_input.length >= 4) return;
    setState(() {
      _input += d;
      _error  = null;
    });
    if (_input.length == 4) _verify();
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _verify() async {
    final ok = await ref.read(pinProvider.notifier).verifyPin(_input);
    if (!mounted) return;
    if (ok) {
      _unlock();
    } else {
      setState(() {
        _error = 'Mã PIN không đúng';
        _input = '';
      });
    }
  }

  void _unlock() {
    if (!mounted) return;
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Bạn quên mã PIN? Đăng xuất để đăng nhập lại.',
            style: TextStyle(color: ctx.colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.danger),
            child: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(authProvider.notifier).logout();
    _unlock();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
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
              const Text('Nhập mã PIN',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 28),
              PinDots(length: 4, filled: _input.length),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: TextStyle(fontSize: 13, color: c.danger)),
              ],
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PinKeypad(
                  onDigit: _onDigit,
                  onDelete: _onDelete,
                  showBiometric: _biometricAvailable,
                  onBiometric: _tryBiometric,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _logout,
                child: Text('Đăng xuất',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: c.textSecondary)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
