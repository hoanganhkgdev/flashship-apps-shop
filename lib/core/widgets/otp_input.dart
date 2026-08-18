import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Quản lý 6 control/focus node của [OtpInput] — tách riêng để nơi gọi có
/// thể đọc mã, xoá và focus lại ô đầu từ bên ngoài (vd khi verify sai).
class OtpInputController {
  final List<TextEditingController> controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode>             focusNodes   = List.generate(6, (_) => FocusNode());

  String get otp => controllers.map((c) => c.text).join();

  void clear() {
    for (final c in controllers) { c.clear(); }
    focusNodes[0].requestFocus();
  }

  void dispose() {
    for (final c in controllers) { c.dispose(); }
    for (final n in focusNodes)  { n.dispose(); }
  }
}

/// 6 ô nhập OTP dùng chung — tự chuyển focus khi gõ/xoá, báo mã hiện tại
/// qua [onChanged] mỗi lần có thay đổi (kể cả khi chưa đủ 6 số).
class OtpInput extends StatelessWidget {
  final OtpInputController controller;
  final ValueChanged<String> onChanged;

  const OtpInput({super.key, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) => _OtpBox(
        controller: controller.controllers[i],
        focusNode:  controller.focusNodes[i],
        onChanged: (v) {
          if (v.isNotEmpty && i < 5) {
            controller.focusNodes[i + 1].requestFocus();
          } else if (v.isEmpty && i > 0) {
            controller.focusNodes[i - 1].requestFocus();
          }
          onChanged(controller.otp);
        },
      )),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final void Function(String) onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 46,
      // Lắng nghe controller để đổi fillColor khi người dùng gõ — TextFormField
      // tự vẽ lại text/border theo focus, nhưng không tự rebuild widget cha khi
      // text đổi nên cần AnimatedBuilder để cập nhật màu "đã nhập".
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final hasValue = controller.text.isNotEmpty;
          return TextFormField(
            controller: controller,
            focusNode:  focusNode,
            maxLength:  1,
            textAlign:  TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: hasValue ? c.primarySoft : c.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: onChanged,
          );
        },
      ),
    );
  }
}
