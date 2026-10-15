import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/features/magazine/presentation/pages/tg_editorial_magazine_view.dart';
import 'package:twoja_gastromania/features/magazine/presentation/pages/tg_magazine_article_view.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/journal/tg_journal_charts.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

import 'helpers/tg_test_app.dart';

void main() {
  test('kDisableDynamicListingImages stays locked', () {
    expect(TGListingImages.kDisableDynamicListingImages, isTrue);
  });

  test('journal metrics: CapEx/OpEx mix, 32% A-class, used payback 14 vs 36', () {
    expect(TGJournalMetrics.capex + TGJournalMetrics.opexEnergy + TGJournalMetrics.opexService, closeTo(1, 1e-9));
    expect(TGJournalMetrics.aClassSaving, 0.32);
    expect(TGJournalMetrics.usedPaybackMonths, 14);
    expect(TGJournalMetrics.newPaybackMonths, 36);
  });

  test('magazine ROI defaults: 28% save, 24k kit, 5k bill, EuroGastro 2027 mix', () {
    expect(TGMagazineMetrics.savingsRate, 0.28);
    expect(TGMagazineMetrics.equipmentCostPln, 24000);
    expect(TGMagazineMetrics.defaultBillPln, 5000);
    expect(TGMagazineMetrics.year, 2027);
    expect(TGMagazineMetrics.edition, 30);
    expect(TGMagazineMetrics.cateringSharePct, 32.3);
    expect(TGMagazineMetrics.foodSharePct, 20.2);
    expect(TGMagazineMetrics.techSharePct, 11.3);
    expect(TGMagazineMetrics.exhibitors, 550);
    expect(TGMagazineMetrics.visitors, 26000);
    expect(TGMagazineMetrics.areaM2, 50000);
    expect(TGMagazineMetrics.halls, 6);
    expect(TGMagazineMetrics.mixKitFlex, 32);
    expect(TGMagazineMetrics.mixFoodFlex, 20);
    expect(TGMagazineMetrics.mixTechFlex, 11);
    expect(TGMagazineMetrics.mixOtherFlex, 37);
  });

  test('ROI contrast inverts with brightness', () {
    final light = TGEditorialRoiContrast.of(Brightness.light);
    final dark = TGEditorialRoiContrast.of(Brightness.dark);
    expect(light.box, TGEditorialRoiContrast.charcoal);
    expect(dark.box, TGEditorialRoiContrast.cream);
    expect(light.text, Colors.white);
    expect(dark.text, TGEditorialRoiContrast.ink);
  });

  test('journal copy exists in TR, PL and EN', () {
    for (final key in [
      'journal_title',
      'journal_dek',
      'journal_p1',
      'journal_p2',
      'journal_p3',
      'journal_chart1_title',
      'journal_chart2_title',
      'journal_chart3_title',
      'mag_brand',
      'mag_badge',
      'mag_lead',
      'mag_chart1_title',
      'mag_chart2_title',
      'mag_roi_title',
      'mag_source',
      'mag_editorial_p1',
      'mag_editorial_p2',
      'mag_balance_title',
      'mag_stat_catering',
      'mag_stat_food',
      'mag_stat_tech',
      'mag_fair_p1',
      'mag_fair_p2',
      'mag_fair_headline',
    ]) {
      final row = kUiTranslations[key]!;
      expect(row['en'], isNotEmpty, reason: key);
      expect(row['pl'], isNotEmpty, reason: key);
      expect(row['tr'], isNotEmpty, reason: key);
      expect(row['pl'], isNot(row['en']), reason: key);
      expect(row['tr'], isNot(row['en']), reason: key);
    }
    expect(kUiTranslations['journal_title']!['tr'], 'Geleceğin mutfağı: EuroGastro 2027 ile büyük giriş');
    expect(kUiTranslations['mag_badge']!['en'], contains('EuroGastro 2027'));
    expect(kUiTranslations['mag_source']!['en'], contains('Ptak Warsaw Expo'));
  });

  testWidgets('home hero advertises the journal article', (tester) async {
    final app = await pumpTgApp(tester, location: '/', size: TGSizes.desktop);
    expect(find.byKey(const Key('hero-slide-BirinciReklamSayfasi')), findsOneWidget);
    expect(find.text('The kitchen of the future: the EuroGastro 2027 opening'), findsWidgets);
    expect(find.text('Read more'), findsWidgets);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('editorial magazine renders cover, two columns, circles and contrast ROI', (tester) async {
    final app = await pumpTgApp(tester, location: '/birinciReklamSayfasi', size: TGSizes.desktop);
    expect(find.byKey(const Key('journal-article')), findsOneWidget);
    expect(find.byType(TgEditorialMagazineView), findsOneWidget);
    expect(find.text('The kitchen of the future: the EuroGastro 2027 opening'), findsWidgets);
    expect(find.byKey(const Key('magazine-fair-banner')), findsOneWidget);
    expect(find.byKey(const Key('magazine-photo-cover')), findsOneWidget);
    expect(find.byKey(const Key('magazine-fair-mix')), findsOneWidget);
    expect(find.text('550+'), findsOneWidget);
    expect(find.text('26,000+'), findsOneWidget);
    expect(find.text('50,000 m²'), findsOneWidget);
    expect(find.byKey(const Key('journal-chart-capex')), findsOneWidget);
    expect(find.byKey(const Key('magazine-stat-catering')), findsOneWidget);
    expect(find.byKey(const Key('magazine-stat-food')), findsOneWidget);
    expect(find.byKey(const Key('magazine-stat-tech')), findsOneWidget);
    expect(find.byKey(const Key('journal-chart-roi')), findsOneWidget);
    expect(find.byKey(const Key('magazine-roi-slider')), findsOneWidget);
    expect(find.byKey(const Key('magazine-roi-contrast')), findsOneWidget);
    expect(find.textContaining('1400'), findsWidgets);
    expect(find.text('This advertising page will be active soon!'), findsNothing);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('journal article follows TR locale', (tester) async {
    final app = await pumpTgApp(tester, location: '/birinciReklamSayfasi', locale: const Locale('tr'), size: TGSizes.desktop);
    expect(find.text('Geleceğin mutfağı: EuroGastro 2027 ile büyük giriş'), findsWidgets);
    expect(find.text('B2B dergi'), findsWidgets);
    expect(find.text('Canlı fuar ROI ve amortisman hesaplayıcı'), findsOneWidget);
    expect(find.byKey(const Key('journal-chart-capex')), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('journal article follows PL locale', (tester) async {
    final app = await pumpTgApp(tester, location: '/birinciReklamSayfasi', locale: const Locale('pl'), size: TGSizes.phone);
    expect(find.text('Kuchnia przyszłości: wejście z EuroGastro 2027'), findsWidgets);
    expect(find.text('Magazyn B2B'), findsWidgets);
    expect(find.byKey(const Key('journal-chart-roi')), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('ROI slider updates savings and payback', (tester) async {
    final app = await pumpTgApp(tester, location: '/magazine/article', size: const Size(1440, 1800));
    expect(find.byKey(const Key('magazine-roi-savings')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('magazine-roi-slider')));
    await tester.drag(find.byKey(const Key('magazine-roi-slider')), const Offset(280, 0));
    await tester.pump();
    final savings = tester.widget<Text>(find.byKey(const Key('magazine-roi-savings'))).data ?? '';
    expect(savings.contains('1400'), isFalse);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('light theme uses a dark ROI box; dark theme uses a cream ROI box', (tester) async {
    final light = await pumpTgApp(
      tester,
      location: '/birinciReklamSayfasi',
      size: TGSizes.phone,
      themeMode: ThemeMode.light,
    );
    expect(find.byType(TgEditorialMagazineView), findsOneWidget);
    final lightBox = tester.widget<Container>(find.byKey(const Key('journal-chart-roi')));
    expect((lightBox.decoration! as BoxDecoration).color, TGEditorialRoiContrast.charcoal);
    expect(TGColors.background, TGPalette.light.background);
    light.errors.stop();
    expect(light.errors.distinct, isEmpty, reason: light.errors.distinct.join('\n'));

    final dark = await pumpTgApp(
      tester,
      location: '/birinciReklamSayfasi',
      size: TGSizes.phone,
      themeMode: ThemeMode.dark,
    );
    final darkBox = tester.widget<Container>(find.byKey(const Key('journal-chart-roi')));
    expect((darkBox.decoration! as BoxDecoration).color, TGEditorialRoiContrast.cream);
    dark.errors.stop();
    expect(dark.errors.distinct, isEmpty, reason: dark.errors.distinct.join('\n'));
  });
}
