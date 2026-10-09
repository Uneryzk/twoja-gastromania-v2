import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';

class DealStatusChip extends StatelessWidget {
  const DealStatusChip({super.key, required this.status, this.verification});
  final TGDealStatus status;
  final TGDealVerification? verification;

  @override
  Widget build(BuildContext context) {
    final spec = _spec(context);
    return AnimatedSwitcher(
      duration: tgAnim(context, const Duration(milliseconds: 200)),
      child: Container(
        key: ValueKey('${status.name}-${verification?.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: spec.fill,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: spec.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, size: 14, color: spec.fg),
            const SizedBox(width: 6),
            Text(spec.label, style: TextStyle(color: spec.fg, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }

  ({String label, IconData icon, Color fg, Color border, Color fill}) _spec(BuildContext context) {
    if (status == TGDealStatus.approvedByModerator || verification == TGDealVerification.moderator) {
      return (label: context.t('ui_deal_chip_moderator'), icon: Icons.verified_user, fg: TGColors.cta, border: TGColors.cta, fill: Colors.transparent);
    }
    return switch (status) {
      TGDealStatus.pendingBuyer => (label: context.t('ui_deal_chip_waiting_buyer'), icon: Icons.schedule, fg: TGColors.slaAmber, border: TGColors.slaAmber, fill: TGColors.slaAmber.withValues(alpha: 0.12)),
      TGDealStatus.pendingSeller => (label: context.t('ui_deal_chip_waiting_seller'), icon: Icons.schedule, fg: TGColors.slaAmber, border: TGColors.slaAmber, fill: TGColors.slaAmber.withValues(alpha: 0.12)),
      TGDealStatus.confirmed => (label: context.t('ui_deal_chip_confirmed'), icon: Icons.handshake, fg: TGColors.cta, border: TGColors.cta, fill: Colors.transparent),
      TGDealStatus.declinedByBuyer || TGDealStatus.declinedBySeller || TGDealStatus.cancelled || TGDealStatus.rejectedByModerator => (
          label: context.t('ui_deal_chip_declined'),
          icon: Icons.close,
          fg: TGColors.textSecondary,
          border: TGColors.border,
          fill: TGColors.border.withValues(alpha: 0.25),
        ),
      TGDealStatus.expired => (label: context.t('ui_deal_chip_expired'), icon: Icons.timer_off, fg: TGColors.textSecondary, border: TGColors.border, fill: TGColors.border.withValues(alpha: 0.25)),
      TGDealStatus.inModeration => (label: context.t('ui_deal_chip_moderation'), icon: Icons.search, fg: TGColors.slaAmber, border: TGColors.slaAmber, fill: TGColors.slaAmber.withValues(alpha: 0.12)),
      TGDealStatus.approvedByModerator => (label: context.t('ui_deal_chip_moderator'), icon: Icons.verified_user, fg: TGColors.cta, border: TGColors.cta, fill: Colors.transparent),
      TGDealStatus.notDisputed => (label: context.t('ui_deal_chip_not_disputed'), icon: Icons.schedule, fg: TGColors.textSecondary, border: TGColors.border, fill: Colors.transparent),
      TGDealStatus.notVerified => (label: context.t('ui_deal_chip_not_verified'), icon: Icons.info_outline, fg: TGColors.textSecondary, border: TGColors.border, fill: TGColors.border.withValues(alpha: 0.25)),
    };
  }
}

class DealRow extends StatelessWidget {
  const DealRow({super.key, required this.deal, required this.sellerView, this.onConfirm, this.onOpen});
  final TGDeal deal;
  final bool sellerView;
  final VoidCallback? onConfirm;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final deals = DealService.instance;
    final acc = deal.buyerId == null ? null : deals.accountById(deal.buyerId!);
    final buyerLabel = deal.isConfirmed ? (acc?.displayName ?? deal.identifierMasked ?? '—') : (deal.identifierMasked ?? '—');
    final sellerLabel = deal.listingSnapshot.sellerName ?? 'Seller';
    final date = DateFormat('d MMM').format(deal.createdAt);
    final phone = MediaQuery.sizeOf(context).width < 520;
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: phone ? double.infinity : 72,
        height: phone ? 120 : 56,
        child: deal.listingSnapshot.imageUrl.isEmpty
            ? const ColoredBox(color: TGColors.border)
            : Image.asset(deal.listingSnapshot.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: TGColors.border)),
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(deal.listingSnapshot.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(context.t('ui_listing_no_short', {'n': deal.listingNo}), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 6),
        if (sellerView)
          Text(buyerLabel, style: theme.bodySmall.override(fontWeight: FontWeight.w700))
        else
          Row(
            children: [
              Flexible(child: Text(sellerLabel, style: theme.bodySmall.override(fontWeight: FontWeight.w700))),
              if (deal.listingSnapshot.sellerVerified) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: TGColors.verified.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
                  child: Text(context.t('ui_verified'), style: const TextStyle(color: TGColors.verified, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
        const SizedBox(height: 6),
        DealStatusChip(status: deal.status, verification: deal.verification),
        const SizedBox(height: 4),
        Text(date, style: theme.bodySmall.override(color: theme.secondaryText, fontSize: 12)),
        const SizedBox(height: 8),
        _Actions(deal: deal, sellerView: sellerView, onConfirm: onConfirm),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: theme.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TGRadius.card), side: BorderSide(color: theme.tertiary)),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(TGRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: phone
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [thumb, const SizedBox(height: 10), text])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [thumb, const SizedBox(width: 12), Expanded(child: text)]),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.deal, required this.sellerView, this.onConfirm});
  final TGDeal deal;
  final bool sellerView;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (!sellerView) {
      if (deal.status == TGDealStatus.pendingBuyer) {
        return Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onConfirm, child: Text(context.t('ui_answer_request'))),
        );
      }
      return const SizedBox.shrink();
    }
    final deals = DealService.instance;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (deal.waitingForBuyer) ...[
          TextButton(
            onPressed: _canResend(deal) ? () => deals.resendReminder(deal) : null,
            child: Text(context.t('ui_resend_reminder')),
          ),
          TextButton(
            onPressed: () => deals.cancel(deal, actorId: deal.sellerId),
            child: Text(context.t('ui_cancel_request')),
          ),
        ],
        if (deal.isConfirmed)
          deal.reviewRequestedAt == null
              ? TextButton(
                  onPressed: () => deals.requestReview(deal),
                  child: Text(context.t('ui_request_review')),
                )
              : Text(context.t('ui_review_requested_on', {'d': DateFormat('d MMM').format(deal.reviewRequestedAt!)}), style: theme.bodySmall),
      ],
    );
  }

  bool _canResend(TGDeal deal) {
    final last = deal.lastReminderAt;
    if (last == null) return true;
    return TGClock.now().difference(last).inDays >= 3;
  }
}
