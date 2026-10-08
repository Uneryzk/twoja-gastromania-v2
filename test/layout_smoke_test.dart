import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';

import 'helpers/tg_test_app.dart';

/// Regression matrix: every page must lay out without a single framework error
/// (RenderFlex overflow, unbounded flex constraints, exceptions, ...) at
/// desktop, laptop, tablet and phone sizes, also with enlarged system text.
///
/// The pristine app failed this matrix everywhere (e.g. "RenderFlex children
/// have non-zero flex but incoming height constraints are unbounded" on
/// /products, /product-detail and /seller, footer overflows of 139-486 px).
void main() {
  const routes = <String, String>{
    'home': '/',
    'products': '/products',
    'products (list view)': '/products?view=list',
    'products (filtered)': '/products?type=rent&cat=refrigeration&verified=1&sort=price_asc',
    'products (empty result)': '/products?q=zzzzzz',
    'product detail': '/product-detail/p001',
    'seller profile': '/seller/seller_primegastro',
    'seller profile slug': '/seller/2931-technica',
    'seller private': '/seller/6621-anna-p',
    'seller inactive': '/seller/7703-oldkitchen',
    'seller 404': '/seller/9999-missing',
    'special order': '/special-order?seller=1847',
    'ad page 1': '/birinciReklamSayfasi',
    'ad page 2': '/ikinciReklamSayfasi',
    'ad page 3': '/ucuncuReklamSayfasi',
    'ad page 4': '/dortuncuReklamSayfasi',
    'login': '/login',
    'add product': '/add-product',
    'checkout': '/add-product/checkout',
    'plans': '/plans',
    'publish success': '/add-product/success',
    'dashboard listings': '/dashboard/listings',
    'dashboard messages': '/dashboard/messages',
    'unknown route': '/definitely-not-a-page',
  };

  const sizes = <String, Size>{
    'desktop 1440x900': TGSizes.desktop,
    'laptop 1100x800': TGSizes.laptop,
    'tablet 820x1100': TGSizes.tablet,
    'phone 390x844': TGSizes.phone,
    'small phone 320x640': TGSizes.smallPhone,
  };

  for (final r in routes.entries) {
    for (final s in sizes.entries) {
      testWidgets('${r.key} @ ${s.key} has no layout errors', (tester) async {
        final app = await pumpTgApp(tester, size: s.value, location: r.value);
        if (r.value == '/add-product/checkout') {
          app.auth.beginCheckout(
            TGCheckoutCart.listing(listingId: 'own_f1', listingFee: 49, promoteFee: 39, promoteDays: 14),
          );
          await tester.pump();
        }
        await _scrollThroughPage(tester);
        app.errors.stop();
        expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
      });
    }
  }

  // Large system fonts are the classic way to break fixed-height layouts.
  for (final r in const ['/', '/products', '/product-detail/p001']) {
    for (final s in const {'desktop': TGSizes.desktop, 'phone': TGSizes.phone}.entries) {
      testWidgets('$r @ ${s.key} with 1.3x text scale has no layout errors', (tester) async {
        final app = await pumpTgApp(tester, size: s.value, location: r, textScale: 1.3);
        await _scrollThroughPage(tester);
        app.errors.stop();
        expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
      });
    }
  }
}

/// Scrolls the page to the footer so lazily laid-out slivers are exercised too.
Future<void> _scrollThroughPage(WidgetTester tester) async {
  final footer = find.byType(TGFooter);
  final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical);
  if (!tester.any(vertical)) return;
  if (tester.any(footer)) {
    await tester.scrollUntilVisible(footer, 700, scrollable: vertical.first, maxScrolls: 80);
  } else {
    await tester.drag(vertical.first, const Offset(0, -2000));
  }
  await tester.pump(const Duration(milliseconds: 400));
}
