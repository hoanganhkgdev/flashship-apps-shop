import 'package:flashship_shop/core/router/app_route.dart';
import 'package:flashship_shop/core/router/app_router.dart';
import 'package:flashship_shop/core/theme/app_theme.dart';
import 'package:flashship_shop/core/widgets/app_decor_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every routed page paints its own opaque app backdrop',
      (tester) async {
    final pages = <Page<void>>[
      appPage(key: const ValueKey('a'), name: '/a', child: const Text('A')),
      appPage(key: const ValueKey('b'), name: '/b', child: const Text('B')),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Navigator(pages: pages, onDidRemovePage: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    // Màn trên cùng có nền riêng, nên màn bên dưới không còn hiện xuyên qua
    // trong lúc chuyển màn.
    expect(
      find.ancestor(of: find.text('B'), matching: find.byType(AppBackdrop)),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('A', skipOffstage: false),
        matching: find.byType(AppBackdrop, skipOffstage: false),
      ),
      findsOneWidget,
    );
  });

  testWidgets('screens pushed with appRoute also get their own backdrop',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const Text('home')),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    navigator.push(appRoute<void>(const Text('pushed')));
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
          of: find.text('pushed'), matching: find.byType(AppBackdrop)),
      findsOneWidget,
    );
  });
}
