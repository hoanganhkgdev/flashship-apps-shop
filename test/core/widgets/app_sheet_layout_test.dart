import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/core/widgets/app_decor_widgets.dart';
import 'package:flashship_shop/core/widgets/app_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppSheet stays responsive with long content and large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 20, bottom: 16),
            textScaler: const TextScaler.linear(1.5),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => AppSheet(
                    icon: Icons.settings_rounded,
                    title: 'Thiết lập tài khoản và ứng dụng',
                    subtitle: 'Quản lý thông tin, giao diện và bảo mật',
                    footer: AppButton(label: 'Lưu thay đổi', onPressed: () {}),
                    child: Column(
                      children: List.generate(
                        8,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppSheetOption(
                            icon: Icons.tune_rounded,
                            label: 'Tùy chọn cài đặt ${index + 1}',
                            selected: index == 0,
                            onTap: () {},
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Mở sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Thiết lập tài khoản và ứng dụng'), findsOneWidget);
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    expect(find.byTooltip('Đóng'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('Thiết lập tài khoản và ứng dụng'), findsNothing);
  });
}
