import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/dashboard/dashboard_overview_page.dart';
import 'package:twoja_gastromania/dashboard/dashboard_shell.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_account_sheets.dart';
import 'package:twoja_gastromania/tg_core/account_capabilities.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_services/dashboard_service.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_models/tg_message.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_lifecycle_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

import 'helpers/tg_test_app.dart';

void _expectNoErrors(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}

List<Map<String, Object?>> _ev(String name) => [for (final e in TGAnalytics.events) if (e.$1 == name) e.$2];

FakeAuthState _signedIn() => FakeAuthState(isLoggedIn: true);

void main() {
  setUp(() {
    TGClock.reset();
    TGRevenueConfigService.instance.reset();
    ModerationService.instance.reset();
    DealService.instance.reset();
    TGSellerProfileService.instance.reset();
    MessagingService.instance.reset();
    RestaurantService.instance.reset();
    RestaurantLifecycleService.instance.reset();
    TGSpecialOrderService.instance.reset();
    TGAnalytics.reset();
  });

  group('AccountCapabilities', () {
    test('default demo seller sells but has no buyer history', () {
      final caps = AccountCapabilities.of(_signedIn());
      expect(caps.isSeller, isTrue);
      expect(caps.isBuyerActive, isFalse);
      expect(caps.store, isFalse);
      expect(caps.isNewUser, isFalse);
      expect(caps.toMap().containsKey('audited'), isFalse);
    });

    test('"New user (no data)" has no capability at all', () {
      final auth = _signedIn()..actAsNewUser();
      final caps = AccountCapabilities.of(auth);
      expect(caps.toMap().values.every((v) => !v), isTrue, reason: '${caps.toMap()}');
      expect(caps.isNewUser, isTrue);
    });

    test('"Seller + buyer" is both, from real deals and own listings', () {
      final auth = _signedIn()..actAsSellerBuyer();
      final caps = AccountCapabilities.of(auth);
      expect(caps.isSeller, isTrue);
      expect(caps.isBuyerActive, isTrue);
      expect(DealService.instance.forBuyer(auth.userId), isNotEmpty);
      expect(auth.ownedListings.every((p) => p.ownerKey == auth.userId), isTrue);
    });

    test('every existing Dev Switcher option maps onto capabilities', () {
      final auth = _signedIn();
      for (final s in TGEntitlementScenario.values) {
        auth.setRole(TGUserRole.seller, notify: false);
        auth.setScenario(s, notify: false);
        final caps = AccountCapabilities.of(auth);
        expect(caps.store, s == TGEntitlementScenario.storeSubscriber, reason: s.name);
        final restos = RestaurantService.instance.ownedBy(auth.userId).isNotEmpty;
        expect(caps.isSeller, s != TGEntitlementScenario.noListings || restos, reason: s.name);
        expect(caps.hasRestaurantListing, restos, reason: s.name);
      }
      for (final p in StoreOwnerDevPick.all) {
        auth.actAsStoreOwner(p);
        expect(AccountCapabilities.of(auth).store, isTrue, reason: p.sellerKey);
      }
      for (final p in ManufacturerDevPick.all) {
        auth.actAsManufacturer(p);
        final caps = AccountCapabilities.of(auth);
        final isMaker = TGSellerProfileService.instance.specialOrderManufacturers.any((m) => m.sellerKey == p.sellerKey);
        expect(caps.manufacturerEligible, isMaker, reason: p.sellerKey);
      }
      for (final p in BuyerDevPick.all) {
        auth.actAsBuyer(p);
        final caps = AccountCapabilities.of(auth);
        expect(caps.isSeller, isFalse, reason: p.userId);
        expect(caps.isBuyerActive, DealService.instance.forBuyer(p.userId).isNotEmpty || DealService.instance.reviewsForBuyer(p.userId).isNotEmpty || TGSpecialOrderService.instance.forBuyer(p.userId).isNotEmpty);
      }
      for (final p in SpecialOrderBuyerDevPick.all) {
        auth.actAsSpecialOrderBuyer(p);
        expect(AccountCapabilities.of(auth).isBuyerActive, TGSpecialOrderService.instance.forBuyer(p.userId).isNotEmpty, reason: p.userId);
      }
      for (final p in RestoSellerDevPick.values) {
        auth.actAsRestoSeller(p);
        AccountCapabilities.of(auth);
      }
      auth.setRole(TGUserRole.moderator);
      expect(AccountCapabilities.of(auth).isModerator, isTrue);
      expect(AccountCapabilities.of(auth).isStaff, isTrue);
      auth.setRole(TGUserRole.admin);
      expect(AccountCapabilities.of(auth).isAdmin, isTrue);
      auth.setRole(TGUserRole.visitor);
      expect(AccountCapabilities.of(auth).toMap().values.every((v) => !v), isTrue);
    });

    test('production mode turns all mock-derived capabilities off', () {
      TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 'test');
      final caps = AccountCapabilities.of(_signedIn());
      expect(caps.isSeller, isFalse);
      expect(caps.isNewUser, isTrue);
      expect(TGDashboard.actionItems(_signedIn()), isEmpty);
      expect(TGDashboard.kpis(_signedIn(), 30).every((k) => !k.enoughData), isTrue);
      expect(tgDevSwitchEnabled, isFalse);
    });
  });

  group('ActionItem', () {
    test('sorts by priority, then dueAt (no deadline last)', () {
      final now = DateTime(2026, 10, 13);
      ActionItem a(String id, ActionPriority p, [DateTime? due]) =>
          ActionItem(id: id, type: ActionItemType.listingExpiring, priority: p, titleKey: 'k', route: '/', dueAt: due);
      final list = [
        a('low', ActionPriority.low),
        a('med-none', ActionPriority.medium),
        a('med-late', ActionPriority.medium, now.add(const Duration(days: 5))),
        a('crit', ActionPriority.critical, now.add(const Duration(days: 9))),
        a('med-soon', ActionPriority.medium, now.add(const Duration(days: 1))),
      ]..sort(ActionItem.compare);
      expect(list.map((e) => e.id), ['crit', 'med-soon', 'med-late', 'med-none', 'low']);
    });

    test('expired / expiring listings deep-link to ?renew=ID', () {
      final items = TGDashboard.actionItems(_signedIn());
      final expired = items.firstWhere((i) => i.id == 'expired-own_f_exp1');
      expect(expired.route, '/dashboard/listings?renew=own_f_exp1');
      final expiring = items.firstWhere((i) => i.id == 'expiring-own_f1');
      expect(expiring.route, '/dashboard/listings?renew=own_f1');
      expect(expiring.dueAt, isNotNull);
      for (var i = 1; i < items.length; i++) {
        expect(ActionItem.compare(items[i - 1], items[i]), lessThanOrEqualTo(0));
      }
    });

    test('moderator info request is critical with the reply deadline', () {
      final auth = _signedIn()..setScenario(TGEntitlementScenario.needsAttention);
      final before = TGDashboard.actionItems(auth).firstWhere((i) => i.id.endsWith('own_review1'));
      expect(before.type, ActionItemType.listingUnderReview);
      expect(before.priority, ActionPriority.medium);
      final due = TGClock.now().add(const Duration(days: 3));
      ModerationService.instance.infoDueAt['43250697'] = due;
      final first = TGDashboard.actionItems(auth).first;
      expect(first.type, ActionItemType.moderatorInfo);
      expect(first.priority, ActionPriority.critical);
      expect(first.dueAt, due);
      expect(first.route, '/dashboard/listings?filter=review');
    });

    test('buyer side: evidence (?evidence=1) and confirm (?confirm=1) links', () {
      final auth = _signedIn()..actAsSellerBuyer();
      final items = TGDashboard.actionItems(auth);
      final deals = DealService.instance;
      final open = deals.objections.where((o) => o.status == TGObjectionStatus.awaitingEvidence && deals.byId(o.dealId)?.buyerId == auth.userId);
      for (final o in open) {
        expect(items.any((i) => i.route == '/account/reviews/${o.reviewId}?evidence=1' && i.priority == ActionPriority.critical), isTrue);
      }
      for (final d in deals.forBuyer(auth.userId).where((d) => d.waitingForBuyer)) {
        expect(items.any((i) => i.route == '/account/deals/${d.id}?confirm=1'), isTrue);
      }
      expect(items.any((i) => i.route == '/dashboard/listings?renew=own_sb2'), isTrue);
    });

    test('a new user has no action items and no KPI data', () {
      final auth = _signedIn()..actAsNewUser();
      expect(TGDashboard.actionItems(auth), isEmpty);
      expect(TGDashboard.kpis(auth, 30).every((k) => k.value == null), isTrue);
      expect(TGDashboard.listings(auth).total, 0);
      expect(TGDashboard.upcomingCharges(auth), isEmpty);
    });

    test('upcoming charges: store renewal at the plan price, sorted by date', () {
      final auth = _signedIn()..setScenario(TGEntitlementScenario.storeSubscriber);
      final charges = TGDashboard.upcomingCharges(auth, now: DateTime(2026, 10, 1));
      final store = charges.firstWhere((c) => c.labelKey == 'dash_charge_store');
      expect(store.amountPln, 199);
      expect(store.dueAt, auth.storeRenewsOn);
      for (var i = 1; i < charges.length; i++) {
        expect(charges[i - 1].dueAt.isAfter(charges[i].dueAt), isFalse);
      }
      final private = _signedIn();
      expect(TGDashboard.upcomingCharges(private), isEmpty);
    });
  });

  test('bottom nav hides on wizard and payment routes', () {
    expect(DashboardShell.hidesBottomNav('/add-product'), isTrue);
    expect(DashboardShell.hidesBottomNav('/add-product/checkout'), isTrue);
    expect(DashboardShell.hidesBottomNav('/restaurants/new'), isTrue);
    expect(DashboardShell.hidesBottomNav('/account/requests/SO-1/consent'), isTrue);
    expect(DashboardShell.hidesBottomNav('/dashboard'), isFalse);
    expect(DashboardShell.hidesBottomNav('/dashboard/actions'), isFalse);
  });

  group('shell & overview', () {
    testWidgets('desktop: 248px sticky sidebar at top 88, ~1008px content', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard');
      await pumpFor(tester, const Duration(milliseconds: 300));
      final sidebar = tester.getRect(find.byKey(const Key('dash-sidebar')));
      expect(sidebar.width, 248);
      expect(sidebar.top, 88);
      final content = tester.getRect(find.byKey(const Key('dash-content')));
      expect(content.width, 1008);
      expect(find.byKey(const Key('dash-action-center')), findsOneWidget);
      expect(find.byKey(const Key('dash-quota')), findsOneWidget);
      expect(find.byKey(const Key('dash-kpis')), findsOneWidget);
      expect(find.byKey(const Key('dash-snapshot')), findsOneWidget);
      expect(find.byKey(const Key('dash-charges')), findsOneWidget);
      expect(find.byKey(const Key('dash-messages')), findsOneWidget);
      expect(find.byKey(const Key('dash-bottom-nav')), findsNothing);
      expect(_ev('dash_view').single['page'], 'overview');

      final scroll = find.byKey(const Key('dash-content'));
      await tester.drag(scroll, const Offset(0, -400));
      await tester.pump();
      expect(tester.getRect(find.byKey(const Key('dash-sidebar'))).top, 88);
      _expectNoErrors(app);
    });

    testWidgets('action item click keeps the deep-link query and fires the event', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard/actions');
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byKey(const Key('dash-action-expired-own_f_exp2')));
      await tester.tap(find.byKey(const Key('dash-action-expired-own_f_exp2')));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/dashboard/listings?renew=own_f_exp2');
      expect(_ev('action_item_click').single['type'], 'listingExpired');
      _expectNoErrors(app);
    });

    testWidgets('KPI period chips switch the window and fire kpi_period_change', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard');
      app.auth.actAsSellerBuyer();
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.text('Last 30 days'), findsOneWidget);
      expect(find.byKey(const Key('dash-kpi-contacts')), findsOneWidget);
      expect(find.text('Not enough data yet'), findsWidgets);
      await tester.tap(find.byKey(const Key('dash-kpi-period-90')));
      await tester.pump();
      expect(find.text('Last 90 days'), findsOneWidget);
      expect(_ev('kpi_period_change').single, {'from': 30, 'to': 90});
      _expectNoErrors(app);
    });

    testWidgets('phone header: no bell or tick; AD shows combined inbox count', (tester) async {
      final app = await pumpTgApp(tester, location: '/', size: TGSizes.phone);
      expect(find.byIcon(Icons.notifications_none), findsNothing);
      expect(find.byIcon(Icons.task_alt), findsNothing);
      expect(find.byKey(const Key('header-avatar')), findsOneWidget);
      expect(find.text('Twoja Gastromania'), findsWidgets);

      final uid = app.auth.userId;
      NotificationService.instance.add(
        userId: uid,
        type: 'new_message',
        dealId: 'd1',
        title: 'Hello',
        body: 'Inbox',
      );
      MessagingService.instance.addMockThread(
        TGChatThread(
          id: 'header_inbox_t',
          listingId: 'p1',
          listingTitle: 'Oven',
          listingImageUrl: '',
          listingPath: '/product-detail/p1',
          buyerId: 'buyer_x',
          sellerId: uid,
          buyerName: 'B',
          sellerName: 'S',
          updatedAt: DateTime(2026, 10, 1),
          unreadSeller: 2,
        ),
      );
      await tester.pump();
      final expected =
          NotificationService.instance.unreadCount(uid) + MessagingService.instance.unreadTotal(uid);
      expect(expected, greaterThan(0));
      expect(find.byKey(const Key('header-inbox-count')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('header-inbox-count')), matching: find.text('$expected')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('header-avatar')));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const Key('account-open-dashboard')), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('320px header does not overflow', (tester) async {
      final app = await pumpTgApp(tester, location: '/', size: TGSizes.smallPhone);
      expect(find.byIcon(Icons.notifications_none), findsNothing);
      expect(find.byIcon(Icons.task_alt), findsNothing);
      expect(find.byKey(const Key('header-avatar')), findsOneWidget);
      _expectNoErrors(app);
    });

    testWidgets('header pill opens the Action center; avatar opens the account menu', (tester) async {
      final app = await pumpTgApp(tester, location: '/products');
      await tester.tap(find.textContaining(' expired · Renew'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/dashboard/actions');
      expect(find.byKey(const Key('dash-actions-page')), findsOneWidget);
      expect(find.byKey(const Key('dash-action-expired-own_f_exp1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('header-avatar')));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const Key('account-open-dashboard')), findsOneWidget);
      await tester.tap(find.byKey(const Key('account-open-dashboard')));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/dashboard');
      _expectNoErrors(app);
    });

    testWidgets('"New user (no data)" pick lands on the 4-card empty state', (tester) async {
      final app = await pumpTgApp(tester, location: '/');
      applyTGDevSwitchPick(app.router, app.auth, DashboardDevPick.newUser);
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/dashboard');
      expect(find.byKey(const Key('dash-empty')), findsOneWidget);
      for (final id in ['sell', 'resto', 'buy', 'special']) {
        expect(find.byKey(Key('dash-empty-$id')), findsOneWidget);
      }
      expect(find.byKey(const Key('dash-kpis')), findsNothing);
      expect(_ev('dash_view').last['newUser'], isTrue);
      await tester.tap(find.byKey(const Key('dash-empty-sell')));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/add-product');
      _expectNoErrors(app);
    });

    testWidgets('production mode: empty states, no dev caps, no demo radios', (tester) async {
      TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 'test');
      final app = await pumpTgApp(tester, location: '/dashboard');
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const Key('dash-empty')), findsOneWidget);
      expect(find.byKey(const Key('dash-dev-caps')), findsNothing);
      expect(_ev('dash_view').single['production'], isTrue);

      await tester.longPress(find.byKey(const Key('header-avatar')));
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(find.text('Dashboard personas'), findsNothing);

      await tester.tap(find.byKey(const Key('header-avatar')));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const Key('account-open-dashboard')), findsOneWidget);
      expect(find.byType(RadioListTile<TGUserRole>), findsNothing);
      _expectNoErrors(app);
    });

    testWidgets('390px: 64px bottom nav, full-screen More, placeholder page', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard', size: TGSizes.phone);
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const Key('dash-sidebar')), findsNothing);
      final nav = tester.getRect(find.byKey(const Key('dash-bottom-nav')));
      expect(nav.height, 64);
      expect(nav.bottom, 844);

      await tester.tap(find.byKey(const Key('dash-bottom-more')));
      await pumpFor(tester, const Duration(milliseconds: 400));
      final menu = tester.getRect(find.byKey(const Key('dash-more-menu')));
      expect(menu.size, const Size(390, 844));
      await tester.ensureVisible(find.byKey(const Key('dash-nav-settings')));
      await tester.tap(find.byKey(const Key('dash-nav-settings')));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/dashboard/settings');
      expect(find.byKey(const Key('settings-page')), findsOneWidget);

      await tester.tap(find.byKey(const Key('dash-bottom-actions')));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/dashboard/actions');
      _expectNoErrors(app);
    });

    testWidgets('existing query routes still resolve', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard/listings?filter=expired');
      expect(find.text('Expired'), findsWidgets);
      app.router.go('/dashboard/listings?renew=own_f_exp1');
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(app.location, '/dashboard/listings?renew=own_f_exp1');
      _expectNoErrors(app);
    });
  });

  testWidgets('skeleton does not animate under reduced motion', (tester) async {
    Future<void> pump(bool reduce) => tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              FFLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduce),
              child: const Scaffold(body: SingleChildScrollView(child: DashSkeleton())),
            ),
          ),
        );
    await pump(true);
    expect(tester.hasRunningAnimations, isFalse);
    await pump(false);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
