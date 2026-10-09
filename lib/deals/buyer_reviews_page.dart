import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/deals/evidence_uploader.dart';
import 'package:twoja_gastromania/deals/review_composer.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_filter_menu.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';

class BuyerReviewsPage extends StatefulWidget {
  const BuyerReviewsPage({super.key, this.tab, this.reviewId, this.evidence = false, this.compose = false, this.listingNo});

  static const routeName = 'BuyerReviews';
  static const routePath = '/account/reviews';

  final String? tab;
  final String? reviewId;
  final bool evidence;
  final bool compose;
  final String? listingNo;

  @override
  State<BuyerReviewsPage> createState() => _BuyerReviewsPageState();
}

class _BuyerReviewsPageState extends State<BuyerReviewsPage> {
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void didUpdateWidget(covariant BuyerReviewsPage old) {
    super.didUpdateWidget(old);
    if (old.reviewId != widget.reviewId || old.evidence != widget.evidence || old.compose != widget.compose) {
      _opened = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    }
  }

  void _open() {
    if (!mounted || _opened) return;
    _opened = true;
    final auth = context.read<FakeAuthState>();
    DealService.instance.ensureSeeded();
    if (widget.compose) {
      showReviewComposer(context, listingNo: widget.listingNo);
      return;
    }
    final id = widget.reviewId;
    if (id == null || id.isEmpty) return;
    final review = DealService.instance.reviewById(id);
    if (review == null || review.authorId != auth.userId) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.t('ui_deal_access_denied')),
          content: Text(context.t('ui_deal_wrong_account')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('ui_close')))],
        ),
      );
      return;
    }
    if (widget.evidence) showEvidenceUploader(context, review);
  }

  @override
  Widget build(BuildContext context) {
    DealService.instance.ensureSeeded();
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final current = widget.tab ?? 'all';
    return TGPageScaffold(
      body: ListenableBuilder(
        listenable: DealService.instance,
        builder: (context, _) {
          final all = DealService.instance.reviewsForBuyer(auth.userId);
          final items = switch (current) {
            'awaiting' => all.where((r) => r.state == TGPurchaseReviewState.awaitingSeller).toList(),
            'evidence' => all.where((r) {
                if (r.state != TGPurchaseReviewState.suspendedObjection) return false;
                final obj = DealService.instance.objectionForReview(r.id);
                return obj == null || obj.status == TGObjectionStatus.awaitingEvidence;
              }).toList(),
            'decided' => all.where((r) => r.state == TGPurchaseReviewState.confirmed || r.state == TGPurchaseReviewState.confirmedModerator || r.state == TGPurchaseReviewState.notDisputed || r.state == TGPurchaseReviewState.notVerified || r.state == TGPurchaseReviewState.removed).toList(),
            _ => all,
          };
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(phone ? 16 : 24, 20, phone ? 16 : 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TGBreadcrumb(items: [
                        TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                        TGBreadcrumbItem(label: context.t('ui_your_reviews')),
                      ]),
                      const SizedBox(height: 12),
                      Text(context.t('ui_your_reviews'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      TGFilterMenu(
                        title: context.t('ui_your_reviews'),
                        currentId: current,
                        onSelect: (t) => TGNav.accountReviews(context, tab: t),
                        options: [
                          for (final t in const ['all', 'awaiting', 'evidence', 'decided'])
                            TGFilterOption(id: t, label: context.t('ui_rev_tab_$t')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        Text(context.t('ui_no_reviews'), style: theme.bodyMedium.override(color: theme.secondaryText))
                      else
                        for (final r in items) _ReviewRow(review: r),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review});
  final TGPurchaseReview review;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final deal = DealService.instance.byId(review.dealId);
    final obj = DealService.instance.objectionForReview(review.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: theme.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TGRadius.card), side: BorderSide(color: theme.tertiary)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(deal?.listingSnapshot.sellerName ?? 'Technica', style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                if (deal?.listingSnapshot.sellerVerified ?? true) ...[
                  const SizedBox(width: 6),
                  Text(context.t('ui_verified'), style: const TextStyle(color: TGColors.verified, fontSize: 10, fontWeight: FontWeight.w800)),
                ],
              ]),
              Text(review.listingTitleSnapshot, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
              Text(context.t('ui_listing_no_short', {'n': review.listingNo}), style: theme.bodySmall.override(color: theme.secondaryText)),
              const SizedBox(height: 6),
              Text(review.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.bodySmall),
              const SizedBox(height: 8),
              _chip(context, review, obj),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (review.state == TGPurchaseReviewState.suspendedObjection && (obj == null || obj.status == TGObjectionStatus.awaitingEvidence))
                    TextButton(onPressed: () => showEvidenceUploader(context, review), child: Text(context.t('ui_send_evidence'))),
                  if (review.canEdit) TextButton(onPressed: () => showReviewComposer(context, listingNo: review.listingNo), child: Text(context.t('ui_edit'))),
                  if (review.state == TGPurchaseReviewState.removed && !review.appealed)
                    TextButton(onPressed: () => _appeal(context, review), child: Text(context.t('ui_appeal'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, TGPurchaseReview review, TGObjection? obj) {
    final due = DealService.instance.byId(review.dealId)?.sellerAnswerDueAt;
    final days = due == null ? 0 : due.difference(TGClock.now()).inHours.clamp(0, 200) ~/ 24;
    final evLeft = obj == null ? '' : '${obj.evidenceDueAt.difference(TGClock.now()).inHours.clamp(0, 99)} h';
    final spec = switch (review.state) {
      TGPurchaseReviewState.awaitingSeller => (context.t('ui_rev_chip_awaiting', {'n': '$days'}), Icons.schedule, TGColors.slaAmber),
      TGPurchaseReviewState.confirmed => (context.t('ui_rev_chip_confirmed'), Icons.handshake, TGColors.cta),
      TGPurchaseReviewState.confirmedModerator => (context.t('ui_rev_chip_moderator'), Icons.verified_user, TGColors.cta),
      TGPurchaseReviewState.notDisputed => (context.t('ui_rev_chip_not_disputed'), Icons.schedule, TGColors.textSecondary),
      TGPurchaseReviewState.notVerified => (context.t('ui_rev_chip_not_verified'), Icons.info_outline, TGColors.textSecondary),
      TGPurchaseReviewState.suspendedObjection => obj?.status == TGObjectionStatus.awaitingEvidence
          ? (context.t('ui_rev_chip_evidence', {'n': evLeft}), Icons.upload_file, TGColors.slaAmber)
          : (context.t('ui_rev_chip_moderation'), Icons.search, TGColors.slaAmber),
      TGPurchaseReviewState.pendingCheck => (context.t('ui_rev_chip_checking'), Icons.gpp_maybe, TGColors.slaAmber),
      TGPurchaseReviewState.removed => (context.t('ui_rev_chip_removed'), Icons.block, TGColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: spec.$3), color: spec.$3.withValues(alpha: 0.12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(spec.$2, size: 14, color: spec.$3),
        const SizedBox(width: 6),
        Text(spec.$1, style: TextStyle(color: spec.$3, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  void _appeal(BuildContext context, TGPurchaseReview review) {
    final note = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('ui_appeal')),
        content: TextField(controller: note, maxLines: 4, decoration: InputDecoration(hintText: context.t('ui_appeal_note'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('ui_close'))),
          TextButton(
            onPressed: () {
              DealService.instance.appealRemoved(review, note: note.text);
              Navigator.pop(ctx);
            },
            child: Text(context.t('ui_submit_appeal')),
          ),
        ],
      ),
    );
  }
}
