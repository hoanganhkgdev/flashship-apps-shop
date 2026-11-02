import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Tiêu đề section dùng chung, đồng bộ nhịp chữ và vạch cam của customer.
class ShopHomeSectionHeading extends StatelessWidget {
  final String title;
  final String? highlight;
  final String? subtitle;
  final IconData? subtitleIcon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const ShopHomeSectionHeading({
    super.key,
    required this.title,
    this.highlight,
    this.subtitle,
    this.subtitleIcon,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final highlighted = highlight?.trim() ?? '';
    final highlightIndex =
        highlighted.isEmpty ? -1 : title.indexOf(highlighted);
    final titleSpans = highlightIndex < 0
        ? <InlineSpan>[TextSpan(text: title)]
        : <InlineSpan>[
            if (highlightIndex > 0)
              TextSpan(text: title.substring(0, highlightIndex)),
            TextSpan(
              text: highlighted,
              style: TextStyle(color: c.primary),
            ),
            if (highlightIndex + highlighted.length < title.length)
              TextSpan(
                text: title.substring(highlightIndex + highlighted.length),
              ),
          ];
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: subtitle == null ? 24 : 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.primary.withValues(alpha: .65),
                  c.primary,
                ],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: titleSpans),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subtitleIcon != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            subtitleIcon,
                            size: 15,
                            color: c.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            height: 1.25,
                            color: c.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
