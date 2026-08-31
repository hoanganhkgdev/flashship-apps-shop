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
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: c.divider),
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 22, color: c.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.warningSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.star_rounded, color: c.warning, size: 30),
            ),
            const SizedBox(height: 12),
            const Text('Đánh giá tài xế',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(widget.driverName,
                style: TextStyle(fontSize: 15, color: c.textSecondary)),
            const SizedBox(height: 20),

            // Stars
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
            const SizedBox(height: 20),

            // Preset tags
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _rating >= 4 ? 'Điều bạn thích' : 'Vấn đề gặp phải',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.textSecondary),
              ),
            ),
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
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? (_rating >= 4 ? c.primary : c.danger)
                          : c.surface,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: selected
                            ? (_rating >= 4 ? c.primary : c.danger)
                            : c.divider,
                        width: 1.2,
                      ),
                    ),
                    child: Text(tag,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : c.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Custom note
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              minLines: 2,
              textInputAction: TextInputAction.newline,
              style: TextStyle(fontSize: 14, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nhận xét thêm (tuỳ chọn)...',
                hintStyle: TextStyle(fontSize: 13, color: c.textTertiary),
                filled: true,
                fillColor: c.background,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: c.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: c.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Gửi đánh giá',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
