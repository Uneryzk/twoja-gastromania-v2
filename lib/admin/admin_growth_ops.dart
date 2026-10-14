import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/dash3_widgets.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_growth.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';
import 'package:twoja_gastromania/tg_services/growth_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/referral_repository.dart';

class GrowthRevenueTab extends StatefulWidget {
  const GrowthRevenueTab({super.key, required this.svc});
  final GrowthService svc;

  @override
  State<GrowthRevenueTab> createState() => _GrowthRevenueTabState();
}

class _GrowthRevenueTabState extends State<GrowthRevenueTab> {
  GrowthRevWindow _window = GrowthRevWindow.thisMonth;
  bool _gross = false;
  late GrowthScenario _draft = widget.svc.scenarioFromConfig();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final snap = widget.svc.actualStreams(_window);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final period = widget.svc.activePeriod() ?? GrowthPeriod.p3to6;
    final band = widget.svc.config.targets.cell(GrowthMetricId.monthlyRevenue, period);
    return ListView(
      key: const Key('gr-revenue'),
      children: [
        Text(context.t('gr_actual_title'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final w in GrowthRevWindow.values)
              ChoiceChip(
                key: Key('gr-rev-win-${w.name}'),
                label: Text(context.t('gr_win_${w.name}')),
                selected: _window == w,
                onSelected: (_) => setState(() => _window = w),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(context.t('gr_basis_net'))),
            ButtonSegment(value: true, label: Text(context.t('gr_basis_gross'))),
          ],
          selected: {_gross},
          onSelectionChanged: (s) => setState(() => _gross = s.first),
        ),
        const SizedBox(height: 12),
        if (!snap.hasSource)
          Text(context.t('gr_no_data'), key: const Key('gr-rev-empty'))
        else ...[
          for (final id in GrowthRevStreamId.values)
            _StreamRow(row: snap.byStream[id]!, gross: _gross),
          const SizedBox(height: 8),
          Text(
            '${context.t('gr_rev_total')}: ${_gross ? GrowthMoney.format(snap.grossGrosz) : GrowthMoney.format(snap.netGrosz)}',
            style: theme.titleSmall.override(fontWeight: FontWeight.w800),
          ),
          Text('${context.t('gr_rev_monthly_eq')}: ${GrowthMoney.format(snap.monthlyNetEqGrosz)}'),
          Text(
            context.t('gr_rev_plan_counts', {
              'b': '${snap.planCounts.basic}',
              'p': '${snap.planCounts.pro}',
              'e': '${snap.planCounts.enterprise}',
            }),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          key: const Key('gr-scenario'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: TGColors.cta, width: 1.5, strokeAlign: BorderSide.strokeAlignInside),
            borderRadius: BorderRadius.circular(8),
          ),
          foregroundDecoration: BoxDecoration(
            border: Border.all(color: TGColors.cta, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: _DashBorderPainter(color: TGColors.cta),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(context.t('gr_scenario_title'), style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
                  const SizedBox(height: 8),
                  _ScenLine(label: context.t('gr_sc_basic'), qty: _draft.qtyBasic, priceGrosz: _draft.priceBasicGrosz, onQty: (v) => setState(() => _draft = _draft.copyWith(qtyBasic: v)), onPrice: (v) => setState(() => _draft = _draft.copyWith(priceBasicGrosz: v))),
                  _ScenLine(label: context.t('gr_sc_pro'), qty: _draft.qtyPro, priceGrosz: _draft.priceProGrosz, onQty: (v) => setState(() => _draft = _draft.copyWith(qtyPro: v)), onPrice: (v) => setState(() => _draft = _draft.copyWith(priceProGrosz: v))),
                  _ScenLine(label: context.t('gr_sc_ent'), qty: _draft.qtyEnterprise, priceGrosz: _draft.priceEnterpriseGrosz, onQty: (v) => setState(() => _draft = _draft.copyWith(qtyEnterprise: v)), onPrice: (v) => setState(() => _draft = _draft.copyWith(priceEnterpriseGrosz: v))),
                  _ScenLine(label: context.t('gr_sc_listing'), qty: _draft.qtyListing, priceGrosz: _draft.priceListingGrosz, onQty: (v) => setState(() => _draft = _draft.copyWith(qtyListing: v)), onPrice: (v) => setState(() => _draft = _draft.copyWith(priceListingGrosz: v))),
                  _ScenLine(label: context.t('gr_sc_promo'), qty: _draft.qtyPromo, priceGrosz: _draft.pricePromoGrosz, onQty: (v) => setState(() => _draft = _draft.copyWith(qtyPromo: v)), onPrice: (v) => setState(() => _draft = _draft.copyWith(pricePromoGrosz: v))),
                  _ScenLine(label: context.t('gr_sc_resto'), qty: _draft.qtyRestaurant, priceGrosz: _draft.priceRestaurantGrosz, onQty: (v) => setState(() => _draft = _draft.copyWith(qtyRestaurant: v)), onPrice: (v) => setState(() => _draft = _draft.copyWith(priceRestaurantGrosz: v))),
                  _ScenLine(label: context.t('gr_sc_banner'), qty: _draft.qtyBanner, priceGrosz: _draft.priceBannerGrosz, onQty: (v) => setState(() => _draft = _draft.copyWith(qtyBanner: v)), onPrice: (v) => setState(() => _draft = _draft.copyWith(priceBannerGrosz: v))),
                  _ScenLine(label: context.t('gr_sc_sponsor'), qty: _draft.qtySponsor, priceGrosz: _draft.priceSponsorGrosz, onQty: (v) => setState(() => _draft = _draft.copyWith(qtySponsor: v)), onPrice: (v) => setState(() => _draft = _draft.copyWith(priceSponsorGrosz: v))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        key: const Key('gr-pdf-example'),
                        onPressed: () => setState(() => _draft = GrowthScenario.pdfExample),
                        child: Text(context.t('gr_load_pdf')),
                      ),
                      OutlinedButton(
                        key: const Key('gr-use-current'),
                        onPressed: () => setState(() => _draft = widget.svc.applyCurrentPrices(_draft)),
                        child: Text(context.t('gr_use_current')),
                      ),
                    ],
                  ),
                  if (_draft.priceProGrosz == 39900)
                    Text(context.t('gr_pdf_pro_note', {'current': '${PricingConfigService.instance.config.proStoreMonthlyPln}'})),
                  const SizedBox(height: 8),
                  Text('${context.t('gr_basis_gross')}: ${GrowthMoney.format(_draft.grossGrosz)}', key: const Key('gr-scen-gross')),
                  Text('${context.t('gr_basis_net')}: ${GrowthMoney.format(_draft.netGrosz)}', key: const Key('gr-scen-net')),
                  const SizedBox(height: 8),
                  _ScenarioVsTarget(grossGrosz: _draft.grossGrosz, band: band, reduce: reduce),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('gr-scen-save'),
                    onPressed: () => _save(context),
                    child: Text(context.t('gr_save_scenario')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    final name = TextEditingController(text: _draft.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('gr_save_scenario')),
        content: TextField(key: const Key('gr-scen-name'), controller: name, decoration: InputDecoration(labelText: context.t('gr_scen_name'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('ui_close'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('gr_save_scenario'))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      widget.svc.saveScenario(_draft.copyWith(name: name.text.trim()), actor: context.read<FakeAuthState>());
    }
  }
}

class _DashBorderPainter extends CustomPainter {
  _DashBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dash = 6.0;
    const gap = 4.0;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashBorderPainter old) => old.color != color;
}

class _StreamRow extends StatelessWidget {
  const _StreamRow({required this.row, required this.gross});
  final GrowthStreamActual row;
  final bool gross;

  @override
  Widget build(BuildContext context) {
    if (row.noData) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      title: Text(context.t('gr_stream_${row.id.name}')),
      trailing: Text(GrowthMoney.format(gross ? row.grossGrosz : row.netGrosz)),
    );
  }
}

class _ScenLine extends StatelessWidget {
  const _ScenLine({required this.label, required this.qty, required this.priceGrosz, required this.onQty, required this.onPrice});
  final String label;
  final int qty;
  final int priceGrosz;
  final ValueChanged<int> onQty;
  final ValueChanged<int> onPrice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label)),
          SizedBox(
            width: 56,
            child: TextFormField(
              initialValue: '$qty',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) => onQty(int.tryParse(v) ?? 0),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextFormField(
              initialValue: GrowthMoney.inputFromGrosz(priceGrosz),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(isDense: true, suffixText: 'PLN'),
              onChanged: (v) {
                final grosz = GrowthMoney.tryParsePlnToGrosz(v);
                if (grosz != null) onPrice(grosz);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioVsTarget extends StatelessWidget {
  const _ScenarioVsTarget({required this.grossGrosz, required this.band, required this.reduce});
  final int grossGrosz;
  final GrowthCell band;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final goal = (band.goal ?? band.min ?? 1) * 100;
    final v = goal == 0 ? 0.0 : (grossGrosz / goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('gr_scen_vs_target')),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: v),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
          builder: (context, value, _) => LinearProgressIndicator(value: value),
        ),
        Text('${GrowthMoney.format(grossGrosz)} · min ${band.min ?? '—'} · goal ${band.goal ?? '—'}'),
      ],
    );
  }
}

class GrowthBudgetTab extends StatefulWidget {
  const GrowthBudgetTab({super.key, required this.svc});
  final GrowthService svc;

  @override
  State<GrowthBudgetTab> createState() => _GrowthBudgetTabState();
}

class _GrowthBudgetTabState extends State<GrowthBudgetTab> {
  String? _phaseFilter;
  GrowthExpenseCategory? _catFilter;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final rows = widget.svc.filteredExpenses(phaseId: _phaseFilter, category: _catFilter);
    final behind = widget.svc.behindCount(GrowthPeriod.p3to6);
    return ListView(
      key: const Key('gr-budget'),
      children: [
        Text(context.t('gr_budget_note'), style: theme.bodySmall),
        const SizedBox(height: 8),
        for (final p in widget.svc.phases) _PhaseCard(view: widget.svc.phaseView(p)),
        Text('${context.t('gr_budget_total')}: ${GrowthMoney.formatZl(widget.svc.phases.fold<int>(0, (a, p) => a + p.plannedGrosz))}'),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(key: const Key('gr-exp-add'), onPressed: () => _form(context), child: Text(context.t('gr_add_expense'))),
        ),
        Wrap(
          spacing: 8,
          children: [
            DropdownButton<String?>(
              value: _phaseFilter,
              hint: Text(context.t('gr_filter_phase')),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                for (final p in widget.svc.phases) DropdownMenuItem(value: p.id, child: Text(context.t(p.labelKey))),
              ],
              onChanged: (v) => setState(() => _phaseFilter = v),
            ),
            DropdownButton<GrowthExpenseCategory?>(
              value: _catFilter,
              hint: Text(context.t('gr_filter_cat')),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                for (final c in GrowthExpenseCategory.values) DropdownMenuItem(value: c, child: Text(context.t('gr_exp_${c.name}'))),
              ],
              onChanged: (v) => setState(() => _catFilter = v),
            ),
            TextButton(
              onPressed: () {
                final csv = widget.svc.expensesCsv(rows);
                widget.svc.exportExpensesCsv(context.read<FakeAuthState>(), rows);
                showDashTextExport(context, title: context.t('gr_exp_csv'), fileName: 'growth-expenses.csv', content: csv);
              },
              child: Text(context.t('gr_exp_csv')),
            ),
          ],
        ),
        if (rows.isEmpty) Text(context.t('gr_no_data')) else ...[
          for (final e in rows) _ExpenseTile(e: e, svc: widget.svc),
        ],
        const SizedBox(height: 16),
        Semantics(header: true, child: Text(context.t('gr_cash_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w800))),
        Text(context.t('gr_cash_not_accounting'), style: theme.bodySmall),
        Table(
          children: [
            TableRow(children: [
              Semantics(header: true, child: Text(context.t('gr_cash_month'))),
              Semantics(header: true, child: Text(context.t('gr_cash_collected'))),
              Semantics(header: true, child: Text(context.t('gr_cash_exp'))),
              Semantics(header: true, child: Text(context.t('gr_cash_pos'))),
            ]),
            for (final m in widget.svc.cashMonths())
              TableRow(children: [
                Text(DateFormat.yMMM().format(m.monthStart)),
                Text(m.hasSource ? GrowthMoney.format(m.collectedNetGrosz) : context.t('gr_no_data')),
                Text(GrowthMoney.format(m.expenseNetGrosz)),
                Text(GrowthMoney.format(m.positionGrosz)),
              ]),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          key: const Key('gr-month6-gate'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('gr_month6_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                Text(context.t('gr_month6_behind', {'n': '$behind'})),
                Text(context.t('gr_month6_principle')),
                FilledButton(
                  key: const Key('gr-commit-612'),
                  onPressed: () => _commit(context),
                  child: Text(context.t('gr_commit_612')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _form(BuildContext context, [GrowthExpense? existing]) async {
    final amount = TextEditingController(text: existing == null ? '' : GrowthMoney.inputFromGrosz(existing.amountGrosz));
    final desc = TextEditingController(text: existing?.description ?? '');
    final vendor = TextEditingController(text: existing?.vendor ?? '');
    final inv = TextEditingController(text: existing?.invoiceRef ?? '');
    final overrun = TextEditingController(text: existing?.overrunNote ?? '');
    var basis = existing?.basis ?? GrowthRevenueBasis.net;
    var cat = existing?.category ?? GrowthExpenseCategory.other;
    var date = existing?.date ?? TGClock.now();
    final err = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom, left: 16, right: 16, top: 16),
          child: StatefulBuilder(
            builder: (ctx, setLocal) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(key: const Key('gr-exp-amount'), controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.t('gr_exp_amount'))),
                  TextField(key: const Key('gr-exp-desc'), controller: desc, decoration: InputDecoration(labelText: context.t('gr_exp_desc'))),
                  TextField(controller: vendor, decoration: InputDecoration(labelText: context.t('gr_exp_vendor'))),
                  TextField(controller: inv, decoration: InputDecoration(labelText: context.t('gr_exp_invoice'))),
                  DropdownButton<GrowthRevenueBasis>(
                    value: basis,
                    items: [for (final b in GrowthRevenueBasis.values) DropdownMenuItem(value: b, child: Text(b.name))],
                    onChanged: (v) => setLocal(() => basis = v ?? basis),
                  ),
                  DropdownButton<GrowthExpenseCategory>(
                    value: cat,
                    items: [for (final c in GrowthExpenseCategory.values) DropdownMenuItem(value: c, child: Text(context.t('gr_exp_${c.name}')))],
                    onChanged: (v) => setLocal(() => cat = v ?? cat),
                  ),
                  TextField(key: const Key('gr-exp-overrun'), controller: overrun, decoration: InputDecoration(labelText: context.t('gr_overrun_note'))),
                  FilledButton(
                    onPressed: () {
                      final grosz = GrowthMoney.tryParsePlnToGrosz(amount.text);
                      if (grosz == null) {
                        Navigator.pop(ctx, 'pln_invalid');
                        return;
                      }
                      final draft = GrowthExpense(
                        id: existing?.id ?? '',
                        date: date,
                        amountGrosz: grosz,
                        basis: basis,
                        category: cat,
                        phaseId: widget.svc.phaseIdForDate(date) ?? '',
                        description: desc.text,
                        vendor: vendor.text,
                        invoiceRef: inv.text,
                        createdBy: context.read<FakeAuthState>().userId,
                        overrunNote: overrun.text,
                      );
                      final result = existing == null
                          ? widget.svc.addExpense(draft, actor: context.read<FakeAuthState>())
                          : widget.svc.editExpense(draft.copyWith(), actor: context.read<FakeAuthState>());
                      Navigator.pop(ctx, result);
                    },
                    child: Text(context.t('gr_add_expense')),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (context.mounted && err != null) {
      final key = switch (err) {
        'overrun_note_required' => 'gr_overrun_required',
        'pln_invalid' => 'gr_pln_invalid',
        _ => 'gr_reason_required',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t(key))));
    }
  }

  Future<void> _commit(BuildContext context) async {
    final note = TextEditingController();
    final err = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('gr_commit_612')),
        content: TextField(key: const Key('gr-commit-note'), controller: note, decoration: InputDecoration(labelText: context.t('gr_reason'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('ui_close'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, widget.svc.commitPhase('bp-6-12', note: note.text, actor: context.read<FakeAuthState>())),
            child: Text(context.t('gr_commit_612')),
          ),
        ],
      ),
    );
    if (context.mounted && err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('gr_reason_required'))));
    }
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.view});
  final BudgetPhaseView view;

  @override
  Widget build(BuildContext context) {
    final p = view.phase;
    final theme = FlutterFlowTheme.of(context);
    return Card(
      key: Key('gr-phase-${p.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t(p.labelKey), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
            Text('${context.t('gr_planned')}: ${GrowthMoney.format(p.plannedGrosz)}'),
            Text('${context.t('gr_spent')}: ${GrowthMoney.format(view.spentGrosz)}'),
            Text('${context.t('gr_remaining')}: ${GrowthMoney.format(view.remainingGrosz)}'),
            Text('${context.t('gr_usage')}: ${view.usageBps ~/ 100}%'),
            if (view.warn80)
              Row(children: [const Icon(Icons.warning_amber_outlined, color: TGColors.slaAmber), const SizedBox(width: 6), Expanded(child: Text(context.t('gr_warn_80')))]),
            if (view.warn100)
              Row(children: [const Icon(Icons.error_outline, color: TGColors.error), const SizedBox(width: 6), Expanded(child: Text(context.t('gr_warn_100')))]),
            Text(p.commitment == BudgetCommitment.committed ? context.t('gr_committed') : context.t('gr_not_committed')),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.e, required this.svc});
  final GrowthExpense e;
  final GrowthService svc;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('gr-exp-${e.id}'),
      title: Text('${e.description} · ${GrowthMoney.format(e.amountGrosz)}'),
      subtitle: Text('${e.category.name} · ${e.voided ? context.t('gr_voided') : e.phaseId}'),
      trailing: e.voided
          ? null
          : TextButton(
              onPressed: () => _void(context),
              child: Text(context.t('gr_void')),
            ),
    );
  }

  Future<void> _void(BuildContext context) async {
    final reason = TextEditingController();
    final err = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('gr_void')),
        content: TextField(key: const Key('gr-void-reason'), controller: reason, decoration: InputDecoration(labelText: context.t('gr_reason'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('ui_close'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, svc.voidExpense(e.id, reason: reason.text, actor: context.read<FakeAuthState>())), child: Text(context.t('gr_void'))),
        ],
      ),
    );
    if (context.mounted && err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('gr_reason_required'))));
    }
  }
}

class GrowthWeeklyTab extends StatefulWidget {
  const GrowthWeeklyTab({super.key, required this.svc});
  final GrowthService svc;

  @override
  State<GrowthWeeklyTab> createState() => _GrowthWeeklyTabState();
}

class _GrowthWeeklyTabState extends State<GrowthWeeklyTab> {
  late DateTime _week = ReferralRepository.warsawWeekStart(TGClock.now());
  String _search = '';
  final _q1 = TextEditingController();
  final _q2 = TextEditingController();
  final _q3 = TextEditingController();
  final _q3over = TextEditingController();
  final _q4 = TextEditingController();
  final _q5 = TextEditingController();
  final _q5owner = TextEditingController();
  final _decisions = TextEditingController();
  GrowthMeetChannel _channel = GrowthMeetChannel.referrals;

  @override
  void dispose() {
    _q1.dispose();
    _q2.dispose();
    _q3.dispose();
    _q3over.dispose();
    _q4.dispose();
    _q5.dispose();
    _q5owner.dispose();
    _decisions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auto = widget.svc.weekAuto(_week);
    final existing = widget.svc.meetingForWeek(_week);
    final prev = widget.svc.previousMeeting(_week);
    final locked = existing?.isLocked(TGClock.now()) ?? false;
    final history = widget.svc.meetings.where((m) => _search.isEmpty || DateFormat.yMMMd().format(m.weekStart).contains(_search));
    return ListView(
      key: const Key('gr-weekly'),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => setState(() => _shiftWeek(-7)), icon: const Icon(Icons.chevron_left)),
            Text('${DateFormat.MMMd().format(_week)} – ${DateFormat.MMMd().format(_week.add(const Duration(days: 6)))}'),
            IconButton(onPressed: () => setState(() => _shiftWeek(7)), icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _Col(
                title: context.t('gr_activity'),
                child: Text('${context.t('gr_src_entered')}: ${auto.repMeetings}'),
              ),
            ),
            Expanded(
              child: _Col(
                title: context.t('gr_results'),
                child: Text('${context.t('ref_status_won')} ${auto.won} · ${context.t('ref_status_paid')} ${auto.paidCustomers} · ${GrowthMoney.format(auto.weekNetGrosz)}'),
              ),
            ),
          ],
        ),
        Text(context.t('gr_activity_hint'), style: theme.bodySmall),
        const SizedBox(height: 12),
        Text('${context.t('gr_q1')} ${auto.won} / ${auto.signups}', style: theme.titleSmall),
        Text(_seg(auto.signupsBySegment, auto.wonBySegment), style: theme.bodySmall),
        Text(context.t('gr_src_system'), style: theme.labelSmall),
        TextField(controller: _q1, enabled: !locked, decoration: InputDecoration(labelText: context.t('gr_note'))),
        Text('${context.t('gr_q2')} ${auto.newActiveListings}'),
        TextField(controller: _q2, enabled: !locked, decoration: InputDecoration(labelText: context.t('gr_note'))),
        Text('${context.t('gr_q3')} ${auto.repMeetings}'),
        Text(context.t('gr_src_entered'), style: theme.labelSmall),
        TextField(controller: _q3over, enabled: !locked, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.t('gr_q3_override'))),
        TextField(controller: _q3, enabled: !locked, decoration: InputDecoration(labelText: context.t('gr_note'))),
        Text('${context.t('gr_q4')} ${auto.paidCustomers} · ${GrowthMoney.format(auto.weekNetGrosz)} / ${GrowthMoney.format(auto.weekGrossGrosz)} · MTD ${GrowthMoney.format(auto.mtdNetGrosz)} / ${GrowthMoney.format(auto.mtdGrossGrosz)}'),
        TextField(controller: _q4, enabled: !locked, decoration: InputDecoration(labelText: context.t('gr_note'))),
        Text(context.t('gr_q5')),
        TextField(controller: _q5, enabled: !locked, decoration: InputDecoration(labelText: context.t('gr_q5_problem'))),
        DropdownButton<GrowthMeetChannel>(
          value: _channel,
          items: [for (final c in GrowthMeetChannel.values) DropdownMenuItem(value: c, child: Text(context.t('gr_ch_${c.name}')))],
          onChanged: locked ? null : (v) => setState(() => _channel = v ?? _channel),
        ),
        TextField(controller: _q5owner, enabled: !locked, decoration: InputDecoration(labelText: context.t('gr_q5_owner'))),
        TextField(controller: _decisions, enabled: !locked, decoration: InputDecoration(labelText: context.t('gr_decisions'))),
        if (!locked)
          FilledButton(
            key: const Key('gr-meet-save'),
            onPressed: () {
              widget.svc.saveMeeting(
                GrowthWeeklyMeeting(
                  id: existing?.id ?? '',
                  weekStart: _week,
                  heldAt: existing?.heldAt ?? TGClock.now(),
                  attendees: existing?.attendees ?? const [],
                  q1Note: _q1.text,
                  q2Note: _q2.text,
                  q3Note: _q3.text,
                  q3Override: int.tryParse(_q3over.text),
                  q4Note: _q4.text,
                  q5Problem: _q5.text,
                  q5Channel: _channel,
                  q5Owner: _q5owner.text,
                  decisions: _decisions.text,
                  actionItems: existing?.actionItems ?? widget.svc.openActionsCarried(),
                  createdBy: context.read<FakeAuthState>().userId,
                  lockedAt: (existing?.heldAt ?? TGClock.now()).add(const Duration(days: 7)),
                  snapshot: auto,
                ),
                actor: context.read<FakeAuthState>(),
              );
            },
            child: Text(context.t('gr_meet_save')),
          )
        else ...[
          Text(context.t('gr_meet_locked')),
          TextField(key: const Key('gr-meet-amend'), decoration: InputDecoration(labelText: context.t('gr_amendment')), onSubmitted: (t) => widget.svc.amendMeeting(existing!.id, t, actor: context.read<FakeAuthState>())),
        ],
        const SizedBox(height: 12),
        if (prev == null)
          Text(context.t('ref_not_enough'), key: const Key('gr-week-nodata'))
        else
          Text(context.t('gr_vs_prev', {'won': '${auto.won - prev.snapshot.won}', 'paid': '${auto.paidCustomers - prev.snapshot.paidCustomers}'})),
        TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(labelText: context.t('gr_week_search'))),
        for (final m in history) ListTile(title: Text(DateFormat.yMMMd().format(m.weekStart)), subtitle: Text(m.q5Problem)),
      ],
    );
  }

  void _shiftWeek(int days) {
    _week = _week.add(Duration(days: days));
    final e = widget.svc.meetingForWeek(_week);
    _q1.text = e?.q1Note ?? '';
    _q2.text = e?.q2Note ?? '';
    _q3.text = e?.q3Note ?? '';
    _q3over.text = e?.q3Override?.toString() ?? '';
    _q4.text = e?.q4Note ?? '';
    _q5.text = e?.q5Problem ?? '';
    _q5owner.text = e?.q5Owner ?? '';
    _decisions.text = e?.decisions ?? '';
    _channel = e?.q5Channel ?? GrowthMeetChannel.referrals;
  }

  String _seg(Map<TGReferralSegment, int> s, Map<TGReferralSegment, int> w) {
    return [for (final e in TGReferralSegment.values) '${e.name}: ${s[e] ?? 0}/${w[e] ?? 0}'].join(' · ');
  }
}


class _Col extends StatelessWidget {
  const _Col({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: FlutterFlowTheme.of(context).labelMedium.override(fontWeight: FontWeight.w800)), child]),
      ),
    );
  }
}
