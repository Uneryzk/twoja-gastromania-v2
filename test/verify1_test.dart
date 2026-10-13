import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/products/products_logic.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_components/tg_badges.dart';
import 'package:twoja_gastromania/tg_core/tg_verified_seller.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_models/tg_review_verified.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/review_verified_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

import 'helpers/tg_test_app.dart';

TGSeller _ind(String id) => TGReviewVerifiedService.mockSellers.firstWhere((s) => s.id == id);

void main() {
  late TGReviewVerifiedService svc;
  List<Map<String, Object?>> ev(String name) => [for (final e in TGAnalytics.events) if (e.$1 == name) e.$2];

  setUp(() {
    TGClock.reset();
    TGRevenueConfigService.instance.reset();
    ModerationService.instance.reset();
    DealService.instance.reset();
    TGSellerProfileService.instance.reset();
    svc = TGReviewVerifiedService.instance..reset();
    NotificationService.instance.reset();
    TGAnalytics.reset();
  });

  group('config & model', () {
    test('ReviewVerifiedConfig defaults', () {
      const c = ReviewVerifiedConfig();
      expect(c.toJson(), {
        'enabled': true,
        'appliesTo': ['individual'],
        'minCountedReviews': 5,
        'minDistinctBuyers': 5,
        'maxNegativeShare': 0.10,
        'negativeStarsMax': 2,
        'windowMonths': 12,
        'minAccountAgeDays': 30,
        'requirePhoneVerified': true,
        'blockedAfterUpheldReportDays': 90,
      });
      expect(ReviewVerifiedConfig.fromJson(c.toJson()).toJson(), c.toJson());
    });

    test('TGSeller carries verifiedBasis / verifiedSince / reviewStats through JSON', () {
      final s = TGSeller(
        id: 'x',
        name: 'X',
        type: TGSellerType.private,
        verified: false,
        rating: 4,
        verifiedBasis: TGVerifiedBasis.buyerReviews,
        verifiedSince: DateTime.utc(2026, 1, 2),
        reviewStats: TGReviewStats(counted: 14, negatives: 1, distinctBuyers: 12, computedAt: DateTime.utc(2026, 1, 3)),
      );
      final j = s.toJson();
      expect(j['verifiedBasis'], 'buyer_reviews');
      expect((j['reviewStats'] as Map)['negativeShare'], closeTo(1 / 14, 1e-9));
      final back = TGSeller.fromJson(j);
      expect(back.verifiedBasis, TGVerifiedBasis.buyerReviews);
      expect(back.verifiedSince, DateTime.utc(2026, 1, 2));
      expect(back.reviewStats!.counted, 14);
      expect(TGVerifiedBasisWire.fromWire('company_registry'), TGVerifiedBasis.companyRegistry);
      expect(TGVerifiedBasisWire.fromWire(null), isNull);
    });

    test('only confirmed / confirmed_moderator / not_disputed reviews are counted', () {
      svc.ensureSeeded();
      // Tomek: 5 counted + 1 awaiting + 1 outside the 12-month window.
      expect(svc.statsFor('seller_ind_tomek').counted, 5);
      // Bartek: suspended and removed reviews are ignored.
      expect(svc.statsFor('seller_ind_bartek').counted, 14);
      for (final st in TGPurchaseReviewState.values) {
        svc.addMockReview('seller_ind_ola', rating: 5, state: st);
      }
      expect(svc.statsFor('seller_ind_ola').counted, 8 + 3);
    });
  });

  group('mock sellers', () {
    test('2 earned, 2 borderline (one exactly 10 %), 1 revoked for negatives', () {
      svc.ensureSeeded();
      expect(svc.isVerified('seller_ind_ola'), isTrue);
      expect(svc.isVerified('seller_ind_bartek'), isTrue);
      final bartek = svc.statsFor('seller_ind_bartek');
      expect((bartek.counted, bartek.negatives, bartek.negativePercent), (14, 1, 7));

      final kasia = svc.statsFor('seller_ind_kasia');
      expect(kasia.negativeShare, 0.10);
      expect(svc.isVerified('seller_ind_kasia'), isTrue);
      expect(svc.statsFor('seller_ind_tomek').counted, svc.config.minCountedReviews);
      expect(svc.isVerified('seller_ind_tomek'), isTrue);

      expect(svc.isVerified('seller_ind_marta'), isFalse);
      expect(svc.requirements('seller_ind_marta').firstWhere((r) => !r.met).id, 'negatives');
      expect(ev('verified_revoked').single['sellerId'], 'seller_ind_marta');
      expect(NotificationService.instance.items.where((n) => n.userId == 'seller_ind_marta' && n.type == 'verified_revoked'), hasLength(1));
    });

    test('mocks are off in production mode', () {
      TGRevenueConfigService.instance.setProductionMode(true, actorId: 'test', reason: 'test');
      svc.ensureSeeded();
      expect(svc.isVerified('seller_ind_ola'), isFalse);
      expect(svc.trackedSellerIds.any((id) => id.startsWith('seller_ind_')), isFalse);
    });
  });

  group('lifecycle', () {
    test('badge is removed instantly when criteria break and restored automatically', () {
      svc.ensureSeeded();
      expect(svc.isVerified('seller_ind_kasia'), isTrue);
      svc.addMockReview('seller_ind_kasia', rating: 1, authorId: 'b-new-1');
      expect(svc.isVerified('seller_ind_kasia'), isFalse);
      expect(ev('verified_revoked').last['sellerId'], 'seller_ind_kasia');
      expect(NotificationService.instance.forUser('seller_ind_kasia').map((n) => n.type), contains('verified_revoked'));
      expect(kUiTranslations['notif_verified_revoked_body']!['en'], contains('returns automatically'));

      for (var i = 0; i < 9; i++) {
        svc.addMockReview('seller_ind_kasia', rating: 5, authorId: 'b-good-$i');
      }
      expect(svc.isVerified('seller_ind_kasia'), isTrue);
      expect(ev('verified_earned').last['sellerId'], 'seller_ind_kasia');
      expect(svc.verifiedSince('seller_ind_kasia'), isNotNull);
    });

    test('daily run re-evaluates (window expiry, account age, upheld report)', () {
      svc.ensureSeeded();
      svc.recordUpheldReport('seller_ind_ola');
      expect(svc.isVerified('seller_ind_ola'), isFalse);
      TGClock.advance(const Duration(days: 91));
      svc.onClockAdvanced();
      expect(svc.isVerified('seller_ind_ola'), isTrue);
    });

    test('review changes in DealService trigger evaluation', () {
      svc.ensureSeeded();
      final before = ev('verified_earned').length;
      svc.setOverride('seller_ind_tomek', verified: false, reason: 'test', actorId: 'admin');
      svc.setOverride('seller_ind_tomek', verified: null, reason: 'restore', actorId: 'admin');
      DealService.instance.reset();
      expect(svc.isVerified('seller_ind_tomek'), isTrue);
      expect(ev('verified_earned').length, greaterThan(before));
    });
  });

  group('admin', () {
    test('override works both ways, needs a reason and is audited', () {
      svc.ensureSeeded();
      expect(() => svc.setOverride('seller_ind_ola', verified: false, reason: '  ', actorId: 'admin'), throwsArgumentError);
      svc.setOverride('seller_ind_ola', verified: false, reason: 'Fraud check', actorId: 'admin');
      expect(svc.isVerified('seller_ind_ola'), isFalse);
      svc.setOverride('seller_ind_marta', verified: true, reason: 'Disputed reviews were spam', actorId: 'admin');
      expect(svc.isVerified('seller_ind_marta'), isTrue);
      final audit = ModerationService.instance.auditFor();
      expect(audit.where((a) => a.summary.contains('Verified override')).map((a) => a.reason), containsAll(['Fraud check', 'Disputed reviews were spam']));
      expect(ev('verified_admin_override'), hasLength(2));
    });

    test('config edits are applied, audited and re-evaluate', () {
      svc.ensureSeeded();
      svc.setConfig(svc.config.copyWith(minCountedReviews: 10), actorId: 'admin');
      expect(svc.isVerified('seller_ind_tomek'), isFalse);
      expect(ModerationService.instance.auditFor().any((a) => a.summary == 'Review-verified config updated'), isTrue);
      svc.setConfig(svc.config.copyWith(enabled: false), actorId: 'admin');
      expect(svc.isVerified('seller_ind_ola'), isFalse);
    });
  });

  group('basis & filters', () {
    test('stores stay company_registry; individuals buyer_reviews; legacy flag is ignored', () {
      svc.ensureSeeded();
      const store = TGSeller(id: 'seller_gastropl', name: 'G', type: TGSellerType.store, verified: true, rating: 4);
      expect(tgVerifiedBasis(store), TGVerifiedBasis.companyRegistry);
      expect(tgVerifiedBasis(_ind('seller_ind_ola')), TGVerifiedBasis.buyerReviews);
      // Private seller with the old static flag but no review basis.
      const legacy = TGSeller(id: 'seller_anna', name: 'A', type: TGSellerType.private, verified: true, rating: 4.6);
      expect(tgVerifiedBasis(legacy), isNull);
      // Store without registry basis can't use reviews.
      const unregistered = TGSeller(id: 'seller_nope', name: 'N', type: TGSellerType.store, verified: true, rating: 5);
      expect(tgVerifiedBasis(unregistered), isNull);
      final live = tgWithVerification(_ind('seller_ind_bartek'));
      expect(live.verifiedBasis, TGVerifiedBasis.buyerReviews);
      expect(live.reviewStats!.negatives, 1);
    });

    test('Verified filter covers both bases', () {
      svc.ensureSeeded();
      TGProduct p(String id, TGSeller s) => TGProduct.fromJson({
            'id': id,
            'title': id,
            'price': 100,
            'seller': s.toJson(),
            'status': 'active',
          });
      final all = [
        p('store', const TGSeller(id: 'seller_gastropl', name: 'G', type: TGSellerType.store, verified: true, rating: 4)),
        p('ind', _ind('seller_ind_ola')),
        p('lost', _ind('seller_ind_marta')),
        p('legacy', const TGSeller(id: 'seller_anna', name: 'A', type: TGSellerType.private, verified: true, rating: 4)),
      ];
      final ids = applyFilters(all, const TGProductsQueryState(verifiedOnly: true)).map((e) => e.id).toSet();
      expect(ids, {'store', 'ind'});
    });

    test('copy: stats line, not purchasable, FAQ', () {
      expect(kUiTranslations['ver_stats_line']!['en'], 'Based on {n} reviews, {neg} negative ({pct}%)');
      expect(kUiTranslations['ver_not_purchasable']!['tr'], 'Doğrulanmış rozeti satın alınamaz.');
      expect(kUiTranslations['ui_so_faq_a5']!['en'], contains("can't be bought"));
      expect(kUiTranslations['ui_so_faq_a5']!['en'], contains('buyer reviews'));
    });
  });

  group('dashboard', () {
    testWidgets('individual sees "Verified through reviews" with ✓/— checklist', (tester) async {
      final app = await pumpTgApp(tester, size: const Size(1280, 1400), location: '/dashboard/verification?seller=seller_ind_marta');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('ver-reviews-card')), findsOneWidget);
      expect(find.text('Verified through reviews'), findsOneWidget);
      expect(find.byKey(const Key('ver-status-off')), findsOneWidget);
      expect(find.text('Based on 12 reviews, 2 negative (17%)'), findsOneWidget);
      final neg = find.byKey(const Key('ver-req-negatives'));
      expect(find.descendant(of: neg, matching: find.text('—')), findsOneWidget);
      final counted = find.byKey(const Key('ver-req-counted'));
      expect(find.descendant(of: counted, matching: find.text('✓')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Not met: At most 10% negative')), findsOneWidget);
      expect(app.errors.distinct.where((e) => e.contains('overflowed')), isEmpty);
    });

    testWidgets('earned seller shows Verified on phone without overflow', (tester) async {
      final app = await pumpTgApp(tester, size: const Size(390, 844), textScale: 1.3, location: '/dashboard/verification?seller=seller_ind_bartek');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('ver-status-on')), findsOneWidget);
      expect(find.text('Based on 14 reviews, 1 negative (7%)'), findsOneWidget);
      expect(app.errors.distinct.where((e) => e.contains('overflowed') && e.contains('seller_verification_page')), isEmpty);
    });

    testWidgets('store sees the company registry card', (tester) async {
      await pumpTgApp(tester, size: const Size(1280, 1000), location: '/dashboard/verification?seller=seller_gastropl');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('ver-company-card')), findsOneWidget);
      expect(find.byKey(const Key('ver-reviews-card')), findsNothing);
    });
  });

  group('info box & admin UI', () {
    testWidgets('store badge opens the company-registry info box', (tester) async {
      final path = TGSellerProfileService.instance.pathForSellerId('seller_gastropl');
      final app = await pumpTgApp(tester, size: const Size(1280, 1600), location: path);
      await tester.pump(const Duration(milliseconds: 600));
      final badge = find.byType(TGVerifiedSellerBadge).first;
      await tester.ensureVisible(badge);
      await tester.tap(badge);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final box = find.byKey(const Key('verified-info-company_registry'));
      expect(box, findsWidgets);
      expect(TGAnalytics.events.any((e) => e.$1 == 'verified_info_open'), isTrue);
      expect(find.bySemanticsLabel(RegExp(r'^Verified company\.')), findsWidgets);
      expect(app.errors.distinct.where((e) => e.contains('tg_verified_info')), isEmpty);
    });

    testWidgets('admin override needs a reason, then is applied and audited', (tester) async {
      final app = await pumpTgApp(tester, location: '/admin/verified', size: const Size(1280, 1400));
      app.auth.setRole(TGUserRole.admin);
      await tester.pumpAndSettle();
      final grant = find.byKey(const Key('ver-admin-grant-seller_ind_marta'));
      await tester.ensureVisible(grant);
      await tester.tap(grant);
      await tester.pumpAndSettle();
      final apply = find.byKey(const Key('ver-admin-apply'));
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('ver-admin-reason')), 'Spam reviews removed');
      await tester.pump();
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(TGReviewVerifiedService.instance.isVerified('seller_ind_marta'), isTrue);
      expect(ModerationService.instance.auditFor().any((a) => a.reason == 'Spam reviews removed'), isTrue);
      expect(find.byKey(const Key('ver-admin-clear-seller_ind_marta')), findsOneWidget);
    });
  });
}
