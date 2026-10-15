import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/home_banner_service.dart';

import 'helpers/tg_test_app.dart';

void main() {
  setUp(HomeBannerService.instance.reset);

  test('kDisableDynamicListingImages stays locked', () {
    expect(TGListingImages.kDisableDynamicListingImages, isTrue);
  });

  test('EuroGastro banner JSON shape and staff-only save', () {
    final cms = HomeBannerService.instance;
    final seed = cms.byId('banner_eurogastro_2027')!;
    expect(seed.toJson(), {
      'id': 'banner_eurogastro_2027',
      'title': '',
      'subtitle': '',
      'imageUrl': TGListingImages.heroSlide(0),
      'buttonText': '',
      'targetUrl': '/birinciReklamSayfasi',
      'order': 1,
      'isActive': true,
    });

    final seller = FakeAuthState(isLoggedIn: true);
    expect(
      cms.save(actor: seller, banner: seed.copyWith(title: 'Nope')),
      'adm_err_staff',
    );
    expect(cms.byId('banner_eurogastro_2027')!.title, isEmpty);

    final admin = FakeAuthState(isLoggedIn: true)..setRole(TGUserRole.admin);
    expect(cms.save(actor: admin, banner: seed.copyWith(title: 'EuroGastro 2027')), isNull);
    expect(cms.byId('banner_eurogastro_2027')!.title, 'EuroGastro 2027');

    final mod = FakeAuthState(isLoggedIn: true)..setRole(TGUserRole.moderator);
    expect(cms.save(actor: mod, banner: seed.copyWith(subtitle: 'Trade visitors')), isNull);
    expect(cms.byId('banner_eurogastro_2027')!.subtitle, 'Trade visitors');
  });

  test('banner edit copy exists in TR, PL and EN', () {
    for (final key in [
      'ui_banner_edit',
      'ui_banner_edit_dialog',
      'ui_banner_subtitle',
      'ui_banner_image',
      'ui_banner_cta',
      'ui_banner_target',
      'ui_banner_edit_sem',
    ]) {
      final row = kUiTranslations[key]!;
      expect(row['en'], isNotEmpty, reason: key);
      expect(row['pl'], isNotEmpty, reason: key);
      expect(row['tr'], isNotEmpty, reason: key);
      expect(row['pl'], isNot(row['en']), reason: key);
      expect(row['tr'], isNot(row['en']), reason: key);
    }
  });

  testWidgets('visitors and sellers do not see the banner edit control', (tester) async {
    final app = await pumpTgApp(tester, location: '/', size: TGSizes.desktop);
    expect(find.byKey(const Key('hero-slide-BirinciReklamSayfasi')), findsOneWidget);
    expect(find.byKey(const Key('home-banner-edit-banner_eurogastro_2027')), findsNothing);
    expect(find.text('Edit banner'), findsNothing);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('admin can edit the EuroGastro banner and the slide updates', (tester) async {
    final app = await pumpTgApp(tester, location: '/', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.admin);
    await tester.pump();
    final edit = find.byKey(const Key('home-banner-edit-banner_eurogastro_2027'));
    expect(edit, findsOneWidget);
    expect(find.text('Edit banner'), findsOneWidget);
    await tester.tap(edit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Edit banner (staff)'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('home-banner-edit-title')), 'EuroGastro floor 2027');
    await tester.enterText(find.byKey(const Key('home-banner-edit-button')), 'Open the fair');
    await tester.tap(find.byKey(const Key('home-banner-edit-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('EuroGastro floor 2027'), findsWidgets);
    expect(find.text('Open the fair'), findsOneWidget);
    expect(HomeBannerService.instance.byId('banner_eurogastro_2027')!.title, 'EuroGastro floor 2027');
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('moderator sees the banner edit control', (tester) async {
    final app = await pumpTgApp(tester, location: '/', size: TGSizes.desktop);
    app.auth.setRole(TGUserRole.moderator);
    await tester.pump();
    expect(find.byKey(const Key('home-banner-edit-banner_eurogastro_2027')), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });
}
