import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/special_order/special_order_hub_widgets.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:twoja_gastromania/tg_services/sponsor_slot_service.dart';

import 'helpers/tg_test_app.dart';

const _vitrin4Files = [
  'special_order_hub_widgets.dart',
  'home_manufacturers_strip.dart',
  'manufacturer_dashboard_page.dart',
  'tg_manufacturer_promote_panel.dart',
];

Iterable<String> _newOverflows(TGApp app) =>
    app.errors.distinct.where((e) => e.contains('overflowed') && _vitrin4Files.any(e.contains));

void main() {
  setUp(() {
    TGClock.reset();
    PricingConfigService.instance.resetForTests();
    PromotionService.instance.resetForTests();
    TGRevenueConfigService.instance.reset();
    TGRevenueConfigService.instance.setPhase(2, actorId: 'test');
    TGSpecialOrderService.instance.reset();
    TGSponsorSlotService.instance.reset();
  });

  for (final (name, size, scale, locale) in [
    ('phone pl 1.3x', const Size(390, 844), 1.3, const Locale('pl')),
    ('desktop tr', const Size(1440, 900), 1.0, const Locale('tr')),
  ]) {
    testWidgets('home manufacturers strip renders compact cards ($name)', (tester) async {
      final app = await pumpTgApp(tester, size: size, textScale: scale, locale: locale);
      final strip = find.byKey(const ValueKey('home_mfr_strip'));
      await tester.scrollUntilVisible(strip, 400, scrollable: find.byType(Scrollable).first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(strip, findsOneWidget);
      final cards = find.descendant(of: strip, matching: find.byType(SoManufacturerCard));
      expect(cards, findsWidgets);
      expect(tester.widgetList(cards).length, lessThanOrEqualTo(6));
      expect(_newOverflows(app), isEmpty);
    });
  }

  testWidgets('home strip is hidden in production mode with < 3 real manufacturers', (tester) async {
    TGRevenueConfigService.instance.setProductionMode(true, actorId: 'test', reason: 'test');
    if (TGSpecialOrderService.instance.manufacturers().length >= 3) return;
    await pumpTgApp(tester, size: const Size(390, 844));
    expect(find.byKey(const ValueKey('home_mfr_strip')), findsNothing);
  });

  for (final tab in ['promote', 'sponsor']) {
    testWidgets('manufacturer dashboard $tab tab renders on phone without overflow', (tester) async {
      final app = await pumpTgApp(
        tester,
        size: const Size(390, 844),
        textScale: 1.3,
        locale: const Locale('pl'),
        location: '/dashboard/manufacturer?tab=$tab',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tab == 'promote' ? 'Wypromuj kartę producenta' : 'Sloty sponsorskie'), findsWidgets);
      expect(_newOverflows(app), isEmpty);
    });
  }
}
