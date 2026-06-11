import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../version/providers/app_version_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appVersionProvider.notifier).check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(appVersionProvider);

    if (version.isChecked && !_dialogShown) {
      if (version.needsForceUpdate) {
        _dialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showForceUpdateDialog(context, version);
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        children: [
          const Spacer(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png', width: 90, height: 90, color: Colors.white),
                const SizedBox(height: 18),
                const Text('FlashShip',
                    style: TextStyle(
                        color: Colors.white, fontSize: 30,
                        fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('Dành cho shop',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: CircularProgressIndicator(
              color: Colors.white.withValues(alpha: 0.6),
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }

  void _showForceUpdateDialog(BuildContext context, AppVersionState v) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cập nhật bắt buộc',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Text(v.message,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openStore(v.storeUrl),
                child: const Text('Cập nhật ngay'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStore(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
