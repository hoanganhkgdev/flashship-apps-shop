import 'package:url_launcher/url_launcher.dart';

/// Mở link store (App Store/Play Store) để cập nhật app — dùng chung giữa
/// dialog "Cập nhật bắt buộc" (main.dart) và banner nhắc cập nhật mềm
/// (home_screen.dart).
Future<void> openStore(String? url) async {
  if (url == null || url.isEmpty) return;
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
