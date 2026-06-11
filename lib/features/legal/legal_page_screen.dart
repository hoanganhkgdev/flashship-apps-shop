import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class LegalPageScreen extends ConsumerStatefulWidget {
  final String slug;
  final String title;
  const LegalPageScreen({super.key, required this.slug, required this.title});

  @override
  ConsumerState<LegalPageScreen> createState() => _LegalPageScreenState();
}

class _LegalPageScreenState extends ConsumerState<LegalPageScreen> {
  late final WebViewController _controller;
  bool   _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() { _loading = false; _error = 'Không tải được nội dung'; });
        },
      ));
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Dùng public endpoint /api/pages/{slug}
      final res = await ref.read(apiClientProvider)
          .get('/pages/${widget.slug}');
      final data    = (res.data['data'] ?? res.data) as Map<String, dynamic>;
      final content = data['content'] as String? ?? '';
      final title   = data['title']   as String? ?? widget.title;

      final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
      font-size: 15px;
      line-height: 1.7;
      color: #111827;
      background: #ffffff;
      padding: 20px 16px 48px;
    }
    h1 { font-size: 20px; font-weight: 700; margin: 0 0 16px; }
    h2 { font-size: 17px; font-weight: 700; margin: 20px 0 8px; }
    h3 { font-size: 15px; font-weight: 600; margin: 16px 0 6px; }
    p  { margin-bottom: 12px; color: #374151; }
    ul, ol { padding-left: 20px; margin-bottom: 12px; }
    li { margin-bottom: 4px; color: #374151; }
    a  { color: #E8720C; text-decoration: none; }
    strong { color: #111827; }
    hr { border: none; border-top: 1px solid #E5E7EB; margin: 20px 0; }
  </style>
</head>
<body>$content</body>
</html>
''';
      _controller.loadHtmlString(html);
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Không tải được nội dung'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
      ),
      body: _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _fetchContent,
                child: const Text('Thử lại'),
              ),
            ]))
          : Stack(children: [
              WebViewWidget(controller: _controller),
              if (_loading)
                const Center(child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2)),
            ]),
    );
  }
}
