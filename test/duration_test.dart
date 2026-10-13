import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
import 'package:twoja_gastromania/tg_core/duration_service.dart';
import 'package:twoja_gastromania/tg_core/restaurant_config.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';

DateTime _warsaw(int y, int m, int d, [int h = 0, int min = 0]) => DurationService.fromWarsawWall(y, m, d, h, min);

void main() {
  group('DurationFormatter.days', () {
    test('Turkish has no plural forms', () {
      expect(DurationFormatter.days(1, 'tr'), '1 gün');
      expect(DurationFormatter.days(14, 'tr'), '14 gün');
      expect(DurationFormatter.days(30, 'tr'), '30 gün');
    });

    test('English one / other', () {
      expect(DurationFormatter.days(1, 'en'), '1 day');
      expect(DurationFormatter.days(7, 'en'), '7 days');
      expect(DurationFormatter.days(0, 'en'), '0 days');
    });

    test('Polish ICU plural (dzień / dni)', () {
      expect(DurationFormatter.days(1, 'pl'), '1 dzień');
      expect(DurationFormatter.days(2, 'pl'), '2 dni');
      expect(DurationFormatter.days(5, 'pl'), '5 dni');
      expect(DurationFormatter.days(22, 'pl'), '22 dni');
      expect(DurationFormatter.days(365, 'pl'), '365 dni');
    });

    test('Slavic few / many categories', () {
      expect(DurationFormatter.days(3, 'cs'), '3 dny');
      expect(DurationFormatter.days(5, 'cs'), '5 dní');
      expect(DurationFormatter.days(21, 'ru'), '21 день');
      expect(DurationFormatter.days(22, 'ru'), '22 дня');
      expect(DurationFormatter.days(25, 'ru'), '25 дней');
      expect(DurationFormatter.days(14, 'uk'), '14 днів');
    });

    test('unknown locale variants fall back to the language, then English', () {
      expect(DurationFormatter.days(14, 'pl_PL'), '14 dni');
      expect(DurationFormatter.days(14, 'fr'), '14 days');
    });

    test('ICU =N exact match and nested arguments', () {
      expect(
        DurationFormatter.formatIcu('{n, plural, =0{none} one{# item} other{# items}} for {who}', 'en', {'n': 0, 'who': 'Ann'}),
        'none for Ann',
      );
      expect(DurationFormatter.pricePerPeriod(129, 7, 'tr'), '129 PLN / 7 gün');
    });
  });

  group('DurationFormatter.remaining', () {
    final end = _warsaw(2026, 10, 20, 18);

    test('days left, rounded up', () {
      expect(DurationFormatter.remaining(end, 'tr', now: _warsaw(2026, 10, 13, 18)), '7 gün kaldı');
      expect(DurationFormatter.remaining(end, 'en', now: _warsaw(2026, 10, 13, 20)), '7 days left');
      expect(DurationFormatter.remaining(end, 'pl', now: _warsaw(2026, 10, 18, 18)), 'Zostały 2 dni');
    });

    test('last 24 hours → "ends today · N h"', () {
      expect(DurationFormatter.remaining(end, 'tr', now: _warsaw(2026, 10, 20, 12)), 'Bugün bitiyor · 6 sa');
      expect(DurationFormatter.remaining(end, 'en', now: _warsaw(2026, 10, 20, 17, 30)), 'Ends today · 1 h');
      expect(DurationFormatter.remaining(end, 'pl', now: _warsaw(2026, 10, 19, 18)), 'Kończy się dziś · 24 godz.');
    });

    test('ended → "N days ago" / "ended today"', () {
      expect(DurationFormatter.remaining(end, 'tr', now: _warsaw(2026, 10, 23, 9)), '3 gün önce bitti');
      expect(DurationFormatter.remaining(end, 'en', now: _warsaw(2026, 10, 21, 9)), 'Ended 1 day ago');
      expect(DurationFormatter.remaining(end, 'tr', now: _warsaw(2026, 10, 20, 23)), 'Bugün bitti');
    });
  });

  group('DurationService (Europe/Warsaw)', () {
    test('offsets: CEST in summer, CET in winter, switch at 01:00 UTC', () {
      expect(DurationService.warsawOffset(DateTime.utc(2026, 7, 1)), const Duration(hours: 2));
      expect(DurationService.warsawOffset(DateTime.utc(2026, 1, 15)), const Duration(hours: 1));
      // 2026: DST ends Sun 25 Oct, starts Sun 29 Mar.
      expect(DurationService.warsawOffset(DateTime.utc(2026, 10, 25, 0, 59)), const Duration(hours: 2));
      expect(DurationService.warsawOffset(DateTime.utc(2026, 10, 25, 1)), const Duration(hours: 1));
      expect(DurationService.warsawOffset(DateTime.utc(2026, 3, 29, 0, 59)), const Duration(hours: 1));
      expect(DurationService.warsawOffset(DateTime.utc(2026, 3, 29, 1)), const Duration(hours: 2));
    });

    test('7 days across the October switch keeps the wall-clock time (169 h)', () {
      final start = _warsaw(2026, 10, 22, 10);
      final end = DurationService.endOf(start, 7);
      final wall = DurationService.toWarsawWall(end);
      expect([wall.year, wall.month, wall.day, wall.hour], [2026, 10, 29, 10]);
      expect(end.difference(start), const Duration(hours: 169));
    });

    test('14 days across the March switch keeps the wall-clock time (335 h)', () {
      final start = _warsaw(2027, 3, 20, 0);
      final end = DurationService.endOf(start, 14);
      final wall = DurationService.toWarsawWall(end);
      expect([wall.month, wall.day, wall.hour], [4, 3, 0]);
      expect(end.difference(start), const Duration(hours: 335));
    });

    test('30 / 365 days land on the same Warsaw date', () {
      final start = _warsaw(2026, 10, 13, 9, 30);
      final w30 = DurationService.toWarsawWall(DurationService.endOf(start, 30));
      expect([w30.month, w30.day, w30.hour, w30.minute], [11, 12, 9, 30]);
      final w365 = DurationService.toWarsawWall(DurationService.endOf(start, 365));
      expect([w365.year, w365.month, w365.day, w365.hour], [2027, 10, 13, 9]);
    });

    test('dayStart is Warsaw midnight, even right after the switch', () {
      final d = DurationService.dayStart(DateTime.utc(2026, 10, 25, 12));
      expect(d.toUtc(), DateTime.utc(2026, 10, 24, 22));
      final d2 = DurationService.dayStart(DateTime.utc(2026, 10, 26, 12));
      expect(d2.toUtc(), DateTime.utc(2026, 10, 25, 23));
    });

    test('non-existent spring time moves forward; ambiguous autumn time takes the first', () {
      expect(_warsaw(2026, 3, 29, 2, 30).toUtc(), DateTime.utc(2026, 3, 29, 1, 30));
      expect(_warsaw(2026, 10, 25, 2, 30).toUtc(), DateTime.utc(2026, 10, 25, 0, 30));
    });

    test('calendar days, days left and days ago', () {
      expect(DurationService.calendarDaysBetween(_warsaw(2026, 10, 24, 23), _warsaw(2026, 10, 25, 1)), 1);
      expect(DurationService.daysLeft(_warsaw(2026, 10, 30, 12), now: _warsaw(2026, 10, 23, 12)), 7);
      expect(DurationService.daysLeft(_warsaw(2026, 10, 30, 12), now: _warsaw(2026, 10, 23, 13)), 7);
      expect(DurationService.daysLeft(_warsaw(2026, 10, 30, 12), now: _warsaw(2026, 10, 23, 11)), 8);
      expect(DurationService.daysLeft(_warsaw(2026, 10, 30, 12), now: _warsaw(2026, 10, 31)), 0);
      expect(DurationService.daysAgo(_warsaw(2026, 10, 30, 12), now: _warsaw(2026, 11, 2, 8)), 3);
      expect(DurationService.hoursLeft(_warsaw(2026, 10, 30, 12), now: _warsaw(2026, 10, 30, 5, 59)), 7);
    });

    test('addDays keeps sub-second precision and UTC flag', () {
      final utc = DateTime.utc(2026, 10, 20, 9, 30, 15, 250, 7);
      final out = DurationService.addDays(utc, 7);
      expect(out.isUtc, isTrue);
      expect(out, DateTime.utc(2026, 10, 27, 10, 30, 15, 250, 7));
      expect(DurationService.addDays(utc, 0), utc);
    });
  });

  group('ICU templates via FFLocalizations', () {
    String t(String lang, String key, Map<String, String> p) => FFLocalizations(Locale(lang)).getText(key, p);

    test('day counts are plural-aware in every template', () {
      expect(t('en', 'ui_n_days', {'n': '1'}), '1 day');
      expect(t('pl', 'ui_n_days', {'n': '5'}), '5 dni');
      expect(t('tr', 'ui_days_left_n', {'n': '1'}), '1 gün kaldı');
      expect(t('pl', 'ui_days_left_n', {'n': '2'}), 'Zostały 2 dni');
      expect(t('en', 'ui_promote_n_days', {'n': '14'}), 'Promote 14 days');
      expect(t('tr', 'ui_duration_days_price', {'days': '30', 'fee': '49'}), '30 gün · 49 PLN');
      expect(t('en', 'ui_expired_ago', {'n': '1'}), 'Expired 1 day ago');
      expect(t('ru', 'ui_expired_ago', {'n': '3'}), 'Истекло 3 дня назад');
      expect(t('en', 'ui_mfr_promote_from', {'price': '49', 'days': '14'}), 'From 49 PLN / 14 days');
      expect(t('pl', 'ui_pill_free', {'n': '2', 'd': '1'}), '2 darmowe · Został 1 dzień');
    });

    test('non-ICU templates still use plain replacement', () {
      expect(t('en', 'ui_banner_refunded', {'price': '129'}), 'Refunded: 129 PLN');
    });

    test('no week / month wording left in paid-duration copy', () {
      for (final key in ['ui_banner_entitlement_week', 'ui_banner_err_entitlement', 'ui_banner_cancel_body_free', 'ui_mfr_sponsor_sub', 'ui_mfr_promote_from']) {
        for (final lang in ['en', 'pl', 'tr']) {
          final s = t(lang, key, {'days': '7', 'price': '89'}).toLowerCase();
          expect(s.contains('week') || s.contains('tydz') || s.contains('tygod') || s.contains('hafta'), isFalse, reason: '$key/$lang: $s');
        }
      }
      expect(kUiTranslations.containsKey('ui_duration_2w'), isFalse);
      expect(kUiTranslations.containsKey('ui_promo_duration_1m'), isFalse);
    });
  });

  group('Config durations are numeric days', () {
    test('picker options come from config keys', () {
      expect(PricingConfig.defaults.banner.durations, [7, 14, 30]);
      expect(PricingConfig.defaults.sponsorSlot.durations, [7, 14, 30]);
      expect(PromotionConfig.defaults.durations, [14, 30]);
      expect(PricingConfig.defaults.banner.pricePln(14), 199);
    });

    test('restaurant promote prices migrate legacy pln14 / pln30 JSON', () {
      final legacy = RestaurantPromotePrices.fromJson({'pln14': 45, 'pln30': 75});
      expect(legacy.prices, {14: 45, 30: 75});
      final roundTrip = RestaurantPromotePrices.fromJson(legacy.toJson());
      expect(roundTrip.durations, [14, 30]);
      expect(roundTrip.pricePln(30), 75);
    });
  });
}
