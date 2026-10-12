import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/audit_service.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/special_review_service.dart';

/// Turquoise outline pill — not green (Verified) and not pink (classification).
class AuditedManufacturerBadge extends StatelessWidget {
  const AuditedManufacturerBadge({super.key, required this.sellerId, this.compact = false});
  final String sellerId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    TGAuditService.instance.ensureSeeded();
    final theme = FlutterFlowTheme.of(context);
    final app = TGAuditService.instance.activeFor(sellerId);
    if (app == null) return const SizedBox.shrink();
    final valid = app.validUntil != null ? TGFounderService.fmtDate(app.validUntil!) : '—';

    return InkWell(
      onTap: () => _showWhatWeChecked(context, valid),
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: theme.primary, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fact_check_outlined, size: compact ? 14 : 16, color: theme.primary),
            const SizedBox(width: 4),
            Text(
              context.t('ui_audited_manufacturer'),
              style: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w800, color: theme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWhatWeChecked(BuildContext context, String validUntil) async {
    final theme = FlutterFlowTheme.of(context);
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final app = TGAuditService.instance.activeFor(sellerId);
    final lines = <String>[
      context.t('ui_audit_check_krs'),
      context.t('ui_audit_check_workshop'),
      context.t('ui_audit_check_video'),
      context.t('ui_audit_check_insurance'),
      context.t('ui_audit_check_refs'),
      context.t('ui_audit_check_docs'),
      if (app?.hadLiveVisit == true) context.t('ui_audit_check_visit'),
      context.t('ui_audit_valid_until', {'d': validUntil}),
    ];
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('ui_audit_what_checked'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Icons.check, size: 16, color: theme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(line)),
            ]),
          ),
        const SizedBox(height: 8),
        Text(
          context.t('ui_audit_disclaimer'),
          style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.35),
        ),
      ],
    );

    if (phone) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: theme.secondaryBackground,
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(ctx).bottom),
          child: body,
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(ctx)},
          child: AlertDialog(
            content: body,
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('ui_close')))],
          ),
        ),
      );
    }
  }
}

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
