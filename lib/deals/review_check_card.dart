import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';

class ReviewCheckCard extends StatefulWidget {
  const ReviewCheckCard({super.key, required this.deal, required this.review});
  final TGDeal deal;
  final TGPurchaseReview review;

  @override
  State<ReviewCheckCard> createState() => _ReviewCheckCardState();
}

class _ReviewCheckCardState extends State<ReviewCheckCard> {
  bool _keep = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final review = widget.review;
    final deal = widget.deal;
    final due = deal.sellerAnswerDueAt;
    final left = due == null ? 0 : due.difference(TGClock.now()).inDays.clamp(0, 5);
    final hidden = review.state == TGPurchaseReviewState.suspendedObjection;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: theme.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TGRadius.card), side: BorderSide(color: theme.tertiary)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('ui_reviewed_you', {'name': review.authorName, 'title': review.listingTitleSnapshot, 'n': review.listingNo}),
                style: theme.bodyMedium.override(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Row(children: [
                for (var i = 1; i <= 5; i++) Icon(i <= review.rating ? Icons.star : Icons.star_border, size: 16, color: TGColors.rating),
              ]),
              const SizedBox(height: 6),
              Text(review.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: theme.bodySmall),
              const SizedBox(height: 8),
              Text(
                hidden ? context.t('ui_review_hidden_checked') : context.t('ui_days_left_respond', {'n': '$left'}),
                style: theme.bodySmall.override(color: TGColors.slaAmber, fontWeight: FontWeight.w700),
              ),
              if (deal.unitRestoreUntil != null && TGClock.now().isBefore(deal.unitRestoreUntil!)) ...[
                const SizedBox(height: 8),
                Text(context.t('ui_deal_confirmed_another_unit'), style: theme.bodySmall),
                TextButton(
                  onPressed: () => DealService.instance.restoreUnit(deal),
                  child: Text(context.t('ui_i_have_another_unit')),
                ),
              ],
              if (!hidden && review.state == TGPurchaseReviewState.awaitingSeller) ...[
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: _keep,
                  onChanged: (v) => setState(() => _keep = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(context.t('ui_keep_listing_units'), style: theme.bodySmall),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TGButton(
                      key: Key('review-yes-${deal.id}'),
                      onPressed: () => DealService.instance.sellerConfirmReview(deal, keepListingActive: _keep),
                      label: context.t('ui_yes_sold_this_buyer'),
                      height: 44,
                      borderRadius: BorderRadius.circular(TGRadius.pill),
                    ),
                    const SizedBox(height: 8),
                    TGButton(
                      onPressed: () => showDisputeSheet(context, deal: deal, review: review, kind: TGObjectionKind.soldToOther),
                      label: context.t('ui_sold_to_someone_else'),
                      variant: TGButtonVariant.outline,
                      height: 44,
                      borderRadius: BorderRadius.circular(TGRadius.pill),
                    ),
                    const SizedBox(height: 8),
                    TGButton(
                      onPressed: () => showDisputeSheet(context, deal: deal, review: review, kind: TGObjectionKind.notSold),
                      label: context.t('ui_no_still_for_sale'),
                      variant: TGButtonVariant.outline,
                      height: 44,
                      borderRadius: BorderRadius.circular(TGRadius.pill),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showDisputeSheet(BuildContext context, {required TGDeal deal, required TGPurchaseReview review, required TGObjectionKind kind}) {
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  Widget sheet() => DisputeSheet(deal: deal, review: review, kind: kind, desktop: wide);
  if (wide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('ui_close'),
      barrierColor: Colors.black54,
      pageBuilder: (ctx, _, __) => sheet(),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.9, child: sheet()),
  );
}

class DisputeSheet extends StatefulWidget {
  const DisputeSheet({super.key, required this.deal, required this.review, required this.kind, required this.desktop});
  final TGDeal deal;
  final TGPurchaseReview review;
  final TGObjectionKind kind;
  final bool desktop;

  @override
  State<DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<DisputeSheet> {
  TGNotSoldReason _reason = TGNotSoldReason.stillForSale;
  final _note = TextEditingController();
  String? _realBuyerId;
  bool _attached = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final requiredEv = DealService.instance.evidenceRequiredFor(widget.deal.sellerId);
    final convos = DealService.instance.conversationsFor(widget.deal.listingNo);
    final body = Material(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('ui_dispute_this_deal'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(context.t('ui_dispute_help'), style: theme.bodySmall.override(color: theme.secondaryText)),
            const SizedBox(height: 12),
            if (widget.kind == TGObjectionKind.soldToOther) ...[
              Text(context.t('ui_name_real_buyer'), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
              for (final c in convos)
                RadioListTile<String>(
                  value: c.buyerId,
                  groupValue: _realBuyerId,
                  onChanged: (v) => setState(() => _realBuyerId = v),
                  title: Text(c.buyerName),
                ),
            ] else ...[
              DropdownButton<TGNotSoldReason>(
                value: _reason,
                isExpanded: true,
                items: [
                  for (final r in TGNotSoldReason.values)
                    DropdownMenuItem(value: r, child: Text(context.t('ui_not_sold_${r.name}'))),
                ],
                onChanged: (v) => setState(() => _reason = v ?? _reason),
              ),
              TextField(controller: _note, maxLength: 500, maxLines: 3, decoration: InputDecoration(hintText: context.t('ui_dispute_note'))),
            ],
            CheckboxListTile(
              value: _attached,
              onChanged: (v) => setState(() => _attached = v ?? false),
              title: Text(requiredEv ? context.t('ui_evidence_required_quota') : context.t('ui_attach_evidence_optional'), style: theme.bodySmall),
            ),
            Text(context.t('ui_dispute_warning'), style: theme.bodySmall.override(color: theme.secondaryText)),
            const SizedBox(height: 12),
            TGButton(
              key: const Key('dispute-submit'),
              onPressed: requiredEv && !_attached
                  ? null
                  : () {
                      DealService.instance.sellerDispute(
                        deal: widget.deal,
                        kind: widget.kind,
                        reason: widget.kind == TGObjectionKind.soldToOther ? 'sold_to_other' : _reason.name,
                        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                        sellerFiles: _attached
                            ? [
                                TGEvidence(
                                  id: 'tmp',
                                  dealId: widget.deal.id,
                                  uploaderRole: TGEvidenceRole.seller,
                                  type: TGEvidenceType.document,
                                  fileUrl: 'mock://seller/doc',
                                ),
                              ]
                            : const [],
                      );
                      Navigator.of(context).maybePop();
                    },
              label: context.t('ui_submit_dispute'),
              height: 48,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
          ],
        ),
      ),
    );
    if (!widget.desktop) return body;
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: body));
  }
}
