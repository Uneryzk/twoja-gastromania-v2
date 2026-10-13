import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/referral_repository.dart';

/// Read-only snapshot. noindex is marked for crawlers; only aggregated seller data.
class RepShareReportPage extends StatelessWidget {
  const RepShareReportPage({super.key, required this.token});

  static const routeName = 'RepShareReport';
  static const routePath = '/r/:token';

  final String token;

  @override
  Widget build(BuildContext context) {
    final repo = ReferralRepository.instance..ensureSeeded();
    final link = repo.openShareLink(token);
    final report = link == null ? null : repo.reportById(link.reportId);
    final theme = FlutterFlowTheme.of(context);
    final loc = FFLocalizations.of(context).languageCode;
    return Scaffold(
      key: const Key('rep-share-page'),
      backgroundColor: TGColors.background,
      appBar: AppBar(title: Text(context.t('ref_share_title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: link == null || report == null
                ? Text(context.t('ref_link_expired'), key: const Key('rep-share-expired'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        container: true,
                        label: 'noindex',
                        child: Text(context.t('ref_share_noindex'), style: theme.labelSmall.override(color: theme.secondaryText)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t('ref_snapshot_as_of', {'date': DateFormat('d MMM', loc).format(report.snapshotAt)}),
                        style: theme.titleLarge.override(fontWeight: FontWeight.w900),
                      ),
                      Text('${DateFormat.yMMMd(loc).format(report.from)} – ${DateFormat.yMMMd(loc).format(report.to)}'),
                      const SizedBox(height: 16),
                      Text(report.views.hasValue ? context.t('ref_fact_views', {'n': '${report.views.value}'}) : context.t('ref_not_enough')),
                      Text('${context.t('ref_col_listings')}: ${report.listingCount.hasValue ? report.listingCount.value : context.t('ref_not_enough')}'),
                      Text('${context.t('ref_metric_calls')}: ${report.callTaps.hasValue ? report.callTaps.value : context.t('ref_not_enough')}'),
                      Text('${context.t('ref_metric_messages')}: ${report.messages.hasValue ? report.messages.value : context.t('ref_not_enough')}'),
                      Text('${context.t('ref_metric_favorites')}: ${report.favorites.hasValue ? report.favorites.value : context.t('ref_not_enough')}'),
                      if (report.topListingTitle != null)
                        Text('${context.t('ref_top_listing')}: ${report.topListingTitle} · ${report.topListingNo}'),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
