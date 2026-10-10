import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_case_page.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/admin/admin_deal_case_page.dart';
import 'package:twoja_gastromania/admin/admin_deal_queue_page.dart';
import 'package:twoja_gastromania/admin/admin_queue_page.dart';
import 'package:twoja_gastromania/admin/admin_so_case_page.dart';
import 'package:twoja_gastromania/admin/admin_so_queue_page.dart';
import 'package:twoja_gastromania/tg_models/tg_deal_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

class AdminListingsLookupPage extends StatefulWidget {
  const AdminListingsLookupPage({super.key});

  @override
  State<AdminListingsLookupPage> createState() => _AdminListingsLookupPageState();
}

class _AdminListingsLookupPageState extends State<AdminListingsLookupPage> {
  String _q = '';
  List<TGProduct> _all = const [];

  @override
  void initState() {
    super.initState();
    TGProductService.instance.getAll().then((v) {
      if (mounted) setState(() => _all = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hits = _all.where((p) {
      if (_q.isEmpty) return true;
      final blob = '${p.listingNo} ${p.title} ${p.seller.name} ${p.phone}'.toLowerCase();
      return blob.contains(_q.toLowerCase());
    }).take(40).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(hintText: context.t('ui_admin_search')),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: hits.length,
            itemBuilder: (context, i) {
              final p = hits[i];
              return ListTile(
                title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${p.listingNo} · ${p.seller.name} · ${p.status.name}'),
                onTap: () => TGAdminNav.openCase(context, p.listingNo ?? p.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class AdminSellersPage extends StatelessWidget {
  const AdminSellersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mod = context.watch<ModerationService>();
    final fmt = DateFormat('d MMM yyyy');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(context.t('ui_admin_sellers'), style: FlutterFlowTheme.of(context).titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        for (final s in mod.sellers.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AdminCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${s.seller.name} · ${adminSellerKindL10n(context, s.seller.type, verified: s.seller.verified)}'),
                subtitle: Text('${s.phone}${s.nip == null ? '' : ' · NIP ${s.nip}'}\n${context.t('ui_past_reports', {'r': '${s.pastReports}', 'm': '${s.pastRemovals}'})} · ${fmt.format(s.accountCreatedAt)}'),
                trailing: s.suspended ? Text(context.t('ui_suspended'), style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w900)) : null,
                onTap: () => TGAdminNav.openCase(context, ModerationService.caseKeyFor(TGReportTarget.seller, s.seller.id)),
              ),
            ),
          ),
      ],
    );
  }
}

class AdminAuditPage extends StatelessWidget {
  const AdminAuditPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mod = context.watch<ModerationService>();
    final fmt = DateFormat('d MMM yyyy HH:mm');
    final rows = mod.auditFor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(context.t('ui_admin_audit'), style: FlutterFlowTheme.of(context).titleMedium.override(fontWeight: FontWeight.w900)),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Text(context.t('ui_no_audit')))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final e = rows[i];
                    return ListTile(
                      dense: true,
                      title: Text(e.summary, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: Text('${e.actorId} · ${e.actorRole} · ${fmt.format(e.at)}${e.listingNo == null ? '' : ' · ${e.listingNo}'}${e.reason == null ? '' : ' · ${e.reason}'}'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class AdminTemplatesPage extends StatefulWidget {
  const AdminTemplatesPage({super.key});

  @override
  State<AdminTemplatesPage> createState() => _AdminTemplatesPageState();
}

class _AdminTemplatesPageState extends State<AdminTemplatesPage> {
  TGEmailTemplate? _editing;

  @override
  Widget build(BuildContext context) {
    final mod = context.watch<ModerationService>();
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(context.t('ui_admin_templates'), style: FlutterFlowTheme.of(context).titleMedium.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              for (final t in mod.templates)
                ListTile(
                  dense: true,
                  selected: _editing?.id == t.id && _editing?.lang == t.lang,
                  title: Text(t.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  subtitle: Text('${t.id} · ${t.lang.toUpperCase()}', style: const TextStyle(fontSize: 11)),
                  onTap: () => setState(() => _editing = t),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _editing == null
              ? Center(child: Text(context.t('ui_select_template')))
              : _Editor(
                  key: ValueKey('${_editing!.id}-${_editing!.lang}'),
                  template: _editing!,
                  onSave: (t) {
                    mod.upsertTemplate(t);
                    setState(() => _editing = t);
                  },
                ),
        ),
      ],
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor({super.key, required this.template, required this.onSave});
  final TGEmailTemplate template;
  final ValueChanged<TGEmailTemplate> onSave;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final TextEditingController _name = TextEditingController(text: widget.template.name);
  late final TextEditingController _subject = TextEditingController(text: widget.template.subject);
  late final TextEditingController _body = TextEditingController(text: widget.template.body);

  @override
  void dispose() {
    _name.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: context.t('ui_template_name'))),
          TextField(controller: _subject, decoration: InputDecoration(labelText: context.t('ui_subject'))),
          Expanded(child: TextField(controller: _body, maxLines: null, expands: true, decoration: InputDecoration(labelText: context.t('ui_template_body')))),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TGButton(
              onPressed: () => widget.onSave(widget.template.copyWith(name: _name.text, subject: _subject.text, body: _body.text)),
              label: context.t('ui_save_template'),
              height: 40,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminQueueHost extends StatelessWidget {
  const AdminQueueHost({super.key, this.filter});
  final String? filter;

  @override
  Widget build(BuildContext context) => AdminShell(section: 'queue', child: AdminQueuePage(filter: filter));
}

class AdminListingsHost extends StatelessWidget {
  const AdminListingsHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'listings', child: AdminListingsLookupPage());
}

class AdminSellersHost extends StatelessWidget {
  const AdminSellersHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'sellers', child: AdminSellersPage());
}

class AdminAuditHost extends StatelessWidget {
  const AdminAuditHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'audit', child: AdminAuditPage());
}

class AdminTemplatesHost extends StatelessWidget {
  const AdminTemplatesHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'templates', child: AdminTemplatesPage());
}

class AdminCaseHost extends StatelessWidget {
  const AdminCaseHost({super.key, required this.listingNo});
  final String listingNo;
  @override
  Widget build(BuildContext context) => AdminShell(section: 'queue', child: AdminCasePage(listingNo: listingNo));
}

class AdminDealsHost extends StatelessWidget {
  const AdminDealsHost({super.key, this.queue});
  final String? queue;

  @override
  Widget build(BuildContext context) {
    final kind = TGDealQueueKind.values.where((e) => e.name == queue).firstOrNull ?? TGDealQueueKind.objection;
    return AdminShell(section: 'deals', child: AdminDealQueuePage(queue: kind));
  }
}

class AdminDealCaseHost extends StatelessWidget {
  const AdminDealCaseHost({super.key, required this.dealNo});
  final String dealNo;
  @override
  Widget build(BuildContext context) => AdminShell(section: 'deals', child: AdminDealCasePage(dealNo: dealNo));
}

class AdminSoHost extends StatelessWidget {
  const AdminSoHost({super.key, this.queue});
  final String? queue;

  @override
  Widget build(BuildContext context) {
    final kind = TGSoAdminQueue.values.where((e) => e.name == queue).firstOrNull ?? TGSoAdminQueue.needsMatching;
    return AdminShell(section: 'special_orders', child: AdminSoQueuePage(queue: kind));
  }
}

class AdminSoCaseHost extends StatelessWidget {
  const AdminSoCaseHost({super.key, required this.requestNo});
  final String requestNo;
  @override
  Widget build(BuildContext context) => AdminShell(section: 'special_orders', child: AdminSoCasePage(requestNo: requestNo));
}
