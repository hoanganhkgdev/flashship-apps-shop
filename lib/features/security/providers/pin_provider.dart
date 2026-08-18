import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinState {
  final bool isEnabled;
  final bool hasPin;
  final bool isInitialized;

  const PinState({
    this.isEnabled = false,
    this.hasPin = false,
    this.isInitialized = false,
  });

  PinState copyWith({bool? isEnabled, bool? hasPin, bool? isInitialized}) => PinState(
        isEnabled:     isEnabled     ?? this.isEnabled,
        hasPin:        hasPin        ?? this.hasPin,
        isInitialized: isInitialized ?? this.isInitialized,
      );
}

class PinNotifier extends StateNotifier<PinState> {
  static const _kHashKey    = 'shop_pin_hash';
  static const _kEnabledKey = 'shop_pin_enabled';

  final _storage = const FlutterSecureStorage();

  PinNotifier() : super(const PinState()) {
    _load();
  }

  Future<void> _load() async {
    final hash       = await _storage.read(key: _kHashKey);
    final enabledStr = await _storage.read(key: _kEnabledKey);
    state = state.copyWith(
      hasPin:        hash != null,
      isEnabled:     enabledStr == 'true' && hash != null,
      isInitialized: true,
    );
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _kHashKey, value: _hash(pin));
    await _storage.write(key: _kEnabledKey, value: 'true');
    state = state.copyWith(hasPin: true, isEnabled: true);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _kHashKey);
    return stored != null && stored == _hash(pin);
  }

  Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _kEnabledKey, value: enabled.toString());
    state = state.copyWith(isEnabled: enabled && state.hasPin);
  }

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();
}

final pinProvider = StateNotifierProvider<PinNotifier, PinState>((ref) => PinNotifier());

// Đánh dấu đã qua màn khoá PIN lúc cold-start trong phiên app hiện tại —
// router đọc để không bắt nhập PIN lại mỗi lần redirect evaluate.
final pinLockPassedProvider = StateProvider<bool>((ref) => false);

// True khi PinLockScreen đang hiển thị (dù ở route /pin-lock lúc cold-start
// hay push overlay lúc resume) — chặn hiện chồng 2 màn khoá cùng lúc. Biến
// thường (không phải provider): chỉ đọc/ghi mệnh lệnh từ initState/dispose
// của PinLockScreen, không widget nào watch để rebuild theo — Riverpod cấm
// sửa provider trong các lifecycle đó nên dùng provider ở đây sẽ crash.
bool pinLockScreenVisible = false;
