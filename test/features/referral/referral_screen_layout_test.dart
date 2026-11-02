import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/features/referral/referral_model.dart';
import 'package:flashship_shop/features/referral/referral_provider.dart';
import 'package:flashship_shop/features/referral/referral_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('referral screen stays responsive with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const info = ReferralInfo(
      code: 'SHOPANH2026',
      points: 120,
      program: ReferralProgram(
        pointsPerReferral: 10,
        minOrders: 5,
        welcomeAmount: 30000,
      ),
      total: 1,
      rewarded: 0,
      pending: 1,
      referrals: [
        ReferralEntry(
          id: 1,
          shopName: 'Cửa hàng Bạn Mình',
          status: 'pending',
          points: null,
          requiredOrders: 5,
          createdAt: null,
        ),
      ],
      transactions: [
        PointTransaction(
          id: 1,
          type: 'referral',
          points: 10,
          balanceAfter: 120,
          description: 'Thưởng giới thiệu cửa hàng',
          createdAt: null,
        ),
      ],
    );
    const rewards = [
      PointRewardItem(
        id: 1,
        name: 'Voucher giảm 30.000đ phí giao hàng',
        pointsCost: 100,
        type: 'fixed',
        value: 30000,
        minOrderValue: 50000,
        maxDiscount: 30000,
        validDays: 30,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralInfoProvider.overrideWith((ref) async => info),
          pointRewardsProvider.overrideWith((ref) async => rewards),
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
          home: const ReferralScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Giới thiệu & tích điểm'), findsOneWidget);
    expect(find.text('SHOPANH2026'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    for (final title in [
      'Cách hoạt động',
      'Đổi điểm lấy voucher',
      'Shop đã mời (1)',
      'Lịch sử điểm',
    ]) {
      final target = find.text(title);
      await tester.scrollUntilVisible(
        target,
        160,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(target, findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
}
