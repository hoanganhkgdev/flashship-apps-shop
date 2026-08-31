import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/device_name.dart';
import '../models/shop_user_model.dart';
import '../data/auth_repository.dart';

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
    bool clearUser = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        token: clearUser ? null : (token ?? this.token),
        isLoading: isLoading ?? this.isLoading,
        isInitialized: isInitialized ?? this.isInitialized,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final TokenStorage _tokenStorage;

  AuthNotifier(this._repository, this._tokenStorage)
      : super(const AuthState()) {
    _loadFromStorage();
  }

  // error là state dùng chung cho mọi thao tác xác thực (login/sendOtp/
  // verifyOtpAndRegister...) nên chỉ tự xoá ở ĐẦU mỗi lần gọi API mới, không
  // tự xoá khi chuyển màn — các màn Login/Register/Otp gọi hàm này trong
  // initState() để không kế thừa lỗi còn sót lại từ màn trước đó.
  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await _tokenStorage.read();
    final userData = prefs.getString(AppConstants.userKey);
    NotificationService.onTokenRefresh = updateFcmToken;
    if (token != null && userData != null) {
      final user = ShopUserModel.fromJson(jsonDecode(userData));
      state = state.copyWith(token: token, user: user, isInitialized: true);
      _registerFcmToken();
    } else {
      state = state.copyWith(isInitialized: true);
    }
  }

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.sendOtp(phone);
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
    int? cityId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final deviceName = await getDeviceName();
      final session = await _repository.register({
        'phone': phone,
        'otp': otp,
        'name': name,
        'password': password,
        if (address != null && address.isNotEmpty) 'address': address,
        if (cityId != null) 'city_id': cityId,
        if (deviceName != null) 'device_name': deviceName,
      });
      await _saveSession(session);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: parseApiError(e));
      return false;
    }
  }

  Future<bool> login({required String phone, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final deviceName = await getDeviceName();
      final session = await _repository.login(
        phone,
        password,
        deviceName: deviceName,
      );
      await _saveSession(session);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: parseApiError(e));
      return false;
    }
  }

  Future<bool> sendLoginOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.sendLoginOtp(phone);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: parseApiError(e));
      return false;
    }
  }

  Future<bool> loginWithOtp(
      {required String phone, required String otp}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final deviceName = await getDeviceName();
      final session = await _repository.verifyLoginOtp(
        phone,
        otp,
        deviceName: deviceName,
      );
      await _saveSession(session);
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
    int? cityId,
  }) async {
    try {
      final user = await _repository.updateProfile({
        'name': name,
        if (address != null) 'address': address,
        if (email != null) 'email': email.isEmpty ? null : email,
        if (cityId != null) 'city_id': cityId,
      });
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
      final user = await _repository.uploadAvatar(filePath);
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
      await _repository.changePassword(current, next);
      return null;
    } catch (e) {
      return parseApiError(e);
    }
  }

  Future<bool> sendChangePhoneOtp(String newPhone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.sendChangePhoneOtp(newPhone);
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
      final user = await _repository.verifyChangePhone(newPhone, otp);
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
      final user = await _repository.me();
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
        await _tokenStorage.delete();
        await prefs.remove(AppConstants.userKey);
        state = state.copyWith(clearUser: true, isInitialized: true);
      } else {
        state = state.copyWith(isInitialized: true);
      }
    }
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await _tokenStorage.delete();
    await prefs.remove(AppConstants.userKey);
    state = state.copyWith(clearUser: true, isInitialized: true);
  }

  Future<String?> deleteAccount() async {
    try {
      await _repository.deleteAccount();
      final prefs = await SharedPreferences.getInstance();
      await _tokenStorage.delete();
      await prefs.remove(AppConstants.userKey);
      state = state.copyWith(clearUser: true, isInitialized: true);
      return null;
    } catch (e) {
      return parseApiError(e);
    }
  }

  Future<void> _saveSession(AuthSession session) async {
    final token = session.token;
    final user = session.user;
    final prefs = await SharedPreferences.getInstance();
    await _tokenStorage.write(token);
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
    state = state.copyWith(
        token: token, user: user, isLoading: false, isInitialized: true);
    NotificationService.onTokenRefresh = updateFcmToken;
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
    if (!state.isAuthenticated) return; // chưa đăng nhập thì bỏ qua
    try {
      await _repository.updateFcmToken(token);
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(tokenStorageProvider),
  );
});
