import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/notification_item.dart';

const _kKey = 'shop_notifications_v1';
const _kMax = 50;

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<NotificationItem>>(
        (ref) => NotificationNotifier(ref));

final unreadCountProvider = Provider<int>((ref) =>
    ref.watch(notificationProvider).where((n) => !n.isRead).length);

class NotificationNotifier extends StateNotifier<List<NotificationItem>> {
  final Ref _ref;
  StreamSubscription? _rtdbSub;

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
    _syncFromServer();
    _startRtdb(userId);
  }

  void _onSignedOut() {
    _rtdbSub?.cancel();
    _rtdbSub = null;
    state   = [];
    _clearLocal();
  }

  // ── Server sync ──────────────────────────────────────────────────────────

  Future<void> syncFromServer() => _syncFromServer();

  Future<void> _syncFromServer() async {
    try {
      final res   = await _ref.read(apiClientProvider).get('/shop/notifications');
      final raw   = res.data['data'] as List? ?? [];
      final items = raw
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _mergeServer(items);
      _saveLocal();
    } catch (_) {}
  }

  // Server is source of truth; keep very-recent local FCM items (< 90s)
  // not yet written to server.
  void _mergeServer(List<NotificationItem> serverItems) {
    final serverIds  = serverItems.map((e) => e.id).toSet();
    final recentLocal = state.where((n) {
      if (serverIds.contains(n.id)) return false;
      return DateTime.now().difference(n.createdAt).inSeconds < 90;
    });
    final seen   = <String>{};
    final merged = [...serverItems, ...recentLocal]
        .where((n) => seen.add(n.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = merged.length > _kMax ? merged.sublist(0, _kMax) : merged;
  }

  // ── RTDB listener: backend pings customer_notifications/{userId} ─────────

  void _startRtdb(int userId) {
    _rtdbSub?.cancel();
    _rtdbSub = FirebaseDatabase.instance
        .ref('customer_notifications/$userId')
        .onValue
        .listen((_) => _syncFromServer());
  }

  // ── Instant local add (FCM while app is foregrounded) ────────────────────

  void add(NotificationItem item) {
    final dup = state.any((n) =>
        n.orderCode == item.orderCode &&
        n.title     == item.title &&
        n.createdAt.difference(item.createdAt).inMinutes.abs() < 5);
    if (dup) return;

    final next = [item, ...state];
    state = next.length > _kMax ? next.sublist(0, _kMax) : next;
    _saveLocal();

    // Pull server-confirmed version after a short delay
    Future.delayed(const Duration(seconds: 4), _syncFromServer);
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
    } catch (_) {}
  }

  Future<void> _patchAllRead() async {
    try {
      await _ref.read(apiClientProvider).post('/shop/notifications/read-all');
    } catch (_) {}
  }

  Future<void> _deleteOnServer(String id) async {
    try {
      await _ref.read(apiClientProvider).delete('/shop/notifications/$id');
    } catch (_) {}
  }

  // ── Local persistence (badge count / offline cache) ───────────────────────

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
      await prefs.setString(
          _kKey, jsonEncode(state.map((e) => e.toJson()).toList()));
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
