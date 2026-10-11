import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
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

  Future<String?> _note(String title, {String hint = 'Reason'}) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: c, decoration: InputDecoration(labelText: hint), autofocus: true),
            const SizedBox(height: 12),
            Text('Email preview (neutral)', style: FlutterFlowTheme.of(ctx).bodySmall.override(fontWeight: FontWeight.w800)),
            Text(
              'Subject: Application update\nYour founding manufacturer application status was updated.',
              style: FlutterFlowTheme.of(ctx).bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TGButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), label: 'Confirm', height: 40),
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
          label: 'Undo',
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
        Text('Founder program', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          'Quota ${svc.spotsTaken} / ${svc.cfg.quota}${svc.quotaFull ? ' · waitlist open' : ''}',
          style: theme.titleSmall.override(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Report: ${report.founders} founders · ${report.qualifiedListings} qualified listings · '
          '${report.discountSales} discounted sales · list ${report.listTotal} / paid ${report.paidTotal} PLN '
          '(Δ ${report.listTotal - report.paidTotal})',
          style: theme.bodySmall,
        ),
        const SizedBox(height: 20),
        Text('Application queue', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (queue.isEmpty)
          Text('No pending applications.', style: theme.bodySmall)
        else if (phone)
          for (final a in queue) _appCard(context, a, auth, detail: true)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Company')),
                DataColumn(label: Text('NIP')),
                DataColumn(label: Text('Profile %')),
                DataColumn(label: Text('Projects')),
                DataColumn(label: Text('Call')),
                DataColumn(label: Text('NIP dup')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final a in queue)
                  DataRow(cells: [
                    DataCell(Text(a.companyName ?? a.sellerId)),
                    DataCell(Text(a.nip)),
                    DataCell(Text('${a.profileCompletePct}%')),
                    DataCell(Text('${a.referenceProjectsCount}')),
                    DataCell(Text(a.feedbackCallDone ? '✓' : '—')),
                    DataCell(Text(svc.nipAlreadyUsed(a.nip, exceptSellerId: a.sellerId) ? 'dup' : 'ok')),
                    DataCell(Text(a.status.name)),
                    DataCell(Wrap(spacing: 4, children: [
                      TextButton(onPressed: () => _decide(a, TGFounderApplicationStatus.approved, auth), child: const Text('Approve')),
                      TextButton(onPressed: () => _decide(a, TGFounderApplicationStatus.rejected, auth), child: const Text('Reject')),
                      TextButton(onPressed: () => _decide(a, TGFounderApplicationStatus.waitlisted, auth), child: const Text('Waitlist')),
                    ])),
                  ]),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text('Participants', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
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
                          final note = await _note('Manual tier', hint: 'Tier 0|1|2 + reason');
                          if (note == null || note.isEmpty) return;
                          final tier = int.tryParse(note.split(' ').first) ?? e.value.tier;
                          TGFounderService.instance.setTierManual(sellerId: e.key, tier: tier, actorId: auth.userId, reason: note);
                          setState(() {});
                        },
                        child: const Text('Tier'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final note = await _note('End program');
                          if (note == null || note.isEmpty) return;
                          TGFounderService.instance.endProgram(sellerId: e.key, actorId: auth.userId, reason: note);
                          setState(() {});
                        },
                        child: const Text('End'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final note = await _note('Extend program', hint: 'Days + reason');
                          if (note == null || note.isEmpty) return;
                          final days = int.tryParse(note.split(' ').first) ?? 30;
                          TGFounderService.instance.extendProgram(sellerId: e.key, days: days, actorId: auth.userId, reason: note);
                          setState(() {});
                        },
                        child: const Text('Extend'),
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
          Text('Qualified listing reasons ($_detailId)', style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
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
          Text('NIP ${svc.nipAlreadyUsed(a.nip, exceptSellerId: a.sellerId) ? "duplicate" : "ok"} · ${a.status.name}'),
          if (detail)
            Wrap(
              spacing: 4,
              children: [
                TextButton(onPressed: () => _decide(a, TGFounderApplicationStatus.approved, auth), child: const Text('Approve')),
                TextButton(onPressed: () => _decide(a, TGFounderApplicationStatus.rejected, auth), child: const Text('Reject')),
                TextButton(onPressed: () => _decide(a, TGFounderApplicationStatus.waitlisted, auth), child: const Text('Waitlist')),
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
                  final note = await _note('Manual tier', hint: 'Tier 0|1|2 + reason');
                  if (note == null || note.isEmpty) return;
                  final tier = int.tryParse(note.split(' ').first) ?? f.tier;
                  TGFounderService.instance.setTierManual(sellerId: sellerId, tier: tier, actorId: auth.userId, reason: note);
                  setState(() {});
                },
                child: const Text('Tier'),
              ),
              TextButton(
                onPressed: () async {
                  final note = await _note('End program');
                  if (note == null || note.isEmpty) return;
                  TGFounderService.instance.endProgram(sellerId: sellerId, actorId: auth.userId, reason: note);
                  setState(() {});
                },
                child: const Text('End'),
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
