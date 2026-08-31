import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

typedef IncomingNotificationCallback = void Function({
  required String title,
  required String body,
  String? orderCode,
});

class NotificationService {
  NotificationService._();

  // Đệm order code khi bấm thông báo đẩy TRƯỚC KHI onOrderTap được gán
  // (vd cold-start: getInitialMessage() xử lý xong trước khi HomeScreen kịp
  // mount và gán callback) — cùng pattern với _pendingNotifications, tránh
  // phụ thuộc thứ tự/số lần gọi init().
  static void Function(String orderCode)? _onOrderTap;
  static String? _pendingOrderTap;

  static set onOrderTap(void Function(String orderCode)? callback) {
    _onOrderTap = callback;
    if (callback != null && _pendingOrderTap != null) {
      callback(_pendingOrderTap!);
      _pendingOrderTap = null;
    }
  }

  static void Function(String orderCode)? get onOrderTap => _onOrderTap;

  static final _pendingNotifications =
      <({String title, String body, String? orderCode})>[];
  static IncomingNotificationCallback? _onIncomingNotification;

  static set onIncomingNotification(IncomingNotificationCallback? callback) {
    _onIncomingNotification = callback;
    if (callback == null) return;

    for (final notification in _pendingNotifications) {
      callback(
        title: notification.title,
        body: notification.body,
        orderCode: notification.orderCode,
      );
    }
    _pendingNotifications.clear();
  }

  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onOpenedSub;
  static StreamSubscription<String>? _onTokenRefreshSub;

  // Đệm token nếu Firebase trả token trước khi AuthNotifier sẵn sàng. Nếu
  // không đệm, cold-start có thể làm mất token mới và backend tiếp tục giữ
  // token cũ cho tới lần đăng nhập tiếp theo.
  static void Function(String newToken)? _onTokenRefresh;
  static String? _pendingToken;

  static set onTokenRefresh(void Function(String newToken)? callback) {
    _onTokenRefresh = callback;
    if (callback != null && _pendingToken != null) {
      callback(_pendingToken!);
      _pendingToken = null;
    }
  }

  static void _dispatchToken(String token) {
    if (_onTokenRefresh != null) {
      _onTokenRefresh!(token);
    } else {
      _pendingToken = token;
    }
  }

  static final _statusController = StreamController<String>.broadcast();
  static Stream<String> get orderStatusStream => _statusController.stream;

  static Future<void> init() async {
    if (Platform.isIOS) {
      await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
    } else {
      await FirebaseMessaging.instance.requestPermission();
    }

    _onMessageSub?.cancel();
    _onMessageSub = FirebaseMessaging.onMessage.listen(_onMessage);
    _onOpenedSub?.cancel();
    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onTap);
    _onTokenRefreshSub?.cancel();
    _onTokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen(_dispatchToken);

    final token = await getToken();
    if (token != null) _dispatchToken(token);

    try {
      final initial = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 3));
      if (initial != null) _onTap(initial);
    } catch (_) {}
  }

  static Future<String?> getToken() async {
    try {
      // Trên iOS, gọi getToken trước khi APNs token sẵn sàng sẽ ném lỗi
      // [firebase_messaging/apns-token-not-set]. Chờ ngắn theo trạng thái thật
      // thay vì để lần đăng ký FCM của cả phiên bị bỏ qua.
      if (Platform.isIOS) {
        for (var attempt = 0; attempt < 5; attempt++) {
          final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  static void _dispatch(String title, String body, {String? orderCode}) {
    if (_onIncomingNotification != null) {
      _onIncomingNotification!(title: title, body: body, orderCode: orderCode);
    } else {
      _pendingNotifications
          .add((title: title, body: body, orderCode: orderCode));
    }
  }

  static void _onMessage(RemoteMessage message) {
    final (:title, :body, :orderCode, :isOrderStatus) = _parseMessage(message);

    if (isOrderStatus) {
      if (orderCode != null) _statusController.add(orderCode);
      _dispatch(title, body, orderCode: orderCode);
    } else if (title.isNotEmpty) {
      _dispatch(title, body);
    }
  }

  static void _onTap(RemoteMessage message) {
    final (:title, :body, :orderCode, :isOrderStatus) = _parseMessage(message);

    if (isOrderStatus) {
      _dispatch(title, body, orderCode: orderCode);
      if (orderCode != null) _dispatchOrderTap(orderCode);
    } else if (title.isNotEmpty) {
      _dispatch(title, body);
    }
  }

  static ({
    String title,
    String body,
    String? orderCode,
    bool isOrderStatus,
  }) _parseMessage(RemoteMessage message) {
    final data = message.data;
    return (
      title: message.notification?.title ?? '${data['title'] ?? ''}',
      body: message.notification?.body ?? '${data['body'] ?? ''}',
      orderCode: data['order_code']?.toString(),
      isOrderStatus: data['type'] == 'order_status',
    );
  }

  static void _dispatchOrderTap(String code) {
    if (_onOrderTap != null) {
      _onOrderTap!(code);
    } else {
      _pendingOrderTap = code;
    }
  }
}
