import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/priority_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

/// Horizontally scrollable chip tabs (phones scroll instead of wrapping).
class DashTabBar extends StatelessWidget {
  const DashTabBar({
    super.key,
    required this.tabs,
    required this.current,
    required this.onSelect,
    required this.keyPrefix,
    required this.semanticsLabel,
  });

  final List<(String id, String label)> tabs;
  final String current;
  final ValueChanged<String> onSelect;
  final String keyPrefix;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: SingleChildScrollView(
        key: Key('$keyPrefix-tabs'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  selected: t.$1 == current,
                  child: ChoiceChip(
                    key: Key('$keyPrefix-tab-${t.$1}'),
                    label: Text(t.$2),
                    selected: t.$1 == current,
                    onSelected: (_) => onSelect(t.$1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bordered surface card used across DASH-3 pages.
class DashBox extends StatelessWidget {
  const DashBox({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: TGColors.surface,
        border: Border.all(color: borderColor ?? TGColors.border),
        borderRadius: BorderRadius.circular(TGRadius.card),
      ),
      child: child,
    );
  }
}

/// "Reach depends on traffic. We show real numbers."
class DashReachNote extends StatelessWidget {
  const DashReachNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      key: const Key('ads-reach-note'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(Icons.info_outline, size: 16, color: theme.secondaryText)),
        const SizedBox(width: 6),
        Expanded(child: Text(context.t('ads_reach_note'), style: theme.bodySmall.override(color: theme.secondaryText))),
      ],
    );
  }
}

/// Full-screen route on phones, centred dialog elsewhere.
Future<T?> showDashSheet<T>(BuildContext context, {required String title, required WidgetBuilder builder, Key? key, double maxWidth = 560}) {
  final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
  if (phone) {
    return Navigator.of(context).push<T>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        key: key,
        backgroundColor: FlutterFlowTheme.of(ctx).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(ctx).primaryBackground,
          title: Text(title, style: FlutterFlowTheme.of(ctx).titleMedium.override(fontWeight: FontWeight.w900)),
          leading: IconButton(tooltip: ctx.t('ui_close'), icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
        ),
        body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: builder(ctx))),
      ),
    ));
  }
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      key: key,
      backgroundColor: TGColors.surface,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: FlutterFlowTheme.of(ctx).titleMedium.override(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  IconButton(tooltip: ctx.t('ui_close'), icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              builder(ctx),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Preview of a generated file (CSV / invoice) with a copy action. The app has
/// no file-saving plugin, so the content is copied to the clipboard.
Future<void> showDashTextExport(BuildContext context, {required String title, required String fileName, required String content}) {
  return showDashSheet<void>(
    context,
    key: const Key('dash-export-sheet'),
    title: title,
    builder: (ctx) {
      final theme = FlutterFlowTheme.of(ctx);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(fileName, style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxHeight: 360),
            decoration: BoxDecoration(color: TGColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: TGColors.border)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: SelectableText(content, key: const Key('dash-export-content'), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('dash-export-copy'),
              style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: content));
                if (ctx.mounted) showTGToast(ctx, ctx.t('bill_copied'));
              },
              icon: const Icon(Icons.copy, size: 18),
              label: Text(ctx.t('bill_copy')),
            ),
          ),
        ],
      );
    },
  );
}

String tgPln(num v) => '${NumberFormat('#,##0.00', 'pl_PL').format(v)} PLN';

String tgTierName(PromotionTier t) => t.brand;

/// Every credit / discount the account really has: store-plan promotion
/// credits, Founder discount, Priority quiet-month extensions and billing credits.
class DashCreditsPanel extends StatelessWidget {
  const DashCreditsPanel({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final fmt = DateFormat('d MMM y', locale);
    final promo = PromotionService.instance.unusedCreditList(userId);
    final founder = TGFounderService.instance.activeDiscountRate(userId);
    final quiet = TGPriorityService.instance.priorityFor(userId).quietMonthCredits;
    final now = TGClock.now();
    final credits = TGBillingService.instance.creditsFor(userId).where((c) => c.isUsable(now)).toList();
    final empty = promo.isEmpty && founder <= 0 && quiet.isEmpty && credits.isEmpty;

    Widget row(Key key, IconData icon, String title, String sub) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DashBox(
            key: key,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ExcludeSemantics(child: Icon(icon, color: TGColors.cta)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(sub, style: theme.bodySmall.override(color: theme.secondaryText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Column(
      key: const Key('credits-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (empty)
          Text(context.t('bill_credits_empty'), key: const Key('credits-empty'), style: theme.bodyMedium.override(color: theme.secondaryText)),
        for (final c in promo)
          row(
            Key('credit-promo-${c.id}'),
            Icons.bolt,
            context.t('bill_credit_promo', {'tier': tgTierName(c.tier), 'n': '${c.durationDays}'}),
            context.t(c.periodKey == 'founder' ? 'bill_credit_promo_founder' : 'bill_credit_promo_period', {'p': c.periodKey}),
          ),
        if (founder > 0)
          row(
            const Key('credit-founder'),
            Icons.star_outline,
            context.t('bill_credit_founder', {'n': '${(founder * 100).round()}'}),
            context.t('bill_credit_founder_sub'),
          ),
        for (final q in quiet)
          row(
            Key('credit-quiet-${q.periodStart.millisecondsSinceEpoch}'),
            Icons.schedule,
            context.t('bill_credit_quiet'),
            context.t('bill_credit_quiet_sub', {'d': fmt.format(q.extendedUntil)}),
          ),
        for (final c in credits)
          row(
            Key('credit-${c.id}'),
            Icons.card_giftcard,
            context.t(c.titleKey),
            [
              if (c.amountPln > 0) tgPln(c.amountPln),
              if (c.percent > 0) '${c.percent}%',
              if (c.expiresAt != null) context.t('bill_credit_expires', {'d': fmt.format(c.expiresAt!)}),
            ].join(' · '),
          ),
      ],
    );
  }
}

/// Small status pill.
class DashPill extends StatelessWidget {
  const DashPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(TGRadius.pill),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

Color tgPaymentStatusColor(TGPaymentStatus s) => switch (s) {
      TGPaymentStatus.succeeded => TGColors.cta,
      TGPaymentStatus.failed => TGColors.error,
      TGPaymentStatus.refunded => TGColors.slaAmber,
    };
