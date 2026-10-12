import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

class AdminFoundersPage extends StatefulWidget {
  const AdminFoundersPage({super.key});

  @override
  State<AdminFoundersPage> createState() => _AdminFoundersPageState();
}

class _AdminFoundersPageState extends State<AdminFoundersPage> {
  String? _detailId;

  @override
  void initState() {
    super.initState();
    TGFounderService.instance.ensureSeeded();
  }

  Future<String?> _note(String title, {String? hint}) async {
    final c = TextEditingController();
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
              decoration: InputDecoration(labelText: hint ?? ctx.t('ui_reason')),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Text(ctx.t('ui_admin_founder_email_preview'), style: FlutterFlowTheme.of(ctx).bodySmall.override(fontWeight: FontWeight.w800)),
            Text(ctx.t('ui_admin_founder_email_body'), style: FlutterFlowTheme.of(ctx).bodySmall),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('ui_cancel'))),
          TGButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), label: ctx.t('ui_confirm'), height: 40),
        ],
      ),
    );
  }

  void _decide(TGFounderApplication app, TGFounderApplicationStatus status, FakeAuthState auth) async {
    final note = await _note(status.name);
    if (note == null || note.isEmpty) return;
    final prev = app.status;
    TGFounderService.instance.decide(
      applicationId: app.id,
      status: status,
      actorId: auth.userId,
      note: note,
      auth: auth,
    );
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${status.name} — $note'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: context.t('ui_undo'),
          onPressed: () {
            TGFounderService.instance.decide(
              applicationId: app.id,
              status: prev,
              actorId: auth.userId,
              note: 'Undo',
              auth: auth,
            );
            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final svc = TGFounderService.instance;
    final report = svc.report();
    final queue = svc.applications.where((a) => a.status == TGFounderApplicationStatus.applied || a.status == TGFounderApplicationStatus.waitlisted).toList();
    final participants = svc.bySeller.entries.where((e) => e.value.enrolled).toList();

    return ListView(
      padding: EdgeInsets.all(phone ? 12 : 20),
      children: [
        Text(context.t('ui_admin_founders_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          context.t('ui_admin_founder_quota', {
            'taken': '${svc.spotsTaken}',
            'quota': '${svc.cfg.quota}',
            'wait': svc.quotaFull ? context.t('ui_admin_waitlist_open') : '',
          }),
          style: theme.titleSmall.override(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          context.t('ui_admin_founder_report', {
            'founders': '${report.founders}',
            'qualified': '${report.qualifiedListings}',
            'sales': '${report.discountSales}',
            'list': '${report.listTotal}',
            'paid': '${report.paidTotal}',
            'delta': '${report.listTotal - report.paidTotal}',
          }),
          style: theme.bodySmall,
        ),
        const SizedBox(height: 20),
        Text(context.t('ui_admin_app_queue'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (queue.isEmpty)
          Text(context.t('ui_admin_no_pending_apps'), style: theme.bodySmall)
        else if (phone)
          for (final a in queue) _appCard(context, a, auth, detail: true)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text(context.t('ui_company'))),
                const DataColumn(label: Text('NIP')),
                DataColumn(label: Text(context.t('ui_admin_profile_pct'))),
                DataColumn(label: Text(context.t('ui_admin_projects'))),
                DataColumn(label: Text(context.t('ui_admin_call'))),
                DataColumn(label: Text(context.t('ui_admin_nip_dup'))),
                DataColumn(label: Text(context.t('ui_status'))),
                DataColumn(label: Text(context.t('ui_admin_actions'))),
              ],
              rows: [
                for (final a in queue)
                  DataRow(cells: [
                    DataCell(Text(a.companyName ?? a.sellerId)),
                    DataCell(Text(a.nip)),
                    DataCell(Text('${a.profileCompletePct}%')),
                    DataCell(Text('${a.referenceProjectsCount}')),
                    DataCell(Text(a.feedbackCallDone ? '✓' : '—')),
                    DataCell(Text(
                      svc.nipAlreadyUsed(a.nip, exceptSellerId: a.sellerId)
                          ? context.t('ui_admin_nip_duplicate')
                          : context.t('ui_admin_nip_ok'),
                    )),
                    DataCell(Text(a.status.name)),
                    DataCell(Wrap(spacing: 4, children: [
                      TextButton(onPressed: () => _decide(a, TGFounderApplicationStatus.approved, auth), child: Text(context.t('ui_approve'))),
                      TextButton(onPressed: () => _decide(a, TGFounderApplicationStatus.rejected, auth), child: Text(context.t('ui_reject'))),
                      TextButton(onPressed: () => _decide(a, TGFounderApplicationStatus.waitlisted, auth), child: Text(context.t('ui_admin_waitlist'))),
                    ])),
                  ]),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text(context.t('ui_admin_participants'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        for (final e in participants)
          phone
              ? _participantCard(context, e.key, e.value, auth)
              : ListTile(
                  title: Text(
                    TGSellerProfileService.instance.bySellerKey(e.key)?.name ?? e.key,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'tier ${e.value.tier} · qualified ${e.value.qualifiedCount} · '
                    'free ${e.value.freeUntil != null ? TGFounderService.fmtDate(e.value.freeUntil!) : "—"} · '
                    'ends ${e.value.programEndsAt != null ? TGFounderService.fmtDate(e.value.programEndsAt!) : "—"}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final note = await _note(context.t('ui_admin_manual_tier'), hint: context.t('ui_admin_manual_tier_hint'));
                          if (note == null || note.isEmpty) return;
                          final tier = int.tryParse(note.split(' ').first) ?? e.value.tier;
                          TGFounderService.instance.setTierManual(sellerId: e.key, tier: tier, actorId: auth.userId, reason: note);
                          setState(() {});
                        },
                        child: Text(context.t('ui_admin_tier')),
                      ),
                      TextButton(
                        onPressed: () async {
                          final note = await _note(context.t('ui_admin_end_program'));
                          if (note == null || note.isEmpty) return;
                          TGFounderService.instance.endProgram(sellerId: e.key, actorId: auth.userId, reason: note);
                          setState(() {});
                        },
                        child: Text(context.t('ui_admin_end')),
                      ),
                      TextButton(
                        onPressed: () async {
                          final note = await _note(context.t('ui_admin_extend_program'), hint: context.t('ui_admin_extend_hint'));
                          if (note == null || note.isEmpty) return;
                          final days = int.tryParse(note.split(' ').first) ?? 30;
                          TGFounderService.instance.extendProgram(sellerId: e.key, days: days, actorId: auth.userId, reason: note);
                          setState(() {});
                        },
                        child: Text(context.t('ui_admin_extend')),
                      ),
                      IconButton(
                        icon: Icon(_detailId == e.key ? Icons.expand_less : Icons.expand_more),
                        onPressed: () => setState(() => _detailId = _detailId == e.key ? null : e.key),
                      ),
                    ],
                  ),
                ),
        if (_detailId != null) ...[
          const SizedBox(height: 8),
          Text(context.t('ui_admin_qualified_reasons', {'id': _detailId!}), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
          for (final info in svc.evaluateSellerListings(_detailId!))
            Text('${info.title}: ${info.qualified ? "OK" : info.reasons.join(", ")}', style: theme.bodySmall),
        ],
      ],
    );
  }

  Widget _appCard(BuildContext context, TGFounderApplication a, FakeAuthState auth, {bool detail = false}) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGFounderService.instance;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: theme.tertiary), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.companyName ?? a.sellerId, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text('NIP ${a.nip} · profile ${a.profileCompletePct}% · projects ${a.referenceProjectsCount} · call ${a.feedbackCallDone ? "✓" : "—"}'),
          Text(
            'NIP ${svc.nipAlreadyUsed(a.nip, exceptSellerId: a.sellerId) ? context.t('ui_admin_nip_duplicate') : context.t('ui_admin_nip_ok')} · ${a.status.name}',
          ),
          if (detail)
            Wrap(
              spacing: 4,
              children: [
                TextButton(onPressed: () => _decide(a, TGFounderApplicationStatus.approved, auth), child: Text(context.t('ui_approve'))),
                TextButton(onPressed: () => _decide(a, TGFounderApplicationStatus.rejected, auth), child: Text(context.t('ui_reject'))),
                TextButton(onPressed: () => _decide(a, TGFounderApplicationStatus.waitlisted, auth), child: Text(context.t('ui_admin_waitlist'))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _participantCard(BuildContext context, String sellerId, TGSellerFounder f, FakeAuthState auth) {
    final theme = FlutterFlowTheme.of(context);
    final name = TGSellerProfileService.instance.bySellerKey(sellerId)?.name ?? sellerId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: theme.tertiary), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(
            'tier ${f.tier} · qualified ${f.qualifiedCount} · '
            'free ${f.freeUntil != null ? TGFounderService.fmtDate(f.freeUntil!) : "—"} · '
            'ends ${f.programEndsAt != null ? TGFounderService.fmtDate(f.programEndsAt!) : "—"}',
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () async {
                  final note = await _note(context.t('ui_admin_manual_tier'), hint: context.t('ui_admin_manual_tier_hint'));
                  if (note == null || note.isEmpty) return;
                  final tier = int.tryParse(note.split(' ').first) ?? f.tier;
                  TGFounderService.instance.setTierManual(sellerId: sellerId, tier: tier, actorId: auth.userId, reason: note);
                  setState(() {});
                },
                child: Text(context.t('ui_admin_tier')),
              ),
              TextButton(
                onPressed: () async {
                  final note = await _note(context.t('ui_admin_end_program'));
                  if (note == null || note.isEmpty) return;
                  TGFounderService.instance.endProgram(sellerId: sellerId, actorId: auth.userId, reason: note);
                  setState(() {});
                },
                child: Text(context.t('ui_admin_end')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminFoundersHost extends StatelessWidget {
  const AdminFoundersHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'founders', child: AdminFoundersPage());
}
