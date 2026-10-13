import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_services/special_review_service.dart';

/// "Custom projects: 4.8 (12)" — quality signal from buyer reviews.
class CustomProjectsRatingLine extends StatelessWidget {
  const CustomProjectsRatingLine({super.key, required this.sellerId});
  final String sellerId;

  @override
  Widget build(BuildContext context) {
    TGSpecialReviewService.instance.ensureSeeded();
    final theme = FlutterFlowTheme.of(context);
    final summary = TGSpecialReviewService.instance.summaryFor(sellerId);
    if (summary.completedCount <= 0) return const SizedBox.shrink();
    final line = summary.countedCount >= 3 && summary.average != null
        ? context.t('ui_custom_projects_rated', {
            'avg': summary.average!.toStringAsFixed(1),
            'n': '${summary.completedCount}',
          })
        : context.t('ui_custom_projects_count', {'n': '${summary.completedCount}'});
    return Text(line, style: theme.bodySmall.override(fontWeight: FontWeight.w700));
  }
}
