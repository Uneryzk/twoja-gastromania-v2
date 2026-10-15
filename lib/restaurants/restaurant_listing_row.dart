import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/listing_images_editor.dart';
import 'package:twoja_gastromania/dashboard/dash2_widgets.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/restaurants/restaurant_renew_sheet.dart';
import 'package:twoja_gastromania/restaurants/restaurant_transfer_sheet.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_user_text.dart';
import 'package:twoja_gastromania/tg_components/tg_watermarked_image.dart';
import 'package:twoja_gastromania/tg_models/tg_watermark.dart';
import 'package:twoja_gastromania/tg_core/restaurant_config.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_services/ad_slot_service.dart';
import 'package:twoja_gastromania/tg_services/listing_stats_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_lifecycle_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

class RestaurantListingRow extends StatelessWidget {
  const RestaurantListingRow({super.key, required this.listing});
  final RestaurantListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final r = listing;
    final cfg = RestaurantConfigService.instance.config;
    final expired = r.status == RestaurantListingStatus.expired;
    final days = r.daysUntilExpiry(TGClock.now());
    final free = r.source == RestaurantListingSource.freeIntro;
    final life = RestaurantLifecycleService.instance;
    final canRenew = life.canOfferRenew(r);
    final amber = r.status == RestaurantListingStatus.active && days <= cfg.renewEarlyDays;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TGFocusRing(
        child: Material(
          color: TGColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TGRadius.card),
            side: BorderSide(color: TGColors.border),
          ),
          child: InkWell(
            onTap: () => context.go(r.detailPath),
            borderRadius: BorderRadius.circular(TGRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 96,
                          height: 72,
                          child: WatermarkedImage(url: r.imageUrl, surface: TGImageSurface.listingCard, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TGUserText(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                            Text(context.t('ui_listing_no_short', {'n': r.listingNo}), style: theme.bodySmall.override(color: theme.secondaryText)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _chip(context.t('dash_type_restaurant'), theme.primaryText),
                                _chip(_statusLabel(context, r), amber ? TGColors.rating : theme.primary),
                                if (free) _chip(context.t('ui_chip_free'), TGColors.cta),
                                if (r.status == RestaurantListingStatus.active) ListingPromoStatus(restaurant: r),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _timer(context, r, free, days, amber, theme),
                            const SizedBox(height: 6),
                            Text(
                              context.t('ui_metrics_vcf', {
                                'v': '${r.engagement.views}',
                                'c': '${r.engagement.uniqueContacts}',
                                'f': '${r.engagement.uniqueFavorites}',
                              }),
                              style: theme.bodySmall.override(fontWeight: FontWeight.w700),
                            ),
                            if (r.publishedAt != null) ...[
                              const SizedBox(height: 4),
                              ListingMetricsStrip(listingKey: TGListingStatsService.keyOfRestaurant(r)),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        key: Key('resto-more-${r.id}'),
                        onSelected: (v) {
                          TGAnalytics.track('listing_action', {'action': v, 'listingId': r.id, 'kind': 'restaurant'});
                          if (v == 'insights') {
                            showListingInsights(
                              context,
                              listingKey: TGListingStatsService.keyOfRestaurant(r),
                              title: r.title,
                              listingNo: r.listingNo,
                              liveSince: r.publishedAt,
                              promotion: PromotionService.instance.effectiveRestaurantPromo(r),
                            );
                          }
                          if (v == 'images') {
                            final fresh = RestaurantService.instance.byId(r.id) ?? r;
                            showListingImagesEditor(context, restaurant: fresh);
                          }
                          if (v == 'transfer') showRestaurantTransferFlow(context, r);
                          if (v == 'remove') {
                            showRestaurantTransferFlow(context, r, mode: RestoCloseMode.removeListing);
                          }
                          if (v == 'renew') showRestaurantRenewSheet(context, r, early: !expired && canRenew);
                          if (v == 'promote') showRestaurantRenewSheet(context, r, promoteOnly: true);
                          if (v == 'banner') context.go('/dashboard/advertising?target=${Uri.encodeComponent(r.detailPath)}');
                        },
                        itemBuilder: (_) => [
                          if (r.publishedAt != null) PopupMenuItem(value: 'insights', child: Text(context.t('dash_insights_open'))),
                          PopupMenuItem(value: 'images', child: Text(context.t('ui_image_change'))),
                          if (canRenew || expired) PopupMenuItem(value: 'renew', child: Text(context.t('ui_renew'))),
                          if (r.status == RestaurantListingStatus.active) PopupMenuItem(value: 'promote', child: Text(context.t('ui_promote'))),
                          if (r.status == RestaurantListingStatus.active && AdSlotService.instance.purchaseVisible) PopupMenuItem(value: 'banner', child: Text(context.t('ui_banner_ad'))),
                          if (r.status == RestaurantListingStatus.active) PopupMenuItem(value: 'transfer', child: Text(context.t('ui_mark_transferred'))),
                          PopupMenuItem(value: 'remove', child: Text(context.t('ui_remove_listing'))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (expired)
                        TGButton(
                          onPressed: () => showRestaurantRenewSheet(context, r),
                          label: context.t('ui_renew_pln', {'fee': '${cfg.paidPricePln}'}),
                          height: 40,
                          borderRadius: BorderRadius.circular(TGRadius.pill),
                        )
                      else if (canRenew)
                        TGButton(
                          onPressed: () => showRestaurantRenewSheet(context, r, early: true),
                          label: context.t('ui_renew_early'),
                          variant: TGButtonVariant.outline,
                          height: 40,
                          borderRadius: BorderRadius.circular(TGRadius.pill),
                        ),
                      if (r.status == RestaurantListingStatus.active)
                        PopupMenuButton<String>(
                          tooltip: context.t('ui_promote'),
                          onSelected: (v) {
                            if (v == 'promote') showRestaurantRenewSheet(context, r, promoteOnly: true);
                            if (v == 'banner') context.go('/dashboard/advertising?target=${Uri.encodeComponent(r.detailPath)}');
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'promote', child: Text(context.t('ui_promote_listing'))),
                            if (AdSlotService.instance.purchaseVisible) PopupMenuItem(value: 'banner', child: Text(context.t('ui_banner_ad'))),
                          ],
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(TGRadius.pill)),
                            child: Text(context.t('ui_promote'), style: theme.bodySmall.override(fontWeight: FontWeight.w800, color: theme.primary)),
                          ),
                        ),
                      if (r.status == RestaurantListingStatus.pendingAuthorization)
                        TGButton(
                          onPressed: () {
                            context.read<FakeAuthState>();
                            showTGAuthProofSheet(context, r);
                          },
                          label: context.t('ui_auth_needed_upload'),
                          height: 40,
                          borderRadius: BorderRadius.circular(TGRadius.pill),
                        ),
                      if (r.status == RestaurantListingStatus.paymentPending)
                        TGButton(
                          onPressed: () => context.go('/restaurants/new?resume=${r.id}'),
                          label: context.t('ui_resume'),
                          height: 40,
                          borderRadius: BorderRadius.circular(TGRadius.pill),
                        ),
                      if (r.status == RestaurantListingStatus.draft)
                        TGButton(
                          onPressed: () => context.go('/restaurants/new?resume=${r.id}'),
                          label: context.t('ui_continue_draft'),
                          variant: TGButtonVariant.outline,
                          height: 40,
                          borderRadius: BorderRadius.circular(TGRadius.pill),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timer(BuildContext context, RestaurantListing r, bool free, int days, bool amber, FlutterFlowTheme theme) {
    final expired = r.status == RestaurantListingStatus.expired;
    final left = context.t('ui_days_left_n', {'n': '$days'});
    final label = expired
        ? context.t('ui_filter_expired')
        : free
            ? '${context.t('ui_chip_free')} · $left'
            : left;
    final total = free ? RestaurantConfigService.instance.config.freeDays : RestaurantConfigService.instance.config.paidDays;
    final value = expired ? 0.0 : (days / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 4,
            backgroundColor: TGColors.border,
            color: amber || expired ? TGColors.rating : TGColors.cta,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.bodySmall.override(color: amber || expired ? TGColors.rating : theme.secondaryText, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );

  String _statusLabel(BuildContext context, RestaurantListing r) => switch (r.status) {
        RestaurantListingStatus.active => context.t('ui_status_active'),
        RestaurantListingStatus.expired => context.t('ui_filter_expired'),
        RestaurantListingStatus.draft => context.t('ui_status_draft'),
        RestaurantListingStatus.paymentPending => context.t('ui_payment_pending'),
        RestaurantListingStatus.pendingAuthorization => context.t('ui_pending_authorization'),
        RestaurantListingStatus.underReview => context.t('ui_under_review'),
        RestaurantListingStatus.sold => context.t('ui_status_transferred'),
        RestaurantListingStatus.removed => context.t('ui_removed_badge'),
      };
}

Future<void> showTGAuthProofSheet(BuildContext context, RestaurantListing listing) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ctx.t('ui_upload_auth_proof'), style: FlutterFlowTheme.of(ctx).titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(ctx.t('ui_auth_proof_hint')),
          const SizedBox(height: 16),
          TGButton(
            onPressed: () {
              RestaurantService.instance.attachAuthorizationProof(
                listing.id,
                'auth_proof_${DateTime.now().millisecondsSinceEpoch}.pdf',
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('ui_proof_uploaded_mock'))));
            },
            label: ctx.t('ui_upload_document'),
            height: 48,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
        ],
      ),
    ),
  );
}
