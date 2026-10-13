import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/restaurants/restaurant_logic.dart';
import 'package:twoja_gastromania/restaurants/restaurant_query.dart';
import 'package:twoja_gastromania/tg_core/pl_business_days.dart';
import 'package:twoja_gastromania/tg_core/restaurant_config.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

void main() {
  setUp(() {
    TGRevenueConfigService.instance.reset();
    RestaurantConfigService.instance.reset();
    RestaurantService.instance.reset();
  });

  test('RestaurantConfig defaults match RESTO-1', () {
    final c = RestaurantConfig.defaults;
    expect(c.freeDays, 30);
    expect(c.freeExtensionDays, 30);
    expect(c.paidPricePln, 149);
    expect(c.paidDays, 90);
    expect(c.renewEarlyDays, 14);
    expect(c.promote.pricePln(14), 49);
    expect(c.promote.pricePln(30), 79);
    expect(c.freeStartCapPer12m, 3);
    expect(c.perPremisesMax, 3);
    expect(c.dailyListingCap, 3);
    expect(c.lowViewsHint, 30);
    expect(c.soldItemReviewBusinessDays, 5);
  });

  test('seed has 14 listings and public hub only active visible', () {
    final all = RestaurantService.instance.all;
    expect(all, hasLength(14));
    final public = RestaurantService.instance.publicListings;
    expect(public.every((r) => r.status == RestaurantListingStatus.active && !r.isHidden), isTrue);
    expect(public.length, greaterThanOrEqualTo(8));
    expect(all.where((r) => r.isPromoted).length, greaterThanOrEqualTo(2));
    expect(all.where((r) => r.transferFee.isNone), isNotEmpty);
    expect(all.where((r) => r.rentBasis == RestaurantVatBasis.vatUnspecified), isNotEmpty);
    expect(all.where((r) => r.declaredMonthlyRevenue != null).length, greaterThanOrEqualTo(2));
    expect(all.where((r) => r.inventory.length >= 10).length, greaterThanOrEqualTo(6));
  });

  test('Production Mode hides mock restaurants', () {
    expect(RestaurantService.instance.publicListings, isNotEmpty);
    TGRevenueConfigService.instance.setProductionMode(true, actorId: 'test', reason: 'unit');
    expect(RestaurantService.instance.publicListings, isEmpty);
    expect(RestaurantService.instance.findPublicByNo('51010001'), isNull);
  });

  test('listing no search resolves public restaurant', () {
    final hit = RestaurantService.instance.findPublicByNo('51010001');
    expect(hit, isNotNull);
    expect(hit!.detailPath, startsWith('/restaurants/51010001-'));
  });

  test('query round-trip and filter by business type', () {
    final q = RestaurantQueryState(
      businessTypes: {RestaurantBusinessType.cafe},
      verifiedOnly: true,
      city: 'Rybnik',
      rentMax: 10000,
    );
    final back = RestaurantQueryState.fromQuery(q.toQuery());
    expect(back.businessTypes, q.businessTypes);
    expect(back.verifiedOnly, isTrue);
    expect(back.city, 'Rybnik');
    expect(back.rentMax, 10000);

    final filtered = applyRestaurantFilters(RestaurantService.instance.all, q);
    expect(filtered.every((r) => r.businessType == RestaurantBusinessType.cafe), isTrue);
  });

  test('Polish business days skip weekend and holidays', () {
    // 2026-01-01 is New Year (Thursday) — next business day from Dec 31 2025.
    final from = DateTime(2025, 12, 31);
    final next = PLBusinessDays.addBusinessDays(from, 1);
    expect(next, DateTime(2026, 1, 2)); // Friday (Jan 1 holiday)
  });

  test('premises key normalization strips ul. and accents', () {
    final a = RestaurantPremisesKey.normalize(city: 'Kraków', street: 'ul. Miodowa', buildingNo: '22');
    final b = RestaurantPremisesKey.normalize(city: 'Krakow', street: 'Miodowa', buildingNo: '22');
    expect(a, equals(b));
  });
}
