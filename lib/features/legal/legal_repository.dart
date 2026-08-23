import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

final legalRepositoryProvider = Provider<LegalRepository>(
  (ref) => LegalRepository(ref.read(apiClientProvider)),
);

class LegalContent {
  final String title;
  final String html;
  const LegalContent({required this.title, required this.html});
}

class LegalRepository {
  final ApiClient _api;
  const LegalRepository(this._api);

  Future<LegalContent> fetch(String slug,
      {required String fallbackTitle}) async {
    final response = await _api.get('/pages/$slug');
    final data = unwrap(response) as Map<String, dynamic>;
    return LegalContent(
      title: data['title'] as String? ?? fallbackTitle,
      html: data['content'] as String? ?? '',
    );
  }
}
