import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:twoja_gastromania/tg_services/special_review_service.dart';
import 'package:twoja_gastromania/tg_services/sponsor_slot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TGClock.reset();
    TGSellerProfileService.instance.reset();
    TGRevenueConfigService.instance.reset();
    TGSpecialOrderService.instance.reset();
    TGSpecialReviewService.instance.reset();
    TGSponsorSlotService.instance.reset();
  });

  test('special reviews seed covers states and counted summaries', () {
    final svc = TGSpecialReviewService.instance..ensureSeeded();
    expect(svc.reviews.length, greaterThanOrEqualTo(6));
    expect(svc.reviews.any((r) => r.state == TGPurchaseReviewState.suspendedObjection), isTrue);
    expect(svc.objections, isNotEmpty);
    expect(svc.evidence, isNotEmpty);
    final gastro = svc.summaryFor('seller_gastropl');
    expect(gastro.countedCount, greaterThanOrEqualTo(3));
    expect(gastro.displayLine, contains('Custom projects'));
    expect(svc.summaryFor('seller_metalgast').countedCount, 0); // pending_check does not count
  });

  test('completion mark opens review window rules', () {
    final so = TGSpecialOrderService.instance..ensureSeeded();
    TGSpecialReviewService.instance.ensureSeeded();
    // Fresh award not covered by seeded reviews
    final open = so.requests.firstWhere((r) => r.status == TGSpecialRequestStatus.open || r.status == TGSpecialRequestStatus.quoted);
    so.award(open.id, 'seller_rm');
    TGSpecialReviewService.instance.markCompleted(open.id, buyerId: open.buyerId);
    final updated = so.byId(open.id)!;
    expect(updated.completionStatus, TGProjectCompletionStatus.completed);
    expect(
      TGSpecialReviewService.instance.canSubmit(authorId: open.buyerId, requestId: open.id),
      isNull,
    );
  });

  test('sponsor slots: one active per segment, founder discount path', () {
    final svc = TGSponsorSlotService.instance..ensureSeeded();
    expect(svc.enabled, isTrue);
    expect(svc.slots.length, 4);
    final active = svc.activeFor(TGStoreSpecialty.extractionHoods, 'Śląskie');
    expect(active?.sellerId, 'seller_gastropl');
    expect(svc.sponsoredFor(specialty: TGStoreSpecialty.extractionHoods, region: 'Śląskie')?.sellerKey, 'seller_gastropl');
    expect(
      () => svc.purchase(
        sellerId: 'seller_inoxline',
        specialty: TGStoreSpecialty.extractionHoods,
        region: 'Śląskie',
        startsAt: TGClock.now(),
        durationDays: 7,
        title: 'Dup',
        imageUrl: 'x',
      ),
      throwsStateError,
    );
  });

  test('day-30 prompt and 5-day silence via clock', () {
    final so = TGSpecialOrderService.instance..ensureSeeded();
    final rev = TGSpecialReviewService.instance..ensureSeeded();
    final awaiting = rev.reviews.firstWhere((r) => r.state == TGPurchaseReviewState.awaitingSeller);
    // Force due
    awaiting.sellerAnswerDueAt = TGClock.now().subtract(const Duration(hours: 1));
    rev.onClockAdvanced();
    expect(rev.byId(awaiting.id)!.state, TGPurchaseReviewState.notDisputed);

    // Award fresh and advance 30d
    final open = so.requests.firstWhere((r) => r.status == TGSpecialRequestStatus.open || r.status == TGSpecialRequestStatus.quoted);
    so.award(open.id, 'seller_stalbar');
    TGClock.advance(const Duration(days: 30));
    so.onClockAdvanced();
    expect(so.byId(open.id)!.status, TGSpecialRequestStatus.awarded);
  });
}
