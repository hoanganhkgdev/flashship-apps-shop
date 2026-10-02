import '../../core/widgets/app_decor_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme.dart';
import 'legal_repository.dart';

class LegalPageScreen extends ConsumerStatefulWidget {
  final String slug;
  final String title;
  const LegalPageScreen({super.key, required this.slug, required this.title});

  @override
  ConsumerState<LegalPageScreen> createState() => _LegalPageScreenState();
}

class _LegalPageScreenState extends ConsumerState<LegalPageScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  String? _content;
  String? _pageTitle;
  Brightness? _renderedBrightness;

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
          if (mounted) {
            setState(() {
              _loading = false;
              _error = 'Không tải được nội dung';
            });
          }
        },
      ));
    _fetchContent();
  }

  // Đổi chế độ sáng/tối khi đang mở trang → dựng lại HTML với bảng màu mới.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final b = Theme.of(context).brightness;
    if (_content != null &&
        _renderedBrightness != null &&
        b != _renderedBrightness) {
      _render();
    }
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  void _render() {
    final c = context.colors;
    _renderedBrightness = Theme.of(context).brightness;
    _controller.setBackgroundColor(c.background);
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${_pageTitle ?? widget.title}</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Inter", "Helvetica Neue", sans-serif;
      font-size: 14px;
      line-height: 1.7;
      color: ${_hex(c.textSecondary)};
      background: ${_hex(c.background)};
      padding: 20px 16px 48px;
    }
    h1 { font-size: 20px; font-weight: 800; margin: 0 0 16px; color: ${_hex(c.textPrimary)}; }
    h2 { font-size: 16px; font-weight: 800; margin: 24px 0 8px; color: ${_hex(c.textPrimary)}; }
    h3 { font-size: 14px; font-weight: 700; margin: 16px 0 6px; color: ${_hex(c.textPrimary)}; }
    p  { margin-bottom: 12px; }
    ul, ol { padding-left: 20px; margin-bottom: 12px; }
    li { margin-bottom: 4px; }
    a  { color: ${_hex(c.primary)}; text-decoration: none; font-weight: 600; }
    strong { color: ${_hex(c.textPrimary)}; }
    hr { border: none; border-top: 1px solid ${_hex(c.divider)}; margin: 20px 0; }
  </style>
</head>
<body>${_content ?? ''}</body>
</html>
''';
    _controller.loadHtmlString(html);
  }

  Future<void> _fetchContent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Dùng public endpoint /api/pages/{slug}
      final page = await ref
          .read(legalRepositoryProvider)
          .fetch(widget.slug, fallbackTitle: widget.title);
      if (!mounted) return;
      _content = page.html;
      _pageTitle = page.title;
      _render();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không tải được nội dung';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppPageHeader(title: widget.title),
      body: _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              AppIconBadge(
                  icon: Icons.wifi_off_rounded,
                  color: c.textSecondary,
                  size: 64),
              const SizedBox(height: AppSpacing.lg),
              Text(_error!,
                  style:
                      AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                onPressed: _fetchContent,
                style: FilledButton.styleFrom(
                    minimumSize: const Size(140, AppSize.buttonHeight),
                    backgroundColor: c.primarySoft,
                    foregroundColor: c.primary),
                child: const Text('Thử lại'),
              ),
            ]))
          : Stack(children: [
              WebViewWidget(controller: _controller),
              if (_loading)
                ColoredBox(
                  color: Colors.transparent,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: c.primary, strokeWidth: 2)),
                ),
            ]),
    );
  }
}
