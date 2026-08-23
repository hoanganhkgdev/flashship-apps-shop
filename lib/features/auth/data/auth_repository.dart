import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/shop_user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.read(apiClientProvider)),
);

class AuthSession {
  final String token;
  final ShopUserModel user;
  const AuthSession({required this.token, required this.user});
}

class LoginDevice {
  final int id;
  final String? deviceName;
  final String? location;
  final DateTime? lastActiveAt;
  final bool isCurrent;

  const LoginDevice(
      {required this.id,
      this.deviceName,
      this.location,
      this.lastActiveAt,
      required this.isCurrent});

  factory LoginDevice.fromJson(Map<String, dynamic> json) => LoginDevice(
        id: json['id'] as int,
        deviceName: json['device_name'] as String?,
        location: json['location'] as String?,
        lastActiveAt: json['last_active_at'] == null
            ? null
            : DateTime.tryParse(json['last_active_at'] as String),
        isCurrent: json['is_current'] as bool? ?? false,
      );

  bool get isTablet {
    final name = deviceName?.toLowerCase() ?? '';
    return name.contains('ipad') ||
        name.contains('tablet') ||
        name.contains('tab ');
  }
}

abstract interface class AuthRepository {
  Future<void> sendOtp(String phone);
  Future<AuthSession> register(Map<String, dynamic> data);
  Future<AuthSession> login(String phone, String password,
      {String? deviceName});
  Future<ShopUserModel> me();
  Future<ShopUserModel> updateProfile(Map<String, dynamic> data);
  Future<ShopUserModel> uploadAvatar(String filePath);
  Future<void> changePassword(String current, String next);
  Future<void> sendChangePhoneOtp(String phone);
  Future<ShopUserModel> verifyChangePhone(String phone, String otp);
  Future<void> updateFcmToken(String token);
  Future<void> logout();
  Future<void> deleteAccount();
  Future<void> sendForgotPasswordOtp(String phone);
  Future<void> resetPassword(String phone, String otp, String password);
  Future<List<LoginDevice>> devices();
  Future<void> revokeDevice(int id);
  Future<void> revokeOtherDevices();
}

class ApiAuthRepository implements AuthRepository {
  final ApiClient _api;
  const ApiAuthRepository(this._api);

  AuthSession _session(Response response) {
    final data = unwrap(response) as Map<String, dynamic>;
    return AuthSession(
      token: data['token'] as String,
      user: ShopUserModel.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  ShopUserModel _user(Response response) =>
      ShopUserModel.fromJson(unwrap(response) as Map<String, dynamic>);

  @override
  Future<void> sendOtp(String phone) async =>
      _api.post('/shop/auth/send-otp', data: {'phone': phone});

  @override
  Future<AuthSession> register(Map<String, dynamic> data) async =>
      _session(await _api.post('/shop/auth/verify-otp-register', data: data));

  @override
  Future<AuthSession> login(String phone, String password,
          {String? deviceName}) async =>
      _session(await _api.post('/shop/auth/login', data: {
        'phone': phone,
        'password': password,
        if (deviceName != null) 'device_name': deviceName,
      }));

  @override
  Future<ShopUserModel> me() async => _user(await _api.get('/shop/auth/me'));
  @override
  Future<ShopUserModel> updateProfile(Map<String, dynamic> data) async =>
      _user(await _api.patch('/shop/auth/profile', data: data));
  @override
  Future<ShopUserModel> uploadAvatar(String filePath) async =>
      _user(await _api.post('/shop/auth/avatar',
          data: FormData.fromMap({
            'image': await MultipartFile.fromFile(filePath),
          })));
  @override
  Future<void> changePassword(String current, String next) async =>
      _api.patch('/shop/auth/password', data: {
        'current_password': current,
        'new_password': next,
        'new_password_confirmation': next,
      });
  @override
  Future<void> sendChangePhoneOtp(String phone) async =>
      _api.post('/shop/auth/change-phone/send-otp', data: {'new_phone': phone});
  @override
  Future<ShopUserModel> verifyChangePhone(String phone, String otp) async =>
      _user(await _api.post('/shop/auth/change-phone/verify', data: {
        'new_phone': phone,
        'otp': otp,
      }));
  @override
  Future<void> updateFcmToken(String token) async =>
      _api.post('/shop/auth/fcm-token', data: {'fcm_token': token});
  @override
  Future<void> logout() async => _api.post('/shop/auth/logout');
  @override
  Future<void> deleteAccount() async => _api.delete('/shop/auth/account');
  @override
  Future<void> sendForgotPasswordOtp(String phone) async =>
      _api.post('/shop/auth/forgot-password', data: {'phone': phone});
  @override
  Future<void> resetPassword(String phone, String otp, String password) async =>
      _api.post('/shop/auth/reset-password', data: {
        'phone': phone,
        'otp': otp,
        'password': password,
        'password_confirmation': password,
      });
  @override
  Future<List<LoginDevice>> devices() async {
    final data = unwrap(await _api.get('/shop/auth/devices')) as List<dynamic>;
    return data
        .map((e) => LoginDevice.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> revokeDevice(int id) async =>
      _api.delete('/shop/auth/devices/$id');
  @override
  Future<void> revokeOtherDevices() async =>
      _api.post('/shop/auth/devices/revoke-others');
}
