import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';

Future<void> showAdminDismiss(BuildContext context, String listingNo) async {
  final auth = context.read<FakeAuthState>();
  final mod = ModerationService.instance;
  var lang = 'pl';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      final preview = mod.previewEmail(templateId: 'reporter_no_violation', lang: lang, vars: {'listingNo': listingNo, 'to': 'reporter@example.com'});
      return AdminDialogScaffold(
        title: ctx.t('ui_dismiss_no_violation'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(key: const Key('admin-dismiss-confirm'), onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_dismiss'), height: 40),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LangToggle(value: lang, onChanged: (v) => setSt(() => lang = v)),
            const SizedBox(height: 8),
            EmailPreviewBlock(email: preview),
          ],
        ),
      );
    }),
  );
  if (ok == true && context.mounted) {
    mod.dismiss(listingNo: listingNo, actorId: auth.userId, actorRole: auth.role.name);
  }
}

Future<void> showAdminRequestInfo(BuildContext context, String listingNo) async {
  final auth = context.read<FakeAuthState>();
  var days = 3;
  var hide = false;
  var lang = 'pl';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setSt) {
        final preview = ModerationService.instance.previewEmail(
          templateId: 'request_info',
          lang: lang,
          vars: {'listingNo': listingNo, 'days': '$days', 'seller': 'seller', 'to': 'seller@example.com'},
        );
        return AdminDialogScaffold(
          title: ctx.t('ui_request_information'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
            const SizedBox(width: 8),
            TGButton(onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_send'), height: 40),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final d in [3, 5, 7])
                    ChoiceChip(label: Text(ctx.t('ui_n_days', {'n': '$d'})), selected: days == d, onSelected: (_) => setSt(() => days = d)),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ctx.t('ui_hide_while_waiting')),
                value: hide,
                onChanged: (v) => setSt(() => hide = v),
              ),
              _LangToggle(value: lang, onChanged: (v) => setSt(() => lang = v)),
              const SizedBox(height: 8),
              EmailPreviewBlock(email: preview),
            ],
          ),
        );
      });
    },
  );
  if (ok == true && context.mounted) {
    await ModerationService.instance.requestInfo(listingNo: listingNo, actorId: auth.userId, actorRole: auth.role.name, days: days, hideWhileWaiting: hide, lang: lang);
  }
}

Future<void> showAdminHide(BuildContext context, String listingNo) async {
  final auth = context.read<FakeAuthState>();
  var lang = 'pl';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      final preview = ModerationService.instance.previewEmail(templateId: 'hide_notice', lang: lang, vars: {'listingNo': listingNo, 'seller': 'seller', 'to': 'seller@example.com'});
      return AdminDialogScaffold(
        title: ctx.t('ui_hide_temporarily'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_hide'), height: 40),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LangToggle(value: lang, onChanged: (v) => setSt(() => lang = v)),
            const SizedBox(height: 8),
            EmailPreviewBlock(email: preview),
          ],
        ),
      );
    }),
  );
  if (ok == true && context.mounted) {
    await ModerationService.instance.hideTemporarily(listingNo: listingNo, actorId: auth.userId, actorRole: auth.role.name);
  }
}

Future<void> showAdminRemove(BuildContext context, String listingNo) async {
  final auth = context.read<FakeAuthState>();
  var reason = TGRemoveReason.fraud;
  var description = '';
  var notify = true;
  var others = false;
  var lang = 'pl';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setSt) {
        final preview = ModerationService.instance.previewEmail(
          templateId: 'remove_seller',
          lang: lang,
          vars: {'listingNo': listingNo, 'reason': reason.label, 'description': description, 'seller': 'seller', 'to': 'seller@example.com'},
        );
        return AdminDialogScaffold(
          title: ctx.t('ui_remove_listing_action'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
            const SizedBox(width: 8),
            TGButton(key: const Key('admin-remove-confirm'), onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_remove'), height: 40),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in TGRemoveReason.values)
                    ChoiceChip(label: Text(ctx.t('ui_reason_${r.name}')), selected: reason == r, onSelected: (_) => setSt(() => reason = r)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                maxLines: 3,
                onChanged: (v) => setSt(() => description = v),
                decoration: InputDecoration(hintText: ctx.t('ui_statement_of_reasons')),
              ),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(ctx.t('ui_notify_seller_reasons')), value: notify, onChanged: (v) => setSt(() => notify = v)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(ctx.t('ui_apply_other_listings')), value: others, onChanged: (v) => setSt(() => others = v)),
              _LangToggle(value: lang, onChanged: (v) => setSt(() => lang = v)),
              const SizedBox(height: 8),
              EmailPreviewBlock(email: preview),
            ],
          ),
        );
      });
    },
  );
  if (ok == true && context.mounted) {
    await ModerationService.instance.removeListing(
      listingNo: listingNo,
      actorId: auth.userId,
      actorRole: auth.role.name,
      reason: reason,
      description: description,
      notifySeller: notify,
      applyToOthers: others,
    );
    if (context.mounted) {
      showTGToast(
        context,
        context.t('ui_listing_removed_undo'),
        duration: ModerationService.instance.undoWindow,
        action: SnackBarAction(
          label: context.t('ui_undo'),
          textColor: TGColors.cta,
          onPressed: () => ModerationService.instance.undoRemove(listingNo, actorId: auth.userId, actorRole: auth.role.name),
        ),
      );
    }
  }
}

Future<void> showAdminRequestProof(BuildContext context, String listingNo) async {
  final auth = context.read<FakeAuthState>();
  var lang = 'pl';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setSt) {
        final preview = ModerationService.instance.previewEmail(templateId: 'request_proof', lang: lang, vars: {'listingNo': listingNo, 'seller': 'seller', 'to': 'seller@example.com'});
        return AdminDialogScaffold(
          title: ctx.t('ui_request_proof'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
            const SizedBox(width: 8),
            TGButton(onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_send'), height: 40),
          ],
          child: Column(
            children: [
              _LangToggle(value: lang, onChanged: (v) => setSt(() => lang = v)),
              const SizedBox(height: 8),
              Text(ctx.t('ui_proof_note')),
              const SizedBox(height: 8),
              EmailPreviewBlock(email: preview),
            ],
          ),
        );
      });
    },
  );
  if (ok == true && context.mounted) {
    await ModerationService.instance.requestProof(listingNo: listingNo, actorId: auth.userId, actorRole: auth.role.name, lang: lang);
  }
}

Future<void> showAdminContact(BuildContext context, String listingNo, {required bool seller}) async {
  final auth = context.read<FakeAuthState>();
  var lang = 'pl';
  final tplId = seller ? 'contact_seller' : 'contact_reporter';
  var subject = '';
  var body = '';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setSt) {
        final preview = ModerationService.instance.previewEmail(
          templateId: tplId,
          lang: lang,
          vars: {'listingNo': listingNo, 'seller': 'seller', 'body': body.isEmpty ? '…' : body, 'to': seller ? 'seller@example.com' : 'reporter@example.com'},
        );
        subject = preview.subject;
        return AdminDialogScaffold(
          title: seller ? ctx.t('ui_contact_seller') : ctx.t('ui_contact_reporter'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
            const SizedBox(width: 8),
            TGButton(onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_send'), height: 40),
          ],
          child: Column(
            children: [
              _LangToggle(value: lang, onChanged: (v) => setSt(() => lang = v)),
              const SizedBox(height: 8),
              TextFormField(initialValue: preview.subject, onChanged: (v) => subject = v, decoration: InputDecoration(labelText: ctx.t('ui_subject'))),
              const SizedBox(height: 8),
              TextField(maxLines: 5, onChanged: (v) => setSt(() => body = v), decoration: InputDecoration(hintText: ctx.t('ui_messages'))),
              const SizedBox(height: 8),
              EmailPreviewBlock(email: preview.copyWith()),
            ],
          ),
        );
      });
    },
  );
  if (ok == true && context.mounted) {
    ModerationService.instance.contactParty(
      listingNo: listingNo,
      seller: seller,
      actorId: auth.userId,
      actorRole: auth.role.name,
      lang: lang,
      subject: subject,
      body: body,
    );
  }
}

Future<void> showAdminWarnSuspend(BuildContext context, {required String sellerId, required String listingNo, required bool suspend}) async {
  final auth = context.read<FakeAuthState>();
  if (!auth.isAdmin) return;
  var lang = 'pl';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      final preview = ModerationService.instance.previewEmail(
        templateId: suspend ? 'suspend_notice' : 'warn_notice',
        lang: lang,
        vars: {'listingNo': listingNo, 'seller': sellerId, 'to': 'seller@example.com'},
      );
      return AdminDialogScaffold(
        title: suspend ? ctx.t('ui_suspend_account') : ctx.t('ui_warn_account'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(key: const Key('admin-suspend-confirm'), onPressed: () => Navigator.pop(ctx, true), label: suspend ? ctx.t('ui_suspend') : ctx.t('ui_warn'), height: 40),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LangToggle(value: lang, onChanged: (v) => setSt(() => lang = v)),
            const SizedBox(height: 8),
            EmailPreviewBlock(email: preview),
          ],
        ),
      );
    }),
  );
  if (ok == true && context.mounted) {
    await ModerationService.instance.warnOrSuspend(sellerId: sellerId, actorId: auth.userId, actorRole: auth.role.name, suspend: suspend, listingNo: listingNo);
  }
}

Future<void> showAdminRestore(BuildContext context, String listingNo) async {
  final auth = context.read<FakeAuthState>();
  if (!auth.isAdmin) return;
  var lang = 'pl';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      final preview = ModerationService.instance.previewEmail(templateId: 'restore_notice', lang: lang, vars: {'listingNo': listingNo, 'seller': 'seller', 'to': 'seller@example.com'});
      return AdminDialogScaffold(
        title: ctx.t('ui_restore_listing'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(key: const Key('admin-restore-confirm'), onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_restore'), height: 40),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LangToggle(value: lang, onChanged: (v) => setSt(() => lang = v)),
            const SizedBox(height: 8),
            EmailPreviewBlock(email: preview),
          ],
        ),
      );
    }),
  );
  if (ok == true && context.mounted) {
    await ModerationService.instance.restore(listingNo: listingNo, actorId: auth.userId, actorRole: auth.role.name, auth: auth);
  }
}

Future<void> showPhotoCompare(BuildContext context, TGPhotoMatch match, TGProduct? a, TGProduct? b) async {
  await showAdminDialog<void>(
    context: context,
    builder: (ctx) => _CompareDialog(match: match, a: a, b: b),
  );
}

class _CompareDialog extends StatefulWidget {
  const _CompareDialog({required this.match, required this.a, required this.b});
  final TGPhotoMatch match;
  final TGProduct? a;
  final TGProduct? b;

  @override
  State<_CompareDialog> createState() => _CompareDialogState();
}

class _CompareDialogState extends State<_CompareDialog> {
  double _t = 0.5;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    return AdminDialogScaffold(
      title: context.t('ui_compare_photos', {'n': '${match.similarityPercent}'}),
      width: 720,
      actions: [TGButton(onPressed: () => Navigator.pop(context), label: context.t('ui_close'), height: 40)],
      child: Column(
        children: [
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            return SizedBox(
              height: 320,
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => setState(() => _t = (_t + d.delta.dx / w).clamp(0.0, 1.0)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _img(match.imageB),
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: _t,
                        child: _img(match.imageA),
                      ),
                    ),
                    Positioned(left: w * _t - 1, top: 0, bottom: 0, child: Container(width: 2, color: TGColors.cta)),
                  ],
                ),
              ),
            );
          }),
          Slider(value: _t, onChanged: (v) => setState(() => _t = v)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('A ${match.listingNoA}\n${widget.a?.seller.name ?? ''} · ${widget.a?.publishedAt?.toIso8601String().split('T').first ?? ''}', style: const TextStyle(fontSize: 12))),
              Expanded(child: Text('B ${match.listingNoB}\n${widget.b?.seller.name ?? ''} · ${widget.b?.publishedAt?.toIso8601String().split('T').first ?? ''}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _img(String src) => Image.asset(src, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: TGColors.surfaceHover));
}

class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(label: const Text('EN'), selected: value == 'en', onSelected: (_) => onChanged('en')),
        ChoiceChip(label: const Text('PL'), selected: value == 'pl', onSelected: (_) => onChanged('pl')),
      ],
    );
  }
}

class AdminActionBar extends StatelessWidget {
  const AdminActionBar({super.key, required this.listingNo, required this.sellerId, this.dense = false});
  final String listingNo;
  final String sellerId;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final buttons = <Widget>[
      TGButton(key: const Key('admin-action-dismiss'), onPressed: () => showAdminDismiss(context, listingNo), label: context.t('ui_dismiss'), height: 40, variant: TGButtonVariant.outline),
      TGButton(onPressed: () => showAdminRequestInfo(context, listingNo), label: context.t('ui_request_info'), height: 40, variant: TGButtonVariant.outline),
      TGButton(key: const Key('admin-action-hide'), onPressed: () => showAdminHide(context, listingNo), label: context.t('ui_hide'), height: 40, variant: TGButtonVariant.outline),
      TGButton(key: const Key('admin-action-remove'), onPressed: () => showAdminRemove(context, listingNo), label: context.t('ui_remove'), height: 40),
      TGButton(onPressed: () => showAdminRequestProof(context, listingNo), label: context.t('ui_request_proof'), height: 40, variant: TGButtonVariant.ghost),
      TGButton(onPressed: () => showAdminContact(context, listingNo, seller: true), label: context.t('ui_contact_seller'), height: 40, variant: TGButtonVariant.ghost),
      TGButton(onPressed: () => showAdminContact(context, listingNo, seller: false), label: context.t('ui_contact_reporter'), height: 40, variant: TGButtonVariant.ghost),
      if (auth.isAdmin) ...[
        TGButton(onPressed: () => showAdminWarnSuspend(context, sellerId: sellerId, listingNo: listingNo, suspend: false), label: context.t('ui_warn'), height: 40, variant: TGButtonVariant.outline),
        TGButton(key: const Key('admin-action-suspend'), onPressed: () => showAdminWarnSuspend(context, sellerId: sellerId, listingNo: listingNo, suspend: true), label: context.t('ui_suspend'), height: 40, variant: TGButtonVariant.outline),
        TGButton(key: const Key('admin-action-restore'), onPressed: () => showAdminRestore(context, listingNo), label: context.t('ui_restore'), height: 40, variant: TGButtonVariant.outline),
      ],
    ];
    if (dense) {
      return Material(
        color: TGColors.adminBar,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), children: [
              for (final b in buttons) ...[b, const SizedBox(width: 8)],
            ]),
          ),
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}
