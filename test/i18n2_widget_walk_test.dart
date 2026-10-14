import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/tg_components/tg_inline_translate.dart';
import 'package:twoja_gastromania/tg_components/tg_user_text.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

import 'helpers/tg_test_app.dart';
import 'i18n2_support.dart';

const _screens = <String, String>{
  'home': '/',
  'products': '/products',
  'product-detail': '/product-detail/p001',
  'add-product': '/add-product',
  'dashboard-overview': '/dashboard',
  'dashboard-listings': '/dashboard/listings',
  'special-order': '/special-order',
  'restaurants': '/restaurants',
  'seller': '/seller/2931-technica',
  'checkout': '/add-product/checkout',
};

class _Hit {
  _Hit(this.screen, this.locale, this.text);
  final String screen;
  final String locale;
  final String text;
  @override
  String toString() => '$screen [$locale] $text';
}

void main() {
  final allow = loadAllowlist();
  final enValues = kUiTranslations.values.map((m) => (m['en'] ?? '').trim()).where((s) => s.length > 2).toSet();

  for (final locale in const [Locale('tr'), Locale('pl')]) {
    testWidgets('g) widget walk ${locale.languageCode}', (tester) async {
      expect(TGRevenueConfigService.instance.productionMode, isFalse);
      final hits = <_Hit>[];
      for (final e in _screens.entries) {
        await pumpTgApp(
          tester,
          location: e.value,
          locale: locale,
          signedIn: true,
          size: TGSizes.desktop,
          ignoreOverflow: true,
        );
        final skip = _userContent();
        _walk(tester.element(find.byType(MaterialApp).first), skip, allow, enValues, locale.languageCode, e.key, hits);
      }
      final unique = hits.map((h) => h.toString()).toSet().toList()..sort();
      expect(unique, isEmpty, reason: unique.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}

Set<String> _userContent() {
  final out = <String>{};
  for (final p in TGProductService.instance.cachedAll) {
    out.add(p.title.trim());
    final d = p.description?.trim();
    if (d != null && d.isNotEmpty) out.add(d);
    out.add(p.seller.name.trim());
    out.add(p.city.trim());
  }
  for (final r in RestaurantService.instance.all) {
    out.add(r.title.trim());
    out.add(r.description.trim());
    if (r.venueName != null) out.add(r.venueName!.trim());
    out.add(r.city.trim());
  }
  for (final s in TGSellerProfileService.instance.all) {
    out.add(s.name.trim());
    final d = s.description.trim();
    if (d.isNotEmpty) out.add(d);
  }
  DealService.instance.ensureSeeded();
  for (final r in DealService.instance.reviews) {
    out.add(r.text.trim());
    out.add(r.authorName.trim());
  }
  return out;
}

void _walk(
  Element root,
  Set<String> userContent,
  Set<String> allow,
  Set<String> enValues,
  String locale,
  String screen,
  List<_Hit> hits,
) {
  void visit(Element el) {
    final w = el.widget;
    if (w is TGUserText || w is TGInlineTranslate) return;
    var underUser = false;
    el.visitAncestorElements((a) {
      if (a.widget is TGUserText || a.widget is TGInlineTranslate) {
        underUser = true;
        return false;
      }
      return true;
    });
    if (!underUser) {
      for (final t in _texts(w)) {
        if (_isBad(t, userContent, allow, enValues)) {
          hits.add(_Hit(screen, locale, t));
        }
      }
    }
    el.visitChildren(visit);
  }

  visit(root);
}

List<String> _texts(Widget w) {
  final out = <String>[];
  if (w is Text) {
    final d = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
    if (d.isNotEmpty) out.add(d);
  }
  if (w is RichText) {
    final d = w.text.toPlainText().trim();
    if (d.isNotEmpty) out.add(d);
  }
  if (w is Tooltip) {
    final m = w.message?.trim();
    if (m != null && m.isNotEmpty) out.add(m);
  }
  if (w is InputDecorator) {
    final d = w.decoration;
    for (final s in [d.hintText, d.labelText, d.helperText, d.errorText]) {
      if (s != null && s.trim().isNotEmpty) out.add(s.trim());
    }
  }
  if (w is Semantics) {
    final l = w.properties.label?.trim();
    if (l != null && l.isNotEmpty) out.add(l);
  }
  return out;
}

bool _isBad(String t, Set<String> userContent, Set<String> allow, Set<String> enValues) {
  if (t.length < 3) return false;
  if (t.startsWith('⚠ ')) return false;
  if (userContent.contains(t)) return false;
  if (allowlistedValue(t, allow)) return false;
  if (!RegExp(r'[A-Za-z]').hasMatch(t)) return false;
  if (RegExp(r'^\d').hasMatch(t) && t.length < 12) return false;
  if (enValues.contains(t)) return true;
  for (final w in visibleWords(t)) {
    if (englishStopWords.contains(w)) return true;
  }
  return false;
}
