import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Label ────────────────────────────────────────────────────────────────────

class GrabLabel extends StatelessWidget {
  final String text;
  const GrabLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );
}

// ─── Input ────────────────────────────────────────────────────────────────────

class GrabField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final Widget? suffixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  const GrabField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.suffixIcon,
    this.prefix,
    this.suffix,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        onChanged: onChanged,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        focusNode: focusNode,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefix: prefix,
          suffix: suffix,
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixIcon)
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 40),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
        ),
        validator: validator,
      );
}

// ─── Error box ────────────────────────────────────────────────────────────────

class GrabErrorBox extends StatelessWidget {
  final String message;
  const GrabErrorBox(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      );
}

// ─── Primary button ───────────────────────────────────────────────────────────

class GrabButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const GrabButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
        ),
      );
}

// ─── Logo box ─────────────────────────────────────────────────────────────────

class GrabLogoBox extends StatelessWidget {
  const GrabLogoBox({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(10),
        child: Image.asset('assets/images/logo.png',
            fit: BoxFit.contain, color: Colors.white),
      );
}

// ─── Section header ───────────────────────────────────────────────────────────

class GrabSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const GrabSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            if (action != null)
              GestureDetector(
                onTap: onAction,
                child: Text(action!,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
          ],
        ),
      );
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────

class GrabBottomNav extends StatelessWidget {
  final int selectedIndex;
  final List<GrabNavItem> items;
  final ValueChanged<int> onTap;

  const GrabBottomNav({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(0, 10, 0, bottom + 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final item     = items[i];
          final selected = i == selectedIndex;
          final color =
              selected ? AppColors.primary : const Color(0xFF9E9E9E);
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(selected ? item.activeIcon : item.icon,
                    size: 24, color: color),
                const SizedBox(height: 3),
                Text(item.label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: color)),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

class GrabNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const GrabNavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label});
}

// ─── White Card ───────────────────────────────────────────────────────────────

class GrabCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const GrabCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: child,
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class GrabStatusBadge extends StatelessWidget {
  final String status;
  const GrabStatusBadge(this.status, {super.key});

  static const _labels = {
    'pending':    'Đang tìm tài xế',
    'assigned':   'Tài xế đã nhận',
    'processing': 'Đang lấy hàng',
    'on_the_way': 'Đang giao',
    'completed':  'Hoàn thành',
    'cancelled':  'Đã huỷ',
  };

  static Color _color(String s) {
    switch (s) {
      case 'pending':                          return const Color(0xFFF59E0B);
      case 'assigned':
      case 'processing':
      case 'on_the_way':                       return const Color(0xFF3B82F6);
      case 'completed':                        return const Color(0xFF10B981);
      case 'cancelled':                        return const Color(0xFFEF4444);
      default:                                 return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    final label = _labels[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}
