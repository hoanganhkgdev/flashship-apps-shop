import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/grab_widgets.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _phoneCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  bool _obscure     = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
      phone:    _phoneCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!ok && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth       = ref.watch(authProvider);
    final bottom     = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 36, 24, bottom + safeBottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GrabLogoBox(),
              const SizedBox(height: 28),
              const Text('Đăng nhập',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),
              const Text('Quản lý đơn giao hàng cho cửa hàng',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 32),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GrabLabel('Số điện thoại'),
                    const SizedBox(height: 8),
                    GrabField(
                      controller: _phoneCtrl,
                      hint: '09xx xxx xxx',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
                        if (v.trim().length < 9) return 'Số điện thoại không hợp lệ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const GrabLabel('Mật khẩu'),
                    const SizedBox(height: 8),
                    GrabField(
                      controller: _passCtrl,
                      hint: '••••••••',
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscure = !_obscure),
                        child: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                        if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                        return null;
                      },
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 16),
                      GrabErrorBox(auth.error!),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              GrabButton(
                label: 'Đăng nhập',
                onPressed: _submit,
                isLoading: auth.isLoading,
              ),
              const SizedBox(height: 24),

              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Chưa có tài khoản? ',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                GestureDetector(
                  onTap: () => context.push('/register'),
                  child: const Text('Đăng ký ngay',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
