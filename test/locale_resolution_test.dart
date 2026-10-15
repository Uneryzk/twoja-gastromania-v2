import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';

import 'helpers/tg_test_app.dart';

void main() {
  test('supported device languages resolve to themselves', () {
    for (final locale in kSupportedLocales) {
      expect(
        resolveAppLocale(Locale(locale.languageCode, 'XX'), kSupportedLocales),
        locale,
        reason: locale.languageCode,
      );
    }
  });

  test('unsupported device languages fall back to English', () {
    expect(resolveAppLocale(const Locale('fr', 'FR'), kSupportedLocales), const Locale('en'));
    expect(resolveAppLocale(const Locale('ja'), kSupportedLocales), const Locale('en'));
    expect(resolveAppLocale(null, kSupportedLocales), const Locale('en'));
  });

  test('region / Google location maps onto a shipped language', () {
    expect(detectAppLocale(preferred: [const Locale('ja', 'PL')]), const Locale('pl'));
    expect(detectAppLocale(preferred: [const Locale('fr', 'TR')]), const Locale('tr'));
    expect(detectAppLocale(preferred: [const Locale('ja', 'DE')]), const Locale('de'));
    expect(detectAppLocale(preferred: [const Locale('en', 'US')]), const Locale('en'));
    expect(detectAppLocale(preferred: [const Locale('pl', 'PL')]), const Locale('pl'));
  });

  test('stored locale wins over device region', () async {
    SharedPreferences.setMockInitialValues({'__locale_key__': 'tr'});
    await FFLocalizations.initialize();
    expect(FFLocalizations.getStoredLocale(), const Locale('tr'));
  });

  test('chrome strings exist for every supported language', () {
    const key = 'ui_buy';
    expect(FFLocalizations(const Locale('en')).getText(key), 'For sale');
    expect(FFLocalizations(const Locale('pl')).getText(key), 'Na sprzedaż');
    expect(FFLocalizations(const Locale('tr')).getText(key), 'Satılık');
    expect(FFLocalizations(const Locale('de')).getText(key), 'Zu verkaufen');
  });

  test('promoted badge follows the selected language', () {
    expect(FFLocalizations(const Locale('en')).getText('ui_promoted_badge'), 'FEATURED');
    expect(FFLocalizations(const Locale('pl')).getText('ui_promoted_badge'), 'WYRÓŻNIONE');
    expect(FFLocalizations(const Locale('tr')).getText('ui_promoted_badge'), 'ÖNE ÇIKAN');
  });

  test('report modal strings follow the selected language', () {
    expect(FFLocalizations(const Locale('en')).getText('ui_whats_wrong'), 'Why are you reporting?');
    expect(FFLocalizations(const Locale('pl')).getText('ui_whats_wrong'), 'Dlaczego zgłaszasz?');
    expect(FFLocalizations(const Locale('tr')).getText('ui_whats_wrong'), 'Neden şikayet ediyorsunuz?');
    expect(FFLocalizations(const Locale('en')).getText('ui_rr_fraud'), 'Suspected fraud or scam');
    expect(FFLocalizations(const Locale('pl')).getText('ui_rr_fraud'), 'Podejrzenie oszustwa');
    expect(FFLocalizations(const Locale('tr')).getText('ui_submit_report'), 'Şikayeti gönder');
  });

  test('FlutterFlow keys inherit chrome translations', () {
    const key = 'x5fioudz'; // generated "For sale"
    expect(FFLocalizations(const Locale('en')).getText(key), 'For sale');
    expect(FFLocalizations(const Locale('pl')).getText(key), 'Na sprzedaż');
    expect(FFLocalizations(const Locale('tr')).getText(key), 'Satılık');
  });

  testWidgets('Turkish locale localizes header nav and filters', (tester) async {
    await pumpTgApp(tester, location: '/products', locale: const Locale('tr'));
    expect(find.text('Satılık'), findsWidgets);
    expect(find.text('Kiralık'), findsWidgets);
    expect(find.text('Filtreler'), findsWidgets);
    expect(find.text('Ürün ara…'), findsWidgets);
    expect(find.text('ÖNE ÇIKAN'), findsWidgets);
    expect(find.text('WYRÓŻNIONE'), findsNothing);
  });

  testWidgets('Polish locale localizes header nav and filters', (tester) async {
    await pumpTgApp(tester, location: '/products', locale: const Locale('pl'));
    expect(find.text('Na sprzedaż'), findsWidgets);
    expect(find.text('Na wynajem'), findsWidgets);
    expect(find.text('Filtry'), findsWidgets);
    expect(find.text('Szukaj produktów…'), findsWidgets);
    expect(find.text('WYRÓŻNIONE'), findsWidgets);
    expect(find.text('FEATURED'), findsNothing);
  });
}
