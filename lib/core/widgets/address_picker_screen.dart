import 'dart:async';
import 'package:flutter/material.dart';
import '../services/address_history_service.dart';
import '../services/address_search_service.dart';
import '../theme/app_theme.dart';
import 'map_picker_screen.dart';

class AddressPickerScreen extends StatefulWidget {
  final String  title;
  final String? initialQuery;

  const AddressPickerScreen({
    super.key,
    this.title        = 'Chọn địa chỉ',
    this.initialQuery,
  });

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();

  List<AddressHistoryItem> _history     = [];
  List<AddressResult>      _suggestions = [];
  bool _searching  = false;
  bool _selecting  = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    if (widget.initialQuery != null) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
        _onChanged(widget.initialQuery!);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _focusNode.requestFocus());
    }
  }

  Future<void> _loadHistory() async {
    final h = await AddressHistoryService.load();
    if (!mounted) return;
    setState(() => _history = h);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() { _suggestions = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await AddressSearchService.search(value);
      if (!mounted) return;
      setState(() { _suggestions = results; _searching = false; });
    });
  }

  Future<void> _selectFromSearch(AddressResult r) async {
    setState(() => _selecting = true);
    final detail = await AddressSearchService.getDetail(r);
    if (!mounted) return;
    setState(() => _selecting = false);

    if (detail != null && detail.lat != null && detail.lng != null) {
      final item = AddressHistoryItem(
          address: detail.display, lat: detail.lat!, lng: detail.lng!);
      await AddressHistoryService.save(item);
      if (!mounted) return;
      Navigator.of(context).pop(
          MapPickResult(address: detail.display, lat: detail.lat!, lng: detail.lng!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Không lấy được tọa độ. Vui lòng thử lại.')),
      );
    }
  }

  Future<void> _selectFromHistory(AddressHistoryItem item) async {
    await AddressHistoryService.save(item);
    if (!mounted) return;
    Navigator.of(context).pop(
        MapPickResult(address: item.address, lat: item.lat, lng: item.lng));
  }

  Future<void> _removeHistory(AddressHistoryItem item) async {
    await AddressHistoryService.remove(item.address);
    setState(() => _history.removeWhere((e) => e.address == item.address));
  }

  Future<void> _clearAllHistory() async {
    await AddressHistoryService.clear();
    setState(() => _history = []);
  }

  Future<void> _openMap() async {
    _focusNode.unfocus();
    final result = await Navigator.of(context).push<MapPickResult>(
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result != null && mounted) {
      await AddressHistoryService.save(AddressHistoryItem(
          address: result.address, lat: result.lat, lng: result.lng));
      if (!mounted) return;
      Navigator.of(context).pop(result);
    }
  }

  bool get _showHistory => _controller.text.trim().length < 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: _openMap,
            child: const Text('Từ bản đồ',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // ── Search field ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nhập địa chỉ...',
                hintStyle: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.search_rounded,
                      color: Colors.white, size: 18),
                ),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.textSecondary),
                        ),
                      )
                    : _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded,
                                color: AppColors.textSecondary, size: 20),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _suggestions = []);
                            },
                          )
                        : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF6F6F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          if (_selecting)
            const LinearProgressIndicator(
                minHeight: 2, color: AppColors.primary),

          // ── Content ───────────────────────────────────────────────────
          Expanded(
            child: _showHistory
                ? _HistoryList(
                    history:    _history,
                    onSelect:   _selectFromHistory,
                    onRemove:   _removeHistory,
                    onClearAll: _clearAllHistory,
                  )
                : _suggestions.isEmpty && !_searching
                    ? const SizedBox.shrink()
                    : _SearchResultList(
                        suggestions: _suggestions,
                        onSelect:    _selectFromSearch,
                      ),
          ),
        ],
      ),
    );
  }
}

// ── History List ──────────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  final List<AddressHistoryItem>      history;
  final void Function(AddressHistoryItem) onSelect;
  final void Function(AddressHistoryItem) onRemove;
  final VoidCallback                  onClearAll;

  const _HistoryList({
    required this.history,
    required this.onSelect,
    required this.onRemove,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            const Expanded(
              child: Text('Đã tìm kiếm gần đây',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: onClearAll,
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0)),
              child: const Text('Xóa tất cả',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: history.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1, indent: 48, color: Color(0xFFF0F0F5)),
            itemBuilder: (_, i) {
              final item = history[i];
              return Dismissible(
                key: ValueKey(item.address),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: AppColors.danger.withValues(alpha: 0.08),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger, size: 20),
                ),
                onDismissed: (_) => onRemove(item),
                child: InkWell(
                  onTap: () => onSelect(item),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 10),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.history_rounded,
                            size: 18, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item.address,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Search Result List ────────────────────────────────────────────────────────

class _SearchResultList extends StatelessWidget {
  final List<AddressResult>                  suggestions;
  final Future<void> Function(AddressResult) onSelect;

  const _SearchResultList(
      {required this.suggestions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: suggestions.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 48, color: Color(0xFFF0F0F5)),
      itemBuilder: (_, i) {
        final s = suggestions[i];
        return InkWell(
          onTap: () => onSelect(s),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_on_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.mainText.isNotEmpty ? s.mainText : s.display,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.secondaryText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(s.secondaryText,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
