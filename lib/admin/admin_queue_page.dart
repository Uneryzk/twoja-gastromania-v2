import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

class AdminQueuePage extends StatefulWidget {
  const AdminQueuePage({super.key, this.filter});
  final String? filter;

  @override
  State<AdminQueuePage> createState() => _AdminQueuePageState();
}

class _AdminQueuePageState extends State<AdminQueuePage> {
  TGReportReason? _reason;
  TGModerationPriority? _priority;
  TGReportStatus? _status;
  String? _assigned;
  int _focus = 0;
  List<TGProduct> _catalogue = const [];

  @override
  void initState() {
    super.initState();
    ModerationService.instance.ensureSeeded();
    _applyIncomingFilter(widget.filter);
    TGProductService.instance.getAll().then((all) {
      if (mounted) setState(() => _catalogue = all);
    });
  }

  @override
  void didUpdateWidget(covariant AdminQueuePage old) {
    super.didUpdateWidget(old);
    if (old.filter != widget.filter) _applyIncomingFilter(widget.filter);
  }

  void _applyIncomingFilter(String? filter) {
    _status = null;
    switch (filter) {
      case 'new':
        _status = TGReportStatus.new_;
        break;
      case 'in_review':
        _status = TGReportStatus.inReview;
        break;
      case 'waiting':
        _status = TGReportStatus.waitingSeller;
        break;
      case 'appeals':
        break;
    }
  }

  TGProduct? _product(String listingNo) {
    for (final p in _catalogue) {
      if (p.listingNo == listingNo) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mod = context.watch<ModerationService>();
    final auth = context.watch<FakeAuthState>();
    final appealsOnly = widget.filter == 'appeals';
    final rows = mod.filterQueue(reason: _reason, priority: _priority, status: _status, assignedTo: _assigned, appealsOnly: appealsOnly);
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
              Text(context.t('ui_admin_queue'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
              _Filter<TGReportReason>(
                label: context.t('ui_reason'),
                value: _reason,
                items: TGReportReason.values,
                nameOf: (r) => adminReasonLabel(context, r),
                onChanged: (v) => setState(() => _reason = v),
              ),
              _Filter<TGModerationPriority>(
                label: context.t('ui_priority'),
                value: _priority,
                items: TGModerationPriority.values,
                nameOf: (r) => adminPriorityLabel(context, r),
                onChanged: (v) => setState(() => _priority = v),
              ),
              _Filter<TGReportStatus>(
                label: context.t('ui_admin_status'),
                value: _status,
                items: const [TGReportStatus.new_, TGReportStatus.inReview, TGReportStatus.waitingSeller],
                nameOf: (r) => adminStatusLabel(context, r),
                onChanged: (v) => setState(() => _status = v),
              ),
              _AssignedFilter(value: _assigned, onChanged: (v) => setState(() => _assigned = v)),
              TextButton(
                key: const Key('admin-assign-to-me'),
                onPressed: rows.isEmpty
                    ? null
                    : () {
                        final row = rows[_focus.clamp(0, rows.length - 1)];
                        mod.assignTo(row.listingNo, auth.userId, actorRole: auth.role.name);
                      },
                child: Text(context.t('ui_assign_to_me')),
              ),
            ],
          ),
        ),
        Expanded(
          child: phone
              ? _QueueCards(
                  rows: rows,
                  focus: _focus,
                  productOf: _product,
                  sellerOf: (id) => id == null ? null : mod.sellerById(id),
                  onOpen: (no) => TGAdminNav.openCase(context, no),
                  onFocus: (i) => setState(() => _focus = i),
                )
              : _QueueTable(
                  rows: rows,
                  focus: _focus,
                  productOf: _product,
                  sellerOf: (id) => id == null ? null : mod.sellerById(id),
                  onOpen: (no) => TGAdminNav.openCase(context, no),
                  onFocus: (i) => setState(() => _focus = i),
                ),
        ),
        const AdminPrinciplesFooter(),
      ],
    );
  }
}

class _Filter<T> extends StatelessWidget {
  const _Filter({required this.label, required this.value, required this.items, required this.nameOf, required this.onChanged});
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) nameOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          hint: Text(label, style: const TextStyle(fontSize: 12)),
          items: [
            DropdownMenuItem<T?>(value: null, child: Text(context.t('ui_all_label', {'label': label}), style: const TextStyle(fontSize: 12))),
            for (final i in items) DropdownMenuItem<T?>(value: i, child: Text(nameOf(i), style: const TextStyle(fontSize: 12))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AssignedFilter extends StatelessWidget {
  const _AssignedFilter({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(context.t('ui_assigned'), style: const TextStyle(fontSize: 12)),
          items: [
            DropdownMenuItem(value: null, child: Text(context.t('ui_all_assigned'), style: const TextStyle(fontSize: 12))),
            DropdownMenuItem(value: '__none__', child: Text(context.t('ui_unassigned'), style: const TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'staff_moderator', child: Text(context.t('ui_role_moderator'), style: const TextStyle(fontSize: 12))),
            DropdownMenuItem(value: 'staff_admin', child: Text(context.t('ui_role_admin'), style: const TextStyle(fontSize: 12))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _QueueTable extends StatelessWidget {
  const _QueueTable({
    required this.rows,
    required this.focus,
    required this.productOf,
    required this.sellerOf,
    required this.onOpen,
    required this.onFocus,
  });

  final List<TGQueueCase> rows;
  final int focus;
  final TGProduct? Function(String) productOf;
  final TGModerationSeller? Function(String?) sellerOf;
  final ValueChanged<String> onOpen;
  final ValueChanged<int> onFocus;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          onFocus((focus + 1).clamp(0, rows.length - 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          onFocus((focus - 1).clamp(0, rows.length - 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter && rows.isNotEmpty) {
          onOpen(rows[focus.clamp(0, rows.length - 1)].listingNo);
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
              dataRowMinHeight: 44,
              dataRowMaxHeight: 52,
              headingRowColor: WidgetStateProperty.all(TGColors.adminBar),
              columns: [
                DataColumn(label: _Th(context.t('ui_report_no'))),
                DataColumn(label: _Th(context.t('ui_target'))),
                DataColumn(label: _Th(context.t('ui_listing_no_header'))),
                DataColumn(label: _Th(context.t('ui_reason'))),
                DataColumn(label: _Th(context.t('ui_reports'))),
                DataColumn(label: _Th(context.t('ui_seller'))),
                DataColumn(label: _Th(context.t('ui_age'))),
                DataColumn(label: _Th(context.t('ui_priority'))),
                DataColumn(label: _Th(context.t('ui_assigned'))),
                DataColumn(label: _Th(context.t('ui_admin_status'))),
              ],
              rows: [
                for (var i = 0; i < rows.length; i++)
                  _row(context, rows[i], i == focus, () {
                    onFocus(i);
                    onOpen(rows[i].listingNo);
                  }, () => onFocus(i)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, TGQueueCase row, bool focused, VoidCallback onOpen, VoidCallback onHover) {
    final product = productOf(row.listingNo);
    final seller = sellerOf(row.sellerId) ?? (product == null
        ? null
        : TGModerationSeller(seller: product.seller, phone: product.phone, accountCreatedAt: DateTime.now()));
    final kind = seller == null ? '—' : adminSellerKindL10n(context, seller.seller.type, verified: seller.seller.verified);
    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) || focused) return TGColors.surfaceHover;
        return TGColors.surface;
      }),
      onSelectChanged: (_) => onOpen(),
      cells: [
        DataCell(Text(row.reports.isEmpty ? '—' : row.primary.reportNo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        DataCell(Text(context.t('ui_target_${row.target.name}'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
        DataCell(
          InkWell(
            onTap: onOpen,
            child: Text(row.listingNo, style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800, decoration: TextDecoration.underline, fontSize: 12)),
          ),
        ),
        DataCell(row.reports.isEmpty ? Text(context.t('ui_appeal')) : AdminReasonChip(reason: row.primary.reason)),
        DataCell(Text('${row.reportCount}', style: const TextStyle(fontWeight: FontWeight.w800))),
        DataCell(Text('${seller?.seller.name ?? '—'} · $kind', style: const TextStyle(fontSize: 12))),
        DataCell(AdminSlaChip(row: row)),
        DataCell(Text(adminPriorityLabel(context, row.priority), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: row.priority == TGModerationPriority.high ? TGColors.error : TGColors.textPrimary))),
        DataCell(Text(row.assignedTo == null ? context.t('ui_unassigned') : (row.assignedTo == 'staff_admin' ? context.t('ui_role_admin') : context.t('ui_role_moderator')), style: const TextStyle(fontSize: 12))),
        DataCell(AdminStatusChip(status: row.status)),
      ],
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Semantics(header: true, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)));
  }
}

class _QueueCards extends StatelessWidget {
  const _QueueCards({
    required this.rows,
    required this.focus,
    required this.productOf,
    required this.sellerOf,
    required this.onOpen,
    required this.onFocus,
  });

  final List<TGQueueCase> rows;
  final int focus;
  final TGProduct? Function(String) productOf;
  final TGModerationSeller? Function(String?) sellerOf;
  final ValueChanged<String> onOpen;
  final ValueChanged<int> onFocus;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        final seller = sellerOf(row.sellerId);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            key: Key('admin-queue-card-${row.listingNo}'),
            onTap: () {
              onFocus(i);
              onOpen(row.listingNo);
            },
            child: AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(row.listingNo, style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Text(context.t('ui_target_${row.target.name}'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      AdminSlaChip(row: row),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (row.reports.isNotEmpty) AdminReasonChip(reason: row.primary.reason),
                      Text(adminPriorityLabel(context, row.priority), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      AdminStatusChip(status: row.status),
                      Text('×${row.reportCount}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(seller?.seller.name ?? context.t('ui_seller'), style: const TextStyle(color: TGColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
