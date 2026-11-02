import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
  String? _interFontBase64;
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
    @font-face {
      font-family: 'Inter';
      src: url('data:font/woff2;base64,$_interFontBase64') format('woff2');
      font-weight: 100 900;
      font-style: normal;
      font-display: block;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body, body * { font-family: 'Inter', sans-serif !important; }
    body {
      font-size: 14px;
      line-height: 1.7;
      color: ${_hex(c.textSecondary)};
      background: ${_hex(c.surface)};
      padding: 20px 16px 48px;
    }
    h1 { font-size: 20px; font-weight: 700; margin: 0 0 16px; color: ${_hex(c.textPrimary)}; }
    h2 { font-size: 16px; font-weight: 700; margin: 24px 0 10px; padding: 8px 10px; color: ${_hex(c.textPrimary)}; background: ${_hex(c.primarySoft)}; border-left: 3px solid ${_hex(c.primary)}; border-radius: 8px; }
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
      final font =
          await rootBundle.load('assets/fonts/inter/InterVariable.woff2');
      if (!mounted) return;
      _interFontBase64 = base64Encode(
          font.buffer.asUint8List(font.offsetInBytes, font.lengthInBytes));
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
      backgroundColor: c.background,
      body: Column(children: [
        _LegalHeader(title: widget.title),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: _LegalInfoBanner(
            isPrivacy: widget.slug.contains('privacy'),
          ),
        ),
        Expanded(
          child: _error != null
              ? _LegalError(message: _error!, onRetry: _fetchContent)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.divider),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(children: [
                      WebViewWidget(controller: _controller),
                      if (_loading)
                        ColoredBox(
                          color: c.surface,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: c.primary,
                                  strokeWidth: 2,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Đang tải nội dung...',
                                  style: AppTextStyles.caption.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _LegalHeader extends StatelessWidget {
  final String title;
  const _LegalHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      color: context.isDark ? c.primarySoft : const Color(0xFFFFE9DE),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 14),
          child: Row(children: [
            IconButton(
              tooltip: 'Quay lại',
              onPressed: () => Navigator.maybePop(context),
              style: IconButton.styleFrom(
                backgroundColor: c.surface,
                foregroundColor: c.textPrimary,
                fixedSize: const Size.square(42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.screenTitle.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Thông tin pháp lý từ Flash Ship',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LegalInfoBanner extends StatelessWidget {
  final bool isPrivacy;
  const _LegalInfoBanner({required this.isPrivacy});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.primarySoft,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          isPrivacy ? Icons.shield_outlined : Icons.description_outlined,
          size: 19,
          color: c.primary,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          isPrivacy
              ? 'Cách Flash Ship thu thập và bảo vệ dữ liệu của bạn'
              : 'Quyền và trách nhiệm khi sử dụng dịch vụ Flash Ship',
          style: AppTextStyles.caption.copyWith(
            color: c.textSecondary,
            height: 1.4,
          ),
        ),
      ),
    ]);
  }
}

class _LegalError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LegalError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
            ),
            child:
                Icon(Icons.wifi_off_rounded, color: c.textSecondary, size: 29),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Vui lòng kiểm tra kết nối và thử lại.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
          ),
        ]),
      ),
    );
  }
}
