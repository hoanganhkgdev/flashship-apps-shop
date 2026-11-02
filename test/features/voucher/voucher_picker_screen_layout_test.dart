import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/voucher/voucher_model.dart';
import 'package:flashship_shop/features/voucher/voucher_provider.dart';
import 'package:flashship_shop/features/voucher/widgets/voucher_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vouchers extends VoucherNotifier {
  @override
  Future<List<VoucherModel>> build() async => [
        VoucherModel(
          id: 1,
          code: 'GIAM20',
          type: 'percent',
          value: 20,
          discountLabel: 'Giảm 20% phí giao hàng',
          description: 'Ưu đãi dành cho cửa hàng',
          minOrderValue: 20000,
          maxDiscount: 30000,
          expiresAt: DateTime(2099, 12, 31),
        ),
        VoucherModel(
          id: 2,
          code: 'DON100K',
          type: 'fixed',
          value: 15000,
          discountLabel: 'Giảm 15.000đ',
          minOrderValue: 100000,
          expiresAt: DateTime(2099, 12, 31),
        ),
      ];
}

void main() {
  testWidgets('voucher picker stays responsive with large text',
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
          home: const VoucherPickerScreen(fee: 50000),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chọn mã giảm giá'), findsOneWidget);
    expect(find.text('50.000đ'), findsOneWidget);
    expect(find.text('GIAM20'), findsOneWidget);
    expect(find.text('Đơn tối thiểu 100.000đ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
