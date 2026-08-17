import 'dart:async';
import 'package:flutter/material.dart';
import '../services/address_search_service.dart';
import '../theme/app_theme.dart';
import 'map_picker_screen.dart';

class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final Color? fillColor;
  final void Function(String address, double? lat, double? lng)? onSelected;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    this.hint = 'Nhập địa chỉ...',
    this.fillColor,
    this.onSelected,
  });

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  List<AddressResult> _suggestions = [];
  Timer? _debounce;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _removeOverlay();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    _debounce?.cancel();
    if (text.trim().length < 3) {
      _removeOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() => _searching = true);
    final results = await AddressSearchService.search(query);
    if (!mounted) return;
    setState(() { _suggestions = results; _searching = false; });
    if (results.isNotEmpty && _focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlay = OverlayEntry(builder: (ctx) => _buildDropdown());
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Future<void> _onSuggestionTap(AddressResult result) async {
    _removeOverlay();
    _focusNode.unfocus();

    // Điền text ngay để UX nhanh
    widget.controller.text = result.display;

    // Lấy tọa độ
    final detail = await AddressSearchService.getDetail(result);
    if (!mounted) return;
    widget.controller.text = detail?.display ?? result.display;
    widget.onSelected?.call(
      detail?.display ?? result.display,
      detail?.lat,
      detail?.lng,
    );
  }

  Future<void> _openMapPicker() async {
    _removeOverlay();
    _focusNode.unfocus();

    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result == null || !mounted) return;

    widget.controller.text = result.address;
    widget.onSelected?.call(result.address, result.lat, result.lng);
  }

  Widget _buildDropdown() {
    return Positioned(
      width: _getFieldWidth(),
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 56),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _suggestions.map((r) => InkWell(
                onTap: () => _onSuggestionTap(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.mainText,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (r.secondaryText.isNotEmpty)
                              Text(r.secondaryText,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }

  double _getFieldWidth() {
    final box = context.findRenderObject() as RenderBox?;
    return box?.size.width ?? 300;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        CompositedTransformTarget(
          link: _layerLink,
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              filled: widget.fillColor != null ? true : null,
              fillColor: widget.fillColor,
              prefixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    )
                  : const Icon(Icons.location_on_rounded, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: const Icon(Icons.map_rounded, color: AppColors.primary),
                tooltip: 'Chọn trên bản đồ',
                onPressed: _openMapPicker,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
