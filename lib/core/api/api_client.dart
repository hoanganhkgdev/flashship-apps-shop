import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ));

    _dio.httpClientAdapter = _buildAdapter();

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) => handler.next(error),
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

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);
}

/// Trích message lỗi từ response API (hỗ trợ cả dạng `message` và
/// `errors` map của Laravel validation). [fallback] dùng khi không có
/// response (mất mạng, exception khác) — tuỳ theo ngữ cảnh gọi.
String parseApiError(dynamic e, {String fallback = 'Lỗi kết nối'}) {
  try {
    final response = (e as dynamic).response;
    if (response != null) {
      final data = response.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg != null) return msg.toString();
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
      }
      return 'Server lỗi ${response.statusCode}';
    }
    final type = (e as dynamic).type?.toString() ?? '';
    if (type.contains('connectionTimeout') || type.contains('receiveTimeout')) {
      return 'Timeout: server không phản hồi';
    }
    return fallback;
  } catch (_) {
    return fallback;
  }
}

/// Bóc `data` khỏi response bọc chuẩn `{ data: ... }`, giữ nguyên nếu
/// response không theo dạng đó.
dynamic unwrap(Response res) =>
    res.data is Map ? (res.data['data'] ?? res.data) : res.data;
