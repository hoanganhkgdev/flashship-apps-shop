import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';

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

  static final _pendingNotifications = <Map<String, String?>>[];

  static void Function({
    required String title,
    required String body,
    String? orderCode,
  })? _onIncomingNotification;

  static set onIncomingNotification(void Function({
    required String title,
    required String body,
    String? orderCode,
  })? callback) {
    _onIncomingNotification = callback;
    if (callback != null) {
      for (final n in _pendingNotifications) {
        callback(title: n['title'] ?? '', body: n['body'] ?? '', orderCode: n['orderCode']);
      }
      _pendingNotifications.clear();
    }
  }

  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onOpenedSub;

  static final _statusController = StreamController<String>.broadcast();
  static Stream<String> get orderStatusStream => _statusController.stream;

  static Future<void> init() async {
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    } else {
      await FirebaseMessaging.instance.requestPermission();
    }

    _onMessageSub?.cancel();
    _onMessageSub = FirebaseMessaging.onMessage.listen(_onMessage);
    _onOpenedSub?.cancel();
    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onTap);

    try {
      final initial = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 3));
      if (initial != null) _onTap(initial);
    } catch (_) {}
  }

  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  static void _dispatch(String title, String body, {String? orderCode}) {
    if (_onIncomingNotification != null) {
      _onIncomingNotification!(title: title, body: body, orderCode: orderCode);
    } else {
      _pendingNotifications.add({'title': title, 'body': body, 'orderCode': orderCode});
    }
  }

  static void _onMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] as String? ?? '';
    final body  = message.notification?.body  ?? message.data['body']  as String? ?? '';
    if (message.data['type'] == 'order_status') {
      final code = message.data['order_code'] as String?;
      if (code != null) _statusController.add(code);
      _dispatch(title, body, orderCode: code);
    } else if (title.isNotEmpty) {
      _dispatch(title, body);
    }
  }

  static void _onTap(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] as String? ?? '';
    final body  = message.notification?.body  ?? message.data['body']  as String? ?? '';
    if (message.data['type'] == 'order_status') {
      final code = message.data['order_code'] as String?;
      _dispatch(title, body, orderCode: code);
      if (code != null) _dispatchOrderTap(code);
    } else if (title.isNotEmpty) {
      _dispatch(title, body);
    }
  }

  static void _dispatchOrderTap(String code) {
    if (_onOrderTap != null) {
      _onOrderTap!(code);
    } else {
      _pendingOrderTap = code;
    }
  }
}
