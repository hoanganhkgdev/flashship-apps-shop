import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../../auth/providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _State();
}

class _State extends ConsumerState<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _changed(String _) {
    if (_error != null) setState(() => _error = null);
    setState(() {});
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_currentCtrl.text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mật khẩu hiện tại');
      return;
    }
    if (_newCtrl.text.length < 6) {
      setState(() => _error = 'Mật khẩu mới phải có ít nhất 6 ký tự');
      return;
    }
    if (_newCtrl.text == _currentCtrl.text) {
      setState(() => _error = 'Mật khẩu mới phải khác mật khẩu hiện tại');
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ref.read(authProvider.notifier).changePassword(
          current: _currentCtrl.text,
          next: _newCtrl.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    AppSnackbar.success(context, 'Đổi mật khẩu thành công');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: c.primary.withValues(alpha: .5),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                _saving ? 'Đang cập nhật...' : 'Cập nhật mật khẩu',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
      body: Column(children: [
        const _PasswordHeader(),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const _SecurityNote(),
              const SizedBox(height: 16),
              _PasswordCard(
                title: 'Xác nhận tài khoản',
                icon: Icons.lock_outline_rounded,
                children: [
                  _PasswordField(
                    label: 'Mật khẩu hiện tại',
                    hint: 'Nhập mật khẩu đang sử dụng',
                    controller: _currentCtrl,
                    visible: _showCurrent,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.password],
                    onChanged: _changed,
                    onToggle: () =>
                        setState(() => _showCurrent = !_showCurrent),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PasswordCard(
                title: 'Tạo mật khẩu mới',
                icon: Icons.lock_reset_rounded,
                children: [
                  _PasswordField(
                    label: 'Mật khẩu mới',
                    hint: 'Tối thiểu 6 ký tự',
                    controller: _newCtrl,
                    visible: _showNew,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: _changed,
                    onToggle: () => setState(() => _showNew = !_showNew),
                  ),
                  Divider(height: 1, color: c.divider),
                  _PasswordField(
                    label: 'Xác nhận mật khẩu mới',
                    hint: 'Nhập lại mật khẩu mới',
                    controller: _confirmCtrl,
                    visible: _showConfirm,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: _changed,
                    onSubmitted: (_) => _save(),
                    onToggle: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yêu cầu mật khẩu',
                            style: AppTextStyles.label.copyWith(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _PasswordRule(
                            passed: _newCtrl.text.length >= 6,
                            label: 'Tối thiểu 6 ký tự',
                          ),
                          const SizedBox(height: 8),
                          _PasswordRule(
                            passed: _currentCtrl.text.isNotEmpty &&
                                _newCtrl.text.isNotEmpty &&
                                _newCtrl.text != _currentCtrl.text,
                            label: 'Khác với mật khẩu hiện tại',
                          ),
                          const SizedBox(height: 8),
                          _PasswordRule(
                            passed: _confirmCtrl.text.isNotEmpty &&
                                _newCtrl.text == _confirmCtrl.text,
                            label: 'Mật khẩu xác nhận trùng khớp',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppErrorBox(_error!),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _PasswordHeader extends StatelessWidget {
  const _PasswordHeader();

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
              onPressed: () => Navigator.maybePop(context),
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
                      const TextSpan(text: 'Đổi '),
                      TextSpan(
                        text: 'mật khẩu',
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
                    'Tăng cường bảo mật cho tài khoản cửa hàng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFFFD1BF)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: .85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.shield_outlined, size: 22, color: c.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bảo vệ tài khoản của bạn',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Dùng mật khẩu dễ nhớ với bạn nhưng khó đoán với người khác.',
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

class _PasswordCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _PasswordCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: c.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
        ),
        Divider(height: 1, color: c.divider),
        ...children,
      ]),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool visible;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;

  const _PasswordField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.visible,
    required this.onToggle,
    required this.onChanged,
    required this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: c.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: !visible,
          enableSuggestions: false,
          autocorrect: false,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: AppTextStyles.body.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(Icons.lock_outline_rounded,
                size: 19, color: c.textTertiary),
            suffixIcon: IconButton(
              tooltip: visible ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
              onPressed: onToggle,
              icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            ),
            filled: true,
            fillColor: c.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: c.primary),
            ),
          ),
        ),
      ]),
    );
  }
}

class _PasswordRule extends StatelessWidget {
  final bool passed;
  final String label;
  const _PasswordRule({required this.passed, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = passed ? c.success : c.textTertiary;
    return Row(children: [
      Icon(
        passed ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 16,
        color: color,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(color: color),
        ),
      ),
    ]);
  }
}
