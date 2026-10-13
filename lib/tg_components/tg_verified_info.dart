import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_verified_seller.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_review_verified.dart';
import 'package:twoja_gastromania/tg_services/review_verified_service.dart';

/// "Based on 14 reviews, 1 negative (7%)".
String tgReviewStatsLine(BuildContext context, TGReviewStats s) => context.t('ver_stats_line', {'n': '${s.counted}', 'neg': '${s.negatives}', 'pct': '${s.negativePercent}'});

/// Basis-specific tooltip for the green shield, or null when not verified.
String? tgVerifiedTooltip(BuildContext context, TGSeller seller) {
  return switch (tgVerifiedBasis(seller)) {
    TGVerifiedBasis.companyRegistry => context.t('ver_tip_company'),
    TGVerifiedBasis.buyerReviews => '${context.t('ver_tip_reviews')} ${tgReviewStatsLine(context, TGReviewVerifiedService.instance.statsFor(seller.id))}',
    null => null,
  };
}

void tgTrackVerifiedInfoOpen(TGSeller seller, String surface) {
  final basis = tgVerifiedBasis(seller);
  if (basis == null) return;
  TGAnalytics.track('verified_info_open', {'sellerId': seller.id, 'basis': basis.wire, 'surface': surface});
}

Future<void> showTGVerifiedInfo(BuildContext context, TGSeller seller, {required String surface}) {
  tgTrackVerifiedInfoOpen(seller, surface);
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: TGColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(tooltip: ctx.t('ui_close'), icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
              Padding(padding: const EdgeInsets.only(right: 8), child: TGVerifiedInfoBox(seller: seller)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Seller detail info box explaining why the shield is shown.
class TGVerifiedInfoBox extends StatelessWidget {
  const TGVerifiedInfoBox({super.key, required this.seller});
  final TGSeller seller;

  @override
  Widget build(BuildContext context) {
    final basis = tgVerifiedBasis(seller);
    if (basis == null) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);
    final reviews = basis == TGVerifiedBasis.buyerReviews;
    final title = context.t(reviews ? 'ver_box_reviews_title' : 'ver_box_company_title');
    final lines = <String>[
      if (reviews) tgReviewStatsLine(context, TGReviewVerifiedService.instance.statsFor(seller.id)),
      context.t(reviews ? 'ver_box_reviews_body' : 'ver_box_company_body'),
      context.t('ver_not_purchasable'),
    ];
    return Semantics(
      container: true,
      label: '$title. ${lines.join(' ')}',
      excludeSemantics: true,
      child: Container(
        key: Key('verified-info-${basis.wire}'),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(TGRadius.input),
          border: Border.all(color: theme.success.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user, color: theme.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                  for (final l in lines) ...[
                    const SizedBox(height: 4),
                    Text(l, style: theme.bodySmall.override(color: theme.secondaryText)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Green shield icon with a basis tooltip; tap opens the info box.
class TGVerifiedShield extends StatelessWidget {
  const TGVerifiedShield({super.key, required this.seller, this.surface = 'card', this.size = 16});
  final TGSeller seller;
  final String surface;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tip = tgVerifiedTooltip(context, seller);
    if (tip == null) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);
    return Tooltip(
      message: tip,
      onTriggered: () => tgTrackVerifiedInfoOpen(seller, '$surface.tooltip'),
      child: Semantics(
        button: true,
        label: tip,
        excludeSemantics: true,
        child: InkResponse(
          key: Key('verified-shield-${seller.id}'),
          radius: size,
          onTap: () => showTGVerifiedInfo(context, seller, surface: surface),
          child: Icon(Icons.verified_user, size: size, color: theme.success),
        ),
      ),
    );
  }
}
