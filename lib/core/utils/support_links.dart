import 'package:url_launcher/url_launcher.dart';

/// Các đường dẫn thử mở theo thứ tự cho một kênh hỗ trợ: đường dẫn mở thẳng
/// app (nếu có) đứng trước, đường dẫn web/universal link đứng sau để làm dự
/// phòng khi máy chưa cài app.
///
/// [link] là đường dẫn server đã chuẩn hoá (`tel:…`, `https://zalo.me/…`…);
/// [value] là giá trị thô admin nhập, chỉ dùng khi server chưa trả [link].
List<Uri> supportLaunchCandidates({
  required String type,
  required String value,
  String? link,
}) {
  final v = value.trim();
  final l = (link ?? '').trim();
  final digits = v.replaceFirst(RegExp(r'^tel:'), '').replaceAll(
        RegExp(r'[^\d+]'),
        '',
      );
  final looksLikePhone = RegExp(r'^\+?\d{8,12}$').hasMatch(digits) &&
      !v.contains(RegExp(r'[A-Za-z]'));

  Uri? web(String s) {
    // Chuỗi trống hoặc có khoảng trắng không phải địa chỉ mở được.
    if (s.isEmpty || RegExp(r'\s').hasMatch(s)) return null;
    final withScheme =
        RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(s)
            ? s
            : 'https://${s.replaceFirst(RegExp(r'^/+'), '')}';
    final uri = Uri.tryParse(withScheme);
    // Máy chủ phải có dạng tên miền (có dấu chấm), vd. zalo.me, facebook.com.
    return (uri == null || !uri.host.contains('.')) ? null : uri;
  }

  switch (type) {
    case 'phone':
      final number = l.startsWith('tel:') ? l.substring(4) : digits;
      return number.isEmpty ? const [] : [Uri(scheme: 'tel', path: number)];
    case 'email':
      final address = l.startsWith('mailto:')
          ? l.substring(7)
          : v.replaceFirst(RegExp(r'^mailto:'), '');
      return address.isEmpty
          ? const []
          : [Uri(scheme: 'mailto', path: address)];
    case 'zalo':
      // https://zalo.me/… là universal link: mở thẳng app Zalo nếu đã cài.
      final target = l.isNotEmpty
          ? web(l)
          : (looksLikePhone ? web('https://zalo.me/$digits') : web(v));
      return [if (target != null) target];
    case 'facebook':
      final page = l.isNotEmpty
          ? web(l)
          : (RegExp(r'^[A-Za-z0-9.]{3,}$').hasMatch(v)
              ? web('https://facebook.com/$v')
              : web(v));
      if (page == null) return const [];
      return [
        // Mở trang ngay trong app Facebook; không có app thì rơi về link web.
        Uri.parse('fb://facewebmodal/f?href=${Uri.encodeComponent('$page')}'),
        page,
      ];
    default:
      final target = l.isNotEmpty ? web(l) : web(v);
      return [if (target != null) target];
  }
}

/// Mở kênh hỗ trợ bằng app tương ứng; thử lần lượt từng đường dẫn cho tới khi
/// một đường mở được. Trả false nếu không đường nào mở được.
Future<bool> openSupportChannel({
  required String type,
  required String value,
  String? link,
}) async {
  for (final uri in supportLaunchCandidates(
    type: type,
    value: value,
    link: link,
  )) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // Thử đường dẫn kế tiếp (vd. chưa cài app Facebook).
    }
  }
  return false;
}
