import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../auth/providers/auth_provider.dart';

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
  static const _kHashKeyPrefix    = 'shop_pin_hash_';
  static const _kEnabledKeyPrefix = 'shop_pin_enabled_';

  final Ref _ref;
  final _storage = const FlutterSecureStorage();
  int? _userId;

  // PIN gắn theo userId — nếu không thì tài khoản B đăng nhập sau tài khoản
  // A trên cùng máy sẽ kế thừa/đọc nhầm PIN của A. Lắng nghe authProvider để
  // tự nạp lại đúng dữ liệu của user hiện tại mỗi khi đăng nhập/đăng xuất,
  // đồng thời reset pinLockPassedProvider ở CÙNG một chỗ — tránh phải nhớ
  // gọi thủ công rải rác ở từng nơi gọi logout()/login() trong app.
  PinNotifier(this._ref) : super(const PinState()) {
    _userId = _ref.read(authProvider).user?.id;
    _load();

    _ref.listen<int?>(
      authProvider.select((s) => s.user?.id),
      (previous, next) {
        if (next == _userId) return;
        _userId = next;
        _load();
        _ref.read(pinLockPassedProvider.notifier).state = false;
      },
    );
  }

  String get _hashKey    => '$_kHashKeyPrefix$_userId';
  String get _enabledKey => '$_kEnabledKeyPrefix$_userId';

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) {
      state = const PinState(isInitialized: true);
      return;
    }

    final hash       = await _storage.read(key: _hashKey);
    final enabledStr = await _storage.read(key: _enabledKey);

    // Nếu userId đã đổi lại trong lúc đang await (đăng xuất/đăng nhập dồn
    // dập), bỏ kết quả cũ — tránh ghi đè state của user mới bằng dữ liệu
    // load chậm của user trước.
    if (userId != _userId) return;

    state = state.copyWith(
      hasPin:        hash != null,
      isEnabled:     enabledStr == 'true' && hash != null,
      isInitialized: true,
    );
  }

  Future<void> setPin(String pin) async {
    if (_userId == null) return;
    await _storage.write(key: _hashKey, value: _hash(pin));
    await _storage.write(key: _enabledKey, value: 'true');
    state = state.copyWith(hasPin: true, isEnabled: true);
  }

  Future<bool> verifyPin(String pin) async {
    if (_userId == null) return false;
    final stored = await _storage.read(key: _hashKey);
    return stored != null && stored == _hash(pin);
  }

  Future<void> setEnabled(bool enabled) async {
    if (_userId == null) return;
    await _storage.write(key: _enabledKey, value: enabled.toString());
    state = state.copyWith(isEnabled: enabled && state.hasPin);
  }

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();
}

final pinProvider = StateNotifierProvider<PinNotifier, PinState>((ref) => PinNotifier(ref));

// Đánh dấu đã qua màn khoá PIN lúc cold-start trong phiên app hiện tại —
// router đọc để không bắt nhập PIN lại mỗi lần redirect evaluate. Được
// PinNotifier tự reset về false mỗi khi user đăng nhập/đăng xuất (xem
// PinNotifier ở trên) — không cần gọi thủ công ở nơi khác.
final pinLockPassedProvider = StateProvider<bool>((ref) => false);

// True khi PinLockScreen đang hiển thị (dù ở route /pin-lock lúc cold-start
// hay push overlay lúc resume) — chặn hiện chồng 2 màn khoá cùng lúc. Biến
// thường (không phải provider): chỉ đọc/ghi mệnh lệnh từ initState/dispose
// của PinLockScreen, không widget nào watch để rebuild theo — Riverpod cấm
// sửa provider trong các lifecycle đó nên dùng provider ở đây sẽ crash.
bool pinLockScreenVisible = false;
