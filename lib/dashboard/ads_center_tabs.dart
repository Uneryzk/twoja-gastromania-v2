import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/dashboard/dash3_widgets.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_restaurant_showcase.dart';
import 'package:twoja_gastromania/tg_components/tg_showcase_section.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/sponsor_slot_service.dart';

String _ctr(int impressions, int clicks) => impressions == 0 ? '—' : '${(clicks * 100 / impressions).toStringAsFixed(1)}%';

/// Impressions · clicks · CTR, always from the real counters.
class AdsCounters extends StatelessWidget {
  const AdsCounters({super.key, required this.impressions, required this.clicks});
  final int impressions;
  final int clicks;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Text(
      context.t('ads_counters', {'i': '$impressions', 'c': '$clicks', 'ctr': _ctr(impressions, clicks)}),
      style: theme.bodySmall.override(fontWeight: FontWeight.w700),
    );
  }
}

Future<bool> confirmStopEarly(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('ads-stop-dialog'),
      title: Text(ctx.t('ads_stop_title')),
      content: Text(ctx.t('ads_stop_body')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
        FilledButton(
          key: const Key('ads-stop-confirm'),
          style: FilledButton.styleFrom(backgroundColor: TGColors.error, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.t('ads_stop_cta')),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Products / restaurants the user can promote, plus a title resolver for rows.
class AdsTargets {
  AdsTargets(this.auth, this.catalogue);
  final FakeAuthState auth;
  final Map<String, TGProduct> catalogue;

  List<TGProduct> get products {
    final seen = <String>{};
    return [
      for (final p in [...auth.ownedListings, ...ModerationService.instance.sellerListings, ...catalogue.values.where((p) => p.ownerId == auth.userId)])
        if (p.isActive && seen.add(p.id)) p,
    ];
  }

  List<RestaurantListing> get restaurants =>
      RestaurantService.instance.ownedBy(auth.userId).where((r) => r.status == RestaurantListingStatus.active).toList();

  TGProduct? product(String id) =>
      catalogue[id] ?? [...auth.ownedListings, ...ModerationService.instance.sellerListings].where((p) => p.id == id).firstOrNull;

  String titleOf(Promotion p) => switch (p.targetKind) {
        PromotionTargetKind.listing => product(p.targetRef)?.title ?? p.targetRef,
        PromotionTargetKind.restaurant => RestaurantService.instance.byId(p.targetRef)?.title ?? p.targetRef,
        PromotionTargetKind.manufacturer => TGSellerProfileService.instance.resolve(p.targetRef)?.name ?? p.targetRef,
      };
}

void _trackPromoAdd(Promotion p) => TGAnalytics.track('promo_add', {
      'promotionId': p.id,
      'tier': p.tier.name,
      'days': p.durationDays,
      'targetKind': p.targetKind.name,
      'source': 'ads_center',
    });

Future<void> showPromoteSheet(BuildContext context, {TGProduct? product, RestaurantListing? restaurant}) {
  return showDashSheet<void>(
    context,
    key: const Key('ads-promote-sheet'),
    title: product?.title ?? restaurant?.title ?? '',
    maxWidth: 1040,
    builder: (ctx) {
      void done(Promotion p) {
        _trackPromoAdd(p);
        Navigator.of(ctx).pop();
        showTGToast(context, context.t('ads_promo_added'));
      }

      return product != null
          ? TGShowcaseSection(product: product, onPurchased: done, onDismissed: () => Navigator.of(ctx).pop())
          : TGRestaurantShowcaseSection(listing: restaurant!, onPurchased: done, onDismissed: () => Navigator.of(ctx).pop());
    },
  );
}

/// Pick a listing, then the regular Showcase flow (tier + duration + payment).
Future<void> showAddPromotionSheet(BuildContext context, AdsTargets targets) {
  return showDashSheet<void>(
    context,
    key: const Key('ads-add-sheet'),
    title: context.t('ads_add_promo'),
    builder: (ctx) {
      final products = targets.products;
      final restos = targets.restaurants;
      if (products.isEmpty && restos.isEmpty) {
        return Text(ctx.t('ads_add_none'), key: const Key('ads-add-none'));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ctx.t('ads_add_pick'), style: FlutterFlowTheme.of(ctx).bodySmall),
          const SizedBox(height: 8),
          for (final p in products)
            ListTile(
              key: Key('ads-add-pick-${p.id}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(ctx).pop();
                showPromoteSheet(context, product: p);
              },
            ),
          for (final r in restos)
            ListTile(
              key: Key('ads-add-pick-${r.id}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restaurant_outlined),
              title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(ctx).pop();
                showPromoteSheet(context, restaurant: r);
              },
            ),
        ],
      );
    },
  );
}

class AdsPromotionsTab extends StatelessWidget {
  const AdsPromotionsTab({super.key, required this.targets});
  final AdsTargets targets;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = PromotionService.instance;
    final userId = targets.auth.userId;
    final now = TGClock.now();
    final items = svc.forOwner(userId)..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    final glowLeft = svc.unusedCreditsOf(userId, PromotionTier.glow);
    final pro = targets.auth.storePlan == TGStorePlanKind.pro;
    final usage = svc.proCreditUsage(userId);
    final credits = glowLeft > 0
        ? context.t(glowLeft == 1 ? 'uyum_glow_credit_left_one' : 'uyum_glow_credits_left', {'n': '$glowLeft'})
        : null;
    return Column(
      key: const Key('ads-promotions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: const Key('ads-add-promo'),
              style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
              onPressed: () => showAddPromotionSheet(context, targets),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.t('ads_add_promo')),
            ),
            if (credits != null)
              Semantics(
                label: pro ? '$credits. ${context.t('uyum_glow_used', {'used': '${usage.used}', 'total': '${usage.total}'})}' : credits,
                excludeSemantics: true,
                child: Text(
                  pro ? '$credits · ${context.t('uyum_glow_used', {'used': '${usage.used}', 'total': '${usage.total}'})}' : credits,
                  key: const Key('ads-glow-credits'),
                  style: theme.bodySmall.override(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _TierSummary(items: items, now: now),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(context.t('ui_promo_none'), key: const Key('ads-promos-empty'), style: theme.bodyMedium.override(color: theme.secondaryText))
        else
          for (final p in items) Padding(padding: const EdgeInsets.only(bottom: 10), child: _PromoCard(p: p, targets: targets)),
      ],
    );
  }
}

/// Bold / Glow / Spotlight: how many of the owner's promotions are live or
/// scheduled per tier.
class _TierSummary extends StatelessWidget {
  const _TierSummary({required this.items, required this.now});
  final List<Promotion> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final tier in PromotionTier.values)
          Builder(builder: (context) {
            final live = items.where((p) => p.tier == tier && p.status == PromotionStatus.active && p.isActiveAt(now)).length;
            final sched = items.where((p) => p.tier == tier && p.status == PromotionStatus.scheduled).length;
            final label = context.t('uyum_tier_summary', {'tier': tier.brand, 'live': '$live', 'sched': '$sched'});
            return Semantics(
              label: label,
              excludeSemantics: true,
              child: DashPill(
                key: Key('ads-tier-${tier.name}'),
                label: label,
                color: live > 0 ? TGColors.cta : theme.secondaryText,
              ),
            );
          }),
      ],
    );
  }
}

/// "N days left" while live, "starts in N days" while scheduled.
String? promoTimeLeft(BuildContext context, Promotion p, DateTime now) {
  int days(Duration d) => (d.inHours / 24).ceil().clamp(0, 9999);
  if (p.status == PromotionStatus.scheduled && now.isBefore(p.startsAt)) {
    return context.t('uyum_starts_in', {'n': '${days(p.startsAt.difference(now))}'});
  }
  if (p.status == PromotionStatus.active && p.isActiveAt(now)) {
    return context.t('ui_days_left_text', {'n': '${days(p.endsAt.difference(now))}'});
  }
  return null;
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.p, required this.targets});
  final Promotion p;
  final AdsTargets targets;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = PromotionService.instance;
    final now = TGClock.now();
    final totals = svc.totalsFor(p.id);
    final fmt = DateFormat('d MMM y', Localizations.localeOf(context).languageCode);
    final live = p.isActiveAt(now);
    final left = promoTimeLeft(context, p, now);
    final statusColor = switch (p.status) {
      PromotionStatus.active => TGColors.cta,
      PromotionStatus.scheduled => TGColors.slaAmber,
      _ => theme.secondaryText,
    };
    final product = p.targetKind == PromotionTargetKind.listing ? targets.product(p.targetRef) : null;
    final resto = p.targetKind == PromotionTargetKind.restaurant ? RestaurantService.instance.byId(p.targetRef) : null;
    final canRepromote = (product?.isActive ?? false) || resto?.status == RestaurantListingStatus.active;
    return DashBox(
      key: Key('ads-promo-${p.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${tgTierName(p.tier)} · ${targets.titleOf(p)}', style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
              DashPill(label: context.t('ads_status_${p.status.name}'), color: statusColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${fmt.format(p.startsAt)} – ${fmt.format(p.endsAt)}',
            style: theme.bodySmall.override(color: theme.secondaryText),
          ),
          if (left != null || p.source == PromotionSource.proIncluded || p.source == PromotionSource.founderCredit) ...[
            const SizedBox(height: 2),
            Text(
              [
                if (left != null) left,
                if (p.source == PromotionSource.proIncluded || p.source == PromotionSource.founderCredit) context.t('uyum_src_credit'),
              ].join(' · '),
              key: Key('ads-promo-left-${p.id}'),
              style: theme.bodySmall.override(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 4),
          AdsCounters(key: Key('ads-promo-counters-${p.id}'), impressions: totals.impressions, clicks: totals.clicks),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (live)
                TextButton(
                  key: Key('ads-promo-stop-${p.id}'),
                  onPressed: () async {
                    if (!await confirmStopEarly(context)) return;
                    final err = svc.stopEarly(p.id, ownerId: targets.auth.userId);
                    if (context.mounted) showTGToast(context, context.t(err ?? 'ads_stopped'));
                  },
                  child: Text(context.t('ads_stop_cta'), style: const TextStyle(color: TGColors.error)),
                ),
              if (!live && p.status != PromotionStatus.scheduled && canRepromote)
                TextButton(
                  key: Key('ads-promo-again-${p.id}'),
                  onPressed: () => showPromoteSheet(context, product: product, restaurant: product == null ? resto : null),
                  child: Text(context.t('ui_promo_add')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdsSponsorTab extends StatelessWidget {
  const AdsSponsorTab({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGSponsorSlotService.instance;
    final slots = svc.forSeller(userId).where((s) => s.status != TGSponsorSlotStatus.available).toList();
    final fmt = DateFormat('d MMM y', Localizations.localeOf(context).languageCode);
    final now = TGClock.now();
    return Column(
      key: const Key('ads-sponsor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('ads-sponsor-book'),
            onPressed: () => context.go('/dashboard/manufacturer'),
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.t('ads_sponsor_book')),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          container: true,
          label: context.t('uyum_sponsor_prices'),
          child: Wrap(
            key: const Key('ads-sponsor-prices'),
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final d in svc.pricing.durations)
                DashPill(
                  key: Key('ads-sponsor-price-$d'),
                  label: '${context.t('ui_duration_days_price', {'days': '$d', 'fee': '${svc.priceFor(d)}'})} · '
                      '${PricingConfigService.instance.config.perDayLabel(svc.priceFor(d), d)}',
                  color: theme.secondaryText,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (slots.isEmpty)
          Text(context.t('ads_sponsor_empty'), key: const Key('ads-sponsor-empty'), style: theme.bodyMedium.override(color: theme.secondaryText))
        else
          for (final s in slots)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Builder(builder: (context) {
                final c = svc.countersFor(s.id);
                final live = s.status == TGSponsorSlotStatus.active && s.endsAt != null && now.isBefore(s.endsAt!);
                return DashBox(
                  key: Key('ads-sponsor-${s.id}'),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('${context.t('ui_so_spec_${s.specialty.name}')} · ${s.region}', style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                          DashPill(label: context.t('ads_slot_${s.status.name}'), color: live ? TGColors.cta : theme.secondaryText),
                        ],
                      ),
                      if ((s.title ?? '').isNotEmpty) Text(s.title!, style: theme.bodySmall),
                      if (s.startsAt != null && s.endsAt != null)
                        Text('${fmt.format(s.startsAt!)} – ${fmt.format(s.endsAt!)}', style: theme.bodySmall.override(color: theme.secondaryText)),
                      const SizedBox(height: 4),
                      AdsCounters(key: Key('ads-sponsor-counters-${s.id}'), impressions: c.impressions, clicks: c.clicks),
                      if (live)
                        TextButton(
                          key: Key('ads-sponsor-stop-${s.id}'),
                          onPressed: () async {
                            if (!await confirmStopEarly(context)) return;
                            final err = svc.stopByOwner(s.id, sellerId: userId);
                            if (context.mounted) showTGToast(context, context.t(err ?? 'ads_stopped'));
                          },
                          child: Text(context.t('ads_stop_cta'), style: const TextStyle(color: TGColors.error)),
                        ),
                    ],
                  ),
                );
              }),
            ),
      ],
    );
  }
}
