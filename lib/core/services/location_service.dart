import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_constants.dart';

class LocationService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            forceLocationManager: false,
            timeLimit: const Duration(seconds: 10),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.best,
            activityType: ActivityType.automotiveNavigation,
            pauseLocationUpdatesAutomatically: false,
            timeLimit: const Duration(seconds: 10),
          );

    // GPS có thể không trả kết quả trong thời hạn (trong nhà, simulator chưa đặt
    // vị trí, vừa bật định vị): không để lỗi này thoát ra thành exception chưa
    // bắt — thử vị trí gần nhất đã biết, không có thì trả null để màn hình tự
    // xử lý (người dùng vẫn kéo bản đồ chọn tay được).
    try {
      return await Geolocator.getCurrentPosition(locationSettings: settings);
    } on TimeoutException {
      return _lastKnownOrNull();
    } catch (_) {
      return _lastKnownOrNull();
    }
  }

  static Future<Position?> _lastKnownOrNull() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> addressFromCoords(double lat, double lng) async {
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': AppConstants.googleMapsApiKey,
          'language': 'vi',
        },
      );
      final results = res.data['results'] as List?;
      if (results == null || results.isEmpty) return null;
      return results.first['formatted_address'] as String?;
    } catch (_) {
      return null;
    }
  }
}
