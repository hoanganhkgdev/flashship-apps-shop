import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/notification/models/notification_item.dart';
import 'package:flashship_shop/features/notification/providers/notification_provider.dart';
import 'package:flashship_shop/features/notification/screens/notification_inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Notifications extends StateNotifier<List<NotificationItem>>
    implements NotificationNotifier {
  _Notifications()
      : super([
          NotificationItem(
            id: '1',
            title: 'Tài xế đang đến lấy hàng',
            body: 'Tài xế Nguyễn Văn A đang di chuyển tới cửa hàng.',
            orderCode: 'FS1001',
            createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
          ),
          NotificationItem(
            id: '2',
            title: 'Đơn hàng đã được xác nhận',
            body: 'Đơn FS1001 đã được hệ thống xác nhận.',
            orderCode: 'FS1001',
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          NotificationItem(
            id: '3',
            title: 'Voucher mới dành cho cửa hàng',
            body: 'Bạn vừa nhận được ưu đãi phí giao hàng.',
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            isRead: true,
          ),
        ]);

  @override
  void markRead(String id) {
    state = state
        .map((item) => item.id == id ? item.copyWith(isRead: true) : item)
        .toList();
  }

  @override
  void markAllRead() {
    state = state.map((item) => item.copyWith(isRead: true)).toList();
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}

  @override
  Future<bool> delete(String id) async {
    state = state.where((item) => item.id != id).toList();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('notification inbox stays responsive with filters and large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationProvider.overrideWith((ref) => _Notifications()),
          notificationHasMoreProvider.overrideWith((ref) => false),
          unreadCountProvider.overrideWith((ref) async => 2),
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
          home: const NotificationInboxScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Chưa đọc'), findsOneWidget);
    expect(find.text('Đơn hàng'), findsOneWidget);
    expect(find.text('Tài xế đang đến lấy hàng'), findsOneWidget);
    expect(find.text('Voucher mới dành cho cửa hàng'), findsOneWidget);
    expect(find.text('Đơn hàng đã được xác nhận'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Đơn hàng đã được xác nhận'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-140, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa đọc'));
    await tester.pumpAndSettle();
    expect(find.text('Voucher mới dành cho cửa hàng'), findsNothing);
    expect(find.text('Thông báo chưa đọc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
