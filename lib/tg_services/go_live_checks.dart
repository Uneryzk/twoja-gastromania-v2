import 'package:twoja_gastromania/tg_components/tg_ranking_info.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:twoja_gastromania/tg_services/watermark_service.dart';

/// One row of the /admin/revenue-config go-live checklist. [labelKey] is an i18n key.
typedef TGGoLiveCheck = ({String id, String labelKey, bool ok, bool blocking});

/// Launch readiness for paid visibility products (VITRIN-4). Modules whose flag
/// is off are skipped rather than reported.
List<TGGoLiveCheck> tgGoLiveChecks() {
  final rc = TGRevenueConfigService.instance;
  final cfg = PricingConfigService.instance.config;
  final promo = cfg.promotions;
  final flags = rc.flags;

  final promoPrices = [
    for (final t in PromotionTier.values)
      for (final d in const [14, 30]) promo.pricePln(t, d),
  ];
  final promoCaps = [for (final t in PromotionTier.values) promo.maxActive(t)];

  return [
    (id: 'production_mode', labelKey: 'ui_golive_production_mode', ok: rc.productionMode, blocking: true),
    (id: 'phase', labelKey: 'ui_golive_phase', ok: rc.config.phase >= 1, blocking: true),
    (id: 'promo_prices', labelKey: 'ui_golive_promo_prices', ok: promoPrices.every((p) => p > 0), blocking: true),
    (id: 'promo_capacity', labelKey: 'ui_golive_promo_capacity', ok: promoCaps.every((c) => c > 0), blocking: true),
    (id: 'ranking_disclosure', labelKey: 'ui_golive_ranking_disclosure', ok: rankingDisclosureComplete(), blocking: true),
    if (flags.sponsorSlots)
      (
        id: 'sponsor_prices',
        labelKey: 'ui_golive_sponsor_prices',
        ok: cfg.sponsorSlot.durations.every((k) => cfg.sponsorSlot.pricePln(k) > 0),
        blocking: true,
      ),
    if (flags.bannerAds)
      (
        id: 'banner_prices',
        labelKey: 'ui_golive_banner_prices',
        ok: cfg.banner.durations.every((k) => cfg.banner.pricePln(k) > 0),
        blocking: true,
      ),
    (
      id: 'listing_images',
      labelKey: 'ui_golive_listing_images',
      ok: TGListingImages.kDisableDynamicListingImages,
      blocking: true,
    ),
    (
      id: 'photo_license_clause',
      labelKey: 'ui_golive_photo_license',
      ok: !kPhotoLicenseClauseIsDraft,
      blocking: true,
    ),
    (
      id: 'home_manufacturers',
      labelKey: 'ui_golive_home_manufacturers',
      ok: TGSpecialOrderService.instance.manufacturers().length >= 3,
      blocking: false,
    ),
  ];
}
