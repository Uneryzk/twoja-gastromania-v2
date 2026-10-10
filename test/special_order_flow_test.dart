import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TGSellerProfileService.instance.reset();
    TGSpecialOrderService.instance.reset();
  });

  test('seed has 14 requests covering statuses and quote cases', () {
    final svc = TGSpecialOrderService.instance..ensureSeeded();
    expect(svc.requests.length, greaterThanOrEqualTo(14));
    expect(svc.requests.where((r) => r.status == TGSpecialRequestStatus.held), isNotEmpty);
    expect(svc.requests.where((r) => r.status == TGSpecialRequestStatus.awarded), isNotEmpty);
    final capped = svc.byRequestNo('SO-2026-000136')!;
    expect(svc.activeQuoteCount(capped.id), 5);
    expect(svc.quotesFor(svc.byRequestNo('SO-2026-000124')!.id).length, greaterThanOrEqualTo(2));
  });

  test('NIP checksum helper', () {
    expect(isValidNip('5261040828'), isTrue);
    expect(isValidNip('5252341134'), isTrue);
    expect(isValidNip('5252341136'), isFalse);
    expect(isValidNip('1234567890'), isFalse);
  });

  test('pro seller only sees directed leads; enterprise sees pool', () {
    final svc = TGSpecialOrderService.instance..ensureSeeded();
    final pro = svc.leadsForSeller('seller_gastropl');
    expect(pro.every((r) {
      final via = svc.viaFor(r.id, 'seller_gastropl');
      return via == TGLeadAccessVia.selected || via == TGLeadAccessVia.matched;
    }), isTrue);
    final ent = svc.leadsForSeller('seller_rm');
    expect(ent.length, greaterThan(pro.length));
  });

  test('basic store cannot receive leads', () {
    final svc = TGSpecialOrderService.instance..ensureSeeded();
    expect(svc.leadsForSeller('seller_technica'), isEmpty);
  });

  test('award closes request and marks other quotes lost', () {
    final svc = TGSpecialOrderService.instance..ensureSeeded();
    final r = svc.byRequestNo('SO-2026-000124')!;
    final qs = svc.quotesFor(r.id);
    expect(qs.length, greaterThanOrEqualTo(2));
    svc.award(r.id, qs.first.sellerId);
    expect(svc.byId(r.id)!.status, TGSpecialRequestStatus.awarded);
    expect(svc.quotesFor(r.id).where((q) => q.status == TGQuoteStatus.lost), isNotEmpty);
  });

  testWidgets('buyer requests list shows seeded items for Marek', (tester) async {
    final app = await pumpTgApp(tester, location: '/account/requests', size: TGSizes.desktop);
    app.auth.actAsBuyer(BuyerDevPick.marek);
    await tester.pumpAndSettle();
    expect(find.text('My requests'), findsWidgets);
    expect(find.textContaining('SO-2026-000123'), findsWidgets);
  });

  testWidgets('wizard gate requires login', (tester) async {
    final app = await pumpTgApp(tester, location: '/special-order/new', size: TGSizes.desktop, signedIn: false);
    await tester.pumpAndSettle();
    expect(app.auth.isLoggedIn, isFalse);
    expect(find.textContaining('Sign in'), findsWidgets);
  });

  testWidgets('seller leads basic shows upgrade lock', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/leads', size: TGSizes.desktop);
    app.auth.actAsStoreOwner(StoreOwnerDevPick.technica);
    await tester.pumpAndSettle();
    expect(find.textContaining('Upgrade to Pro'), findsOneWidget);
  });

  testWidgets('enterprise leads page lists cards', (tester) async {
    final app = await pumpTgApp(tester, location: '/dashboard/leads', size: TGSizes.desktop);
    app.auth.actAsStoreOwner(StoreOwnerDevPick.rmEnterprise);
    await tester.pumpAndSettle();
    expect(find.text('Special Order leads'), findsWidgets);
    expect(find.textContaining('SO-2026-'), findsWidgets);
  });
}
