import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/restaurants/restaurant_renew_sheet.dart';
import 'package:twoja_gastromania/restaurants/restaurant_transfer_sheet.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_core/restaurant_config.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/ad_slot_service.dart';
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
      child: Material(
        color: TGColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TGRadius.card),
          side: const BorderSide(color: TGColors.border),
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
                        child: TGSmartImage(url: r.imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                          Text('No. ${r.listingNo}', style: theme.bodySmall.override(color: theme.secondaryText)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _chip('Restaurant', theme.primaryText),
                              _chip(_statusLabel(r), amber ? TGColors.rating : theme.primary),
                              if (free) _chip('FREE', TGColors.cta),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _timer(r, free, days, amber, theme),
                          const SizedBox(height: 6),
                          Text(
                            'Views ${r.engagement.views} · Contacts ${r.engagement.uniqueContacts} · Favorites ${r.engagement.uniqueFavorites}',
                            style: theme.bodySmall.override(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'transfer') showRestaurantTransferFlow(context, r);
                        if (v == 'remove') {
                          showRestaurantTransferFlow(context, r, mode: RestoCloseMode.removeListing);
                        }
                        if (v == 'renew') showRestaurantRenewSheet(context, r, early: !expired && canRenew);
                        if (v == 'promote') showRestaurantRenewSheet(context, r, promoteOnly: true);
                        if (v == 'banner') context.go('/dashboard/advertising?target=${Uri.encodeComponent(r.detailPath)}');
                      },
                      itemBuilder: (_) => [
                        if (canRenew || expired) const PopupMenuItem(value: 'renew', child: Text('Renew')),
                        if (r.status == RestaurantListingStatus.active)
                          const PopupMenuItem(value: 'promote', child: Text('Promote')),
                        if (r.status == RestaurantListingStatus.active && AdSlotService.instance.purchaseVisible)
                          const PopupMenuItem(value: 'banner', child: Text('Banner ad')),
                        if (r.status == RestaurantListingStatus.active)
                          const PopupMenuItem(value: 'transfer', child: Text('Mark as transferred')),
                        const PopupMenuItem(value: 'remove', child: Text('Remove')),
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
                        label: 'Renew · ${cfg.paidPricePln} PLN',
                        height: 40,
                        borderRadius: BorderRadius.circular(TGRadius.pill),
                      )
                    else if (canRenew)
                      TGButton(
                        onPressed: () => showRestaurantRenewSheet(context, r, early: true),
                        label: 'Renew early',
                        variant: TGButtonVariant.outline,
                        height: 40,
                        borderRadius: BorderRadius.circular(TGRadius.pill),
                      ),
                    if (r.status == RestaurantListingStatus.active)
                      PopupMenuButton<String>(
                        tooltip: 'Promote',
                        onSelected: (v) {
                          if (v == 'promote') showRestaurantRenewSheet(context, r, promoteOnly: true);
                          if (v == 'banner') context.go('/dashboard/advertising?target=${Uri.encodeComponent(r.detailPath)}');
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'promote', child: Text('Promote listing')),
                          if (AdSlotService.instance.purchaseVisible)
                            const PopupMenuItem(value: 'banner', child: Text('Banner ad')),
                        ],
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(TGRadius.pill)),
                          child: Text('Promote', style: theme.bodySmall.override(fontWeight: FontWeight.w800, color: theme.primary)),
                        ),
                      ),
                    if (r.status == RestaurantListingStatus.pendingAuthorization)
                      TGButton(
                        onPressed: () {
                          context.read<FakeAuthState>();
                          showTGAuthProofSheet(context, r);
                        },
                        label: 'Authorization needed · upload proof',
                        height: 40,
                        borderRadius: BorderRadius.circular(TGRadius.pill),
                      ),
                    if (r.status == RestaurantListingStatus.paymentPending)
                      TGButton(
                        onPressed: () => context.go('/restaurants/new?resume=${r.id}'),
                        label: 'Resume',
                        height: 40,
                        borderRadius: BorderRadius.circular(TGRadius.pill),
                      ),
                    if (r.status == RestaurantListingStatus.draft)
                      TGButton(
                        onPressed: () => context.go('/restaurants/new?resume=${r.id}'),
                        label: 'Continue draft',
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
    );
  }

  Widget _timer(RestaurantListing r, bool free, int days, bool amber, FlutterFlowTheme theme) {
    final expired = r.status == RestaurantListingStatus.expired;
    final label = expired
        ? 'Expired'
        : free
            ? 'FREE · $days days left'
            : '$days days left';
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

  String _statusLabel(RestaurantListing r) => switch (r.status) {
        RestaurantListingStatus.active => 'Active',
        RestaurantListingStatus.expired => 'Expired',
        RestaurantListingStatus.draft => 'Draft',
        RestaurantListingStatus.paymentPending => 'Payment pending',
        RestaurantListingStatus.pendingAuthorization => 'Pending authorization',
        RestaurantListingStatus.underReview => 'Under review',
        RestaurantListingStatus.sold => 'Transferred',
        RestaurantListingStatus.removed => 'Removed',
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
          Text('Upload proof of authorization', style: FlutterFlowTheme.of(ctx).titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Lease page, owner letter, or agent (pośrednik) contract. Only moderators can see this file.'),
          const SizedBox(height: 16),
          TGButton(
            onPressed: () {
              RestaurantService.instance.attachAuthorizationProof(
                listing.id,
                'auth_proof_${DateTime.now().millisecondsSinceEpoch}.pdf',
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proof uploaded (mock) — awaiting review')));
            },
            label: 'Upload document',
            height: 48,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
        ],
      ),
    ),
  );
}
