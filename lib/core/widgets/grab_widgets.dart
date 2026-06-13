import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Label ────────────────────────────────────────────────────────────────────

class GrabLabel extends StatelessWidget {
  final String text;
  const GrabLabel(this.text, {super.key});

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

class GrabField extends StatelessWidget {
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
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
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
        fillColor: c.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
          borderSide: BorderSide(color: c.danger),
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

// ─── Error box ────────────────────────────────────────────────────────────────

class GrabErrorBox extends StatelessWidget {
  final String message;
  const GrabErrorBox(this.message, {super.key});

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

class GrabLogoBox extends StatelessWidget {
  const GrabLogoBox({super.key});

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

class GrabNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const GrabNavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label});
}

// ─── Surface Card ─────────────────────────────────────────────────────────────

class GrabCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final bool elevated;

  const GrabCard({
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
    final label = _labels[status] ?? status;
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
