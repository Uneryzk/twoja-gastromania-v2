import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_services/audit_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

class AdminAuditsPage extends StatefulWidget {
  const AdminAuditsPage({super.key});
  @override
  State<AdminAuditsPage> createState() => _AdminAuditsPageState();
}

class _AdminAuditsPageState extends State<AdminAuditsPage> {
  String? _openId;

  @override
  void initState() {
    super.initState();
    TGAuditService.instance.ensureSeeded();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final svc = TGAuditService.instance;
    final queue = svc.applications.where((a) => a.status != TGAuditApplicationStatus.revoked).toList();

    return ListView(
      padding: EdgeInsets.all(phone ? 12 : 20),
      children: [
        Text(context.t('ui_admin_audits_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(context.t('ui_admin_audits_sub'), style: theme.bodySmall),
        const SizedBox(height: 16),
        for (final a in queue)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: theme.tertiary), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TGSellerProfileService.instance.bySellerKey(a.sellerId)?.name ?? a.sellerId,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text('${a.status.name} · ${a.id}${a.validUntil != null ? " · until ${a.validUntil!.toIso8601String().substring(0, 10)}" : ""}'),
                TextButton(
                  onPressed: () {
                    svc.logView(a.id, auth.displayName);
                    setState(() => _openId = _openId == a.id ? null : a.id);
                  },
                  child: Text(_openId == a.id ? context.t('ui_admin_hide_case') : context.t('ui_admin_open_case')),
                ),
                if (_openId == a.id) _CaseBody(app: a, onChanged: () => setState(() {})),
              ],
            ),
          ),
      ],
    );
  }
}

class _CaseBody extends StatelessWidget {
  const _CaseBody({required this.app, required this.onChanged});
  final TGAuditApplication app;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final svc = TGAuditService.instance;
    final video = app.workshopVideo;
    final hints = svc.liveVisitHints(app);
    final fmt = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(context.t('ui_admin_workshop_video'), style: const TextStyle(fontWeight: FontWeight.w800)),
        if (video == null)
          Text(context.t('ui_admin_no_video'))
        else ...[
          Container(
            height: 140,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
            child: Text(
              video.kind == TGAuditVideoKind.file
                  ? '▶ File player (mock)\n${video.fileUrl}'
                  : '▶ Sandboxed embed (mock)\n${video.linkUrl}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          if (video.kind == TGAuditVideoKind.link)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: theme.primary), borderRadius: BorderRadius.circular(99)),
              child: Text(context.t('ui_admin_external_link_note'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          const SizedBox(height: 8),
          Text(context.t('ui_admin_expected_code', {'code': video.challengeCode}), style: const TextStyle(fontWeight: FontWeight.w900)),
          Wrap(
            spacing: 4,
            children: [
              for (final m in TGAuditCodeMatch.values)
                ChoiceChip(
                  label: Text(switch (m) {
                    TGAuditCodeMatch.matches => context.t('ui_admin_code_matches'),
                    TGAuditCodeMatch.doesntMatch => context.t('ui_admin_code_no_match'),
                    TGAuditCodeMatch.cantTell => context.t('ui_admin_code_cant_tell'),
                  }),
                  selected: app.codeMatch == m,
                  onSelected: (_) {
                    svc.setCodeMatch(app.id, m);
                    onChanged();
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text(context.t('ui_admin_checklist'), style: const TextStyle(fontWeight: FontWeight.w800)),
        for (final c in app.checklist)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(c.label),
            subtitle: Text('${c.result.name}${c.note != null ? " · ${c.note}" : ""}'),
            trailing: PopupMenuButton<TGAuditCheckResult>(
              onSelected: (v) {
                svc.setChecklistItem(app.id, c.id, v);
                onChanged();
              },
              itemBuilder: (_) => [for (final r in TGAuditCheckResult.values) PopupMenuItem(value: r, child: Text(r.name))],
            ),
          ),
        if (video?.kind == TGAuditVideoKind.link)
          CheckboxListTile(
            value: app.linkAckChecked,
            onChanged: (v) {
              svc.setLinkAck(app.id, v ?? false);
              onChanged();
            },
            title: Text(context.t('ui_admin_link_ack')),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        if (hints.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(context.t('ui_admin_hints_human'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
          Wrap(
            spacing: 6,
            children: [
              for (final h in hints)
                Chip(
                  label: Text(context.t('ui_admin_consider_visit', {'h': h}), style: const TextStyle(fontSize: 11)),
                  backgroundColor: theme.alternate,
                ),
            ],
          ),
        ],
        if (app.viewLog.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(context.t('ui_admin_views'), style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final v in app.viewLog.take(5))
            Text(context.t('ui_admin_viewed_by', {'viewer': v.viewer, 'at': fmt.format(v.at)}), style: theme.bodySmall),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            TGButton(
              onPressed: !app.canApprove
                  ? null
                  : () async {
                      final note = await _dlg(context, context.t('ui_approve'));
                      if (note == null || note.isEmpty) return;
                      final prev = app.status;
                      try {
                        svc.decide(applicationId: app.id, status: TGAuditApplicationStatus.approved, actorId: auth.userId, note: note);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                        return;
                      }
                      onChanged();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.t('ui_admin_approved')),
                        duration: const Duration(seconds: 10),
                        action: SnackBarAction(
                          label: context.t('ui_undo'),
                          onPressed: () {
                            app.status = prev;
                            onChanged();
                          },
                        ),
                      ));
                    },
              label: context.t('ui_approve'),
              height: 40,
            ),
            TGButton(
              onPressed: () async {
                final note = await _dlg(context, context.t('ui_reject'));
                if (note == null || note.isEmpty) return;
                svc.decide(applicationId: app.id, status: TGAuditApplicationStatus.rejected, actorId: auth.userId, note: note);
                onChanged();
              },
              label: context.t('ui_reject'),
              height: 40,
              variant: TGButtonVariant.outline,
            ),
            TGButton(
              onPressed: () async {
                final note = await _dlg(
                  context,
                  context.t('ui_admin_request_more_docs_title'),
                  template: context.t('ui_admin_request_more_docs_tpl'),
                );
                if (note == null || note.isEmpty) return;
                svc.requestMoreDocuments(applicationId: app.id, actorId: auth.userId, note: note, days: 5);
                onChanged();
              },
              label: context.t('ui_admin_request_more_docs'),
              height: 40,
              variant: TGButtonVariant.ghost,
            ),
            TGButton(
              onPressed: () async {
                final note = await _dlg(
                  context,
                  context.t('ui_admin_request_live_visit'),
                  template: context.t('ui_admin_request_live_visit_tpl'),
                );
                if (note == null || note.isEmpty) return;
                svc.requestLiveVisit(applicationId: app.id, actorId: auth.userId, reason: note);
                onChanged();
              },
              label: context.t('ui_admin_request_live_visit'),
              height: 40,
              variant: TGButtonVariant.outline,
            ),
            if (app.status == TGAuditApplicationStatus.visitScheduled)
              TGButton(
                onPressed: () {
                  svc.markVisitDone(app.id, notes: 'Visit completed — notes (mock)');
                  onChanged();
                },
                label: context.t('ui_admin_mark_visit_done'),
                height: 40,
              ),
            if (app.badgeActive)
              TGButton(
                onPressed: () async {
                  final note = await _dlg(context, context.t('ui_admin_revoke'));
                  if (note == null || note.isEmpty) return;
                  svc.revoke(applicationId: app.id, actorId: auth.userId, reason: note);
                  onChanged();
                },
                label: context.t('ui_admin_revoke'),
                height: 40,
                variant: TGButtonVariant.ghost,
              ),
          ],
        ),
        if (svc.auditLog.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(context.t('ui_admin_audit_log_section'), style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final e in svc.auditLog.where((e) => e.detail == app.id || (e.detail?.contains(app.id) ?? false)).take(6))
            Text('${e.action} · ${e.actorId}', style: theme.bodySmall),
        ],
      ],
    );
  }

  Future<String?> _dlg(BuildContext context, String title, {String? template}) async {
    final c = TextEditingController(text: template ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: c,
              maxLines: 4,
              decoration: InputDecoration(labelText: ctx.t('ui_admin_reason_message')),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(ctx.t('ui_admin_audit_email_preview')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('ui_cancel'))),
          TGButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), label: ctx.t('ui_confirm'), height: 40),
        ],
      ),
    );
  }
}

class AdminAuditsHost extends StatelessWidget {
  const AdminAuditsHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'audits', child: AdminAuditsPage());
}
