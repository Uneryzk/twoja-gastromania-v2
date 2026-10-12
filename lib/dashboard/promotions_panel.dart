import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

/// DASH-3 Promotions tab — real impressions/clicks, Add / Upgrade / Extend.
class TGPromotionsPanel extends StatelessWidget {
  const TGPromotionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final svc = PromotionService.instance..ensureSeeded();
    final items = svc.forOwner(auth.userId);
    final credits = svc.unusedCredits(auth.userId);
    final now = TGClock.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_reach_disclaimer'), style: theme.bodySmall.override(color: theme.secondaryText)),
        if (credits > 0) ...[
          const SizedBox(height: 8),
          Text(context.t('ui_pro_credits_n', {'n': '$credits'}), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        ],
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(context.t('ui_promo_none'), style: theme.bodyMedium)
        else
          for (final p in items) ...[
            _PromoRow(promotion: p, now: now),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _PromoRow extends StatelessWidget {
  const _PromoRow({required this.promotion, required this.now});
  final Promotion promotion;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final totals = PromotionService.instance.totalsFor(promotion.id);
    final left = promotion.endsAt.difference(now).inDays.clamp(0, 9999);
    final tier = promotion.tier.name[0].toUpperCase() + promotion.tier.name.substring(1);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.tertiary),
        borderRadius: BorderRadius.circular(TGRadius.card),
        color: theme.secondaryBackground,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$tier · ${promotion.status.name}', style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
              ),
              if (promotion.status == PromotionStatus.active)
                Text(context.t('ui_days_left_text', {'n': '$left'}), style: theme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${totals.impressions} impressions · ${totals.clicks} clicks',
            style: theme.bodySmall.override(color: theme.secondaryText),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (promotion.status == PromotionStatus.active || promotion.status == PromotionStatus.scheduled)
                TextButton(onPressed: () {}, child: Text(context.t('ui_promo_upgrade'))),
              if (promotion.status == PromotionStatus.active)
                TextButton(onPressed: () {}, child: Text(context.t('ui_promo_extend'))),
              if (promotion.status == PromotionStatus.ended)
                TextButton(onPressed: () {}, child: Text(context.t('ui_promo_add'))),
            ],
          ),
        ],
      ),
    );
  }
}
