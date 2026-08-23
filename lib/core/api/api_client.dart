import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../storage/token_storage.dart';
import 'session_expired_notifier.dart';

export 'api_error.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.read(tokenStorageProvider)),
);

// 401 ở các endpoint này là lỗi nghiệp vụ bình thường (sai mật khẩu, OTP hết
// hạn...), không phải phiên đăng nhập hết hạn — không bắn SessionExpiredNotifier.
// '/shop/auth/logout' cũng loại trừ: gọi logout khi token đã chết vẫn hợp lệ,
// 401 ở đó không mang thêm thông tin gì và tránh vòng lặp lại tự kích hoạt
// luồng hết phiên ngay trong lúc đang xử lý logout.
const _sessionExemptPaths = {
  '/shop/auth/login',
  '/shop/auth/send-otp',
  '/shop/auth/verify-otp-register',
  '/shop/auth/forgot-password',
  '/shop/auth/reset-password',
  '/shop/auth/logout',
  '/app-version',
};

class ApiClient {
  late final Dio _dio;
  final TokenStorage _tokenStorage;

  ApiClient(this._tokenStorage) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ));

    _dio.httpClientAdapter = _buildAdapter();

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.read();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        final path = error.requestOptions.path;
        if (error.response?.statusCode == 401 &&
            !_sessionExemptPaths.contains(path)) {
          SessionExpiredNotifier.notify();
        }
        handler.next(error);
      },
    ));
  }

  IOHttpClientAdapter _buildAdapter() {
    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 8);
      return client;
    };
    return adapter;
  }

  /// Đóng connection cũ rồi gắn adapter mới — gọi khi app resume từ
  /// background lâu, tránh request bị treo do tái dùng socket mà OS đã
  /// đóng băng trong lúc app ở nền.
  void resetConnection() {
    final old = _dio.httpClientAdapter;
    _dio.httpClientAdapter = _buildAdapter();
    old.close(force: true);
  }

  Future<Response> get(String path,
          {Map<String, dynamic>? params, Options? options}) =>
      _dio.get(path, queryParameters: params, options: options);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);
}

/// Bóc `data` khỏi response bọc chuẩn `{ data: ... }`, giữ nguyên nếu
/// response không theo dạng đó.
dynamic unwrap(Response res) =>
    res.data is Map ? (res.data['data'] ?? res.data) : res.data;

/// Đọc cờ phân trang từ cả contract mới (`meta.has_more`) lẫn contract cũ
/// (`has_more` ở root) trong giai đoạn backend đang chuyển đổi.
bool apiHasMore(Response response) {
  final body = response.data;
  if (body is! Map) return false;
  final meta = body['meta'];
  if (meta is Map && meta['has_more'] is bool) {
    return meta['has_more'] as bool;
  }
  return body['has_more'] as bool? ?? false;
}
