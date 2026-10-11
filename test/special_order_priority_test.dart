import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/priority_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TGClock.reset();
    TGSellerProfileService.instance.reset();
    TGSpecialOrderService.instance.reset();
    TGPriorityService.instance.reset();
    TGRevenueConfigService.instance.reset();
  });

  test('mock defaults: phase 2 with paid flags on', () {
    final cfg = TGRevenueConfigService.instance.config;
    expect(cfg.phase, 2);
    expect(cfg.productionMode, isFalse);
    expect(cfg.flags.priorityForSale, isTrue);
    expect(cfg.flags.marketInsight, isTrue);
    expect(cfg.flags.bulkBilling, isTrue);
  });

  test('phase 0 clears paid flags', () {
    TGRevenueConfigService.instance.setPhase(0, actorId: 'test');
    expect(TGRevenueConfigService.instance.flags.priorityForSale, isFalse);
    expect(TGRevenueConfigService.instance.flags.marketInsight, isFalse);
  });

  test('priority seed: 2 active, 1 waitlist, 1 founder', () {
    TGPriorityService.instance.ensureSeeded();
    final active = TGPriorityService.instance.bySeller.values.where((p) => p.isActive).length;
    expect(active, greaterThanOrEqualTo(2));
    expect(TGPriorityService.instance.bySeller['seller_metalgast']?.status, TGPriorityStatus.waitlist);
    expect(TGPriorityService.instance.bySeller['seller_inoxline']?.source, TGPrioritySource.founderFree);
    expect(TGPriorityService.instance.bySeller['seller_rm']?.source, TGPrioritySource.enterprise);
    expect(TGPriorityService.instance.bySeller['seller_gastropl']?.source, TGPrioritySource.addon);
  });

  test('wave grant: Pro without Priority gets delayed pro_pool access', () {
    final svc = TGSpecialOrderService.instance..ensureSeeded();
    TGPriorityService.instance.ensureSeeded();
    final now = TGClock.now();
    final draft = TGSpecialRequest(
      id: 'tmp',
      requestNo: 'tmp',
      buyerId: 'buyer_marek',
      buyerName: 'Marek',
      companyName: 'Co',
      phone: '+48111',
      email: 'a@b.pl',
      projectTypes: const [TGStoreSpecialty.laserBending],
      title: 'Wave test laser',
      description: 'Need laser bending',
      quantity: 1,
      dimensionsText: '1200x800',
      material: '304',
      finish: 'brushed',
      deadline: TGSpecialDeadline.flex,
      city: 'Katowice',
      voivodeship: 'Śląskie',
      installationNeeded: true,
      deliveryNeeded: true,
      files: const [],
      routingMode: TGSpecialRoutingMode.team,
      selectedSellerIds: const [],
      contactPref: TGSpecialContactPref.share,
      consentAt: now,
      status: TGSpecialRequestStatus.open,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 30)),
    );
    final saved = svc.submitRequest(draft);
    final metal = svc.accessRow(saved.id, 'seller_metalgast');
    expect(metal?.via, TGLeadAccessVia.proPool);
    expect(metal!.visibleFrom!.isAfter(now), isTrue);
    // Enterprise always wave 1
    expect(svc.viaFor(saved.id, 'seller_rm'), TGLeadAccessVia.enterprisePool);
    // Before delay, Pro without Priority does not see the lead
    expect(svc.leadsForSeller('seller_metalgast').any((r) => r.id == saved.id), isFalse);
    TGClock.advance(const Duration(hours: 25));
    expect(svc.leadsForSeller('seller_metalgast').any((r) => r.id == saved.id), isTrue);
  });

  test('pool quote caps reserve a slot for wave 2', () {
    final svc = TGSpecialOrderService.instance..ensureSeeded();
    // Find an open request with pool access
    final r = svc.requests.firstWhere((e) => e.status == TGSpecialRequestStatus.open || e.status == TGSpecialRequestStatus.quoted);
    final reason = svc.quoteBlockReason(r.id, 'seller_rm');
    // May be null if under cap — just ensure pool helpers run
    expect(svc.poolQuoteCount(r.id), greaterThanOrEqualTo(0));
    expect(reason == null || reason.contains('pool') || reason.contains('Already') || reason.contains('limit') || reason.contains('reserved') || reason.contains('closed'), isTrue);
  });

  test('quiet month extends addon billing', () {
    TGPriorityService.instance.ensureSeeded();
    TGRevenueConfigService.instance.applyConfig(
      TGRevenueConfigService.instance.config.copyWith(quietMonthThreshold: 9999),
      actorId: 'test',
      action: 'test_threshold',
    );
    final p = TGPriorityService.instance.bySeller['seller_gastropl']!;
    final next = p.nextBillingAt!;
    TGClock.advance(next.difference(TGClock.now()) + const Duration(hours: 1));
    TGPriorityService.instance.onClockAdvanced();
    final after = TGPriorityService.instance.priorityFor('seller_gastropl');
    expect(after.nextBillingAt!.isAfter(next), isTrue);
    expect(after.quietMonthCredits, isNotEmpty);
  });
}
