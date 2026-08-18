import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// N chấm tròn hiện tiến trình nhập PIN — [filled] chấm đầu tô đặc.
class PinDots extends StatelessWidget {
  final int length;
  final int filled;

  const PinDots({super.key, required this.length, required this.filled});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(length, (i) {
        final active = i < filled;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 9),
          width: 16, height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.primary : Colors.transparent,
            border: Border.all(
                color: active ? AppColors.primary : c.divider, width: 1.5),
          ),
        );
      }),
    );
  }
}

/// Bàn phím số 0-9 tối giản dùng cho nhập/thiết lập PIN — hàng cuối gồm nút
/// vân tay/Face ID (trái, chỉ hiện khi [showBiometric]), số 0 (giữa), nút
/// xoá (phải).
class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback         onDelete;
  final VoidCallback?        onBiometric;
  final bool                 showBiometric;

  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
    this.showBiometric = false,
  });

  Widget _key(BuildContext context, {String? label, Widget? child, VoidCallback? onTap}) {
    final c = context.colors;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          height: 68,
          child: Center(
            child: child ??
                Text(label ?? '',
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w600, color: c.textPrimary)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Row(children: [
          _key(context, label: '1', onTap: () => onDigit('1')),
          _key(context, label: '2', onTap: () => onDigit('2')),
          _key(context, label: '3', onTap: () => onDigit('3')),
        ]),
        Row(children: [
          _key(context, label: '4', onTap: () => onDigit('4')),
          _key(context, label: '5', onTap: () => onDigit('5')),
          _key(context, label: '6', onTap: () => onDigit('6')),
        ]),
        Row(children: [
          _key(context, label: '7', onTap: () => onDigit('7')),
          _key(context, label: '8', onTap: () => onDigit('8')),
          _key(context, label: '9', onTap: () => onDigit('9')),
        ]),
        Row(children: [
          _key(context,
              onTap: showBiometric ? onBiometric : null,
              child: showBiometric
                  ? Icon(Icons.fingerprint_rounded, size: 30, color: AppColors.primary)
                  : const SizedBox.shrink()),
          _key(context, label: '0', onTap: () => onDigit('0')),
          _key(context,
              onTap: onDelete,
              child: Icon(Icons.backspace_outlined, size: 24, color: c.textSecondary)),
        ]),
      ],
    );
  }
}
