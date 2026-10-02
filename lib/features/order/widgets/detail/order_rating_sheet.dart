part of '../../screens/order_detail_screen.dart';

// ─── Rating Sheet ─────────────────────────────────────────────────────────────

class _RatingSheet extends ConsumerStatefulWidget {
  final String orderCode, driverName;
  final VoidCallback onDone;
  const _RatingSheet({
    required this.orderCode,
    required this.driverName,
    required this.onDone,
  });

  @override
  ConsumerState<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<_RatingSheet> {
  int _rating = 5;
  bool _submitting = false;
  final Set<String> _selectedTags = {};
  final _noteCtrl = TextEditingController();

  static const _positiveTags = [
    'Giao hàng nhanh',
    'Đúng giờ',
    'Thái độ lịch sự',
    'Cẩn thận hàng hóa',
    'Liên lạc dễ dàng',
    'Chuyên nghiệp',
  ];

  static const _negativeTags = [
    'Giao hàng chậm',
    'Trễ giờ',
    'Thái độ không tốt',
    'Làm hỏng hàng',
    'Khó liên lạc',
    'Không đúng địa chỉ',
  ];

  List<String> get _tags => _rating >= 4 ? _positiveTags : _negativeTags;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final parts = [
      ..._selectedTags,
      if (_noteCtrl.text.trim().isNotEmpty) _noteCtrl.text.trim(),
    ];
    final note = parts.join(', ');
    try {
      await ref.read(orderRepositoryProvider).rate(
            widget.orderCode,
            rating: _rating,
            note: note,
          );
      widget.onDone();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppSnackbar.error(context,
            parseApiError(e, fallback: 'Không thể gửi đánh giá. Thử lại sau.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final positive = _rating >= 4;
    final tone = positive ? c.primary : c.danger;
    return AppSheet(
      icon: Icons.star_rounded,
      color: c.warning,
      title: 'Đánh giá tài xế',
      subtitle: widget.driverName.isEmpty ? null : widget.driverName,
      footer: AppButton(
        label: 'Gửi đánh giá',
        onPressed: _submitting ? null : _submit,
        isLoading: _submitting,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
              5,
              (i) => GestureDetector(
                    onTap: () => setState(() {
                      _rating = i + 1;
                      _selectedTags.clear();
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i < _rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: c.warning,
                        size: 42,
                      ),
                    ),
                  )),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(positive ? 'Điều bạn thích' : 'Vấn đề gặp phải',
            style: AppTextStyles.label.copyWith(color: c.textSecondary)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags.map((tag) {
            final selected = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  _selectedTags.remove(tag);
                } else {
                  _selectedTags.add(tag);
                }
              }),
              child: AnimatedContainer(
                duration: AppDuration.fast,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? tone.withValues(alpha: .12) : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: selected ? tone : c.divider),
                ),
                child: Text(tag,
                    style: AppTextStyles.label.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? tone : c.textSecondary)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          minLines: 2,
          textInputAction: TextInputAction.newline,
          style: TextStyle(fontSize: AppFontSize.md, color: c.textPrimary),
          decoration:
              const InputDecoration(hintText: 'Nhận xét thêm (tuỳ chọn)...'),
        ),
      ]),
    );
  }
}
