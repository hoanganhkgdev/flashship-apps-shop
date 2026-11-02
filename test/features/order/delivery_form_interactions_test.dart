import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/address/models/address_entry.dart';
import 'package:flashship_shop/features/address/providers/address_provider.dart';
import 'package:flashship_shop/features/auth/providers/auth_provider.dart';
import 'package:flashship_shop/features/order/screens/create_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth() : super(const AuthState(isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Addresses extends StateNotifier<AsyncValue<List<AddressEntry>>>
    implements AddressNotifier {
  _Addresses()
      : super(const AsyncData([
          AddressEntry(
              id: 1,
              name: 'Linh Nguyễn',
              phone: '0901234567',
              address: '25 Trần Hưng Đạo',
              lat: 10.2,
              lng: 104.0),
        ]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> showForm(WidgetTester tester, {bool compact = false}) async {
    tester.view.physicalSize = Size(compact ? 320 : 390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _Auth()),
        addressProvider.overrideWith((ref) => _Addresses()),
      ],
      child: MaterialApp(
        theme: compact ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(compact ? 1.5 : 1.08)),
          child: child!,
        ),
        home: const CreateOrderScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('amount and note sheets preserve edits and allow clearing',
      (tester) async {
    await showForm(tester);
    await tester.ensureVisible(find.text('Tiền lấy hàng'));
    await tester.tap(find.text('Tiền lấy hàng'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '150000');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('150.000đ'), findsOneWidget);

    await tester.tap(find.text('Tiền lấy hàng'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '150.000');
    await tester.enterText(find.byType(TextField).last, '');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Không bắt buộc'), findsOneWidget);

    await tester.ensureVisible(find.text('Ghi chú cho tài xế'));
    await tester.tap(find.text('Ghi chú cho tài xế'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Gọi trước khi giao');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Gọi trước khi giao'), findsOneWidget);
    await tester.tap(find.text('Ghi chú cho tài xế'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'Gọi trước khi giao');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('address book opens saved tab and fills recipient contact',
      (tester) async {
    await showForm(tester);
    await tester.tap(find.text('Sổ địa chỉ'));
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    await tester.tap(find.text('Linh Nguyễn'));
    await tester.pumpAndSettle();
    expect(find.text('25 Trần Hưng Đạo'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
        fields.any((field) => field.controller?.text == '0901234567'), isTrue);
    expect(
        fields.any((field) => field.controller?.text == 'Linh Nguyễn'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small dark form keeps submit visible and reveals inline errors',
      (tester) async {
    await showForm(tester, compact: true);
    expect(tester.takeException(), isNull);
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đặt giao hàng'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng chọn điểm lấy hàng'), findsWidgets);
    expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
    expect(tester.getTopLeft(find.text('ĐIỂM LẤY HÀNG')).dy, lessThan(200));
    expect(tester.takeException(), isNull);
  });
}
