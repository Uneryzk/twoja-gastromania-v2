import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/account_capabilities.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_models/tg_growth.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/referral_repository.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TGAnalytics.reset();
    TGClock.reset();
    TGRevenueConfigService.instance.reset();
    ReferralRepository.instance.reset();
    TGBillingService.instance.reset();
  });

  tearDown(() {
    TGRevenueConfigService.instance.reset();
    ReferralRepository.instance.reset();
    TGBillingService.instance.reset();
    TGClock.reset();
  });

  group('code', () {
    test('normalises Polish letters and is case-insensitive', () {
      expect(ReferralRepository.foldCode('Łukasz-IND2026'), 'Lukasz-IND2026');
      expect(ReferralRepository.codeKey('Marek-IND2026'), ReferralRepository.codeKey('marek-ind2026'));
      expect(ReferralRepository.isValidShape('Marek-IND2026'), isTrue);
      expect(ReferralRepository.isValidShape('abc'), isFalse);
      expect(ReferralRepository.isValidShape('x' * 25), isFalse);
    });

    test('uniqueness is case-insensitive', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      expect(repo.isCodeTaken('marek-ind2026'), isTrue);
      expect(repo.isCodeTaken('Piotr-CORP2026'), isTrue);
    });

    test('invalid and passive codes return a neutral unrecognized result', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      repo.debugAddRep(TGRepresentative(
        id: 'rep_old',
        userId: 'rep_old',
        displayName: 'Old',
        role: TGRepRole.individualPortfolio,
        code: 'Old-IND2020',
        status: TGRepStatus.inactive,
        createdAt: DateTime(2020),
      ));
      expect(repo.checkCode('nope').result, TGReferralCodeResult.unrecognized);
      expect(repo.checkCode('Old-IND2020').result, TGReferralCodeResult.unrecognized);
      expect(repo.checkCode('Marek-IND2026').result, TGReferralCodeResult.valid);
      expect(repo.checkCode('Marek-IND2026').firstName, 'Marek');
      expect(TGAnalytics.has('referral_code_entered'), isTrue);
    });

    test('passive code keeps an existing assignment', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      repo.debugAddRep(TGRepresentative(
        id: 'rep_old',
        userId: 'rep_old',
        displayName: 'Old',
        role: TGRepRole.individualPortfolio,
        code: 'Old-IND2020',
        status: TGRepStatus.inactive,
        createdAt: DateTime(2020),
      ));
      repo.debugAddAccount(TGReferredAccount(
        userId: 'kept',
        displayName: 'Kept User',
        segment: TGReferralSegment.individual,
        referredByCode: 'Old-IND2020',
        referredByRepId: 'rep_old',
        referredAt: DateTime(2021),
        referralConsentAt: DateTime(2021),
      ));
      expect(repo.accountOf('kept')?.referredByRepId, 'rep_old');
      expect(repo.checkCode('Old-IND2020').result, TGReferralCodeResult.unrecognized);
    });
  });

  group('signup', () {
    test('code is not applied without consent', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      repo.setSessionCode('Marek-IND2026');
      repo.setSessionConsent(false);
      expect(
        repo.applySessionOnSignup(userId: 'u1', displayName: 'Ada L.', segment: TGReferralSegment.individual, accountCreatedThisSession: true),
        isNull,
      );
      expect(repo.accountOf('u1'), isNull);
    });

    test('self-referral by email, phone or own account is blocked', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      repo.setSessionCode('Marek-IND2026');
      repo.setSessionConsent(true);
      expect(
        repo.applySessionOnSignup(userId: 'rep_marek', displayName: 'Marek', segment: TGReferralSegment.individual, accountCreatedThisSession: true),
        isNull,
      );
      repo.setSessionCode('Marek-IND2026');
      repo.setSessionConsent(true);
      expect(
        repo.applySessionOnSignup(
          userId: 'other',
          displayName: 'X',
          segment: TGReferralSegment.individual,
          email: 'marek.rep@example.com',
          accountCreatedThisSession: true,
        ),
        isNull,
      );
      repo.setSessionCode('Marek-IND2026');
      repo.setSessionConsent(true);
      expect(
        repo.applySessionOnSignup(
          userId: 'other2',
          displayName: 'Y',
          segment: TGReferralSegment.individual,
          phone: '+48100100100',
          accountCreatedThisSession: true,
        ),
        isNull,
      );
    });

    test('referredBy is pinned at signup and admin correction is audited', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      repo.setSessionCode('Marek-IND2026');
      repo.setSessionConsent(true);
      final acc = repo.applySessionOnSignup(userId: 'pin', displayName: 'Ada Nowak', segment: TGReferralSegment.individual, accountCreatedThisSession: true);
      expect(acc?.referredByRepId, 'rep_marek');
      expect(acc?.referredByCode, 'Marek-IND2026');
      expect(TGAnalytics.has('referral_signup_success'), isTrue);

      final firstAt = acc!.referredAt;
      expect(
        repo.adminCorrectReferral(userId: 'pin', actorId: 'staff_admin', reason: '', newCode: 'Piotr-CORP2026'),
        'reason_required',
      );
      expect(repo.adminCorrectReferral(userId: 'pin', actorId: 'staff_admin', reason: 'typo', newCode: 'Piotr-CORP2026'), isNull);
      expect(repo.accountOf('pin')!.referredByRepId, 'rep_piotr');
      expect(repo.accountOf('pin')!.referredAt, firstAt);
      expect(repo.audit.any((a) => a.action == 'referral_admin_correct' && a.reason == 'typo'), isTrue);
    });

    test('existing user in register mode cannot change assignment with another code', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      repo.setSessionCode('Marek-IND2026');
      repo.setSessionConsent(true);
      final first = repo.applySessionOnSignup(
        userId: 'exist',
        displayName: 'Exist U.',
        segment: TGReferralSegment.individual,
        accountCreatedThisSession: true,
      );
      expect(first?.referredByRepId, 'rep_marek');
      expect(first?.referralConsentAt, isNotNull);

      repo.setSessionCode('Piotr-CORP2026');
      repo.setSessionConsent(true);
      expect(
        repo.applySessionOnSignup(
          userId: 'exist',
          displayName: 'Exist U.',
          segment: TGReferralSegment.individual,
          accountCreatedThisSession: true,
        ),
        isNull,
      );
      expect(repo.accountOf('exist')!.referredByRepId, 'rep_marek');
      expect(repo.accountOf('exist')!.referredByCode, 'Marek-IND2026');

      repo.setSessionCode('Piotr-CORP2026');
      repo.setSessionConsent(true);
      expect(
        repo.applySessionOnSignup(userId: 'exist', displayName: 'Exist U.', segment: TGReferralSegment.individual),
        isNull,
      );
      expect(repo.accountOf('exist')!.referredByRepId, 'rep_marek');
    });

    test('signup without a code cannot attach one later', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      expect(
        repo.applySessionOnSignup(
          userId: 'late',
          displayName: 'Late U.',
          segment: TGReferralSegment.individual,
          accountCreatedThisSession: true,
        ),
        isNull,
      );
      expect(repo.accountOf('late'), isNull);
      expect(repo.isSignupLocked('late'), isTrue);

      repo.setSessionCode('Marek-IND2026');
      repo.setSessionConsent(true);
      expect(
        repo.applySessionOnSignup(
          userId: 'late',
          displayName: 'Late U.',
          segment: TGReferralSegment.individual,
          accountCreatedThisSession: true,
        ),
        isNull,
      );
      expect(repo.accountOf('late'), isNull);
      expect(repo.checkCode('Marek-IND2026', applicantUserId: 'late').result, TGReferralCodeResult.signupOnly);
    });

    test('only adminCorrectReferral mutates assignment and rejects an empty reason', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      repo.setSessionCode('Marek-IND2026');
      repo.setSessionConsent(true);
      final acc = repo.applySessionOnSignup(
        userId: 'only_admin',
        displayName: 'Ada',
        segment: TGReferralSegment.individual,
        accountCreatedThisSession: true,
      );
      expect(acc?.referredByRepId, 'rep_marek');

      repo.setSessionCode('Piotr-CORP2026');
      repo.setSessionConsent(true);
      repo.applySessionOnSignup(
        userId: 'only_admin',
        displayName: 'Ada',
        segment: TGReferralSegment.individual,
        accountCreatedThisSession: true,
      );
      expect(repo.accountOf('only_admin')!.referredByRepId, 'rep_marek');

      expect(
        repo.adminCorrectReferral(userId: 'only_admin', actorId: 'staff_admin', reason: '', newCode: 'Piotr-CORP2026'),
        'reason_required',
      );
      expect(repo.accountOf('only_admin')!.referredByRepId, 'rep_marek');
      expect(
        repo.adminCorrectReferral(userId: 'only_admin', actorId: 'staff_admin', reason: 'correction', newCode: 'Piotr-CORP2026'),
        isNull,
      );
      expect(repo.accountOf('only_admin')!.referredByRepId, 'rep_piotr');
      expect(repo.audit.any((a) => a.action == 'referral_admin_correct' && a.reason == 'correction'), isTrue);
    });

    test('new account with consent and a valid code writes assignment', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      repo.setSessionCode('Marek-IND2026');
      repo.setSessionConsent(true);
      final acc = repo.applySessionOnSignup(
        userId: 'fresh_ok',
        displayName: 'Fresh Ok',
        segment: TGReferralSegment.individual,
        accountCreatedThisSession: true,
      );
      expect(acc, isNotNull);
      expect(acc!.referredByRepId, 'rep_marek');
      expect(acc.referredByCode, 'Marek-IND2026');
      expect(acc.referralConsentAt, isNotNull);
      expect(acc.referredAt, isNotNull);
      expect(repo.accountOf('fresh_ok')!.referredByRepId, 'rep_marek');
    });
  });

  group('isolation', () {
    test('representative sees only own visible sellers; no phone/email on rows', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      final mine = repo.sellersFor('rep_marek');
      expect(mine.map((s) => s.userId), isNot(contains('ref_hidden')));
      expect(mine, isNotEmpty);
      expect(repo.sellersFor('rep_piotr'), isEmpty);
      expect(repo.withdrawnCountFor('rep_marek'), 1);
      for (final row in mine) {
        final json = row.toJson();
        expect(json.containsKey('phone'), isFalse);
        expect(json.containsKey('email'), isFalse);
        expect(json.containsKey('address'), isFalse);
        expect(json.containsKey('attributedNetGrosz'), isTrue);
        expect(json.containsKey('attributedNetPln'), isFalse);
        expect(row.attributedNetGrosz == null || row.attributedNetGrosz is int, isTrue);
      }
    });

    test('withdrawn seller has no detail row', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      expect(repo.sellersFor('rep_marek').any((s) => s.userId == 'ref_hidden'), isFalse);
      expect(repo.funnelFor('rep_marek').withdrawnCount, greaterThan(0));
    });

    test('report is not enough when coverage is under 7 days', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      repo.debugAddAccount(TGReferredAccount(
        userId: 'fresh',
        displayName: 'Fresh K.',
        segment: TGReferralSegment.individual,
        referredByCode: 'Marek-IND2026',
        referredByRepId: 'rep_marek',
        referredAt: TGClock.now(),
        referralConsentAt: TGClock.now(),
        listings: const [TGRefListingMeta(id: 'fresh_l', title: 'X', listingNo: '1', photos: 3, completionPct: 80)],
      ));
      final report = repo.createReport(repId: 'rep_marek', sellerUserId: 'fresh', periodDays: 30, actorId: 'rep_marek');
      expect(report, isNotNull);
      expect(report!.views.state, TGRepMetricState.notEnough);
      expect(report.listingCount.state, TGRepMetricState.notEnough);
    });

    test('share link expires and revoke is audited', () {
      final repo = ReferralRepository.instance..ensureSeeded();
      final report = repo.createReport(repId: 'rep_marek', sellerUserId: 'ref_jan', periodDays: 30, actorId: 'rep_marek')!;
      final link = repo.createShareLink(reportId: report.id, actorId: 'rep_marek')!;
      expect(link.token.length, 32);
      expect(repo.openShareLink(link.token), isNotNull);
      expect(repo.revokeShareLink(token: link.token, actorId: 'rep_marek'), isTrue);
      expect(repo.openShareLink(link.token), isNull);
      expect(TGAnalytics.has('rep_report_created'), isTrue);
      expect(TGAnalytics.has('rep_report_link_revoked'), isTrue);

      final live = repo.createShareLink(reportId: report.id, actorId: 'rep_marek')!;
      TGClock.advance(Duration(days: repo.config.shareLinkDays + 1));
      expect(repo.openShareLink(live.token), isNull);
    });
  });

  group('production & auth', () {
    test('Production Mode hides mock representatives', () {
      ReferralRepository.instance.ensureSeeded();
      expect(ReferralRepository.instance.profileForUser('rep_marek'), isNotNull);
      TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 'test');
      ReferralRepository.instance.reset();
      ReferralRepository.instance.ensureSeeded();
      expect(ReferralRepository.instance.profileForUser('rep_marek'), isNull);
      expect(ReferralRepository.instance.sellersFor('rep_marek'), isEmpty);
    });

    test('Production Mode blocks debugAddAccount and seed referral writes', () {
      TGRevenueConfigService.instance.setProductionMode(true, actorId: 't', reason: 'test');
      final repo = ReferralRepository.instance;
      repo.ensureSeeded();
      expect(repo.profileForUser('rep_marek'), isNull);
      expect(repo.accountOf('ref_jan'), isNull);
      repo.debugAddAccount(TGReferredAccount(
        userId: 'prod_block',
        displayName: 'Blocked',
        segment: TGReferralSegment.individual,
        referredByCode: 'Marek-IND2026',
        referredByRepId: 'rep_marek',
        referredAt: DateTime(2026),
        referralConsentAt: DateTime(2026),
      ));
      expect(repo.accountOf('prod_block'), isNull);
      expect(repo.isSignupLocked('prod_block'), isFalse);
    });

    testWidgets('non-representative gets 403 on /dashboard/representative', (tester) async {
      await pumpTgApp(tester, location: '/dashboard/representative', size: TGSizes.desktop);
      expect(find.byKey(const Key('rep-403')), findsOneWidget);
    });

    testWidgets('representative can open the panel', (tester) async {
      final app = await pumpTgApp(tester, location: '/dashboard', size: TGSizes.desktop);
      app.auth.actAsRepresentative(RepresentativeDevPick.marek);
      app.router.go('/dashboard/representative');
      await pumpFor(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const Key('rep-403')), findsNothing);
      expect(find.byKey(const Key('rep-page')), findsOneWidget);
      expect(AccountCapabilities.of(app.auth).isRepresentative, isTrue);
    });
  });

  test('attributed net is integer grosz and formats pl-PL', () {
    final repo = ReferralRepository.instance..ensureSeeded();
    final paid = TGBillingService.instance.recordPayment(
      userId: 'ref_jan',
      kind: TGPaymentKind.listing,
      description: 'listing',
      grossPln: 123,
      at: TGClock.now(),
    );
    final net = repo.attributedNetGrosz('ref_jan');
    expect(net, isNotNull);
    expect(net, paid.amount.netGr);
    expect(net, 10000);
    expect(GrowthMoney.format(net!), '100,00 PLN');
  });

  test('individual public name uses initial', () {
    expect(ReferralRepository.publicDisplayName('Jan Nowak', TGReferralSegment.individual), 'Jan N.');
    expect(ReferralRepository.publicDisplayName('GastroLab', TGReferralSegment.store), 'GastroLab');
  });
}
