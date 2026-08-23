import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

final versionRepositoryProvider = Provider<VersionRepository>(
  (ref) => VersionRepository(ref.read(apiClientProvider)),
);

class VersionConfig {
  final String minVersion;
  final String latestVersion;
  final bool forceUpdate;
  final String forceMessage;
  final String? androidUrl;
  final String? iosUrl;

  const VersionConfig({
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.forceMessage,
    this.androidUrl,
    this.iosUrl,
  });
}

class VersionRepository {
  final ApiClient _api;
  const VersionRepository(this._api);

  Future<VersionConfig> fetchShopConfig() async {
    final response = await _api.get(
      '/app-version',
      params: {'platform': 'shop'},
      options: Options(receiveTimeout: const Duration(seconds: 8)),
    );
    final data = response.data as Map<String, dynamic>;
    return VersionConfig(
      minVersion: data['min_version'] as String? ?? '1.0.0',
      latestVersion: data['latest_version'] as String? ?? '1.0.0',
      forceUpdate: data['force_update'] as bool? ?? false,
      forceMessage: data['force_message'] as String? ?? '',
      androidUrl: data['android_url'] as String?,
      iosUrl: data['ios_url'] as String?,
    );
  }
}
