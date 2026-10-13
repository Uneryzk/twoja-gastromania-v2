import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/dashboard_shell.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/account_capabilities.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_growth.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/referral_repository.dart';

class RepresentativePage extends StatelessWidget {
  const RepresentativePage({super.key, this.tab});

  static const routeName = 'DashboardRepresentative';
  static const routePath = '/dashboard/representative';
  static const tabs = ['sellers', 'reports', 'log', 'code'];

  final String? tab;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final caps = AccountCapabilities.of(auth);
    if (!caps.isRepresentative || caps.repProfile == null) {
      return const _RepForbidden();
    }
    final initial = tabs.contains(tab) ? tabs.indexOf(tab!) : 0;
    return DashboardShell(
      current: 'representative',
      child: ListenableBuilder(
        listenable: ReferralRepository.instance,
        builder: (context, _) => _RepBody(rep: caps.repProfile!, auth: auth, initialTab: initial),
      ),
    );
  }
}

class _RepForbidden extends StatelessWidget {
  const _RepForbidden();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      key: const Key('rep-403'),
      backgroundColor: TGColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40, color: TGColors.error),
                const SizedBox(height: 12),
                Text(context.t('ui_admin_forbidden'), style: theme.titleLarge.override(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(context.t('ref_403'), textAlign: TextAlign.center, style: theme.bodyMedium.override(color: theme.secondaryText)),
                const SizedBox(height: 18),
                FilledButton(onPressed: () => TGNav.home(context), child: Text(context.t('ui_home'))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RepBody extends StatefulWidget {
  const _RepBody({required this.rep, required this.auth, required this.initialTab});
  final TGRepresentative rep;
  final FakeAuthState auth;
  final int initialTab;

  @override
  State<_RepBody> createState() => _RepBodyState();
}

class _RepBodyState extends State<_RepBody> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final rep = widget.rep;
    return Column(
      key: const Key('rep-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(context.t('ref_panel_title'), style: theme.headlineMedium.override(fontWeight: FontWeight.w900))),
        const SizedBox(height: 4),
        Text(context.t('ref_ui_filter_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (i, key) in const ['sellers', 'reports', 'log', 'code'].indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('rep-tab-$key'),
                    label: Text(context.t('ref_tab_$key')),
                    selected: _tab == i,
                    onSelected: (_) => setState(() => _tab = i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        switch (_tab) {
          1 => _ReportsTab(rep: rep, actorId: widget.auth.userId),
          2 => _LogTab(rep: rep),
          3 => _CodeTab(rep: rep),
          _ => _SellersTab(rep: rep),
        },
      ],
    );
  }
}

class _SellersTab extends StatelessWidget {
  const _SellersTab({required this.rep});
  final TGRepresentative rep;

  @override
  Widget build(BuildContext context) {
    final repo = ReferralRepository.instance;
    final funnel = repo.funnelFor(rep.id);
    final rows = repo.sellersFor(rep.id);
    final theme = FlutterFlowTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FunnelChip(label: context.t('ref_funnel_registered'), value: funnel.registered),
            _FunnelChip(label: context.t('ref_funnel_phone'), value: funnel.phoneVerified),
            _FunnelChip(label: context.t('ref_funnel_qualified'), value: funnel.firstQualifiedListing),
            _FunnelChip(label: context.t('ref_funnel_paid'), value: funnel.paid),
            _FunnelChip(label: context.t('ref_funnel_week'), value: funnel.weeklySignups),
          ],
        ),
        if (funnel.withdrawnCount > 0) ...[
          const SizedBox(height: 8),
          Text(context.t('ref_visibility_off_count', {'n': '${funnel.withdrawnCount}'}), style: theme.bodySmall.override(color: theme.secondaryText)),
        ],
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Text(context.t('ref_not_enough'), style: theme.bodyMedium)
        else if (narrow)
          ...rows.map((r) => _SellerCard(row: r))
        else
          _SellerTable(rows: rows),
      ],
    );
  }
}

class _FunnelChip extends StatelessWidget {
  const _FunnelChip({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      label: '$label $value',
      child: Chip(
        label: Text('$label · $value', style: theme.labelMedium.override(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _SellerTable extends StatelessWidget {
  const _SellerTable({required this.rows});
  final List<TGRepSellerRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget th(String k) => Semantics(header: true, child: Padding(padding: const EdgeInsets.all(8), child: Text(context.t(k), style: theme.labelMedium.override(fontWeight: FontWeight.w800))));
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.4), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1.2), 4: FlexColumnWidth(1.2)},
      children: [
        TableRow(children: [th('ref_col_name'), th('ref_col_type'), th('ref_col_status'), th('ref_col_engagement'), th('ref_col_net')]),
        for (final r in rows)
          TableRow(children: [
            Padding(padding: const EdgeInsets.all(8), child: Text(r.publicName)),
            Padding(padding: const EdgeInsets.all(8), child: Text(_seg(context, r.segment))),
            Padding(padding: const EdgeInsets.all(8), child: _StatusChip(status: r.status)),
            Padding(padding: const EdgeInsets.all(8), child: Text(_eng(context, r))),
            Padding(padding: const EdgeInsets.all(8), child: Text(_net(context, r.attributedNetGrosz))),
          ]),
      ],
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.row});
  final TGRepSellerRow row;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Card(
      key: Key('rep-seller-${row.userId}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.publicName, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${_seg(context, row.segment)} · ${row.planLabel} · ${DateFormat.yMMMd(FFLocalizations.of(context).languageCode).format(row.registeredAt)}', style: theme.bodySmall),
            const SizedBox(height: 6),
            _StatusChip(status: row.status),
            const SizedBox(height: 6),
            Text('${context.t('ref_col_listings')}: ${row.listingCount} · ${context.t('ref_col_qualified')}: ${row.qualifiedActiveCount}', style: theme.bodySmall),
            Text(_eng(context, row), style: theme.bodySmall),
            Text(_net(context, row.attributedNetGrosz), style: theme.bodySmall),
            Text(context.t('ref_no_commission'), style: theme.labelSmall.override(color: theme.secondaryText)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final TGRepSellerStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, key) = switch (status) {
      TGRepSellerStatus.registered => (Icons.person_add_alt_1_outlined, 'ref_status_registered'),
      TGRepSellerStatus.phoneVerified => (Icons.phone_android, 'ref_status_phone'),
      TGRepSellerStatus.won => (Icons.emoji_events_outlined, 'ref_status_won'),
      TGRepSellerStatus.paid => (Icons.payments_outlined, 'ref_status_paid'),
    };
    final label = context.t(key);
    return Semantics(
      label: label,
      child: Chip(avatar: Icon(icon, size: 16), label: Text(label)),
    );
  }
}

String _net(BuildContext context, int? grosz) =>
    grosz == null ? context.t('ref_not_enough') : context.t('ref_net_revenue', {'n': GrowthMoney.format(grosz)});

String _seg(BuildContext context, TGReferralSegment s) => context.t('ref_seg_${s.name}');

String _eng(BuildContext context, TGRepSellerRow r) {
  if (!r.enoughEngagement) return context.t('ref_not_enough');
  return context.t('ref_engagement_line', {
    'v': '${r.views30}',
    'c': '${r.callTaps30}',
    'm': '${r.messages30}',
    'f': '${r.favorites30}',
  });
}

class _ReportsTab extends StatefulWidget {
  const _ReportsTab({required this.rep, required this.actorId});
  final TGRepresentative rep;
  final String actorId;

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  String? _sellerId;
  int _days = 30;
  TGRepPerformanceReport? _last;

  @override
  Widget build(BuildContext context) {
    final repo = ReferralRepository.instance;
    final sellers = repo.sellersFor(widget.rep.id);
    final links = repo.activeLinksFor(widget.rep.id);
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ref_report_create'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        DropdownButton<String>(
          key: const Key('rep-report-seller'),
          hint: Text(context.t('ref_report_pick_seller')),
          value: _sellerId,
          isExpanded: true,
          items: [
            for (final s in sellers) DropdownMenuItem(value: s.userId, child: Text(s.publicName)),
          ],
          onChanged: (v) => setState(() => _sellerId = v),
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 30, label: Text(context.t('ref_period_30'))),
            ButtonSegment(value: 90, label: Text(context.t('ref_period_90'))),
          ],
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('rep-report-create'),
          onPressed: _sellerId == null
              ? null
              : () {
                  final r = repo.createReport(repId: widget.rep.id, sellerUserId: _sellerId!, periodDays: _days, actorId: widget.actorId);
                  setState(() => _last = r);
                },
          child: Text(context.t('ref_report_create')),
        ),
        if (_last != null) ...[
          const SizedBox(height: 16),
          _ReportPreview(report: _last!),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('rep-report-print'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(context.t('ref_report_print')),
                    content: SingleChildScrollView(child: _ReportPreview(report: _last!)),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('ui_close')))],
                  ),
                ),
                child: Text(context.t('ref_report_print')),
              ),
              OutlinedButton(
                key: const Key('rep-report-share'),
                onPressed: () {
                  final link = repo.createShareLink(reportId: _last!.id, actorId: widget.actorId);
                  if (link != null) {
                    Clipboard.setData(ClipboardData(text: '/r/${link.token}'));
                    showTGToast(context, context.t('ref_link_copied'));
                    setState(() {});
                  }
                },
                child: Text(context.t('ref_report_share')),
              ),
              OutlinedButton(
                key: const Key('rep-report-send'),
                onPressed: () {
                  NotificationService.instance.add(
                    userId: _last!.sellerUserId,
                    type: 'rep_report',
                    dealId: _last!.id,
                    title: context.t('ref_report_notify_title'),
                    body: context.t('ref_report_notify_body'),
                    deepLink: '/dashboard/insights',
                  );
                  showTGToast(context, context.t('ref_report_sent'));
                },
                child: Text(context.t('ref_report_send')),
              ),
            ],
          ),
        ],
        if (links.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(context.t('ref_open_links'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
          for (final l in links)
            ListTile(
              title: Text('/r/${l.token}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(context.t('ref_link_expires', {'date': DateFormat.yMMMd().format(l.expiresAt)})),
              trailing: TextButton(
                key: Key('rep-revoke-${l.token}'),
                onPressed: () {
                  repo.revokeShareLink(token: l.token, actorId: widget.actorId);
                  setState(() {});
                },
                child: Text(context.t('ref_revoke')),
              ),
            ),
        ],
      ],
    );
  }
}

class _ReportPreview extends StatelessWidget {
  const _ReportPreview({required this.report});
  final TGRepPerformanceReport report;

  String _m(BuildContext context, TGRepMetric<int> m) => m.hasValue ? '${m.value}' : context.t('ref_not_enough');

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final loc = FFLocalizations.of(context).languageCode;
    final snap = DateFormat('d MMM', loc).format(report.snapshotAt);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('ref_snapshot_as_of', {'date': snap}), style: theme.labelLarge.override(fontWeight: FontWeight.w800)),
            Text('${DateFormat.yMMMd(loc).format(report.from)} – ${DateFormat.yMMMd(loc).format(report.to)}', style: theme.bodySmall),
            const SizedBox(height: 8),
            Text('${context.t('ref_col_listings')}: ${_m(context, report.listingCount)}'),
            Text(report.views.hasValue ? context.t('ref_fact_views', {'n': '${report.views.value}'}) : context.t('ref_not_enough')),
            Text('${context.t('ref_metric_calls')}: ${_m(context, report.callTaps)}'),
            Text('${context.t('ref_metric_messages')}: ${_m(context, report.messages)}'),
            Text('${context.t('ref_metric_favorites')}: ${_m(context, report.favorites)}'),
            if (report.topListingTitle != null)
              Text('${context.t('ref_top_listing')}: ${report.topListingTitle} · ${report.topListingNo}'),
          ],
        ),
      ),
    );
  }
}

class _LogTab extends StatefulWidget {
  const _LogTab({required this.rep});
  final TGRepresentative rep;

  @override
  State<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<_LogTab> {
  late TGRepWeeklyLog _log;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _log = ReferralRepository.instance.weeklyLogFor(widget.rep.id);
    _note = TextEditingController(text: _log.note);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    ReferralRepository.instance.saveWeeklyLog(_log.copyWith(note: _note.text));
    showTGToast(context, context.t('ref_log_saved'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ref_log_pii_warn'), style: theme.bodySmall.override(color: TGColors.slaAmber, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(context.t('ref_no_target'), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: null, color: theme.alternate),
        const SizedBox(height: 16),
        for (final c in TGRepContactCategory.values) ...[
          Text(context.t('ref_cat_${c.name}'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
          Row(
            children: [
              Expanded(child: _NumField(label: context.t('ref_log_contacts'), value: _log.contacts[c] ?? 0, onChanged: (n) => setState(() => _log = _log.copyWith(contacts: {..._log.contacts, c: n})))),
              const SizedBox(width: 8),
              Expanded(child: _NumField(label: context.t('ref_log_meetings'), value: _log.meetings[c] ?? 0, onChanged: (n) => setState(() => _log = _log.copyWith(meetings: {..._log.meetings, c: n})))),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          key: const Key('rep-log-note'),
          controller: _note,
          maxLines: 3,
          decoration: InputDecoration(labelText: context.t('ref_log_note')),
        ),
        const SizedBox(height: 12),
        FilledButton(key: const Key('rep-log-save'), onPressed: _save, child: Text(context.t('ref_log_save'))),
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: '$value',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (t) => onChanged(int.tryParse(t) ?? 0),
    );
  }
}

class _CodeTab extends StatelessWidget {
  const _CodeTab({required this.rep});
  final TGRepresentative rep;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final week = ReferralRepository.instance.weeklySignupsFor(rep.id);
    final link = '/register?ref=${rep.code}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(rep.code, key: const Key('rep-my-code'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(rep.roleLabel, style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 12),
        SelectableText(link, style: theme.bodyMedium),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('rep-copy-invite'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: link));
            showTGToast(context, context.t('ref_link_copied'));
          },
          child: Text(context.t('ref_copy_invite')),
        ),
        const SizedBox(height: 16),
        Text(context.t('ref_funnel_week_n', {'n': '$week'}), style: theme.titleMedium.override(fontWeight: FontWeight.w800)),
      ],
    );
  }
}
