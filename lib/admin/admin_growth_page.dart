import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_growth.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';
import 'package:twoja_gastromania/admin/admin_growth_ops.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/growth_service.dart';
import 'package:twoja_gastromania/tg_services/referral_repository.dart';

class AdminGrowthHost extends StatelessWidget {
  const AdminGrowthHost({super.key, this.tab});

  final String? tab;

  @override
  Widget build(BuildContext context) => AdminShell(section: 'growth', child: AdminGrowthPage(tab: tab));
}

class AdminGrowthPage extends StatefulWidget {
  const AdminGrowthPage({super.key, this.tab});

  static const routePath = '/admin/growth';
  static const tabs = ['targets', 'team', 'roadmap', 'revenue', 'budget', 'weekly'];

  final String? tab;

  @override
  State<AdminGrowthPage> createState() => _AdminGrowthPageState();
}

class _AdminGrowthPageState extends State<AdminGrowthPage> {
  late String _tab;
  String? _logged;

  @override
  void initState() {
    super.initState();
    GrowthService.instance.ensureSeeded();
    ReferralRepository.instance.ensureSeeded();
    _tab = AdminGrowthPage.tabs.contains(widget.tab) ? widget.tab! : 'targets';
    WidgetsBinding.instance.addPostFrameCallback((_) => _audit());
  }

  @override
  void didUpdateWidget(covariant AdminGrowthPage old) {
    super.didUpdateWidget(old);
    if (widget.tab != old.tab && AdminGrowthPage.tabs.contains(widget.tab)) {
      _tab = widget.tab!;
      _audit();
    }
  }

  void _audit() {
    if (_logged == _tab || !mounted) return;
    _logged = _tab;
    GrowthService.instance.logView(context.read<FakeAuthState>(), _tab);
  }

  void _go(String tab) {
    context.go('${AdminGrowthPage.routePath}?tab=$tab');
    setState(() => _tab = tab);
    _audit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final svc = GrowthService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([svc, ReferralRepository.instance, TGBillingService.instance]),
      builder: (context, _) {
        return Padding(
          key: const Key('admin-growth'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(context.t('gr_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900))),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final t in AdminGrowthPage.tabs)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: Key('gr-tab-$t'),
                          label: Text(context.t('gr_tab_$t')),
                          selected: _tab == t,
                          onSelected: (_) => _go(t),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: reduce ? Duration.zero : const Duration(milliseconds: 150),
                  child: KeyedSubtree(
                    key: ValueKey(_tab),
                    child: switch (_tab) {
                      'targets' => _TargetsTab(svc: svc),
                      'team' => _TeamTab(svc: svc),
                      'roadmap' => _RoadmapTab(svc: svc),
                      'revenue' => GrowthRevenueTab(svc: svc),
                      'budget' => GrowthBudgetTab(svc: svc),
                      'weekly' => GrowthWeeklyTab(svc: svc),
                      _ => _ComingNext(tab: _tab),
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ComingNext extends StatelessWidget {
  const _ComingNext({required this.tab});
  final String tab;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: Key('gr-placeholder-$tab'),
      child: Text(context.t('dash_coming_next'), textAlign: TextAlign.center),
    );
  }
}

class _TargetsTab extends StatefulWidget {
  const _TargetsTab({required this.svc});
  final GrowthService svc;

  @override
  State<_TargetsTab> createState() => _TargetsTabState();
}

class _TargetsTabState extends State<_TargetsTab> {
  GrowthPeriod? _picked;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = widget.svc;
    final frozen = svc.config.programStartDate == null;
    final active = svc.activePeriod();
    final period = frozen ? GrowthPeriod.p0to3 : (_picked ?? active ?? GrowthPeriod.p0to3);
    final rows = svc.rowsFor(period);
    final snap = svc.actuals();
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ListView(
      children: [
        if (frozen)
          _Banner(keyName: 'gr-no-start', text: context.t('gr_set_start'), color: TGColors.slaAmber)
        else
          TextButton(
            key: const Key('gr-start-set'),
            onPressed: () => svc.setProgramStart(null, actor: context.read<FakeAuthState>()),
            child: Text(context.t('gr_start_on', {'date': DateFormat.yMMMd().format(svc.config.programStartDate!)})),
          ),
        if (frozen)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('gr-set-start'),
              onPressed: () => svc.setProgramStart(TGClock.now(), actor: context.read<FakeAuthState>()),
              child: Text(context.t('gr_set_start_btn')),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final p in GrowthPeriod.values)
              ChoiceChip(
                key: Key('gr-period-${p.name}'),
                label: Text(context.t('gr_period_${p.name}')),
                selected: period == p,
                onSelected: frozen ? null : (_) => setState(() => _picked = p),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<GrowthRevenueBasis>(
          segments: [
            ButtonSegment(value: GrowthRevenueBasis.net, label: Text(context.t('gr_basis_net')), tooltip: context.t('gr_basis_net')),
            ButtonSegment(value: GrowthRevenueBasis.gross, label: Text(context.t('gr_basis_gross')), tooltip: context.t('gr_basis_gross')),
          ],
          selected: {svc.config.revenueBasis},
          onSelectionChanged: (s) => svc.setRevenueBasis(s.first, actor: context.read<FakeAuthState>()),
        ),
        const SizedBox(height: 12),
        if (narrow)
          Column(
            key: const Key('gr-cards'),
            children: [for (final r in rows) _MetricCard(row: r, frozen: frozen, reduce: reduce, period: period)],
          )
        else
          _MetricTable(rows: rows, frozen: frozen, reduce: reduce, period: period),
        const SizedBox(height: 12),
        Text(context.t('gr_same_account_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
        Text(context.t('gr_unique_sellers', {'n': '${snap.uniqueSellers}'}), key: const Key('gr-unique'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (snap.hasSparkline)
          _Spark(values: snap.monthlyUniqueSellers)
        else
          Text(context.t('ref_not_enough'), key: const Key('gr-spark-empty')),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.keyName, required this.text, required this.color});
  final String keyName;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(keyName),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      color: color.withValues(alpha: 0.15),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _MetricTable extends StatelessWidget {
  const _MetricTable({required this.rows, required this.frozen, required this.reduce, required this.period});
  final List<GrowthRowView> rows;
  final bool frozen;
  final bool reduce;
  final GrowthPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget th(String k) => Semantics(header: true, child: Padding(padding: const EdgeInsets.all(6), child: Text(context.t(k), style: theme.labelMedium.override(fontWeight: FontWeight.w800))));
    return Opacity(
      opacity: frozen ? 0.45 : 1,
      child: Table(
        key: const Key('gr-table'),
        columnWidths: const {0: FlexColumnWidth(1.4), 1: FlexColumnWidth(1), 2: FlexColumnWidth(0.8), 3: FlexColumnWidth(0.7), 4: FlexColumnWidth(0.7), 5: FlexColumnWidth(1)},
        children: [
          TableRow(children: [th('gr_col_metric'), th('gr_col_target'), th('gr_col_actual'), th('gr_col_min_pct'), th('gr_col_goal_pct'), th('gr_col_tempo')]),
          for (final r in rows)
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: InkWell(
                  onTap: () => _editTarget(context, r.metric, period, r.cell),
                  child: Text(context.t('gr_metric_${r.metric.name}')),
                ),
              ),
              Padding(padding: const EdgeInsets.all(6), child: Text(_targetLabel(context, r.cell))),
              Padding(padding: const EdgeInsets.all(6), child: Text(_actualLabel(context, r))),
              Padding(padding: const EdgeInsets.all(6), child: Text(_pct(r.pctMin))),
              Padding(padding: const EdgeInsets.all(6), child: Text(_pct(r.pctGoal))),
              Padding(padding: const EdgeInsets.all(6), child: _TempoChip(tempo: r.tempo)),
            ]),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.row, required this.frozen, required this.reduce, required this.period});
  final GrowthRowView row;
  final bool frozen;
  final bool reduce;
  final GrowthPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Opacity(
      opacity: frozen ? 0.45 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _editTarget(context, row.metric, period, row.cell),
                child: Text(context.t('gr_metric_${row.metric.name}'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
              ),
              Text('${context.t('gr_col_target')}: ${_targetLabel(context, row.cell)}'),
              Text('${context.t('gr_col_actual')}: ${_actualLabel(context, row)}'),
              _TempoChip(tempo: row.tempo),
              const SizedBox(height: 6),
              _Bar(row: row, reduce: reduce),
              Text(
                '${context.t('gr_col_min_pct')} ${_pct(row.pctMin)} · ${context.t('gr_col_goal_pct')} ${_pct(row.pctGoal)} · ${context.t('gr_tempo_${row.tempo.name}')}',
                style: theme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.row, required this.reduce});
  final GrowthRowView row;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final goal = (row.cell.goal ?? row.cell.min ?? 1).toDouble();
    final min = (row.cell.min ?? 0).toDouble();
    final v = (row.actual.value ?? 0) / goal;
    return Semantics(
      label: '${context.t('gr_col_actual')} ${row.actual.value ?? context.t('gr_no_data')} ${context.t('gr_tempo_${row.tempo.name}')}',
      child: LayoutBuilder(
        builder: (context, box) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: v.clamp(0, 1.2)),
            duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
            builder: (context, value, _) {
              return SizedBox(
                height: 14,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 8),
                    if (row.cell.min != null && goal > 0)
                      Positioned(left: (min / goal).clamp(0, 1) * box.maxWidth, child: Container(width: 2, height: 14, color: TGColors.slaAmber)),
                    if (row.cell.goal != null)
                      Positioned(left: box.maxWidth - 2, child: Container(width: 2, height: 14, color: TGColors.cta)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TempoChip extends StatelessWidget {
  const _TempoChip({required this.tempo});
  final GrowthTempo tempo;

  @override
  Widget build(BuildContext context) {
    final label = context.t('gr_tempo_${tempo.name}');
    return Semantics(label: label, child: Chip(key: Key('gr-tempo-${tempo.name}'), label: Text(label), visualDensity: VisualDensity.compact));
  }
}

class _Spark extends StatelessWidget {
  const _Spark({required this.values});
  final List<int> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('gr-spark'),
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in values)
            Expanded(
              child: Container(
                height: 8 + (v.clamp(0, 20) * 2.0),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                color: TGColors.cta,
              ),
            ),
        ],
      ),
    );
  }
}

String _targetLabel(BuildContext context, GrowthCell c) {
  if (c.text != null && !c.hasNumber) return c.text!;
  if (c.min != null && c.goal != null) return '${c.min}–${c.goal}';
  if (c.min != null) return '${c.min}';
  if (c.goal != null) return '${c.goal}';
  return context.t('gr_tempo_noTarget');
}

String _actualLabel(BuildContext context, GrowthRowView r) {
  if (r.actual.noData) return context.t('gr_no_data');
  final extra = r.actual.founderGrant > 0 ? ' · ${context.t('gr_founder_grant', {'n': '${r.actual.founderGrant}'})}' : '';
  return '${r.actual.value}$extra';
}

String _pct(double? v) => v == null ? '—' : '${(v * 100).round()}%';

Future<void> _editTarget(BuildContext context, GrowthMetricId id, GrowthPeriod period, GrowthCell cell) async {
  final min = TextEditingController(text: cell.min?.toString() ?? '');
  final goal = TextEditingController(text: cell.goal?.toString() ?? '');
  final text = TextEditingController(text: cell.text ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.t('gr_edit_target')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(key: const Key('gr-edit-min'), controller: min, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.t('gr_col_min_pct'))),
          TextField(key: const Key('gr-edit-goal'), controller: goal, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.t('gr_col_goal_pct'))),
          TextField(key: const Key('gr-edit-text'), controller: text, decoration: InputDecoration(labelText: context.t('gr_target_text'))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('ui_close'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('gr_edit_target'))),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    GrowthService.instance.setTargetCell(
      id,
      period,
      GrowthCell(
        min: int.tryParse(min.text.trim()),
        goal: int.tryParse(goal.text.trim()),
        text: text.text.trim().isEmpty ? null : text.text.trim(),
      ),
      actor: context.read<FakeAuthState>(),
    );
  }
}

class _TeamTab extends StatefulWidget {
  const _TeamTab({required this.svc});
  final GrowthService svc;

  @override
  State<_TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<_TeamTab> {
  late DateTime _week = ReferralRepository.warsawWeekStart(TGClock.now());
  String? _openRep;

  @override
  Widget build(BuildContext context) {
    final rows = widget.svc.teamRows(_week);
    final flags = ReferralRepository.instance.attributionFlags();
    return ListView(
      children: [
        Row(
          children: [
            IconButton(onPressed: () => setState(() => _week = _week.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left)),
            Text('${DateFormat.MMMd().format(_week)} – ${DateFormat.MMMd().format(_week.add(const Duration(days: 6)))}'),
            IconButton(onPressed: () => setState(() => _week = _week.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const Key('gr-add-rep'),
            onPressed: () => _addRep(context),
            child: Text(context.t('gr_add_rep')),
          ),
        ),
        if (flags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(context.t('gr_attr_flags'), style: FlutterFlowTheme.of(context).titleSmall.override(fontWeight: FontWeight.w800)),
          for (final f in flags) Text('• ${context.t('gr_flag_${f.kind.name}')} ${f.detail}', style: FlutterFlowTheme.of(context).bodySmall),
        ],
        const SizedBox(height: 8),
        if (rows.isEmpty) Text(context.t('gr_no_data'), key: const Key('gr-team-empty')) else ...[
          for (final r in rows) _RepCard(row: r, onOpen: () => setState(() => _openRep = r.rep.id), svc: widget.svc),
        ],
        if (_openRep != null) _RepDrawer(repId: _openRep!, onClose: () => setState(() => _openRep = null)),
      ],
    );
  }

  Future<void> _addRep(BuildContext context) async {
    final name = TextEditingController();
    var role = TGRepRole.individualPortfolio;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('gr_add_rep')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(key: const Key('gr-rep-name'), controller: name, decoration: InputDecoration(labelText: context.t('gr_rep_name'))),
            DropdownButton<TGRepRole>(
              value: role,
              items: [for (final r in TGRepRole.values) DropdownMenuItem(value: r, child: Text(r.name))],
              onChanged: (v) => role = v ?? role,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('ui_close'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('gr_add_rep'))),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty && context.mounted) {
      widget.svc.addRep(displayName: name.text.trim(), role: role, actor: context.read<FakeAuthState>());
    }
  }
}

class _RepCard extends StatelessWidget {
  const _RepCard({required this.row, required this.onOpen, required this.svc});
  final GrowthRepWeekRow row;
  final VoidCallback onOpen;
  final GrowthService svc;

  @override
  Widget build(BuildContext context) {
    final r = row.rep;
    final theme = FlutterFlowTheme.of(context);
    final resultsDen = (row.contactMin).clamp(1, 9999);
    final results = (row.signups + row.won + row.paid) / resultsDen;
    return Card(
      key: Key('gr-rep-${r.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.displayName, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
            Text('${r.roleLabel} · ${r.code} · ${r.status.name}'),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '/register?ref=${r.code}'));
              },
              child: Text(context.t('ref_copy_invite')),
            ),
            Text('${context.t('gr_src_entered')}: ${row.contactsEntered} / ${row.contactGoal}'),
            Text('${context.t('gr_src_system')}: ${context.t('ref_funnel_week')} ${row.signups} · ${context.t('ref_status_won')} ${row.won} · ${context.t('ref_status_paid')} ${row.paid}'),
            if (row.attributedNetGrosz != null) Text(context.t('ref_net_revenue', {'n': GrowthMoney.format(row.attributedNetGrosz!)})),
            Row(
              children: [
                Expanded(child: _MiniBar(label: context.t('gr_activity'), value: row.contactGoal == 0 ? 0 : row.contactsEntered / row.contactGoal)),
                const SizedBox(width: 8),
                Expanded(child: _MiniBar(label: context.t('gr_results'), value: results)),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: onOpen, child: Text(context.t('gr_rep_detail'))),
                TextButton(
                  onPressed: () => svc.setRepActive(r.id, r.status != TGRepStatus.active, actor: context.read<FakeAuthState>()),
                  child: Text(r.status == TGRepStatus.active ? context.t('gr_deactivate') : context.t('gr_activate')),
                ),
                TextButton(onPressed: () => _editTargets(context, r.id), child: Text(context.t('gr_edit_rep_targets'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTargets(BuildContext context, String repId) async {
    final current = svc.targetsFor(repId);
    final controllers = {
      for (final t in current) t.category: (TextEditingController(text: '${t.min}'), TextEditingController(text: '${t.goal}')),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('gr_edit_rep_targets')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in controllers.entries)
              Row(
                children: [
                  Expanded(child: Text(context.t('ref_cat_${e.key.name}'))),
                  SizedBox(width: 64, child: TextField(controller: e.value.$1, keyboardType: TextInputType.number)),
                  SizedBox(width: 64, child: TextField(controller: e.value.$2, keyboardType: TextInputType.number)),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('ui_close'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('gr_edit_rep_targets'))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final actor = context.read<FakeAuthState>();
      for (final e in controllers.entries) {
        svc.setRepTarget(
          GrowthRepTarget(repId: repId, category: e.key, min: int.tryParse(e.value.$1.text) ?? 0, goal: int.tryParse(e.value.$2.text) ?? 0),
          actor: actor,
        );
      }
    }
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FlutterFlowTheme.of(context).labelSmall),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
          builder: (context, v, _) => LinearProgressIndicator(value: v),
        ),
      ],
    );
  }
}

class _RepDrawer extends StatelessWidget {
  const _RepDrawer({required this.repId, required this.onClose});
  final String repId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final repo = ReferralRepository.instance;
    final funnel = repo.funnelFor(repId);
    final sellers = repo.sellersFor(repId);
    final logs = repo.logsFor(repId);
    final acc = repo.rawAccountsFor(repId)..sort((a, b) => a.referredAt.compareTo(b.referredAt));
    return Card(
      key: Key('gr-rep-drawer-$repId'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(context.t('gr_rep_detail'), style: FlutterFlowTheme.of(context).titleSmall.override(fontWeight: FontWeight.w800))),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
            ]),
            Text('${context.t('ref_funnel_registered')} ${funnel.registered} · ${context.t('ref_funnel_phone')} ${funnel.phoneVerified} · ${context.t('ref_status_won')} ${funnel.firstQualifiedListing} · ${context.t('ref_status_paid')} ${funnel.paid}'),
            const SizedBox(height: 8),
            Text(context.t('gr_signup_timeline'), style: FlutterFlowTheme.of(context).labelMedium.override(fontWeight: FontWeight.w800)),
            for (final a in acc.take(12)) Text('${DateFormat.yMMMd().format(a.referredAt)} · ${ReferralRepository.publicDisplayName(a.displayName, a.segment)}'),
            const SizedBox(height: 8),
            Text(context.t('ref_tab_sellers'), style: FlutterFlowTheme.of(context).labelMedium.override(fontWeight: FontWeight.w800)),
            for (final s in sellers) Text(s.publicName),
            const SizedBox(height: 8),
            Text(context.t('ref_tab_log'), style: FlutterFlowTheme.of(context).labelMedium.override(fontWeight: FontWeight.w800)),
            for (final l in logs.take(6)) Text('${DateFormat.yMMMd().format(l.weekStart)} · ${l.note}'),
            OutlinedButton(
              key: const Key('gr-correct-ref'),
              onPressed: () => _correct(context),
              child: Text(context.t('gr_correct_assignment')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _correct(BuildContext context) async {
    final user = TextEditingController();
    final code = TextEditingController();
    final reason = TextEditingController();
    final err = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('gr_correct_assignment')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(key: const Key('gr-corr-user'), controller: user, decoration: const InputDecoration(labelText: 'userId')),
            TextField(key: const Key('gr-corr-code'), controller: code, decoration: InputDecoration(labelText: context.t('ref_code_label'))),
            TextField(key: const Key('gr-corr-reason'), controller: reason, decoration: InputDecoration(labelText: context.t('gr_reason'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('ui_close'))),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              ReferralRepository.instance.adminCorrectReferral(
                userId: user.text.trim(),
                actorId: context.read<FakeAuthState>().userId,
                reason: reason.text,
                newCode: code.text.trim(),
              ),
            ),
            child: Text(context.t('gr_correct_assignment')),
          ),
        ],
      ),
    );
    if (context.mounted && err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t(err == 'reason_required' ? 'gr_reason_required' : 'ref_code_unknown'))));
    }
  }
}

class _RoadmapTab extends StatelessWidget {
  const _RoadmapTab({required this.svc});
  final GrowthService svc;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final snap = svc.actuals();
    return ListView(
      children: [
        for (final item in svc.roadmap)
          Card(
            key: Key('gr-road-${item.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t(item.goalKey), style: FlutterFlowTheme.of(context).titleSmall.override(fontWeight: FontWeight.w800)),
                  if (svc.isOverdue(item))
                    Text(context.t('gr_overdue'), key: Key('gr-overdue-${item.id}'), style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w800)),
                  for (final t in item.tasks)
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            value: t.done,
                            title: Text(t.text.startsWith('gr_') ? context.t(t.text) : t.text),
                            onChanged: (_) => svc.toggleTask(item.id, t.id),
                          ),
                        ),
                        IconButton(
                          tooltip: context.t('gr_del_task'),
                          onPressed: () => svc.removeTask(item.id, t.id, actor: auth),
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ],
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: Key('gr-add-task-${item.id}'),
                      onPressed: () => _addTask(context, item.id),
                      child: Text(context.t('gr_add_task')),
                    ),
                  ),
                  Text(context.t(item.checkpointKey), style: FlutterFlowTheme.of(context).bodySmall),
                  if (item.id == 'm3') ...[
                    Text('${context.t('gr_metric_individualSellers')}: ${snap.byMetric[GrowthMetricId.individualSellers]?.noData == true ? context.t('gr_no_data') : snap.byMetric[GrowthMetricId.individualSellers]?.value}'),
                    Text('${context.t('gr_metric_individualListings')}: ${snap.byMetric[GrowthMetricId.individualListings]?.noData == true ? context.t('gr_no_data') : snap.byMetric[GrowthMetricId.individualListings]?.value}'),
                  ] else if (item.checkpointMetricRef != null)
                    Text('${context.t('gr_metric_${item.checkpointMetricRef!.name}')}: ${snap.byMetric[item.checkpointMetricRef!]?.noData == true ? context.t('gr_no_data') : snap.byMetric[item.checkpointMetricRef!]?.value}'),
                  if (item.id == 'm6')
                    TextButton(
                      key: const Key('gr-second-period'),
                      onPressed: () => context.go('${AdminGrowthPage.routePath}?tab=budget'),
                      child: Text(context.t('gr_second_period')),
                    ),
                  CheckboxListTile(
                    key: Key('gr-check-${item.id}'),
                    value: item.monthEndCheck?.done ?? false,
                    title: Text(context.t('gr_month_end')),
                    subtitle: item.monthEndCheck == null ? null : Text(item.monthEndCheck!.note),
                    onChanged: auth.isAdmin ? (v) => _check(context, item, v ?? false) : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addTask(BuildContext context, String itemId) async {
    final text = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('gr_add_task')),
        content: TextField(key: const Key('gr-task-text'), controller: text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('ui_close'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('gr_add_task'))),
        ],
      ),
    );
    if (ok == true && text.text.trim().isNotEmpty && context.mounted) {
      svc.addTask(itemId, text.text.trim(), actor: context.read<FakeAuthState>());
    }
  }

  Future<void> _check(BuildContext context, GrowthRoadmapItem item, bool done) async {
    if (!done) {
      svc.setMonthEndCheck(item.id, done: false, note: '', actor: context.read<FakeAuthState>());
      return;
    }
    final note = TextEditingController(text: item.monthEndCheck?.note ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('gr_month_end')),
        content: TextField(key: const Key('gr-check-note'), controller: note, decoration: InputDecoration(labelText: context.t('gr_reason'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('ui_close'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('gr_month_end'))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      svc.setMonthEndCheck(item.id, done: true, note: note.text, actor: context.read<FakeAuthState>());
    }
  }
}
