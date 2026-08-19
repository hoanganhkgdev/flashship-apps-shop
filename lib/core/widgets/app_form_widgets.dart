import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

// ─── Label ────────────────────────────────────────────────────────────────────

class AppLabel extends StatelessWidget {
  final String text;
  const AppLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.colors.textPrimary,
        ),
      );
}

// ─── Input ────────────────────────────────────────────────────────────────────

class AppField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final Color? fillColor;

  const AppField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.suffixIcon,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextFormField(
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
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: c.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: c.textTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        prefix: prefix,
        suffix: suffix,
        prefixIcon: prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 4),
                child: prefixIcon)
            : null,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: suffixIcon)
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
        filled: true,
        fillColor: fillColor ?? c.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.danger, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}

// ─── Phone input (mã vùng +84 cố định) ─────────────────────────────────────────

/// Field số điện thoại kiểu Grab — "+84" cố định bên trái, ngăn cách bằng
/// vạch dọc mỏng, phần nhập chỉ nhận số thuê bao (không gồm số 0 đầu).
/// [controller] vẫn giữ đúng định dạng cũ ("0912345678") để không đổi format
/// gửi lên backend — PhoneField chỉ đổi cách hiển thị, tự đồng bộ 2 chiều
/// với 1 controller nội bộ chỉ chứa phần số sau "+84".
class PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final String? Function(String?)? validator;

  const PhoneField({
    super.key,
    required this.controller,
    this.hint = '912 345 678',
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late final TextEditingController _localCtrl;

  @override
  void initState() {
    super.initState();
    final initial = widget.controller.text;
    _localCtrl = TextEditingController(
        text: initial.startsWith('0') ? initial.substring(1) : initial);
    _localCtrl.addListener(_syncToController);
  }

  void _syncToController() {
    widget.controller.text = '0${_localCtrl.text}';
  }

  @override
  void dispose() {
    _localCtrl.removeListener(_syncToController);
    _localCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextFormField(
      controller: _localCtrl,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: c.textPrimary,
      ),
      // Validate trên giá trị đầy đủ đã đồng bộ (widget.controller), không
      // phải phần hiển thị — giữ đúng logic validate cũ (Validators.phone).
      validator: (_) => widget.validator?.call(widget.controller.text),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(
          color: c.textTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        // Chỉ phục vụ thị trường Việt Nam — bỏ mã vùng "+84", dùng icon điện
        // thoại đơn giản thay vì hiện mã vùng không cần thiết.
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Icon(Icons.phone_outlined, size: 20, color: c.textSecondary),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: c.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.danger, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
      ),
    );
  }
}

// ─── Error box ────────────────────────────────────────────────────────────────

class AppErrorBox extends StatelessWidget {
  final String message;
  const AppErrorBox(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: c.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: c.danger, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: TextStyle(
                  fontSize: 13,
                  color: c.danger,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

// ─── Primary button ───────────────────────────────────────────────────────────

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          disabledBackgroundColor: c.primary.withValues(alpha: 0.5),
          foregroundColor: c.onPrimary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
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
                )),
      ),
    );
  }
}

// ─── Logo box ─────────────────────────────────────────────────────────────────

class AppLogoBox extends StatelessWidget {
  const AppLogoBox({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: context.colors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(10),
        child: Image.asset('assets/images/logo.png',
            fit: BoxFit.contain, color: Colors.white),
      );
}

// ─── Section header ───────────────────────────────────────────────────────────

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.primary)),
            ),
        ],
      ),
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────

class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final List<AppNavItem> items;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c      = context.colors;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(0, 8, 0, bottom + 6),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider, width: 1)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final item     = items[i];
          final selected = i == selectedIndex;
          final color    = selected ? c.primary : c.textTertiary;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  decoration: BoxDecoration(
                    color: selected ? c.primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(selected ? item.activeIcon : item.icon,
                      size: 24, color: color),
                ),
                const SizedBox(height: 3),
                Text(item.label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                        color: color)),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

class AppNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const AppNavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label});
}

// ─── Surface Card ─────────────────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final bool elevated;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final card = Container(
      width: double.infinity,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            elevated ? BorderRadius.circular(AppRadius.card) : null,
        boxShadow: elevated ? c.cardShadow : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

// ─── Snackbar ─────────────────────────────────────────────────────────────────

class AppSnackbar {
  static void error(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: context.colors.danger,
      duration: duration ?? const Duration(seconds: 4),
    ));
  }

  static void success(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: context.colors.success,
      duration: duration ?? const Duration(seconds: 4),
    ));
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double boxSize;
  final BoxShape boxShape;
  final double boxRadius;
  final Color? boxColor;
  final Color? iconColor;
  final double iconSize;
  final double titleFontSize;
  final FontWeight titleWeight;
  final Color? titleColor;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.boxSize = 72,
    this.boxShape = BoxShape.rectangle,
    this.boxRadius = 20,
    this.boxColor,
    this.iconColor,
    this.iconSize = 34,
    this.titleFontSize = 15,
    this.titleWeight = FontWeight.w600,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: boxSize,
        height: boxSize,
        decoration: BoxDecoration(
          color: boxColor ?? c.surfaceAlt,
          shape: boxShape,
          borderRadius: boxShape == BoxShape.rectangle
              ? BorderRadius.circular(boxRadius)
              : null,
        ),
        child: Icon(icon, size: iconSize, color: iconColor ?? c.textTertiary),
      ),
      SizedBox(height: 14),
      Text(title,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: titleWeight,
              color: titleColor ?? c.textSecondary)),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textSecondary)),
      ],
      if (action != null) ...[
        const SizedBox(height: 20),
        action!,
      ],
    ]);
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class AppStatusBadge extends StatelessWidget {
  final String status;
  const AppStatusBadge(this.status, {super.key});

  static (Color, Color) _colorsFor(String s, Palette c) {
    switch (s) {
      case 'pending':     return (c.warning, c.warningSoft);
      case 'assigned':
      case 'processing':
      case 'on_the_way':  return (c.info, c.infoSoft);
      case 'completed':   return (c.success, c.successSoft);
      case 'cancelled':   return (c.danger, c.dangerSoft);
      default:            return (c.textSecondary, c.surfaceAlt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colorsFor(status, context.colors);
    final label = Fmt.orderStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg)),
    );
  }
}
