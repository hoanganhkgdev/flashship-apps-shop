import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../version_repository.dart';

class AppVersionState {
  final bool isChecked;
  final bool needsForceUpdate;
  final bool needsSoftUpdate;
  final String? storeUrl;
  final String? latestVersion;
  final String message;

  const AppVersionState({
    this.isChecked = false,
    this.needsForceUpdate = false,
    this.needsSoftUpdate = false,
    this.storeUrl,
    this.latestVersion,
    this.message = 'Vui lòng cập nhật ứng dụng để tiếp tục sử dụng.',
  });
}

class AppVersionNotifier extends StateNotifier<AppVersionState> {
  final VersionRepository _repository;
  AppVersionNotifier(this._repository) : super(const AppVersionState());

  Future<void> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final config = await _repository.fetchShopConfig();
      final storeUrl = Platform.isIOS ? config.iosUrl : config.androidUrl;

      final needsForce =
          config.forceUpdate && _isOlderThan(current, config.minVersion);
      final needsSoft =
          !needsForce && _isOlderThan(current, config.latestVersion);

      state = AppVersionState(
        isChecked: true,
        needsForceUpdate: needsForce,
        needsSoftUpdate: needsSoft,
        storeUrl: storeUrl,
        latestVersion: config.latestVersion,
        message: config.forceMessage.isNotEmpty
            ? config.forceMessage
            : 'Vui lòng cập nhật ứng dụng để tiếp tục sử dụng.',
      );
    } catch (_) {
      state = const AppVersionState(isChecked: true);
    }
  }

  bool _isOlderThan(String a, String b) {
    final av = _parse(a);
    final bv = _parse(b);
    for (var i = 0; i < 3; i++) {
      if (av[i] < bv[i]) return true;
      if (av[i] > bv[i]) return false;
    }
    return false;
  }

  List<int> _parse(String v) {
    final parts = v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }
}

final appVersionProvider =
    StateNotifierProvider<AppVersionNotifier, AppVersionState>(
  (ref) => AppVersionNotifier(ref.read(versionRepositoryProvider)),
);

// ─── Đã ẩn banner nhắc cập nhật mềm cho phiên bản nào ──────────────────────────
//
// Lưu latest_version đã bị bấm "Để sau" — banner chỉ ẩn cho ĐÚNG phiên bản đó,
// nếu backend công bố bản mới hơn nữa thì latestVersion đổi khác, so sánh lệch
// nên banner hiện lại bình thường.
const _kDismissedSoftUpdateVersionKey = 'dismissed_soft_update_version';

class DismissedSoftUpdateNotifier extends StateNotifier<String?> {
  DismissedSoftUpdateNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kDismissedSoftUpdateVersionKey);
  }

  Future<void> dismiss(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDismissedSoftUpdateVersionKey, version);
    state = version;
  }
}

final dismissedSoftUpdateVersionProvider =
    StateNotifierProvider<DismissedSoftUpdateNotifier, String?>(
  (ref) => DismissedSoftUpdateNotifier(),
);
