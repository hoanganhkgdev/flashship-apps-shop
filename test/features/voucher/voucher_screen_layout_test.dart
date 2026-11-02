import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/voucher/voucher_model.dart';
import 'package:flashship_shop/features/voucher/voucher_provider.dart';
import 'package:flashship_shop/features/voucher/voucher_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vouchers extends VoucherNotifier {
  @override
  Future<List<VoucherModel>> build() async => [
        const VoucherModel(
          id: 1,
          code: 'SHOP10',
          type: 'percent',
          value: 10,
          discountLabel: 'Giảm 10% phí giao hàng',
          description: 'Ưu đãi dành cho cửa hàng thân thiết',
          minOrderValue: 50000,
          maxDiscount: 30000,
          usageCount: 1,
          usageLimit: 5,
        ),
        VoucherModel(
          id: 2,
          code: 'OLD20',
          type: 'percent',
          value: 20,
          discountLabel: 'Giảm 20% phí giao hàng',
          expiresAt: DateTime(2020),
        ),
      ];
}

void main() {
  testWidgets('voucher screen stays responsive with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [voucherProvider.overrideWith(_Vouchers.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: const VoucherScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mã giảm giá'), findsOneWidget);
    expect(find.text('SHOP10'), findsOneWidget);
    expect(find.text('Giảm 10% phí giao hàng'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('Hết hạn').first);
    await tester.pumpAndSettle();
    expect(find.text('OLD20'), findsOneWidget);
    expect(find.text('Đã hết hạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
