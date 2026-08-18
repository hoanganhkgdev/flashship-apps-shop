import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_item.dart';

const _kKey = 'shop_notifications_v1';
// Giới hạn CACHE offline (SharedPreferences) — KHÔNG phải giới hạn hiển thị.
// Danh sách hiển thị trong state không còn bị cắt; số trang tải được kiểm
// soát tự nhiên qua notificationHasMoreProvider (pagination thật từ server).
const _kLocalCacheMax = 100;

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<NotificationItem>>(
        (ref) => NotificationNotifier(ref));

// Còn trang tiếp theo để loadMore() hay không — cập nhật bởi NotificationNotifier
// sau mỗi lần refresh()/loadMore(), UI (nút "Xem thêm") watch provider này.
final notificationHasMoreProvider = StateProvider<bool>((ref) => true);

// Đếm chưa đọc CHÍNH XÁC trên toàn bộ DB (không giới hạn theo số item đã tải
// về máy) — gọi thẳng endpoint đếm riêng thay vì derive từ notificationProvider.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final res = await ref.read(apiClientProvider).get('/shop/notifications/unread-count');
    return (res.data['count'] as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

class NotificationNotifier extends StateNotifier<List<NotificationItem>> {
  final Ref _ref;
  StreamSubscription? _rtdbSub;
  int  _page = 1;
  bool _loadingMore = false;

  NotificationNotifier(this._ref) : super([]) {
    _loadLocal();
    final auth = _ref.read(authProvider);
    if (auth.isAuthenticated && auth.user != null) {
      _onAuthenticated(auth.user!.id);
    }
    _ref.listen<AuthState>(authProvider, (_, next) {
      if (next.isAuthenticated && next.user != null) {
        _onAuthenticated(next.user!.id);
      } else {
        _onSignedOut();
      }
    });
  }

  void _onAuthenticated(int userId) {
    refresh();
    _startRtdb(userId);
  }

  void _onSignedOut() {
    _rtdbSub?.cancel();
    _rtdbSub = null;
    state = [];
    _page = 1;
    _ref.read(notificationHasMoreProvider.notifier).state = true;
    _clearLocal();
  }

  // ── Trang 1 — thay thế toàn bộ state hiện có ────────────────────────────
  // Dùng lúc mở app, RTDB ping, pull-to-refresh.

  Future<void> refresh() async {
    try {
      final res  = await _ref.read(apiClientProvider)
          .get('/shop/notifications', params: {'page': 1});
      final raw  = res.data['data'] as List? ?? [];
      final items = raw
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final hasMore = res.data['has_more'] as bool? ?? false;

      _mergeRefresh(items);
      _page = 2;
      _ref.read(notificationHasMoreProvider.notifier).state = hasMore;
      _saveLocal();
      _ref.invalidate(unreadCountProvider);
    } catch (_) {}
  }

  // Giữ tên cũ cho các chỗ gọi trước đây (RTDB listener, add()).
  Future<void> syncFromServer() => refresh();

  // ── Trang kế tiếp — nối vào cuối state hiện có ──────────────────────────
  // Dùng khi bấm "Xem thêm". Không sort/cắt lại toàn bộ danh sách như
  // refresh() — trang sau vốn chỉ là dữ liệu server nối thêm.

  Future<void> loadMore() async {
    if (_loadingMore || !_ref.read(notificationHasMoreProvider)) return;
    _loadingMore = true;
    try {
      final res  = await _ref.read(apiClientProvider)
          .get('/shop/notifications', params: {'page': _page});
      final raw  = res.data['data'] as List? ?? [];
      final items = raw
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final hasMore = res.data['has_more'] as bool? ?? false;

      final existingIds = state.map((n) => n.id).toSet();
      final appended = items.where((n) => !existingIds.contains(n.id));
      state = [...state, ...appended];
      _page += 1;
      _ref.read(notificationHasMoreProvider.notifier).state = hasMore;
      _saveLocal();
    } catch (_) {} finally {
      _loadingMore = false;
    }
  }

  // Server là nguồn sự thật cho trang 1; vẫn giữ item local rất mới (<90s)
  // từ FCM chưa kịp lên server — CHỈ áp dụng cho refresh() (trang 1),
  // loadMore() không cần vì các trang sau không thể có item instant-add.
  void _mergeRefresh(List<NotificationItem> serverItems) {
    final serverIds  = serverItems.map((e) => e.id).toSet();
    final recentLocal = state.where((n) {
      if (serverIds.contains(n.id)) return false;
      return DateTime.now().difference(n.createdAt).inSeconds < 90;
    });
    final seen = <String>{};
    state = [...serverItems, ...recentLocal]
        .where((n) => seen.add(n.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ── RTDB listener: backend pings customer_notifications/{userId} ─────────

  void _startRtdb(int userId) {
    _rtdbSub?.cancel();
    _rtdbSub = FirebaseDatabase.instance
        .ref('customer_notifications/$userId')
        .onValue
        .listen((_) => refresh());
  }

  // ── Instant local add (FCM while app is foregrounded) ────────────────────

  void add(NotificationItem item) {
    final dup = state.any((n) =>
        n.orderCode == item.orderCode &&
        n.title     == item.title &&
        n.createdAt.difference(item.createdAt).inMinutes.abs() < 5);
    if (dup) return;

    state = [item, ...state];
    _saveLocal();

    // Pull server-confirmed version after a short delay (refresh() ở đây
    // cũng tự invalidate unreadCountProvider nên badge sẽ tự cập nhật theo).
    Future.delayed(const Duration(seconds: 4), refresh);
  }

  // ── Read / Delete ─────────────────────────────────────────────────────────

  void markRead(String id) {
    state = state.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
    _saveLocal();
    _patchRead(id);
  }

  void markAllRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    _saveLocal();
    _patchAllRead();
  }

  void delete(String id) {
    state = state.where((n) => n.id != id).toList();
    _saveLocal();
    _deleteOnServer(id);
  }

  Future<void> _patchRead(String id) async {
    try {
      await _ref.read(apiClientProvider).post('/shop/notifications/$id/read');
      _ref.invalidate(unreadCountProvider);
    } catch (_) {}
  }

  Future<void> _patchAllRead() async {
    try {
      await _ref.read(apiClientProvider).post('/shop/notifications/read-all');
      _ref.invalidate(unreadCountProvider);
    } catch (_) {}
  }

  Future<void> _deleteOnServer(String id) async {
    try {
      await _ref.read(apiClientProvider).delete('/shop/notifications/$id');
    } catch (_) {}
  }

  // ── Local persistence (offline cache) ───────────────────────────────────

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kKey);
      if (raw != null) {
        state = (jsonDecode(raw) as List)
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Cache offline giới hạn _kLocalCacheMax item gần nhất — khác với
      // state hiển thị trong bộ nhớ (không giới hạn, do pagination kiểm soát).
      final toCache = state.length > _kLocalCacheMax
          ? state.sublist(0, _kLocalCacheMax)
          : state;
      await prefs.setString(
          _kKey, jsonEncode(toCache.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _clearLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kKey);
    } catch (_) {}
  }

  @override
  void dispose() {
    _rtdbSub?.cancel();
    super.dispose();
  }
}
