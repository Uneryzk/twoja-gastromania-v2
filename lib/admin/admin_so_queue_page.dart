import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/special_order/so_status_chip.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

class AdminSoQueuePage extends StatefulWidget {
  const AdminSoQueuePage({super.key, this.queue = TGSoAdminQueue.needsMatching});
  final TGSoAdminQueue queue;

  @override
  State<AdminSoQueuePage> createState() => _AdminSoQueuePageState();
}

class _AdminSoQueuePageState extends State<AdminSoQueuePage> {
  int _focus = 0;
  String _q = '';

  @override
  void initState() {
    super.initState();
    TGSpecialOrderService.instance.ensureSeeded();
    TGAnalytics.track('so_admin_open', {'queue': widget.queue.name});
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FakeAuthState>();
    final svc = TGSpecialOrderService.instance..ensureSeeded();
    // Force rebuild via listen - service is not in provider; use AnimatedBuilder workaround by reading lengths
    final rows = svc.adminQueue(widget.queue, q: _q);
    if (_focus >= rows.length) _focus = rows.isEmpty ? 0 : rows.length - 1;
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final theme = FlutterFlowTheme.of(context);

    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final live = svc.adminQueue(widget.queue, q: _q);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(_title(context, widget.queue), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                  SizedBox(
                    width: 260,
                    height: 36,
                    child: TextField(
                      key: const Key('admin-so-search'),
                      onChanged: (v) => setState(() => _q = v),
                      onSubmitted: (v) {
                        final hit = svc.resolveAdminSearch(v);
                        if (hit != null) TGAdminNav.openSoCase(context, hit);
                      },
                      decoration: InputDecoration(isDense: true, hintText: context.t('ui_so_admin_search')),
                    ),
                  ),
                  TextButton(
                    onPressed: live.isEmpty
                        ? null
                        : () {
                            final row = live[_focus.clamp(0, live.length - 1)];
                            final auth = context.read<FakeAuthState>();
                            svc.assignAdmin(row.id, auth.userId);
                          },
                    child: Text(context.t('ui_assign_to_me')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: phone
                  ? _SoQueueCards(rows: live, focus: _focus, onOpen: (no) => TGAdminNav.openSoCase(context, no), onFocus: (i) => setState(() => _focus = i))
                  : _SoQueueTable(rows: live, focus: _focus, onOpen: (no) => TGAdminNav.openSoCase(context, no), onFocus: (i) => setState(() => _focus = i)),
            ),
            const AdminPrinciplesFooter(),
          ],
        );
      },
    );
  }

  String _title(BuildContext context, TGSoAdminQueue q) => switch (q) {
        TGSoAdminQueue.needsMatching => context.t('ui_so_admin_needs_matching'),
        TGSoAdminQueue.held => context.t('ui_so_admin_held'),
        TGSoAdminQueue.noQuotes => context.t('ui_so_admin_no_quotes'),
        TGSoAdminQueue.reported => context.t('ui_so_admin_reported'),
        TGSoAdminQueue.all => context.t('ui_so_admin_all'),
      };
}

class _SoQueueTable extends StatelessWidget {
  const _SoQueueTable({required this.rows, required this.focus, required this.onOpen, required this.onFocus});
  final List<TGSpecialRequest> rows;
  final int focus;
  final ValueChanged<String> onOpen;
  final ValueChanged<int> onFocus;

  @override
  Widget build(BuildContext context) {
    final svc = TGSpecialOrderService.instance;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          onFocus((focus + 1).clamp(0, rows.isEmpty ? 0 : rows.length - 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          onFocus((focus - 1).clamp(0, rows.isEmpty ? 0 : rows.length - 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter && rows.isNotEmpty) {
          onOpen(rows[focus.clamp(0, rows.length - 1)].requestNo);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(1.3),
            1: FlexColumnWidth(1.1),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(0.9),
            4: FlexColumnWidth(1.3),
            5: FlexColumnWidth(0.7),
            6: FlexColumnWidth(0.9),
            7: FlexColumnWidth(0.9),
            8: FlexColumnWidth(1.0),
            9: FlexColumnWidth(1.0),
          },
          children: [
            TableRow(
              children: [
                for (final h in [
                  'Request No.',
                  context.t('ui_so_admin_queue_type'),
                  context.t('ui_project_type'),
                  context.t('ui_region'),
                  context.t('ui_buyer'),
                  'Quotes',
                  context.t('ui_age'),
                  context.t('ui_assigned'),
                  context.t('ui_flags'),
                  context.t('ui_status'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Semantics(header: true, child: Text(h, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
                  ),
              ],
            ),
            for (var i = 0; i < rows.length; i++)
              TableRow(
                decoration: BoxDecoration(color: i == focus ? const Color(0xFF2A2A2A) : null),
                children: _cells(context, rows[i], svc, () {
                  onFocus(i);
                  onOpen(rows[i].requestNo);
                }),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _cells(BuildContext context, TGSpecialRequest r, TGSpecialOrderService svc, VoidCallback open) {
    final sla = svc.slaFor(r);
    final flags = svc.spamFlagsFor(r);
    final quotes = svc.activeQuoteCount(r.id);
    Widget cell(Widget child) => InkWell(
          onTap: open,
          onHover: (v) {},
          child: MouseRegion(
            onEnter: (_) {},
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2), child: child),
          ),
        );
    return [
      cell(Text(r.requestNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
      cell(Text(svc.queueKindFor(r).name, style: const TextStyle(fontSize: 11))),
      cell(Text(r.projectTypes.take(2).map((s) => context.t('ui_so_spec_${s.name}')).join(', '), maxLines: 2, style: const TextStyle(fontSize: 11))),
      cell(Text(r.voivodeship, style: const TextStyle(fontSize: 11))),
      cell(Row(children: [
        Flexible(child: Text(r.buyerName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
        if (r.phoneVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_user, size: 12, color: TGColors.cta)],
      ])),
      cell(Text('$quotes / ${r.quoteLimit}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
      cell(SoAdminSlaChip(tone: sla.$1, label: sla.$2)),
      cell(Text(r.assignedTo ?? '—', style: const TextStyle(fontSize: 11))),
      cell(Text(flags.take(2).join(', '), style: const TextStyle(fontSize: 10))),
      cell(Text(r.status.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
    ];
  }
}

class _SoQueueCards extends StatelessWidget {
  const _SoQueueCards({required this.rows, required this.focus, required this.onOpen, required this.onFocus});
  final List<TGSpecialRequest> rows;
  final int focus;
  final ValueChanged<String> onOpen;
  final ValueChanged<int> onFocus;

  @override
  Widget build(BuildContext context) {
    final svc = TGSpecialOrderService.instance;
    if (rows.isEmpty) return Center(child: Text(context.t('ui_so_admin_empty')));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = rows[i];
        final sla = svc.slaFor(r);
        return Material(
          color: i == focus ? const Color(0xFF2A2A2A) : TGColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              onFocus(i);
              onOpen(r.requestNo);
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(r.requestNo, style: const TextStyle(fontWeight: FontWeight.w900))),
                      SoAdminSlaChip(tone: sla.$1, label: sla.$2),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('${r.buyerName} · ${r.voivodeship} · ${svc.activeQuoteCount(r.id)}/${r.quoteLimit} quotes', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  SoStatusChip(status: r.status, quoteCount: svc.activeQuoteCount(r.id)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SoAdminSlaChip extends StatelessWidget {
  const SoAdminSlaChip({super.key, required this.tone, required this.label});
  final TGSoSlaTone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      TGSoSlaTone.ok => TGColors.textSecondary,
      TGSoSlaTone.warning => TGColors.slaAmber,
      TGSoSlaTone.overdue => const Color(0xFFFF5252),
    };
    return AnimatedDefaultTextStyle(
      duration: TGMotion.of(context, const Duration(milliseconds: 200)),
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
      child: Text(label),
    );
  }
}
