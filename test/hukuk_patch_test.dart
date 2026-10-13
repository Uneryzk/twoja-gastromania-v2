import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/restaurants/restaurant_card.dart';
import 'package:twoja_gastromania/special_order/special_order_hub_widgets.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_components/tg_ranking_info.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/go_live_checks.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/special_consent_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:twoja_gastromania/tg_services/sponsor_slot_service.dart';

import 'helpers/tg_test_app.dart';

const _listingsTr = "'Önerilen' sıralama; öncelikle yüksek satıcı puanını, ardından en yeni yayın tarihini temel alır.";
const _specialTr = "'Önerilen' sıralama; üreticinin tamamladığı proje sayısını, müşteri puanını ve ortalama yanıt süresini temel alır.";
const _paidTr =
    "Satıcılar ücret karşılığında ilanlarını öne çıkarabilir: Spotlight ve Glow ilanları listenin en üstünde 'ÖNE ÇIKAN' etiketiyle, "
    'Bold ilanları ise standart ilanlardan önce kalın başlıkla gösterilir. '
    'Fiyat, tarih veya yakınlık sıralamasında yalnızca Spotlight ve Glow ilanları üstte sabit kalır. '
    'Özel sipariş üreticilerinde Spotlight, Glow ve Bold ilanları tüm sıralama seçeneklerinde '
    '(puan, proje sayısı, yanıt süresi) organik sonuçların üstünde yer alır.';

const _warning = {
  'tr': 'TWOJA GASTROMANIA SİPARİŞİN TARAFI DEĞİLDİR. BİREYSEL VEYA KURUMSAL SİPARİŞLERİNİZDE ÜRETİCİ İLE ARANIZDA OLUŞABİLECEK AKSAKLIK, AKSİLİK VE HATALAR SİZİN VE ÜRETİCİNİN SORUMLULUĞUNDADIR.',
  'en': 'TWOJA GASTROMANIA IS NOT A PARTY TO YOUR ORDER. ANY PROBLEMS, DELAYS OR ERRORS THAT MAY ARISE IN YOUR INDIVIDUAL OR BUSINESS ORDERS ARE THE RESPONSIBILITY OF YOU AND THE MANUFACTURER.',
  'pl': 'TWOJA GASTROMANIA NIE JEST STRONĄ ZAMÓWIENIA. ODPOWIEDZIALNOŚĆ ZA PROBLEMY, OPÓŹNIENIA I BŁĘDY W ZAMÓWIENIACH INDYWIDUALNYCH LUB FIRMOWYCH PONOSZĄ ZAMAWIAJĄCY I PRODUCENT.',
};

const _locales = ['en', 'pl', 'tr', 'de', 'cs', 'sk', 'uk', 'be', 'lt', 'ru'];

Finder _within(Finder of, Finder matching) => find.descendant(of: of, matching: matching);

void main() {
  setUp(() {
    TGClock.reset();
    PricingConfigService.instance.resetForTests();
    PromotionService.instance.resetForTests();
    TGRevenueConfigService.instance.reset();
    TGSpecialOrderService.instance.reset();
    TGSponsorSlotService.instance.reset();
  });

  group('bold label cleanup', () {
    test('labelBold defaults to false and no go-live check depends on it', () {
      expect(const PromotionConfig().labelBold, isFalse);
      expect(PromotionService.instance.config.labelBold, isFalse);
      final ids = tgGoLiveChecks().map((c) => c.id);
      expect(ids, isNot(contains('bold_label')));
      expect(kUiTranslations.containsKey('ui_admin_promo_label_bold'), isFalse);
    });

    testWidgets('product cards: Bold has no label and a w700 title; Spotlight/Glow keep ÖNE ÇIKAN', (tester) async {
      // A stale stored config with labelBold=true must not bring the label back.
      final svc = PricingConfigService.instance;
      svc.setConfig(svc.config.copyWith(promotions: svc.config.promotions.copyWith(labelBold: true)));
      await pumpTgApp(tester, size: const Size(1440, 1400), locale: const Locale('tr'), location: '/products');
      await tester.pump(const Duration(milliseconds: 300));

      final bold = find.byWidgetPredicate((w) => w is TGProductCard && w.promotionTier == PromotionTier.bold);
      final featured = find.byWidgetPredicate(
        (w) => w is TGProductCard && (w.promotionTier == PromotionTier.spotlight || w.promotionTier == PromotionTier.glow),
      );
      expect(bold, findsWidgets);
      expect(featured, findsWidgets);
      for (final card in tester.widgetList<TGProductCard>(bold)) {
        final f = find.byWidget(card);
        expect(_within(f, find.text('SPONSORLU')), findsNothing);
        expect(_within(f, find.text('ÖNE ÇIKAN')), findsNothing);
        final title = tester.widget<Text>(_within(f, find.text(card.product.title)).first);
        expect(title.style?.fontWeight, FontWeight.w700);
      }
      expect(_within(featured.first, find.text('ÖNE ÇIKAN')), findsWidgets);
      expect(find.text('SPONSORLU'), findsNothing);
    });

    testWidgets('restaurant cards: Bold has no label; Spotlight/Glow keep ÖNE ÇIKAN', (tester) async {
      await pumpTgApp(tester, size: const Size(1440, 1400), locale: const Locale('tr'), location: '/restaurants');
      await tester.pump(const Duration(milliseconds: 300));
      final bold = find.byWidgetPredicate((w) => w is RestaurantCard && w.promotionTier == PromotionTier.bold);
      final featured = find.byWidgetPredicate(
        (w) => w is RestaurantCard && (w.promotionTier == PromotionTier.spotlight || w.promotionTier == PromotionTier.glow),
      );
      expect(bold, findsWidgets);
      expect(featured, findsWidgets);
      expect(_within(bold.first, find.text('SPONSORLU')), findsNothing);
      expect(_within(bold.first, find.text('ÖNE ÇIKAN')), findsNothing);
      expect(_within(featured.first, find.text('ÖNE ÇIKAN')), findsWidgets);
    });

    testWidgets('manufacturer cards: Bold has no label; Spotlight/Glow keep ÖNE ÇIKAN', (tester) async {
      TGRevenueConfigService.instance.setPhase(2, actorId: 'test');
      final keys = TGSpecialOrderService.instance.manufacturers().map((p) => p.sellerKey).toList();
      final tiers = {keys[0]: PromotionTier.bold, keys[1]: PromotionTier.glow, keys[2]: PromotionTier.spotlight};
      tiers.forEach((key, tier) => PromotionService.instance.purchase(
            ownerId: key,
            kind: PromotionTargetKind.manufacturer,
            targetRef: key,
            tier: tier,
            durationDays: 14,
            pricePln: PricingConfigService.instance.config.promoFeePln(tier, 14),
            source: PromotionSource.paid,
          ));
      await pumpTgApp(tester, size: const Size(1440, 2400), locale: const Locale('tr'), location: '/special-order');
      await tester.pump(const Duration(milliseconds: 300));

      Finder card(String key) => find.byWidgetPredicate((w) => w is SoManufacturerCard && w.profile.sellerKey == key);
      final boldKey = keys[0];
      expect(card(boldKey), findsWidgets);
      expect(_within(card(boldKey).first, find.text('SPONSORLU')), findsNothing);
      expect(_within(card(boldKey).first, find.text('ÖNE ÇIKAN')), findsNothing);
      for (final key in [keys[1], keys[2]]) {
        expect(_within(card(key).first, find.text('ÖNE ÇIKAN')), findsWidgets);
      }
    });
  });

  group('"How sorting works" sheet', () {
    Future<void> openAndCheck(WidgetTester tester, String surface, {required bool phone}) async {
      final link = find.byKey(Key('ranking-info-link-$surface')).first;
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ranking-info-sheet')), findsOneWidget);
      expect(find.text('Listeleri nasıl sıralıyoruz?'), findsOneWidget);
      final footer = surface == 'footer';
      expect(find.text(_listingsTr), surface == 'special_order' ? findsNothing : findsOneWidget);
      expect(find.text(_specialTr), surface == 'special_order' || footer ? findsOneWidget : findsNothing);
      expect(find.text(_paidTr), findsOneWidget);
      expect(find.text('Ürünler ve restoranlar'), footer ? findsOneWidget : findsNothing);
      expect(find.text('Özel sipariş üreticileri'), footer ? findsOneWidget : findsNothing);
      if (phone) {
        expect(find.byType(BottomSheet), findsOneWidget);
      } else {
        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.getSize(find.byKey(const Key('ranking-info-sheet'))).width, lessThanOrEqualTo(480));
      }
      await tester.tap(find.byTooltip('Kapat').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ranking-info-sheet')), findsNothing);
    }

    for (final (surface, location) in [
      ('products', '/products'),
      ('restaurants', '/restaurants'),
      ('special_order', '/special-order'),
    ]) {
      testWidgets('opens as a 480px modal from $location sort bar (desktop)', (tester) async {
        await pumpTgApp(tester, size: const Size(1440, 1000), locale: const Locale('tr'), location: location);
        await tester.pump(const Duration(milliseconds: 300));
        await openAndCheck(tester, surface, phone: false);
      });
    }

    testWidgets('opens as a bottom sheet from /restaurants mobile controls', (tester) async {
      await pumpTgApp(tester, size: const Size(390, 844), locale: const Locale('tr'), location: '/restaurants');
      await tester.pump(const Duration(milliseconds: 300));
      await openAndCheck(tester, 'restaurants', phone: true);
    });

    testWidgets('opens as a bottom sheet from /special-order on phone', (tester) async {
      await pumpTgApp(tester, size: const Size(390, 844), locale: const Locale('tr'), location: '/special-order');
      await tester.pump(const Duration(milliseconds: 300));
      await openAndCheck(tester, 'special_order', phone: true);
    });

    testWidgets('opens from the footer', (tester) async {
      await pumpTgApp(tester, size: const Size(1440, 1000), locale: const Locale('tr'), location: '/products');
      await tester.pump(const Duration(milliseconds: 300));
      await openAndCheck(tester, 'footer', phone: false);
    });

    test('ranking go-live check passes and stays blocking', () {
      final check = tgGoLiveChecks().firstWhere((c) => c.id == 'ranking_disclosure');
      expect(check.blocking, isTrue);
      expect(rankingDisclosureComplete(), isTrue);
      expect(check.ok, isTrue);
    });
  });

  group('copy', () {
    test('ranking strings match the real sort and exist in every locale', () {
      expect(kUiTranslations['ranking_info_link']!['tr'], 'Sıralama nasıl çalışır?');
      expect(kUiTranslations['ranking_info_link']!['en'], 'How sorting works');
      expect(kUiTranslations['ranking_info_heading']!['tr'], 'Listeleri nasıl sıralıyoruz?');
      expect(kUiTranslations['ranking_info_listings']!['tr'], _listingsTr);
      expect(kUiTranslations['ranking_info_special']!['tr'], _specialTr);
      expect(kUiTranslations['ranking_info_paid']!['tr'], _paidTr);
      expect(kUiTranslations['ranking_info_listings']!['en'], contains('seller rating'));
      expect(kUiTranslations['ranking_info_special']!['en'], contains('response time'));
      expect(kUiTranslations['ranking_info_paid']!['en'], contains("'FEATURED'"));
      expect(kUiTranslations['ranking_info_paid']!['pl'], contains('„WYRÓŻNIONE”'));
      expect(kUiTranslations['ranking_info_paid']!['en'], endsWith('(rating, number of projects, response time).'));
      for (final l in _locales) {
        for (final k in kRankingInfoKeys) {
          expect(kUiTranslations[k]![l], isNotEmpty, reason: '$k/$l');
        }
        expect(kUiTranslations['ranking_info_paid']![l], contains(kUiTranslations['badge.featured']![l]!), reason: l);
      }
      // No claims about filters or proximity in the Recommended explanation.
      for (final k in ['ranking_info_listings', 'ranking_info_special']) {
        expect(kUiTranslations[k]!['tr'], isNot(contains('filtre')));
        expect(kUiTranslations[k]!['tr'], isNot(contains('yakınlık')));
      }
      expect(kUiTranslations.containsKey('ranking_info_draft'), isFalse);
    });

    test('Showcase Bold subtitle', () {
      expect(kUiTranslations['ui_showcase_where_bold']!['tr'], 'Listelerde standart ilanlardan önce, kalın başlıkla');
      for (final l in ['en', 'pl', 'tr']) {
        expect(kUiTranslations['ui_showcase_where_bold']![l]!.toUpperCase(), isNot(contains('SPONSOR')));
        expect(kUiTranslations['ui_mfr_promote_where_bold']![l]!.toUpperCase(), isNot(contains('SPONSOR')));
      }
    });

    test('consent warning: exact TR/EN/PL, uppercase in every locale, version bumped', () {
      _warning.forEach((l, text) => expect(kUiTranslations['so_consent_warning_body']![l], text));
      for (final l in _locales) {
        final body = FFLocalizations(Locale(l)).getText('so_consent_warning_body');
        expect(body, isNotEmpty);
        expect(body, body.toUpperCase(), reason: l);
        expect(body, startsWith('TWOJA GASTROMANIA'), reason: l);
      }
      expect(kSoConsentTextVersion, 'so-consent-1.2');
      expect(TGSpecialConsentService.consentText('tr'), contains(_warning['tr']!));
    });
  });
}
