import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

class AppVersionState {
  final bool isChecked;
  final bool needsForceUpdate;
  final bool needsSoftUpdate;
  final String? storeUrl;
  final String? latestVersion;
  final String message;

  const AppVersionState({
    this.isChecked      = false,
    this.needsForceUpdate = false,
    this.needsSoftUpdate  = false,
    this.storeUrl,
    this.latestVersion,
    this.message = 'Vui lòng cập nhật ứng dụng để tiếp tục sử dụng.',
  });
}

class AppVersionNotifier extends StateNotifier<AppVersionState> {
  AppVersionNotifier() : super(const AppVersionState());

  Future<void> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final res = await Dio().get(
        '${AppConstants.baseUrl}/app-version',
        queryParameters: {'platform': 'shop'},
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final data = res.data as Map<String, dynamic>;

      final minVersion    = data['min_version']    as String? ?? '1.0.0';
      final latestVersion = data['latest_version'] as String? ?? '1.0.0';
      final forceUpdate   = data['force_update']   as bool?   ?? false;
      final forceMessage  = data['force_message']  as String? ?? '';
      final androidUrl    = data['android_url']    as String?;
      final iosUrl        = data['ios_url']        as String?;
      final storeUrl      = Platform.isIOS ? iosUrl : androidUrl;

      final needsForce = forceUpdate && _isOlderThan(current, minVersion);
      final needsSoft  = !needsForce && _isOlderThan(current, latestVersion);

      state = AppVersionState(
        isChecked:        true,
        needsForceUpdate: needsForce,
        needsSoftUpdate:  needsSoft,
        storeUrl:         storeUrl,
        latestVersion:    latestVersion,
        message: forceMessage.isNotEmpty ? forceMessage : 'Vui lòng cập nhật ứng dụng để tiếp tục sử dụng.',
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
    while (parts.length < 3) { parts.add(0); }
    return parts;
  }
}

final appVersionProvider =
    StateNotifierProvider<AppVersionNotifier, AppVersionState>(
  (ref) => AppVersionNotifier(),
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
