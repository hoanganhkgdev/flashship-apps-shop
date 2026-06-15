import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/address/models/address_entry.dart';
import '../../features/address/providers/address_provider.dart';
import '../services/address_history_service.dart';
import '../services/address_search_service.dart';
import '../theme/app_theme.dart';
import 'map_picker_screen.dart';

class AddressPickerScreen extends ConsumerStatefulWidget {
  final String  title;
  final String? initialQuery;

  const AddressPickerScreen({
    super.key,
    this.title        = 'Chọn địa chỉ',
    this.initialQuery,
  });

  @override
  ConsumerState<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends ConsumerState<AddressPickerScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();
  late final TabController _tabController;

  List<AddressHistoryItem> _history     = [];
  List<AddressResult>      _suggestions = [];
  bool _searching  = false;
  bool _selecting  = false;
  int  _savedLimit   = 10;
  int  _historyLimit = 5;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _tabController.dispose();
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
      final pn = r.mainText != r.display ? r.mainText : null;
      final item = AddressHistoryItem(
          address: detail.display, lat: detail.lat!, lng: detail.lng!, placeName: pn);
      await AddressHistoryService.save(item);
      if (!mounted) return;
      Navigator.of(context).pop(MapPickResult(
          address: detail.display, lat: detail.lat!, lng: detail.lng!, placeName: pn));
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
    Navigator.of(context).pop(MapPickResult(
        address: item.address, lat: item.lat, lng: item.lng, placeName: item.placeName));
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
    final savedEntries = ref.watch(addressProvider).valueOrNull ?? [];

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
          if (_showHistory) ...[
            // Chọn trên bản đồ
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: InkWell(
                onTap: _openMap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.map_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text('Chọn vị trí trên bản đồ',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary, size: 20),
                  ]),
                ),
              ),
            ),

            // Segmented tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(3),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.history_rounded, size: 14),
                          const SizedBox(width: 5),
                          const Text('Gần đây'),
                          if (_history.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            _TabBadge(count: _history.length),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bookmark_rounded, size: 14),
                          const SizedBox(width: 5),
                          const Text('Đã lưu'),
                          if (savedEntries.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            _TabBadge(count: savedEntries.length),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 2),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Tìm kiếm gần đây
                  _history.isEmpty
                      ? const _EmptyTab(
                          icon: Icons.history_rounded,
                          label: 'Chưa có tìm kiếm gần đây',
                        )
                      : _HistoryTab(
                          history:    _history,
                          limit:      _historyLimit,
                          onSelect:   _selectFromHistory,
                          onRemove:   _removeHistory,
                          onClearAll: _clearAllHistory,
                          onLoadMore: _history.length > _historyLimit
                              ? () => setState(() =>
                                  _historyLimit = (_historyLimit + 5)
                                      .clamp(0, _history.length))
                              : null,
                        ),

                  // Tab 1: Địa chỉ đã lưu
                  savedEntries.isEmpty
                      ? const _EmptyTab(
                          icon: Icons.bookmark_outline_rounded,
                          label: 'Chưa có địa chỉ đã lưu',
                        )
                      : _SavedTab(
                          entries:  savedEntries,
                          limit:    _savedLimit,
                          onLoadMore: savedEntries.length > _savedLimit
                              ? () => setState(() =>
                                  _savedLimit = (_savedLimit + 10)
                                      .clamp(0, savedEntries.length))
                              : null,
                          onSelect: (entry) {
                            if (entry.lat == null || entry.lng == null) return;
                            Navigator.of(context).pop(MapPickResult(
                              address:      entry.address,
                              lat:          entry.lat!,
                              lng:          entry.lng!,
                              placeName:    entry.displayName,
                              contactName:  entry.name,
                              contactPhone: entry.phone,
                            ));
                          },
                        ),
                ],
              ),
            ),
          ] else
            Expanded(
              child: _suggestions.isEmpty && !_searching
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

// ── Tab badge ─────────────────────────────────────────────────────────────────

class _TabBadge extends StatelessWidget {
  final int count;
  const _TabBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: AppColors.primary)),
    );
  }
}

// ── Empty tab ─────────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _EmptyTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: AppColors.textSecondary),
        const SizedBox(height: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary)),
      ]),
    );
  }
}

// ── Saved address tile ────────────────────────────────────────────────────────

class _SavedAddressTile extends StatelessWidget {
  final AddressEntry entry;
  final VoidCallback onTap;
  const _SavedAddressTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bookmark_rounded,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.displayName,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(entry.address,
                    style: const TextStyle(fontSize: 12,
                        color: AppColors.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── History tab ───────────────────────────────────────────────────────────────

// ── Saved tab ─────────────────────────────────────────────────────────────────

class _SavedTab extends StatelessWidget {
  final List<AddressEntry>          entries;
  final int                         limit;
  final void Function(AddressEntry) onSelect;
  final VoidCallback?               onLoadMore;

  const _SavedTab({
    required this.entries,
    required this.limit,
    required this.onSelect,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final visible = entries.take(limit).toList();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: visible.length + (onLoadMore != null ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i == visible.length) {
          return TextButton(
            onPressed: onLoadMore,
            child: Text(
              'Xem thêm (${entries.length - limit} địa chỉ)',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.primary,
                  fontWeight: FontWeight.w600),
            ),
          );
        }
        return _SavedAddressTile(
          entry: visible[i],
          onTap: () => onSelect(visible[i]),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final List<AddressHistoryItem>          history;
  final int                               limit;
  final void Function(AddressHistoryItem) onSelect;
  final void Function(AddressHistoryItem) onRemove;
  final VoidCallback                      onClearAll;
  final VoidCallback?                     onLoadMore;

  const _HistoryTab({
    required this.history,
    required this.limit,
    required this.onSelect,
    required this.onRemove,
    required this.onClearAll,
    this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final visible = history.take(limit).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(children: [
            const Text('Gần đây',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const Spacer(),
            TextButton(
              onPressed: onClearAll,
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 0)),
              child: const Text('Xóa tất cả',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: visible.length + (onLoadMore != null ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (i == visible.length) {
                return TextButton(
                  onPressed: onLoadMore,
                  child: Text(
                    'Xem thêm (${history.length - limit} địa chỉ)',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                );
              }
              final item = visible[i];
              return Dismissible(
                key: ValueKey(item.address),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger, size: 20),
                ),
                onDismissed: (_) => onRemove(item),
                child: InkWell(
                  onTap: () => onSelect(item),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.history_rounded,
                            size: 18, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.placeName ?? item.address,
                                style: const TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (item.placeName != null) ...[
                              const SizedBox(height: 2),
                              Text(item.address,
                                  style: const TextStyle(fontSize: 12,
                                      color: AppColors.textSecondary),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = suggestions[i];
        return InkWell(
          onTap: () => onSelect(s),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(12),
            ),
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
