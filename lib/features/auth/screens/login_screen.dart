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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(authProvider.notifier).clearError(),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authProvider).isLoading) return;
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
    final c = context.colors;

    return Scaffold(
      backgroundColor: context.isDark ? c.primarySoft : const Color(0xFFFFE9DE),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
          final compact = keyboardVisible || constraints.maxHeight < 680;
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final heroHeight = compact ? 104.0 : 194.0 + (scale - 1) * 24;

          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LoginHero(compact: compact, height: heroHeight),
                  Container(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - heroHeight)
                          .clamp(0, double.infinity),
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _LoginHeading(),
                                const SizedBox(height: 20),
                                const AppLabel('Số điện thoại'),
                                const SizedBox(height: 7),
                                PhoneField(
                                  controller: _phoneCtrl,
                                  hint: '912 345 678',
                                  fillColor: c.surfaceAlt,
                                  outlined: true,
                                  textInputAction: TextInputAction.next,
                                  validator: Validators.phone,
                                ),
                                const SizedBox(height: 15),
                                const AppLabel('Mật khẩu'),
                                const SizedBox(height: 7),
                                AppField(
                                  controller: _passCtrl,
                                  hint: 'Nhập mật khẩu',
                                  fillColor: c.surfaceAlt,
                                  outlined: true,
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    size: 20,
                                    color: c.textSecondary,
                                  ),
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure
                                        ? 'Hiện mật khẩu'
                                        : 'Ẩn mật khẩu',
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                  validator: Validators.password,
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () =>
                                        context.push('/forgot-password'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: c.primary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 7,
                                      ),
                                      minimumSize: const Size(0, 42),
                                    ),
                                    child: const Text(
                                      'Quên mật khẩu?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                if (auth.error != null) ...[
                                  const SizedBox(height: 4),
                                  AppErrorBox(auth.error!),
                                  const SizedBox(height: 12),
                                ] else
                                  const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: auth.isLoading ? null : _submit,
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
                                    child: auth.isLoading
                                        ? const SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Đăng nhập',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(width: 7),
                                              Icon(Icons.arrow_forward_rounded,
                                                  size: 20),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const _SecurityNote(),
                                const SizedBox(height: 18),
                                Row(children: [
                                  Expanded(
                                      child:
                                          Divider(color: c.divider, height: 1)),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      'Chưa có tài khoản?',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.caption.copyWith(
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child:
                                          Divider(color: c.divider, height: 1)),
                                ]),
                                const SizedBox(height: 13),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => context.push('/register'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 50),
                                      foregroundColor: c.primary,
                                      side: BorderSide(color: c.divider),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.storefront_outlined,
                                        size: 19),
                                    label: const Text(
                                      'Tạo tài khoản cửa hàng',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  final bool compact;
  final double height;

  const _LoginHero({required this.compact, required this.height});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: height,
      child: Stack(children: [
        Positioned(
          top: -50,
          right: -32,
          child: Container(
            width: 142,
            height: 142,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          left: -22,
          bottom: 18,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: .55),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Center(
          child: compact
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: [
                    Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        semanticLabel: 'Flash Ship',
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: _BrandName(
                        fontSize: 25,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ]),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                      semanticLabel: 'Flash Ship',
                    ),
                    const SizedBox(height: 2),
                    const _BrandName(fontSize: 27),
                    const SizedBox(height: 5),
                    Text(
                      'Đồng hành cùng cửa hàng mỗi ngày',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ]),
    );
  }
}

class _BrandName extends StatelessWidget {
  final double fontSize;
  final Alignment alignment;

  const _BrandName({
    required this.fontSize,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final baseStyle = TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: fontSize,
      height: 1,
      fontWeight: FontWeight.w800,
      letterSpacing: -.7,
    );
    return Align(
      alignment: alignment,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'FLASH', style: baseStyle.copyWith(color: c.success)),
          TextSpan(text: 'SHIP', style: baseStyle.copyWith(color: c.primary)),
        ]),
        maxLines: 1,
        semanticsLabel: 'Flash Ship',
      ),
    );
  }
}

class _LoginHeading extends StatelessWidget {
  const _LoginHeading();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 45,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Chào mừng '),
                  TextSpan(
                    text: 'trở lại',
                    style: TextStyle(color: c.primary),
                  ),
                ]),
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Đăng nhập để tiếp tục quản lý giao hàng',
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_outlined, size: 16, color: c.success),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Không chia sẻ mật khẩu hoặc mã OTP',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}
