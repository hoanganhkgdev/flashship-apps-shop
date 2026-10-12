import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/vi_text.dart';
import '../../../core/widgets/app_decor_widgets.dart';
import '../../../core/widgets/app_form_widgets.dart';
import '../data/order_repository.dart';

/// Kết quả chọn khu vực giao: [destination] null nghĩa là "tự tính theo
/// quãng đường". Trả null từ [showDestinationSheet] khi đóng sheet mà chưa chọn.
class DestinationChoice {
  final DestinationPrice? destination;
  const DestinationChoice(this.destination);
}

Future<DestinationChoice?> showDestinationSheet(
  BuildContext context, {
  required List<DestinationPrice> options,
  required int? selectedId,
}) async {
  // Bản ghi id -1 đại diện cho "Tự tính theo km", phân biệt với việc đóng sheet.
  const auto = DestinationPrice(id: -1, name: '', fee: 0);
  final picked = await showModalBottomSheet<DestinationPrice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DestinationSheet(
      options: options,
      selectedId: selectedId,
      autoOption: auto,
    ),
  );
  if (picked == null) return null;
  return DestinationChoice(picked.id == auto.id ? null : picked);
}

// ─── Chọn khu vực giao có giá cố định ────────────────────────────────────────

class DestinationSheet extends StatefulWidget {
  final List<DestinationPrice> options;
  final int? selectedId;
  final DestinationPrice autoOption;
  const DestinationSheet({
    super.key,
    required this.options,
    required this.selectedId,
    required this.autoOption,
  });

  @override
  State<DestinationSheet> createState() => DestinationSheetState();
}

class DestinationSheetState extends State<DestinationSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _query.trim();
    final shown =
        widget.options.where((o) => matchesVietnamese(o.name, q)).toList();
    return AppSheet(
      icon: Icons.sell_rounded,
      title: 'Khu vực giao',
      subtitle: 'Chọn nơi giao để áp giá cố định',
      scrollable: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: AppField(
            controller: _searchCtrl,
            hint: 'Tìm khu vực giao',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xoá',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
            children: [
              if (q.isEmpty) ...[
                _DestinationTile(
                  icon: Icons.route_rounded,
                  title: 'Tự tính theo quãng đường',
                  subtitle: 'Giá theo km, tự áp giá khu vực nếu trùng',
                  selected: widget.selectedId == null,
                  onTap: () => Navigator.pop(context, widget.autoOption),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Text('Không tìm thấy khu vực phù hợp',
                        style: AppTextStyles.body
                            .copyWith(color: c.textSecondary)),
                  ),
                ),
              for (final o in shown) ...[
                _DestinationTile(
                  icon: Icons.location_on_rounded,
                  title: o.name,
                  subtitle: o.feeMax != null && o.feeMax! > o.fee
                      ? 'Tối đa ${Fmt.currency(o.feeMax!)}'
                      : null,
                  price: Fmt.currency(o.fee),
                  selected: o.id == widget.selectedId,
                  onTap: () => Navigator.pop(context, o),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? price;
  final bool selected;
  final VoidCallback onTap;
  const _DestinationTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.price,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.primarySoft : c.surfaceAlt,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(children: [
            Icon(icon,
                size: AppSize.iconMd,
                color: selected ? c.primary : c.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.bodyStrong.copyWith(
                          color: selected ? c.primary : c.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle!,
                        style: AppTextStyles.label
                            .copyWith(color: c.textSecondary)),
                  ],
                ],
              ),
            ),
            if (price != null) ...[
              const SizedBox(width: AppSpacing.md),
              Text(price!,
                  style: AppTextStyles.bodyStrong
                      .copyWith(color: selected ? c.primary : c.textPrimary)),
            ],
            if (selected) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.check_circle_rounded,
                  size: AppSize.iconMd, color: c.primary),
            ],
          ]),
        ),
      ),
    );
  }
}
