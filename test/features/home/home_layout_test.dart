import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/address/data/address_repository.dart';
import 'package:flashship_shop/features/address/models/address_entry.dart';
import 'package:flashship_shop/features/auth/models/shop_user_model.dart';
import 'package:flashship_shop/features/auth/providers/auth_provider.dart';
import 'package:flashship_shop/features/home/providers/today_stats_provider.dart';
import 'package:flashship_shop/features/home/screens/home_screen.dart';
import 'package:flashship_shop/features/notification/providers/notification_provider.dart';
import 'package:flashship_shop/features/order/models/order_model.dart';
import 'package:flashship_shop/features/order/providers/order_provider.dart';
import 'package:flashship_shop/features/profile/models/support_config_item.dart';
import 'package:flashship_shop/features/profile/providers/support_config_provider.dart';
import 'package:flashship_shop/features/stats/stats_repository.dart';
import 'package:flashship_shop/features/voucher/voucher_model.dart';
import 'package:flashship_shop/features/voucher/voucher_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth()
      : super(const AuthState(
          isInitialized: true,
          user: ShopUserModel(
            id: 1,
            name: 'Cửa hàng bánh ngọt Nhà Mình',
            phone: '0900000000',
            address: '12 Nguyễn Trãi, phường Dương Đông, Phú Quốc',
          ),
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Orders extends StateNotifier<OrderListState>
    implements OrderListNotifier {
  _Orders(super.state);

  @override
  Future<void> fetch({bool refresh = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stats implements StatsRepository {
  @override
  Future<Map<String, dynamic>> fetch({String? period}) async => {};
}

class _Vouchers extends VoucherNotifier {
  @override
  Future<List<VoucherModel>> build() async => const [
        VoucherModel(
            id: 1,
            code: 'SHOP10',
            type: 'percent',
            value: 10,
            discountLabel: 'Giảm 10% phí giao hàng'),
      ];
}

class _Addresses implements AddressRepository {
  @override
  Future<List<AddressEntry>> fetchAll() async => const [
        AddressEntry(
          id: 1,
          label: 'Khách quen',
          name: 'Nguyễn Văn An',
          phone: '0909123456',
          address: '25 Trần Hưng Đạo, Phú Quốc',
        ),
      ];

  @override
  Future<AddressEntry> add(AddressDraft draft) => throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();

  @override
  Future<void> update(int id, AddressDraft draft) => throw UnimplementedError();
}

OrderModel _order(int id, String status) => OrderModel(
      id: id,
      code: 'FS$id',
      status: status,
      pickupAddress: '12 Nguyễn Trãi, Dương Đông',
      deliveryAddress: '25 Trần Hưng Đạo, Phú Quốc',
      deliveryPhone: '090000000$id',
      receiverName: 'Khách hàng $id',
      shippingFee: 25000,
      createdAt: DateTime(2026, 10, 28),
      driver: status == 'assigned'
          ? const DriverInfo(
              id: 1, name: 'Nguyễn Văn Minh', phone: '0901234567')
          : null,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final dark in [false, true]) {
    testWidgets(
        'home scrolls and collapses header in ${dark ? 'dark large text' : 'light'}',
        (tester) async {
      tester.view.physicalSize = Size(dark ? 320 : 390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _Auth()),
          orderListProvider.overrideWith((ref) => _Orders(OrderListState(
                hasMore: false,
                orders: [
                  _order(1, 'pending'),
                  _order(2, 'assigned'),
                  _order(3, 'processing'),
                  _order(4, 'completed')
                ],
              ))),
          statsRepositoryProvider.overrideWithValue(_Stats()),
          todayStatsProvider.overrideWith((ref) async => const TodayStats(
              orders: 4, active: 3, completed: 1, revenue: 25000)),
          unreadCountProvider.overrideWith((ref) async => 12),
          voucherProvider.overrideWith(_Vouchers.new),
          addressRepositoryProvider.overrideWithValue(_Addresses()),
          supportConfigProvider.overrideWith((ref) async => const [
                SupportConfigItem(
                  title: 'Tổng đài hỗ trợ',
                  type: 'phone',
                  value: '0909123456',
                ),
              ]),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              textScaler: TextScaler.linear(dark ? 1.5 : 1.08),
            ),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Xin chào,'), findsOneWidget);
      expect(find.text('Giao hàng'), findsWidgets);

      final view = find.byType(CustomScrollView).first;
      final scrollable =
          find.descendant(of: view, matching: find.byType(Scrollable)).first;
      await tester.drag(view, const Offset(0, -240));
      await tester.pumpAndSettle();
      final intro = find.descendant(
          of: find.byType(SliverPersistentHeader),
          matching: find.byType(Opacity));
      expect(tester.widget<Opacity>(intro).opacity, 0);
      expect(find.text('Địa chỉ lấy hàng'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final title in [
        'Đơn đang thực hiện',
        'Hôm nay của shop',
        'Gửi lại nhanh',
        'Địa chỉ thường dùng',
        'Ưu đãi của shop',
        'Bạn cần hỗ trợ?',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 150,
            scrollable: scrollable);
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(find.text('SHOP10'), findsOneWidget);

      await tester.tap(find.text('Đơn hàng').last);
      await tester.pumpAndSettle();
      expect(find.text('Theo dõi đơn và đặt lại khi cần'), findsOneWidget);
      expect(find.text('Chờ tài xế'), findsOneWidget);
      expect(find.text('Phí ship'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Thống kê').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Theo dõi hiệu quả hoạt động của cửa hàng'),
        findsOneWidget,
      );
      expect(find.text('Tổng phí ship'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Tổng quan đơn hàng'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Tổng quan đơn hàng'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Tài khoản').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Quản lý cửa hàng và thiết lập của bạn'),
        findsOneWidget,
      );
      expect(find.text('Cửa hàng bánh ngọt Nhà Mình'), findsOneWidget);
      expect(find.text('Hoạt động tháng này'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Đơn hàng 7 ngày qua'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Đơn hàng 7 ngày qua'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
