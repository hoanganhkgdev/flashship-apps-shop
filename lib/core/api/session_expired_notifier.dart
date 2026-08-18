import 'dart:async';

/// Báo cho tầng trên (main.dart) khi API trả 401 ngoài các endpoint auth mà
/// 401 là lỗi nghiệp vụ bình thường — tức phiên đăng nhập đã hết hạn.
/// ApiClient không có Ref/context nên không thể tự logout/điều hướng, đặt ở
/// đây để tránh phụ thuộc ngược ApiClient → AuthNotifier.
class SessionExpiredNotifier {
  SessionExpiredNotifier._();

  static final _controller = StreamController<void>.broadcast();
  static Stream<void> get stream => _controller.stream;

  static void notify() => _controller.add(null);
}
