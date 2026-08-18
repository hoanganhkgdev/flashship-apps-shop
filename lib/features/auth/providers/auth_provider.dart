import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/notification_service.dart';
import '../models/shop_user_model.dart';

class AuthState {
  final ShopUserModel? user;
  final String? token;
  final bool isLoading;
  final bool isInitialized;
  final String? error;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
  });

  bool get isAuthenticated => token != null && user != null;

  AuthState copyWith({
    ShopUserModel? user,
    String? token,
    bool? isLoading,
    bool? isInitialized,
    String? error,
    bool clearError = false,
    bool clearUser  = false,
  }) =>
      AuthState(
        user:          clearUser ? null : (user ?? this.user),
        token:         clearUser ? null : (token ?? this.token),
        isLoading:     isLoading ?? this.isLoading,
        isInitialized: isInitialized ?? this.isInitialized,
        error:         clearError ? null : (error ?? this.error),
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthNotifier(this._api) : super(const AuthState()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token    = prefs.getString(AppConstants.tokenKey);
    final userData = prefs.getString(AppConstants.userKey);
    if (token != null && userData != null) {
      final user = ShopUserModel.fromJson(jsonDecode(userData));
      state = state.copyWith(token: token, user: user, isInitialized: true);
    } else {
      state = state.copyWith(isInitialized: true);
    }
  }

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.post('/shop/auth/send-otp', data: {'phone': phone});
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: parseApiError(e));
      return false;
    }
  }

  Future<bool> verifyOtpAndRegister({
    required String phone,
    required String otp,
    required String name,
    required String password,
    String? address,
    int?    cityId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.post('/shop/auth/verify-otp-register', data: {
        'phone':    phone,
        'otp':      otp,
        'name':     name,
        'password': password,
        if (address != null && address.isNotEmpty) 'address': address,
        if (cityId != null) 'city_id': cityId,
      });
      await _saveSession(res.data);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: parseApiError(e));
      return false;
    }
  }

  Future<bool> login({required String phone, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.post('/shop/auth/login', data: {
        'phone': phone,
        'password': password,
      });
      await _saveSession(res.data);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: parseApiError(e));
      return false;
    }
  }

  Future<String?> updateProfile({
    required String name,
    String? address,
    String? email,
    int?    cityId,
  }) async {
    try {
      final res = await _api.patch('/shop/auth/profile', data: {
        'name': name,
        if (address != null) 'address': address,
        if (email != null)   'email':   email.isEmpty ? null : email,
        if (cityId != null)  'city_id': cityId,
      });
      final user = ShopUserModel.fromJson(
          unwrap(res) as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      state = state.copyWith(user: user);
      return null;
    } catch (e) {
      return parseApiError(e);
    }
  }

  Future<String?> uploadAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath),
      });
      final res = await _api.post('/shop/auth/avatar', data: formData);
      final user = ShopUserModel.fromJson(
          unwrap(res) as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      state = state.copyWith(user: user);
      return null;
    } catch (e) {
      return parseApiError(e);
    }
  }

  Future<String?> changePassword({
    required String current,
    required String next,
  }) async {
    try {
      await _api.patch('/shop/auth/password', data: {
        'current_password':              current,
        'new_password':                  next,
        'new_password_confirmation':     next,
      });
      return null;
    } catch (e) {
      return parseApiError(e);
    }
  }

  Future<bool> sendChangePhoneOtp(String newPhone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.post('/shop/auth/change-phone/send-otp', data: {'new_phone': newPhone});
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: parseApiError(e));
      return false;
    }
  }

  Future<bool> verifyChangePhone(String newPhone, String otp) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res  = await _api.post('/shop/auth/change-phone/verify', data: {
        'new_phone': newPhone,
        'otp':       otp,
      });
      final user = ShopUserModel.fromJson(unwrap(res) as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isLoading: false, isInitialized: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: parseApiError(e));
      return false;
    }
  }

  Future<void> refreshUser() async {
    if (state.token == null) return;
    try {
      final res = await _api.get('/shop/auth/me');
      final user = ShopUserModel.fromJson(
          unwrap(res) as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isInitialized: true);
    } catch (e) {
      // Chỉ đọc statusCode khi đúng là lỗi HTTP (DioException) — lỗi khác
      // (vd parse JSON thất bại) mà ép kiểu dynamic ném NoSuchMethodError
      // ngay trong catch, thoát khỏi refreshUser() không kiểm soát được.
      final statusCode = e is DioException ? e.response?.statusCode : null;
      if (statusCode == 401 || statusCode == 403) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(AppConstants.tokenKey);
        await prefs.remove(AppConstants.userKey);
        state = state.copyWith(clearUser: true, isInitialized: true);
      } else {
        state = state.copyWith(isInitialized: true);
      }
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/shop/auth/logout');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
    state = state.copyWith(clearUser: true, isInitialized: true);
  }

  Future<String?> deleteAccount() async {
    try {
      await _api.delete('/shop/auth/account');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.tokenKey);
      await prefs.remove(AppConstants.userKey);
      state = state.copyWith(clearUser: true, isInitialized: true);
      return null;
    } catch (e) {
      return parseApiError(e);
    }
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final payload = data['data'] as Map<String, dynamic>;
    final token = payload['token'] as String;
    final user  = ShopUserModel.fromJson(payload['user']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
    state = state.copyWith(token: token, user: user, isLoading: false, isInitialized: true);
    _registerFcmToken();
  }

  Future<void> _registerFcmToken() async {
    final fcmToken = await NotificationService.getToken();
    if (fcmToken == null) return;
    await updateFcmToken(fcmToken);
  }

  // Gọi lại khi NotificationService.onTokenRefresh báo Firebase đã xoay vòng
  // token — nhận thẳng token mới thay vì tự getToken() lại.
  Future<void> updateFcmToken(String token) async {
    if (state.token == null) return; // chưa đăng nhập thì bỏ qua
    try {
      await _api.post('/shop/auth/fcm-token', data: {'fcm_token': token});
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});
