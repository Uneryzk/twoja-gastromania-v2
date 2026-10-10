import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

TGQueuedEmail _toQueued(TGSoEmailPreview p, String to) => TGQueuedEmail(
      id: 'so-mail',
      to: to,
      subject: p.subject,
      body: p.body,
      templateId: 'so_${p.lang}',
      createdAt: TGClock.now(),
    );

Future<void> showSoRejectModal(BuildContext context, TGSpecialRequest request) async {
  final auth = context.read<FakeAuthState>();
  final svc = TGSpecialOrderService.instance;
  var lang = 'en';
  final reason = TextEditingController(text: 'Out of scope or spam');
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      final preview = svc.previewEmail('reject', request, lang: lang, reason: reason.text);
      return AdminDialogScaffold(
        title: ctx.t('ui_so_admin_reject'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_confirm'), height: 40),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: reason, decoration: InputDecoration(labelText: ctx.t('ui_reason')), onChanged: (_) => setSt(() {})),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'en', label: Text('EN')), ButtonSegment(value: 'pl', label: Text('PL'))],
              selected: {lang},
              onSelectionChanged: (s) => setSt(() => lang = s.first),
            ),
            const SizedBox(height: 12),
            EmailPreviewBlock(email: _toQueued(preview, request.email)),
          ],
        ),
      );
    }),
  );
  if (ok == true && context.mounted) {
    svc.rejectRequest(request.id, actorId: auth.userId, actorRole: auth.role.name, reason: reason.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: svc.undoWindow,
        content: Text(context.t('ui_so_admin_rejected_undo')),
        action: SnackBarAction(
          label: context.t('ui_undo'),
          onPressed: () => svc.undoReject(actorId: auth.userId, actorRole: auth.role.name),
        ),
      ),
    );
  }
  reason.dispose();
}

Future<void> showSoContactBuyerModal(BuildContext context, TGSpecialRequest request) async {
  final auth = context.read<FakeAuthState>();
  final svc = TGSpecialOrderService.instance;
  var lang = 'en';
  final body = TextEditingController(text: svc.previewEmail('contact', request).body);
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      final preview = svc.previewEmail('contact', request, lang: lang);
      return AdminDialogScaffold(
        title: ctx.t('ui_so_admin_contact_buyer'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_send'), height: 40),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'en', label: Text('EN')), ButtonSegment(value: 'pl', label: Text('PL'))],
              selected: {lang},
              onSelectionChanged: (s) => setSt(() {
                lang = s.first;
                body.text = svc.previewEmail('contact', request, lang: lang).body;
              }),
            ),
            const SizedBox(height: 12),
            TextField(controller: body, maxLines: 5, decoration: InputDecoration(labelText: ctx.t('ui_message'))),
            const SizedBox(height: 12),
            EmailPreviewBlock(email: _toQueued(preview.copyWith(body: body.text), request.email)),
          ],
        ),
      );
    }),
  );
  if (ok == true && context.mounted) {
    svc.contactBuyer(request.id, actorId: auth.userId, actorRole: auth.role.name, lang: lang, body: body.text);
  }
  body.dispose();
}

Future<void> showSoDeleteFilesModal(BuildContext context, TGSpecialRequest request) async {
  final auth = context.read<FakeAuthState>();
  if (!auth.isAdmin) return;
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => AdminDialogScaffold(
      title: ctx.t('ui_so_admin_delete_files'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
        const SizedBox(width: 8),
        TGButton(onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_confirm'), height: 40),
      ],
      child: Text(ctx.t('ui_so_admin_delete_files_body')),
    ),
  );
  if (ok == true && context.mounted) {
    TGSpecialOrderService.instance.deleteFiles(request.id, actorId: auth.userId, actorRole: auth.role.name);
  }
}

Future<void> showSoMatchModal(BuildContext context, TGSpecialRequest request) async {
  final auth = context.read<FakeAuthState>();
  final svc = TGSpecialOrderService.instance;
  final selected = <String>{};
  var region = '';
  TGStoreSpecialty? type;
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
      var makers = svc.manufacturers(types: type == null ? {} : {type!});
      if (region.isNotEmpty) {
        makers = makers.where((m) => m.serviceRegions.contains(region) || m.serviceRegions.contains('nationwide')).toList();
      }
      return AdminDialogScaffold(
        width: 560,
        title: ctx.t('ui_so_admin_match'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(
            onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
            label: ctx.t('ui_so_admin_add_to_request'),
            height: 40,
          ),
        ],
        child: SizedBox(
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  DropdownButton<TGStoreSpecialty?>(
                    value: type,
                    hint: Text(ctx.t('ui_project_type')),
                    items: [
                      DropdownMenuItem(value: null, child: Text(ctx.t('ui_all'))),
                      for (final s in TGStoreSpecialty.values.where((e) => e != TGStoreSpecialty.other))
                        DropdownMenuItem(value: s, child: Text(ctx.t('ui_so_spec_${s.name}'))),
                    ],
                    onChanged: (v) => setLocal(() => type = v),
                  ),
                  DropdownButton<String?>(
                    value: region.isEmpty ? null : region,
                    hint: Text(ctx.t('ui_region')),
                    items: [
                      for (final r in const ['Śląskie', 'Małopolskie', 'Mazowieckie', 'Dolnośląskie'])
                        DropdownMenuItem(value: r, child: Text(r)),
                    ],
                    onChanged: (v) => setLocal(() => region = v ?? ''),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final m in makers)
                      CheckboxListTile(
                        dense: true,
                        value: selected.contains(m.sellerKey),
                        title: Text(m.name),
                        subtitle: Text('${m.plan?.name ?? 'store'} · ${m.city}'),
                        onChanged: (v) => setLocal(() {
                          v == true ? selected.add(m.sellerKey) : selected.remove(m.sellerKey);
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }),
  );
  if (ok == true && selected.isNotEmpty && context.mounted) {
    svc.matchManufacturers(request.id, selected.toList(), actorId: auth.userId, actorRole: auth.role.name);
  }
}

extension on TGSoEmailPreview {
  TGSoEmailPreview copyWith({String? body}) => TGSoEmailPreview(subject: subject, body: body ?? this.body, lang: lang);
}
