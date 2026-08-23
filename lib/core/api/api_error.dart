/// Trích message lỗi từ response API (hỗ trợ cả dạng `message` và
/// `errors` map của Laravel validation). [fallback] dùng khi không có
/// response (mất mạng, exception khác) — tuỳ theo ngữ cảnh gọi.
String parseApiError(dynamic error, {String fallback = 'Lỗi kết nối'}) {
  try {
    final response = (error as dynamic).response;
    if (response != null) {
      final data = response.data;
      if (data is Map) {
        final message = data['message'];
        if (message != null) return message.toString();

        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
      }
      return 'Server lỗi ${response.statusCode}';
    }

    final type = (error as dynamic).type?.toString() ?? '';
    if (type.contains('connectionTimeout') || type.contains('receiveTimeout')) {
      return 'Timeout: server không phản hồi';
    }
    return fallback;
  } catch (_) {
    return fallback;
  }
}
