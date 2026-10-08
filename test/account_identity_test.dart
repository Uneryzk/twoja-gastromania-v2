import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_company.dart';
import 'package:twoja_gastromania/tg_services/account_identity_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUp(() {
    TGAnalytics.reset();
    AccountIdentityService.instance.reset();
  });

  test('seed emails and phones are taken; a new pair is free', () {
    final ids = AccountIdentityService.instance..ensureSeeded();
    expect(ids.checkEmail('tg.demo@twojagastromania.pl'), isNotNull);
    expect(ids.checkEmail('TG.Demo@TwojaGastromania.pl'), isNotNull);
    expect(ids.checkPhone('+48 532 784 074'), isNotNull);
    expect(ids.checkPhone('532784074'), isNotNull);
    expect(ids.checkEmail('new.seller@example.com'), isNull);
    expect(ids.checkPhone('+48 511 000 111'), isNull);
  });

  testWidgets('sign-up with a taken e-mail shows the warning and report button', (tester) async {
    final app = await pumpTgApp(tester, location: '/login', signedIn: false);
    await tester.tap(find.byKey(const Key('login-toggle-mode')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-email')), 'tg.demo@twojagastromania.pl');
    await tester.enterText(find.byKey(const Key('login-password')), 'password');
    await tester.enterText(find.byKey(const Key('login-phone')), '511000111');
    await tester.tap(find.byKey(const Key('login-primary')));
    await tester.pump();
    expect(find.byKey(const Key('login-duplicate-notice')), findsOneWidget);
    expect(find.text('This phone number or e-mail address is already in use.'), findsOneWidget);
    expect(find.byKey(const Key('login-report-issue')), findsOneWidget);
    expect(app.auth.isLoggedIn, isFalse);
    expect(TGAnalytics.has('signup_blocked'), isTrue);
    _ok(app);
  });

  testWidgets('sign-up with a taken phone is blocked', (tester) async {
    final app = await pumpTgApp(tester, location: '/login', signedIn: false);
    await tester.tap(find.byKey(const Key('login-toggle-mode')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-email')), 'fresh.account@example.com');
    await tester.enterText(find.byKey(const Key('login-password')), 'password');
    await tester.enterText(find.byKey(const Key('login-phone')), '+48 601 222 111');
    await tester.tap(find.byKey(const Key('login-primary')));
    await tester.pump();
    expect(find.byKey(const Key('login-duplicate-notice')), findsOneWidget);
    expect(app.auth.isLoggedIn, isFalse);
    _ok(app);
  });

  testWidgets('Google sign-up is blocked when the account is already linked', (tester) async {
    final app = await pumpTgApp(tester, location: '/login', signedIn: false);
    await tester.tap(find.byKey(const Key('login-toggle-mode')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-google')));
    await tester.pump();
    expect(find.text('This Google account is already linked to a membership.'), findsOneWidget);
    expect(find.text('Report the issue to us'), findsOneWidget);
    expect(app.auth.isLoggedIn, isFalse);
    _ok(app);
  });

  testWidgets('report-the-issue opens a mailto to support', (tester) async {
    final app = await pumpTgApp(tester, location: '/login', signedIn: false);
    await tester.tap(find.byKey(const Key('login-toggle-mode')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-facebook')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-report-issue')));
    await tester.pump();
    expect(app.log.launchedUrls, isNotEmpty);
    expect(app.log.launchedUrls.last, contains('mailto:${TGCompany.email}'));
    expect(TGAnalytics.has('signup_issue_report'), isTrue);
    _ok(app);
  });

  testWidgets('a unique e-mail and phone can still sign up', (tester) async {
    final app = await pumpTgApp(tester, location: '/login', signedIn: false);
    await tester.tap(find.byKey(const Key('login-toggle-mode')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-email')), 'brand.new@example.com');
    await tester.enterText(find.byKey(const Key('login-password')), 'password');
    await tester.enterText(find.byKey(const Key('login-phone')), '511000222');
    await tester.tap(find.byKey(const Key('login-primary')));
    await tester.pump();
    expect(find.byKey(const Key('login-duplicate-notice')), findsNothing);
    expect(app.auth.isLoggedIn, isTrue);
    _ok(app);
  });
}

void _ok(TGApp app) {
  app.errors.stop();
  expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
}
