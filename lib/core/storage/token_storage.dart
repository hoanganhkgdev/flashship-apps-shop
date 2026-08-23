import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

final tokenStorageProvider = Provider<TokenStorage>(
  (_) => SecureTokenStorage(),
);

abstract interface class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStorage implements TokenStorage {
  static const _storage = FlutterSecureStorage();
  String? _cachedToken;
  bool _hasLoaded = false;

  @override
  Future<String?> read() async {
    if (_hasLoaded) return _cachedToken;

    final secureToken = await _storage.read(key: AppConstants.tokenKey);
    if (secureToken != null) {
      _cachedToken = secureToken;
      _hasLoaded = true;
      return secureToken;
    }

    // One-time migration for sessions created by older app versions.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(AppConstants.tokenKey);
    if (legacyToken == null) {
      _hasLoaded = true;
      return null;
    }

    await _storage.write(key: AppConstants.tokenKey, value: legacyToken);
    await prefs.remove(AppConstants.tokenKey);
    _cachedToken = legacyToken;
    _hasLoaded = true;
    return legacyToken;
  }

  @override
  Future<void> write(String token) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
    _cachedToken = token;
    _hasLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }

  @override
  Future<void> delete() async {
    await _storage.delete(key: AppConstants.tokenKey);
    _cachedToken = null;
    _hasLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }
}
