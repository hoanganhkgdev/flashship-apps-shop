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
      state = state.copyWith(isLoading: false, error: _parseError(e));
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
      state = state.copyWith(isLoading: false, error: _parseError(e));
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
      state = state.copyWith(isLoading: false, error: _parseError(e));
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
          (res.data['data'] ?? res.data) as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      state = state.copyWith(user: user);
      return null;
    } catch (e) {
      return _parseError(e);
    }
  }

  Future<String?> uploadAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath),
      });
      final res = await _api.post('/shop/auth/avatar', data: formData);
      final user = ShopUserModel.fromJson(
          (res.data['data'] ?? res.data) as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      state = state.copyWith(user: user);
      return null;
    } catch (e) {
      return _parseError(e);
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
      return _parseError(e);
    }
  }

  Future<void> refreshUser() async {
    if (state.token == null) return;
    try {
      final res = await _api.get('/shop/auth/me');
      final user = ShopUserModel.fromJson(
          (res.data['data'] ?? res.data) as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isInitialized: true);
    } catch (e) {
      final statusCode = (e as dynamic).response?.statusCode as int?;
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
      return _parseError(e);
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
    try {
      final fcmToken = await NotificationService.getToken();
      if (fcmToken == null) return;
      await _api.post('/shop/auth/fcm-token', data: {'fcm_token': fcmToken});
    } catch (_) {}
  }

  String _parseError(dynamic e) {
    try {
      final response = (e as dynamic).response;
      if (response != null) {
        final data = response.data;
        if (data is Map) {
          final msg = data['message'];
          if (msg != null) return msg.toString();
          final errors = data['errors'];
          if (errors is Map) return errors.values.first.first.toString();
        }
        return 'Server lỗi ${response.statusCode}';
      }
      final type = (e as dynamic).type?.toString() ?? '';
      if (type.contains('connectionTimeout') || type.contains('receiveTimeout')) {
        return 'Timeout: server không phản hồi';
      }
      return 'Lỗi kết nối';
    } catch (_) {
      return 'Lỗi: $e';
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});
