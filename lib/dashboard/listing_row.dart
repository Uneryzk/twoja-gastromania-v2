import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/dashboard/seller_moderation_sheets.dart';
import 'package:twoja_gastromania/deals/sold_flow_sheet.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';

class ListingRow extends StatelessWidget {
  const ListingRow({super.key, required this.product, this.onRenew, this.onRenewEarly, this.onResume});
  final TGProduct product;
  final VoidCallback? onRenew;
  final VoidCallback? onRenewEarly;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final expired = product.status == TGListingStatus.expired;
    final meta = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        if (product.listingNo != null) ...[
          const SizedBox(height: 2),
          Text(context.t('ui_listing_no_short', {'n': product.listingNo!}), style: theme.bodySmall.override(color: theme.secondaryText, fontSize: 12)),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _SourceTag(product: product),
            _StatusChip(product: product),
            if (ModerationService.instance.sellerCaseFor(product.listingNo)?.replyBy != null)
              _ReplyByChip(at: ModerationService.instance.sellerCaseFor(product.listingNo)!.replyBy!),
            if (product.status == TGListingStatus.removed && ModerationService.instance.sellerCaseFor(product.listingNo)?.shortReason != null)
              Text(ModerationService.instance.sellerCaseFor(product.listingNo)!.shortReason!, style: const TextStyle(fontSize: 11, color: TGColors.error, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        ListingTimer(product: product),
      ],
    );
    Widget info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 96,
            height: 72,
            child: product.imageUrl.isEmpty
                ? const ColoredBox(color: TGColors.border)
                : Image.asset(product.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: TGColors.border)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: meta),
      ],
    );
    Widget fade(Widget child) => Opacity(
          opacity: 0.6,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: child,
          ),
        );
    if (expired) {
      info = fade(info);
    }
    final fadedMeta = expired ? fade(meta) : meta;
    final pending = product.status == TGListingStatus.paymentPending;
    final sellerCase = ModerationService.instance.sellerCaseFor(product.listingNo);
    final auth = context.read<FakeAuthState>();
    Widget? action = pending && onResume != null
        ? TGButton(
            key: Key('dashboard-resume-${product.id}'),
            onPressed: onResume,
            label: context.t('ui_resume'),
            height: 44,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          )
        : expired && onRenew != null
            ? TGButton(
                key: Key('dashboard-renew-${product.id}'),
                onPressed: onRenew,
                label: context.t('ui_renew_pln', {'fee': '${TGPricing.listingFeePln}'}),
                height: 44,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              )
            : (product.isExpiringSoon && onRenewEarly != null
                ? TGButton(
                    key: Key('dashboard-renew-early-${product.id}'),
                    onPressed: onRenewEarly,
                    label: context.t('ui_renew_early'),
                    variant: TGButtonVariant.outline,
                    height: 44,
                    borderRadius: BorderRadius.circular(TGRadius.pill),
                  )
                : null);
    if (sellerCase != null && sellerCase.soldNudge && !sellerCase.soldResolved) {
      action = Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(context.t('ui_still_for_sale'), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
          TextButton(
            key: Key('dashboard-did-you-sell-${product.id}'),
            onPressed: () => showSoldFlow(context, product, mode: SoldFlowMode.markSold),
            child: Text(context.t('ui_did_you_sell')),
          ),
          TGButton(
            key: Key('dashboard-keep-live-${product.id}'),
            onPressed: () => ModerationService.instance.keepListingLive(product.listingNo ?? product.id, actorId: auth.userId),
            label: context.t('ui_keep_live'),
            variant: TGButtonVariant.outline,
            height: 40,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
          TGButton(
            key: Key('dashboard-mark-sold-${product.id}'),
            onPressed: () => showSoldFlow(context, product, mode: SoldFlowMode.markSold),
            label: context.t('ui_mark_sold'),
            height: 40,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
        ],
      );
    } else if (sellerCase != null && product.status == TGListingStatus.underReview) {
      action = TGButton(
        key: Key('dashboard-respond-${product.id}'),
        onPressed: () => showSellerRespondSheet(context, sellerCase),
        label: context.t('ui_respond'),
        height: 44,
        borderRadius: BorderRadius.circular(TGRadius.pill),
      );
    } else if (sellerCase != null && product.status == TGListingStatus.removed) {
      action = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TGButton(
            key: Key('dashboard-removed-details-${product.id}'),
            onPressed: () => showSellerRemovalSheet(context, sellerCase),
            label: context.t('ui_view_details'),
            variant: TGButtonVariant.outline,
            height: 40,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
          if (!sellerCase.appealed && !sellerCase.finalRemoval)
            TGButton(
              key: Key('dashboard-appeal-${product.id}'),
              onPressed: () => showSellerAppealSheet(context, sellerCase),
              label: context.t('ui_appeal'),
              height: 40,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
        ],
      );
    }
    final more = product.status == TGListingStatus.active || product.status == TGListingStatus.expired
        ? PopupMenuButton<String>(
            key: Key('listing-more-${product.id}'),
            tooltip: context.t('ui_more'),
            onSelected: (v) {
              if (v == 'sold') showSoldFlow(context, product, mode: SoldFlowMode.markSold);
              if (v == 'remove') showSoldFlow(context, product, mode: SoldFlowMode.removeListing);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'sold', child: Text(context.t('ui_mark_sold'))),
              PopupMenuItem(value: 'remove', child: Text(context.t('ui_remove_listing'))),
            ],
          )
        : null;
    final narrow = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    if (narrow) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Material(
          color: TGColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TGRadius.card), side: const BorderSide(color: TGColors.border)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => context.go(product.detailPath),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: product.imageUrl.isEmpty
                            ? const ColoredBox(color: TGColors.border)
                            : Image.asset(product.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: TGColors.border)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    fadedMeta,
                  ],
                ),
              ),
              if (action != null || more != null)
                Row(
                  children: [
                    if (action != null) Expanded(child: action) else const Spacer(),
                    if (more != null) more,
                  ],
                ),
            ],
          ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => context.go(product.detailPath),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: info),
            if (action != null) ...[const SizedBox(width: 8), action],
            if (more != null) more,
          ],
        ),
      ),
    );
  }
}

class ListingTimer extends StatelessWidget {
  const ListingTimer({super.key, required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    if (product.status == TGListingStatus.draft || product.status == TGListingStatus.paymentPending) {
      return const SizedBox.shrink();
    }
    final theme = FlutterFlowTheme.of(context);
    final expired = product.status == TGListingStatus.expired;
    final days = expired ? product.daysSinceExpiry() : product.daysUntilExpiry();
    final expiring = product.isExpiringSoon;
    final label = expired
        ? context.t('ui_expired_ago', {'n': '$days'})
        : (days <= 0 ? 'Ends today, ${DateTime.now().difference(product.expiresAt ?? DateTime.now()).inHours.abs()} h' : context.t('ui_days_left_n', {'n': '$days'}));
    final value = expired ? 0.0 : (product.daysUntilExpiry() / TGPricing.listingPeriodDays).clamp(0.0, 1.0);
    final color = expired
        ? TGColors.border
        : (expiring ? TGColors.rating : theme.primary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 4,
            backgroundColor: TGColors.border,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.bodySmall.override(color: expiring || expired ? TGColors.rating : theme.secondaryText, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    final text = switch (product.source) {
      TGListingSource.free => context.t('ui_source_free', {'n': '${product.freeSlotIndex ?? 1}'}),
      TGListingSource.paid => context.t('ui_source_paid'),
      TGListingSource.store => context.t('ui_source_store'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: TGColors.border), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    late final Color border;
    late final String label;
    IconData? icon;
    if (product.status == TGListingStatus.expired) {
      border = TGColors.border;
      label = context.t('ui_filter_expired');
      icon = Icons.pause_circle_outline;
    } else if (product.isExpiringSoon) {
      border = TGColors.rating;
      label = context.t('ui_filter_expiring');
      icon = Icons.schedule;
    } else if (product.status == TGListingStatus.paymentPending) {
      border = TGColors.accent;
      label = context.t('ui_payment_pending');
    } else if (product.status == TGListingStatus.underReview) {
      border = TGColors.slaAmber;
      label = context.t('ui_under_review');
      icon = Icons.gpp_maybe_outlined;
    } else if (product.status == TGListingStatus.removed) {
      border = TGColors.error;
      final fin = ModerationService.instance.sellerCaseFor(product.listingNo)?.finalRemoval ?? false;
      label = context.t(fin ? 'ui_removed_final' : 'ui_removed_badge');
      icon = Icons.block;
    } else if (product.status == TGListingStatus.draft) {
      border = TGColors.border;
      label = context.t('ui_status_draft');
    } else {
      border = theme.primary;
      label = context.t('ui_status_active');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: border), const SizedBox(width: 4)],
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: border),
          ),
        ],
      ),
    );
  }
}

class _ReplyByChip extends StatelessWidget {
  const _ReplyByChip({required this.at});
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final label = context.t('ui_reply_by', {'d': DateFormat('d MMM', locale).format(at)});
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: TGColors.slaAmber),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: TGColors.slaAmber)),
    );
  }
}
