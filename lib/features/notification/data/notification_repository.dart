import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/notification_item.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => ApiNotificationRepository(ref.read(apiClientProvider)),
);

class NotificationPage {
  final List<NotificationItem> items;
  final bool hasMore;
  const NotificationPage({required this.items, required this.hasMore});
}

abstract interface class NotificationRepository {
  Future<NotificationPage> fetchPage(int page);
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> delete(String id);
}

class ApiNotificationRepository implements NotificationRepository {
  final ApiClient _api;
  const ApiNotificationRepository(this._api);

  @override
  Future<NotificationPage> fetchPage(int page) async {
    final response =
        await _api.get('/shop/notifications', params: {'page': page});
    final data = unwrap(response) as List<dynamic>? ?? const [];
    return NotificationPage(
      items: data
          .map(
              (item) => NotificationItem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      hasMore: apiHasMore(response),
    );
  }

  @override
  Future<int> unreadCount() async {
    final response = await _api.get('/shop/notifications/unread-count');
    final data = unwrap(response);
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> markRead(String id) async {
    await _api.post('/shop/notifications/$id/read');
  }

  @override
  Future<void> markAllRead() async {
    await _api.post('/shop/notifications/read-all');
  }

  @override
  Future<void> delete(String id) async {
    await _api.delete('/shop/notifications/$id');
  }
}
