import 'package:flutter/material.dart';
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
  bool _obscure = true;

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
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
          phone: _phoneCtrl.text.trim(),
          password: _passCtrl.text,
        );
    if (!ok && mounted) setState(() {});
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
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: c.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Nhập số điện thoại và mật khẩu để tiếp tục',
                          style:
                              TextStyle(fontSize: 14, color: c.textSecondary)),
                      const SizedBox(height: AppSpace.xxl),

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
                                textInputAction: TextInputAction.next,
                                validator: Validators.phone,
                              ),
                              const SizedBox(height: AppSpace.lg),
                              AppLabel('Mật khẩu'),
                              const SizedBox(height: 6),
                              AppField(
                                controller: _passCtrl,
                                hint: '••••••••',
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
                              if (auth.error != null) ...[
                                const SizedBox(height: AppSpace.lg),
                                AppErrorBox(auth.error!),
                              ],
                            ]),
                      ),
                      const SizedBox(height: AppSpace.md),

                      // ── Forgot password ─────────────────────────────────
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => context.push('/forgot-password'),
                          child: Text('Quên mật khẩu?',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: c.primary)),
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg + AppSpace.xs),

                      // ── Button ───────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed: auth.isLoading ? null : _submit,
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Đăng nhập'),
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),

                      // ── Divider ──────────────────────────────────────────
                      Row(children: [
                        Expanded(child: Divider(color: c.divider)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('hoặc',
                              style: TextStyle(
                                  fontSize: 12.5, color: c.textTertiary)),
                        ),
                        Expanded(child: Divider(color: c.divider)),
                      ]),
                      const SizedBox(height: AppSpace.xl),

                      // ── Register link ────────────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: () => context.push('/register'),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Chưa có tài khoản? ',
                                    style: TextStyle(
                                        fontSize: 14, color: c.textSecondary)),
                                Text('Đăng ký cửa hàng mới',
                                    style: TextStyle(
                                        fontSize: 14,
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

// ─── Hero gradient — thương hiệu + minh hoạ giao hàng ────────────────────────

class _LoginHero extends StatelessWidget {
  final Color primary;
  const _LoginHero({required this.primary});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      height: top + 240,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, const Color(0xFFFF9A5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            top: top + 66,
            right: 32,
            child: Transform.rotate(
              angle: 0.14,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
          ),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 16,
                          offset: Offset(0, 6)),
                    ],
                  ),
                  child: Icon(Icons.storefront_rounded,
                      color: primary, size: 24),
                ),
                const SizedBox(height: 8),
                const Text('FlashShip Shop',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text('Quản lý đơn giao hàng cho cửa hàng của bạn',
                    style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white.withValues(alpha: 0.88))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
