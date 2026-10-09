import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_deal_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_services/deal_moderation_service.dart';

class AdminDealQueuePage extends StatefulWidget {
  const AdminDealQueuePage({super.key, this.queue = TGDealQueueKind.objection});
  final TGDealQueueKind queue;

  @override
  State<AdminDealQueuePage> createState() => _AdminDealQueuePageState();
}

class _AdminDealQueuePageState extends State<AdminDealQueuePage> {
  int _focus = 0;
  String _q = '';

  @override
  void initState() {
    super.initState();
    DealModerationService.instance.ensureSeeded();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DealModerationService>();
    final auth = context.watch<FakeAuthState>();
    var rows = svc.filtered(widget.queue);
    if (_q.trim().isNotEmpty) {
      final q = _q.trim().toLowerCase();
      rows = rows.where((c) => '${c.dealNo} ${c.listingNo} ${c.seller.name} ${c.buyer.name}'.toLowerCase().contains(q)).toList();
    }
    if (_focus >= rows.length) _focus = rows.isEmpty ? 0 : rows.length - 1;
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final theme = FlutterFlowTheme.of(context);

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
                width: 240,
                height: 36,
                child: TextField(
                  key: const Key('admin-deals-search'),
                  onChanged: (v) => setState(() => _q = v),
                  onSubmitted: (v) {
                    final hit = DealModerationService.instance.resolveSearch(v);
                    if (hit != null) TGAdminNav.openDeal(context, hit);
                  },
                  decoration: InputDecoration(isDense: true, hintText: context.t('ui_search_deals')),
                ),
              ),
              TextButton(
                key: const Key('admin-deal-assign-to-me'),
                onPressed: rows.isEmpty
                    ? null
                    : () {
                        final row = rows[_focus.clamp(0, rows.length - 1)];
                        if (!svc.canAssign(row, auth.userId)) return;
                        svc.assign(row, auth.userId, actorId: auth.userId, actorRole: auth.role.name);
                      },
                child: Text(context.t('ui_assign_to_me')),
              ),
            ],
          ),
        ),
        Expanded(
          child: phone
              ? _DealQueueCards(rows: rows, focus: _focus, onOpen: (no) => TGAdminNav.openDeal(context, no), onFocus: (i) => setState(() => _focus = i))
              : _DealQueueTable(rows: rows, focus: _focus, onOpen: (no) => TGAdminNav.openDeal(context, no), onFocus: (i) => setState(() => _focus = i)),
        ),
        const AdminPrinciplesFooter(),
      ],
    );
  }

  String _title(BuildContext context, TGDealQueueKind k) => switch (k) {
        TGDealQueueKind.objection => context.t('ui_admin_objections'),
        TGDealQueueKind.flagged => context.t('ui_admin_flagged_reviews'),
        TGDealQueueKind.dispute => context.t('ui_admin_disputes'),
        TGDealQueueKind.appeal => context.t('ui_admin_deal_appeals'),
        TGDealQueueKind.all => context.t('ui_admin_all_deals'),
      };
}

String adminDealQueueLabel(BuildContext context, TGDealQueueKind k) => switch (k) {
      TGDealQueueKind.objection => context.t('ui_queue_objection'),
      TGDealQueueKind.flagged => context.t('ui_queue_flagged'),
      TGDealQueueKind.dispute => context.t('ui_queue_dispute'),
      TGDealQueueKind.appeal => context.t('ui_queue_appeal'),
      TGDealQueueKind.all => context.t('ui_admin_all_deals'),
    };

List<Widget> dealSlaChips(BuildContext context, TGAdminDealCase c) {
  final now = TGClock.now();
  final chips = <Widget>[];
  if (c.evidenceDueAt != null) {
    final left = c.evidenceDueAt!.difference(now);
    final tone = c.toneFor(c.slaStart, c.evidenceDueAt!, now);
    chips.add(AdminDeadlineChip(
      label: left.isNegative ? context.t('ui_evidence_overdue') : context.t('ui_evidence_left', {'n': '${left.inHours.clamp(0, 999)}'}),
      tone: tone,
    ));
  }
  final dLeft = c.decisionDueAt.difference(now);
  var bd = 0;
  var cursor = now;
  while (cursor.isBefore(c.decisionDueAt)) {
    cursor = cursor.add(const Duration(days: 1));
    if (cursor.weekday != DateTime.saturday && cursor.weekday != DateTime.sunday) bd++;
  }
  chips.add(AdminDeadlineChip(
    label: dLeft.isNegative
        ? context.t('ui_decision_overdue')
        : (dLeft < const Duration(hours: 48)
            ? context.t('ui_decision_due_hours', {'n': '${dLeft.inHours.clamp(1, 47)}'})
            : context.t('ui_decision_due', {'n': '${bd.clamp(1, 99)}'})),
    tone: c.toneFor(c.slaStart, c.decisionDueAt, now),
  ));
  if (c.hardCapAt != null) {
    final h = c.hardCapAt!.difference(now);
    final tone = c.hardCapBreached ? TGSlaTone.overdue : c.toneFor(c.createdAt, c.hardCapAt!, now);
    final label = c.hardCapBreached
        ? context.t('ui_hard_cap_breached')
        : (h.inHours < 48 ? context.t('ui_hard_cap_hours', {'n': '${h.inHours.clamp(0, 999)}'}) : context.t('ui_hard_cap_in', {'n': '${h.inDays.clamp(0, 99)}'}));
    chips.add(AdminDeadlineChip(label: label, tone: tone));
  }
  return chips;
}

class _Th extends StatelessWidget {
  const _Th(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Semantics(header: true, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
  }
}

class _DealQueueTable extends StatelessWidget {
  const _DealQueueTable({required this.rows, required this.focus, required this.onOpen, required this.onFocus});
  final List<TGAdminDealCase> rows;
  final int focus;
  final ValueChanged<String> onOpen;
  final ValueChanged<int> onFocus;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          onFocus((focus + 1).clamp(0, rows.length - 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          onFocus((focus - 1).clamp(0, rows.length - 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter && rows.isNotEmpty) {
          onOpen(rows[focus.clamp(0, rows.length - 1)].dealNo);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 220),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 40,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              headingRowColor: WidgetStateProperty.all(TGColors.adminBar),
              columns: [
                DataColumn(label: _Th(context.t('ui_deal_no_header'))),
                DataColumn(label: _Th(context.t('ui_queue_type'))),
                DataColumn(label: _Th(context.t('ui_listing_no_header'))),
                DataColumn(label: _Th(context.t('ui_seller'))),
                DataColumn(label: _Th(context.t('ui_buyer'))),
                DataColumn(label: _Th(context.t('ui_risk_flags'))),
                DataColumn(label: _Th(context.t('ui_age'))),
                DataColumn(label: _Th(context.t('ui_priority'))),
                DataColumn(label: _Th(context.t('ui_assigned'))),
                DataColumn(label: _Th(context.t('ui_admin_status'))),
              ],
              rows: [
                for (var i = 0; i < rows.length; i++)
                  _row(context, rows[i], i == focus, () {
                    onFocus(i);
                    onOpen(rows[i].dealNo);
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, TGAdminDealCase row, bool focused, VoidCallback onOpen) {
    final kind = row.seller.sellerType == null
        ? '—'
        : adminSellerKindL10n(context, row.seller.sellerType!, verified: false);
    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) || focused) return TGColors.surfaceHover;
        return TGColors.surface;
      }),
      onSelectChanged: (_) => onOpen(),
      cells: [
        DataCell(Text(row.dealNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: TGColors.cta))),
        DataCell(Text(adminDealQueueLabel(context, row.queue), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
        DataCell(Text(row.listingNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        DataCell(Text('${row.seller.name} ($kind)', style: const TextStyle(fontSize: 12))),
        DataCell(Text(row.buyer.name, style: const TextStyle(fontSize: 12))),
        DataCell(Text('${row.flags.length}', style: const TextStyle(fontWeight: FontWeight.w800))),
        DataCell(Wrap(spacing: 4, runSpacing: 4, children: dealSlaChips(context, row))),
        DataCell(Text(adminPriorityLabel(context, row.priority), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: row.priority == TGModerationPriority.high ? TGColors.error : TGColors.textPrimary))),
        DataCell(Text(row.assignedTo == null ? context.t('ui_unassigned') : (row.assignedTo == 'staff_admin' ? context.t('ui_role_admin') : context.t('ui_role_moderator')), style: const TextStyle(fontSize: 12))),
        DataCell(
          AnimatedSwitcher(
            duration: tgAnim(context, const Duration(milliseconds: 200)),
            child: Text(row.statusLabel, key: ValueKey(row.statusLabel), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _DealQueueCards extends StatelessWidget {
  const _DealQueueCards({required this.rows, required this.focus, required this.onOpen, required this.onFocus});
  final List<TGAdminDealCase> rows;
  final int focus;
  final ValueChanged<String> onOpen;
  final ValueChanged<int> onFocus;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            key: Key('admin-deal-card-${row.dealNo}'),
            onTap: () {
              onFocus(i);
              onOpen(row.dealNo);
            },
            child: AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(row.dealNo, style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w900))),
                      Text(adminDealQueueLabel(context, row.queue), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${row.listingNo} · ${row.seller.name} → ${row.buyer.name}', style: const TextStyle(fontSize: 12, color: TGColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    ...dealSlaChips(context, row),
                    Text(adminPriorityLabel(context, row.priority), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    Text(row.statusLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
