import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_account_sheets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Admin pick sets staff auth and navigates to /admin', (tester) async {
    final auth = FakeAuthState(); // visitor by default
    late GoRouter router;
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
        GoRoute(path: '/admin', builder: (_, __) => const Scaffold(body: Text('admin-home'))),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(auth.isLoggedIn, isFalse);
    expect(auth.role, TGUserRole.visitor);

    applyTGDevSwitchPick(router, auth, TGUserRole.admin);
    await tester.pumpAndSettle();

    expect(auth.isLoggedIn, isTrue);
    expect(auth.role, TGUserRole.admin);
    expect(auth.canModerate, isTrue);
    expect(find.text('admin-home'), findsOneWidget);
  });

  testWidgets('Moderator pick navigates to /admin', (tester) async {
    final auth = FakeAuthState();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
        GoRoute(path: '/admin', builder: (_, __) => const Scaffold(body: Text('admin-home'))),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    applyTGDevSwitchPick(router, auth, TGUserRole.moderator);
    await tester.pumpAndSettle();

    expect(auth.role, TGUserRole.moderator);
    expect(find.text('admin-home'), findsOneWidget);
  });

  testWidgets('buyer and manufacturer picks update FakeAuthState', (tester) async {
    final auth = FakeAuthState();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
        GoRoute(path: '/account/deals', builder: (_, __) => const Scaffold(body: Text('deals'))),
        GoRoute(path: '/seller/:id', builder: (_, __) => const Scaffold(body: Text('store'))),
        GoRoute(path: '/account/requests', builder: (_, __) => const Scaffold(body: Text('requests'))),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    applyTGDevSwitchPick(router, auth, BuyerDevPick.marek);
    await tester.pumpAndSettle();
    expect(auth.role, TGUserRole.buyer);
    expect(auth.userId, 'buyer_marek');
    expect(find.text('deals'), findsOneWidget);

    applyTGDevSwitchPick(router, auth, ManufacturerDevPick.rm);
    await tester.pumpAndSettle();
    expect(auth.role, TGUserRole.storeSeller);
    expect(auth.userId, 'seller_rm');
    expect(find.text('store'), findsOneWidget);

    applyTGDevSwitchPick(router, auth, SpecialOrderBuyerDevPick.jan);
    await tester.pumpAndSettle();
    expect(auth.userId, 'buyer_jan');
    expect(find.text('requests'), findsOneWidget);
  });
}
