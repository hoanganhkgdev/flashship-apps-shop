import 'package:local_auth/local_auth.dart';

/// Bọc [LocalAuthentication] — mọi lỗi (không hỗ trợ, người dùng huỷ, khoá
/// do thử sai quá nhiều...) đều quy về false, màn khoá PIN luôn còn lối vào
/// bằng mã PIN nên không cần phân biệt loại lỗi ở tầng gọi.
class BiometricAuth {
  static final _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck   = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Xác thực để mở khoá ứng dụng',
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
