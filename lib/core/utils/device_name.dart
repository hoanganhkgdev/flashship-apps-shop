import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Tên thiết bị để gửi kèm lúc đăng nhập (hiện ở màn "Thiết bị đăng nhập").
///
/// iOS: dùng tên người dùng tự đặt cho máy (Cài đặt > Cài đặt chung > Giới
/// thiệu > Tên) qua [IosDeviceInfo.name] — package không cung cấp bảng tra
/// mã hiệu (vd "iPhone16,2") sang tên thương mại ("iPhone 15 Pro Max"), tự
/// duy trì bảng đó sẽ nhanh lỗi thời mỗi khi Apple ra máy mới.
/// Android: [AndroidDeviceInfo.model] đã là tên model khá dễ đọc sẵn.
Future<String?> getDeviceName() async {
  try {
    final plugin = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return info.name;
    }
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      final name = '${info.manufacturer} ${info.model}'.trim();
      return name.isEmpty ? null : name;
    }
  } catch (_) {}
  return null;
}
