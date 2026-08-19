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
    // Ô vuông nhỏ viền mảnh, nền trắng — rõ ràng dễ đọc/dễ gõ, không cần
    // hiệu ứng màu mè (thay bản gạch chân trước đó).
    return SizedBox(
      width: 44, height: 48,
      child: TextFormField(
        controller: controller,
        focusNode:  focusNode,
        maxLength:  1,
        textAlign:  TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: c.surface,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.divider, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.divider, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.primary, width: 1.5),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
