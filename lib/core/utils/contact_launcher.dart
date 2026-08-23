import 'package:url_launcher/url_launcher.dart';

Future<bool> callPhone(String phone) => _launchContact('tel', phone);

Future<bool> sendSms(String phone) => _launchContact('sms', phone);

Future<bool> _launchContact(String scheme, String value) async {
  final normalized = value.trim();
  if (normalized.isEmpty) return false;

  final uri = Uri(scheme: scheme, path: normalized);
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri);
}
