import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/core/widgets/address_picker_screen.dart';
import 'package:flashship_shop/features/address/models/address_entry.dart';
import 'package:flashship_shop/features/address/providers/address_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Addresses extends StateNotifier<AsyncValue<List<AddressEntry>>>
    implements AddressNotifier {
  _Addresses()
      : super(
          const AsyncData([
            AddressEntry(
              id: 1,
              name: 'Nguyễn Văn An',
              phone: '0909123456',
              address: '12 Nguyễn Trãi, Ninh Kiều, Cần Thơ',
              label: 'Khách quen',
              lat: 10.03,
              lng: 105.78,
            ),
          ]),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('delivery address picker stays responsive with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressProvider.overrideWith((ref) => _Addresses()),
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
          home: const AddressPickerScreen(
            title: 'Địa chỉ giao hàng',
            showSaved: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Địa chỉ giao hàng'), findsOneWidget);
    expect(find.text('Tìm tên đường, địa điểm...'), findsOneWidget);
    expect(find.text('Chọn vị trí trên bản đồ'), findsOneWidget);
    expect(find.text('Đã lưu'), findsOneWidget);
    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
