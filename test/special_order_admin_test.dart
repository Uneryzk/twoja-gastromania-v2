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

  test('admin queues cover matching held no-quotes reported', () {
    final svc = TGSpecialOrderService.instance..ensureSeeded();
    expect(svc.adminCount(TGSoAdminQueue.needsMatching), greaterThanOrEqualTo(2));
    expect(svc.adminCount(TGSoAdminQueue.held), greaterThanOrEqualTo(2));
    expect(svc.adminCount(TGSoAdminQueue.noQuotes), greaterThanOrEqualTo(1));
    expect(svc.adminCount(TGSoAdminQueue.reported), greaterThanOrEqualTo(1));
    expect(svc.resolveAdminSearch('SO-2026-000135'), 'SO-2026-000135');
  });

  test('approve held and match manufacturers write audit', () {
    final svc = TGSpecialOrderService.instance..ensureSeeded();
    final held = svc.adminQueue(TGSoAdminQueue.held).first;
    svc.approveAndRoute(held.id, actorId: 'mod_1', actorRole: 'moderator');
    expect(svc.byId(held.id)!.status, TGSpecialRequestStatus.open);
    expect(svc.auditFor(held.id).any((a) => a.action == 'approve_route'), isTrue);

    final need = svc.adminQueue(TGSoAdminQueue.needsMatching).first;
    svc.matchManufacturers(need.id, ['seller_gastropl'], actorId: 'mod_1', actorRole: 'moderator');
    expect(svc.viaFor(need.id, 'seller_gastropl'), TGLeadAccessVia.matched);
  });

  test('reject supports 10s undo', () {
    final svc = TGSpecialOrderService.instance..ensureSeeded();
    final r = svc.byRequestNo('SO-2026-000123')!;
    svc.rejectRequest(r.id, actorId: 'mod_1', actorRole: 'moderator', reason: 'spam');
    expect(svc.byId(r.id)!.status, TGSpecialRequestStatus.rejected);
    expect(svc.undoReject(actorId: 'mod_1', actorRole: 'moderator'), isTrue);
    expect(svc.byId(r.id)!.status, isNot(TGSpecialRequestStatus.rejected));
  });

  testWidgets('admin special-orders queue loads for moderator', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin/special-orders', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pumpAndSettle();
    expect(find.textContaining('Needs matching'), findsWidgets);
  });

  testWidgets('390px admin so queue shows cards', (tester) async {
    final app = await pumpTgApp(tester, location: '/admin/special-orders', size: TGSizes.phone);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pumpAndSettle();
    expect(find.textContaining('SO-2026-'), findsWidgets);
  });
}
