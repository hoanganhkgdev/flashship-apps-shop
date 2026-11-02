import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/address/data/address_repository.dart';
import 'package:flashship_shop/features/address/models/address_entry.dart';
import 'package:flashship_shop/features/address/screens/address_book_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Addresses implements AddressRepository {
  @override
  Future<List<AddressEntry>> fetchAll() async => const [
        AddressEntry(
          id: 1,
          label: 'Khách quen',
          name: 'Nguyễn Văn An',
          phone: '0909123456',
          address: '25 Trần Hưng Đạo, phường Dương Đông, Phú Quốc',
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('address book stays responsive with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressRepositoryProvider.overrideWithValue(_Addresses()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: const AddressBookScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Địa chỉ thường giao'), findsOneWidget);
    expect(find.text('Khách quen'), findsOneWidget);
    expect(find.text('Thêm địa chỉ mới'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Khách quen'));
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa'), findsOneWidget);
    expect(find.text('Lưu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
