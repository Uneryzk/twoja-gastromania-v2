import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

const kRankingInfoKeys = [
  'ranking_info_link',
  'ranking_info_heading',
  'ranking_info_scope_listings',
  'ranking_info_scope_special',
  'ranking_info_listings',
  'ranking_info_special',
  'ranking_info_paid',
];

/// Go-live: every ranking key is translated in every locale and the paid
/// paragraph quotes the exact FEATURED badge shown on cards in that locale.
bool rankingDisclosureComplete() {
  for (final l in FFLocalizations.languages()) {
    for (final k in kRankingInfoKeys) {
      if ((kUiTranslations[k]?[l] ?? '').isEmpty) return false;
    }
    final badge = kUiTranslations['badge.featured']?[l] ?? '';
    if (badge.isEmpty || !kUiTranslations['ranking_info_paid']![l]!.contains(badge)) return false;
  }
  return true;
}

/// "How sorting works" — 480 px modal on desktop, bottom sheet on phones.
Future<void> showTGRankingInfo(BuildContext context, {required String surface}) {
  TGAnalytics.track('ranking_info_open', {'surface': surface});
  final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
  if (phone) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(TGRadius.modal))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
          child: TGRankingInfoBody(surface: surface),
        ),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: TGColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TGRadius.modal)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: TGRankingInfoBody(surface: surface),
      ),
    ),
  );
}

/// Products/restaurants explain seller rating → newest; special order explains
/// projects, rating and response time; the footer shows both.
class TGRankingInfoBody extends StatelessWidget {
  const TGRankingInfoBody({super.key, required this.surface});
  final String surface;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final both = surface != 'products' && surface != 'restaurants' && surface != 'special_order';
    Widget para(String key) => Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 12),
          child: Text(context.t(key), key: Key('ranking-info-$key'), style: theme.bodyMedium.override(lineHeight: 1.5)),
        );
    Widget scope(String key) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Semantics(header: true, child: Text(context.t(key), style: theme.titleSmall.override(fontWeight: FontWeight.w800))),
        );
    return SingleChildScrollView(
      key: const Key('ranking-info-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(context.t('ranking_info_heading'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                ),
              ),
              IconButton(
                tooltip: context.t('ui_close'),
                icon: Icon(Icons.close, color: theme.secondaryText),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          if (both) scope('ranking_info_scope_listings'),
          if (both || surface != 'special_order') para('ranking_info_listings'),
          if (both) scope('ranking_info_scope_special'),
          if (both || surface == 'special_order') para('ranking_info_special'),
          para('ranking_info_paid'),
        ],
      ),
    );
  }
}

/// "How sorting works" link next to sort controls.
class TGRankingInfoLink extends StatelessWidget {
  const TGRankingInfoLink({super.key, required this.surface, this.compact = false});

  /// `products`, `restaurants`, `special_order` or `footer` (analytics + test keys).
  final String surface;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: Key('ranking-info-link-$surface'),
      onPressed: () => showTGRankingInfo(context, surface: surface),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
        visualDensity: compact ? VisualDensity.compact : null,
      ),
      icon: const Icon(Icons.info_outline, size: 18),
      label: Text(context.t('ranking_info_link'), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
