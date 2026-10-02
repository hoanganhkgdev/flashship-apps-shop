class AppConstants {
  static const String baseUrl = 'https://app.flashship.vn/api';
  static const String tokenKey = 'shop_auth_token';
  static const String userKey = 'shop_user_data';
  static const String googleMapsApiKey =
      'AIzaSyDnE3bCwhzy4tJ22BVmRMyolwuyCx-1rQc';

  static const String facebookUrl = 'https://facebook.com/flashship.vn';
  static const String zaloUrl = 'https://zalo.me/flashship';
  static const String hotline = '1900xxxx';
}

/// Bán kính (km) tìm gợi ý địa chỉ quanh trung tâm khu vực.
const double kAddressSearchRadiusKm = 25.0;

/// Toạ độ trung tâm dự phòng cho khu vực chưa có lat/lng trên server.
const Map<String, ({double lat, double lng})> kCityCenters = {
  'Rạch Giá': (lat: 10.0126, lng: 105.0809),
};
