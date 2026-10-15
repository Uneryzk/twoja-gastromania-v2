import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('magazine ROI defaults: 28% save, 22k kit, 4.5k bill', () {
    expect(TGMagazineMetrics.savingsRate, 0.28);
    expect(TGMagazineMetrics.equipmentCostPln, 22000);
    expect(TGMagazineMetrics.defaultBillPln, 4500);
    expect(TGMagazineMetrics.traditionalCapex + TGMagazineMetrics.smartCapex, closeTo(1, 1e-9));
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
    ]) {
      final row = kUiTranslations[key]!;
      expect(row['en'], isNotEmpty, reason: key);
      expect(row['pl'], isNotEmpty, reason: key);
      expect(row['tr'], isNotEmpty, reason: key);
      expect(row['pl'], isNot(row['en']), reason: key);
      expect(row['tr'], isNot(row['en']), reason: key);
    }
    expect(kUiTranslations['journal_title']!['tr'], 'Endüstriyel Mutfak Maliyetleri ve Kârlılık');
  });

  testWidgets('home hero advertises the journal article', (tester) async {
    final app = await pumpTgApp(tester, location: '/', size: TGSizes.desktop);
    expect(find.byKey(const Key('hero-slide-BirinciReklamSayfasi')), findsOneWidget);
    expect(find.text('Industrial Kitchen Costs and Profitability'), findsWidgets);
    expect(find.text('Read more'), findsWidgets);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('journal page renders article copy, four icons, four photos and three charts', (tester) async {
    final app = await pumpTgApp(tester, location: '/birinciReklamSayfasi', size: TGSizes.desktop);
    expect(find.byKey(const Key('journal-article')), findsOneWidget);
    expect(find.byType(TgMagazineArticleView), findsOneWidget);
    expect(find.text('Industrial Kitchen Costs and Profitability'), findsWidgets);
    expect(find.byKey(const Key('magazine-icon-energy')), findsOneWidget);
    expect(find.byKey(const Key('magazine-icon-capex')), findsOneWidget);
    expect(find.byKey(const Key('magazine-icon-roi')), findsOneWidget);
    expect(find.byKey(const Key('magazine-icon-aclass')), findsOneWidget);
    expect(find.byKey(const Key('magazine-photo-cover')), findsOneWidget);
    expect(find.byKey(const Key('magazine-photo-intro')), findsOneWidget);
    expect(find.byKey(const Key('magazine-photo-gallery-a')), findsOneWidget);
    expect(find.byKey(const Key('magazine-photo-gallery-b')), findsOneWidget);
    expect(find.byKey(const Key('journal-chart-capex')), findsOneWidget);
    expect(find.byKey(const Key('journal-chart-energy')), findsOneWidget);
    expect(find.byKey(const Key('journal-chart-roi')), findsOneWidget);
    expect(find.byKey(const Key('magazine-roi-slider')), findsOneWidget);
    expect(find.textContaining('1260'), findsWidgets);
    expect(find.text('This advertising page will be active soon!'), findsNothing);
    expect(find.text('"This advertising page will be active soon!"'), findsNothing);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('journal article follows TR locale', (tester) async {
    final app = await pumpTgApp(tester, location: '/birinciReklamSayfasi', locale: const Locale('tr'), size: TGSizes.desktop);
    expect(find.text('Endüstriyel Mutfak Maliyetleri ve Kârlılık'), findsWidgets);
    expect(find.text('B2B dergi'), findsWidgets);
    expect(find.text('Canlı ROI ve amortisman hesaplayıcı'), findsOneWidget);
    expect(find.byKey(const Key('journal-chart-capex')), findsOneWidget);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('journal article follows PL locale', (tester) async {
    final app = await pumpTgApp(tester, location: '/birinciReklamSayfasi', locale: const Locale('pl'), size: TGSizes.phone);
    expect(find.text('Koszty kuchni gastronomicznej i rentowność'), findsWidgets);
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
    expect(savings.contains('1260'), isFalse);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });

  testWidgets('magazine article follows light theme without overflow', (tester) async {
    final app = await pumpTgApp(
      tester,
      location: '/birinciReklamSayfasi',
      size: TGSizes.phone,
      themeMode: ThemeMode.light,
    );
    expect(find.byType(TgMagazineArticleView), findsOneWidget);
    expect(TGColors.background, TGPalette.light.background);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });
}
