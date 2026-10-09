import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_deal_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_services/deal_moderation_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';

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

Future<void> showDealDecide(BuildContext context, TGAdminDealCase c, {TGObjectionDecision? locked}) async {
  final auth = context.read<FakeAuthState>();
  var decision = locked ?? TGObjectionDecision.confirmed;
  var markSold = true;
  var rationale = '';
  var lang = 'en';
  final svc = DealModerationService.instance;
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      final buyerMail = svc.preview(
        templateId: 'deal_decision_buyer',
        lang: lang,
        to: '${c.buyer.name} <buyer@mail.com>',
        subject: 'Update on your review',
        body: switch (decision) {
          TGObjectionDecision.confirmed => 'Your review is live and counts toward the rating.',
          TGObjectionDecision.removed => 'This review was removed. A human moderator decided it did not meet our rules. You may appeal once.',
          TGObjectionDecision.notVerified => "We couldn't verify this deal. Your review stays visible but is not included in the rating.",
        },
      );
      final sellerMail = svc.preview(
        templateId: 'deal_decision_seller',
        lang: lang,
        to: '${c.seller.name} <seller@mail.com>',
        subject: 'Update on a review',
        body: 'A moderator reviewed the case for ${c.listingTitle}.',
      );
      Widget card(TGObjectionDecision v, String title, List<String> rows, {Widget? extra}) {
        final on = decision == v;
        return InkWell(
          onTap: locked != null ? null : () => setSt(() => decision = v),
          child: Semantics(
            inMutuallyExclusiveGroup: true,
            checked: on,
            button: true,
            label: title,
            child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? TGColors.cta : TGColors.border, width: on ? 1.6 : 1),
              color: on ? TGColors.cta.withValues(alpha: 0.08) : TGColors.surface,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: on ? TGColors.cta : TGColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(ctx.t('ui_what_happens'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: TGColors.textSecondary)),
                      for (final r in rows) Padding(padding: const EdgeInsets.only(top: 2), child: Text('· $r', style: const TextStyle(fontSize: 12, height: 1.35))),
                      if (extra != null) extra,
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        );
      }

      return AdminDialogScaffold(
        title: ctx.t('ui_decide'),
        width: 560,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(
            key: const Key('admin-deal-decide-confirm'),
            onPressed: rationale.trim().isEmpty ? null : () => Navigator.pop(ctx, true),
            label: ctx.t('ui_decide'),
            height: 40,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            card(TGObjectionDecision.confirmed, ctx.t('ui_decision_confirmed'), [
              ctx.t('ui_happen_confirmed_review'),
              ctx.t('ui_happen_confirmed_sold'),
              ctx.t('ui_happen_confirmed_unjust'),
            ], extra: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Checkbox(value: markSold, onChanged: (v) => setSt(() => markSold = v ?? true)),
                  Expanded(child: Text(ctx.t('ui_mark_listing_sold'), style: const TextStyle(fontSize: 12))),
                ],
              ),
            )),
            card(TGObjectionDecision.removed, ctx.t('ui_decision_invalid'), [
              ctx.t('ui_happen_removed_review'),
              ctx.t('ui_happen_listing_unchanged'),
              ctx.t('ui_happen_counter_unchanged'),
            ]),
            card(TGObjectionDecision.notVerified, ctx.t('ui_decision_unknown'), [
              ctx.t('ui_happen_not_verified'),
              ctx.t('ui_happen_listing_unchanged'),
              ctx.t('ui_happen_counter_unchanged'),
            ]),
            const SizedBox(height: 8),
            TextField(
              key: const Key('admin-deal-rationale'),
              maxLines: 3,
              onChanged: (v) => setSt(() => rationale = v),
              decoration: InputDecoration(hintText: ctx.t('ui_internal_rationale')),
            ),
            const SizedBox(height: 8),
            _LangToggle(value: lang, onChanged: (v) => setSt(() => lang = v)),
            const SizedBox(height: 8),
            EmailPreviewBlock(email: buyerMail),
            const SizedBox(height: 8),
            EmailPreviewBlock(email: sellerMail),
          ],
        ),
      );
    }),
  );
  if (ok == true && context.mounted) {
    svc.decide(c, decision: decision, rationale: rationale, markSold: markSold, actorId: auth.userId, actorRole: auth.role.name);
    if (decision == TGObjectionDecision.confirmed || decision == TGObjectionDecision.removed) {
      showTGToast(
        context,
        context.t('ui_deal_undo'),
        duration: ModerationService.instance.undoWindow,
        action: SnackBarAction(
          label: context.t('ui_undo'),
          textColor: TGColors.cta,
          onPressed: () => svc.undo(actorId: auth.userId, actorRole: auth.role.name),
        ),
      );
    }
  }
}

Future<void> showDealMoreEvidence(BuildContext context, TGAdminDealCase c) async {
  final auth = context.read<FakeAuthState>();
  var lang = 'en';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      final preview = DealModerationService.instance.preview(
        templateId: 'deal_more_evidence',
        lang: lang,
        to: '${c.buyer.name} <buyer@mail.com>',
        subject: 'More evidence needed',
        body: lang == 'pl'
            ? 'Potrzebujemy od Ciebie więcej dowodów do ${c.dealNo}.'
            : 'Please send additional evidence for ${c.dealNo}.',
      );
      return AdminDialogScaffold(
        title: ctx.t('ui_request_more_evidence'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(key: const Key('admin-deal-more-evidence'), onPressed: c.evidenceExtended ? null : () => Navigator.pop(ctx, true), label: ctx.t('ui_send'), height: 40),
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
    DealModerationService.instance.requestMoreEvidence(c, actorId: auth.userId, actorRole: auth.role.name, lang: lang);
  }
}

Future<void> showDealCrossCheck(BuildContext context, TGAdminDealCase c) async {
  final auth = context.read<FakeAuthState>();
  var amount = '';
  var date = '';
  var lang = 'en';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      final preview = DealModerationService.instance.preview(
        templateId: 'deal_crosscheck',
        lang: lang,
        to: '${c.seller.name} <seller@mail.com>',
        subject: 'Quick check on a listing',
        body: lang == 'pl'
            ? 'Czy otrzymałeś wpłatę około $amount około $date za ogłoszenie nr ${c.listingNo}? Tak / Nie / Nie wiem.'
            : 'Did you receive a payment of about $amount around $date for Listing No. ${c.listingNo}? Yes / No / Not sure.',
      );
      return AdminDialogScaffold(
        title: ctx.t('ui_request_crosscheck'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(
            key: const Key('admin-deal-crosscheck'),
            onPressed: amount.trim().isEmpty || date.trim().isEmpty ? null : () => Navigator.pop(ctx, true),
            label: ctx.t('ui_send'),
            height: 40,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(onChanged: (v) => setSt(() => amount = v), decoration: InputDecoration(hintText: ctx.t('ui_crosscheck_amount'))),
            const SizedBox(height: 8),
            TextField(onChanged: (v) => setSt(() => date = v), decoration: InputDecoration(hintText: ctx.t('ui_crosscheck_date'))),
            const SizedBox(height: 8),
            _LangToggle(value: lang, onChanged: (v) => setSt(() => lang = v)),
            const SizedBox(height: 8),
            EmailPreviewBlock(email: preview),
          ],
        ),
      );
    }),
  );
  if (ok == true && context.mounted) {
    DealModerationService.instance.requestCrossCheck(c, actorId: auth.userId, actorRole: auth.role.name, amount: amount, date: date, lang: lang);
  }
}

Future<void> showDealContact(BuildContext context, TGAdminDealCase c, {required bool seller}) async {
  final auth = context.read<FakeAuthState>();
  var lang = 'en';
  var body = '';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      final preview = DealModerationService.instance.preview(
        templateId: seller ? 'deal_contact_seller' : 'deal_contact_buyer',
        lang: lang,
        to: '${seller ? c.seller.name : c.buyer.name} <party@mail.com>',
        subject: 'Message about ${c.dealNo}',
        body: body.isEmpty
            ? (lang == 'pl' ? 'Dzień dobry, piszemy w sprawie ${c.dealNo}.' : 'Hello, we are writing about ${c.dealNo}.')
            : body,
      );
      return AdminDialogScaffold(
        title: seller ? ctx.t('ui_contact_seller') : ctx.t('ui_contact_buyer'),
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
                ActionChip(label: Text(lang == 'pl' ? 'Szablon PL' : 'EN template'), onPressed: () => setSt(() => body = lang == 'pl' ? 'Dzień dobry, piszemy w sprawie ${c.dealNo}.' : 'Hello, we are writing about ${c.dealNo}.')),
              ],
            ),
            TextField(maxLines: 4, onChanged: (v) => setSt(() => body = v), decoration: InputDecoration(hintText: ctx.t('ui_message'))),
            _LangToggle(value: lang, onChanged: (v) => setSt(() => lang = v)),
            const SizedBox(height: 8),
            EmailPreviewBlock(email: preview),
          ],
        ),
      );
    }),
  );
  if (ok == true && context.mounted) {
    DealModerationService.instance.contactParty(c, seller: seller, actorId: auth.userId, actorRole: auth.role.name, body: body, lang: lang);
  }
}

Future<void> showDealPrivate(BuildContext context, TGAdminDealCase c) async {
  final auth = context.read<FakeAuthState>();
  var reason = '';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      return AdminDialogScaffold(
        title: ctx.t('ui_open_private'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(key: const Key('admin-deal-private'), onPressed: reason.trim().isEmpty ? null : () => Navigator.pop(ctx, true), label: ctx.t('ui_open_private'), height: 40),
        ],
        child: TextField(
          key: const Key('admin-deal-private-reason'),
          maxLines: 3,
          onChanged: (v) => setSt(() => reason = v),
          decoration: InputDecoration(hintText: ctx.t('ui_private_reason')),
        ),
      );
    }),
  );
  if (ok == true && context.mounted) {
    DealModerationService.instance.openPrivateConversation(c, reason: reason, actorId: auth.userId, actorRole: auth.role.name);
  }
}

Future<void> showDealFlagged(BuildContext context, TGAdminDealCase c, {required bool approve}) async {
  final auth = context.read<FakeAuthState>();
  var rationale = '';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      return AdminDialogScaffold(
        title: approve ? ctx.t('ui_approve') : ctx.t('ui_remove'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(onPressed: rationale.trim().isEmpty ? null : () => Navigator.pop(ctx, true), label: approve ? ctx.t('ui_approve') : ctx.t('ui_remove'), height: 40),
        ],
        child: TextField(maxLines: 3, onChanged: (v) => setSt(() => rationale = v), decoration: InputDecoration(hintText: ctx.t('ui_internal_rationale'))),
      );
    }),
  );
  if (ok == true && context.mounted) {
    if (approve) {
      DealModerationService.instance.flaggedApprove(c, actorId: auth.userId, actorRole: auth.role.name, rationale: rationale);
    } else {
      DealModerationService.instance.flaggedRemove(c, actorId: auth.userId, actorRole: auth.role.name, rationale: rationale);
    }
  }
}

Future<void> showDealAppealUphold(BuildContext context, TGAdminDealCase c) async {
  final auth = context.read<FakeAuthState>();
  if (c.removedBy == auth.userId) return;
  var rationale = '';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      return AdminDialogScaffold(
        title: ctx.t('ui_uphold_removal'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(onPressed: rationale.trim().isEmpty ? null : () => Navigator.pop(ctx, true), label: ctx.t('ui_uphold_removal'), height: 40),
        ],
        child: TextField(maxLines: 3, onChanged: (v) => setSt(() => rationale = v), decoration: InputDecoration(hintText: ctx.t('ui_internal_rationale'))),
      );
    }),
  );
  if (ok == true && context.mounted) {
    DealModerationService.instance.appealUphold(c, actorId: auth.userId, actorRole: auth.role.name, rationale: rationale);
  }
}

Future<void> showDealAnnul(BuildContext context, TGAdminDealCase c) async {
  final auth = context.read<FakeAuthState>();
  var rationale = '';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      return AdminDialogScaffold(
        title: ctx.t('ui_annul'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(onPressed: rationale.trim().isEmpty ? null : () => Navigator.pop(ctx, true), label: ctx.t('ui_annul'), height: 40),
        ],
        child: TextField(maxLines: 3, onChanged: (v) => setSt(() => rationale = v), decoration: InputDecoration(hintText: ctx.t('ui_internal_rationale'))),
      );
    }),
  );
  if (ok == true && context.mounted) {
    DealModerationService.instance.annul(c, actorId: auth.userId, actorRole: auth.role.name, rationale: rationale);
  }
}

Future<void> showDealWarnSuspend(BuildContext context, TGAdminDealCase c, {required bool suspend}) async {
  final auth = context.read<FakeAuthState>();
  var rationale = '';
  final ok = await showAdminDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      return AdminDialogScaffold(
        title: suspend ? ctx.t('ui_suspend') : ctx.t('ui_warn'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          const SizedBox(width: 8),
          TGButton(onPressed: rationale.trim().isEmpty ? null : () => Navigator.pop(ctx, true), label: suspend ? ctx.t('ui_suspend') : ctx.t('ui_warn'), height: 40),
        ],
        child: TextField(maxLines: 3, onChanged: (v) => setSt(() => rationale = v), decoration: InputDecoration(hintText: ctx.t('ui_internal_rationale'))),
      );
    }),
  );
  if (ok == true && context.mounted) {
    DealModerationService.instance.warnOrSuspend(c, suspend: suspend, actorId: auth.userId, actorRole: auth.role.name, rationale: rationale);
  }
}

class AdminDealActionBar extends StatelessWidget {
  const AdminDealActionBar({super.key, required this.kase, this.dense = false});
  final TGAdminDealCase kase;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final sameAppeal = kase.queue == TGDealQueueKind.appeal && kase.removedBy == auth.userId;
    final buttons = <Widget>[
      if (kase.queue == TGDealQueueKind.flagged) ...[
        TGButton(onPressed: () => showDealFlagged(context, kase, approve: true), label: context.t('ui_approve'), height: 40, variant: TGButtonVariant.outline),
        TGButton(onPressed: () => showDealFlagged(context, kase, approve: false), label: context.t('ui_remove'), height: 40),
      ] else if (kase.queue == TGDealQueueKind.appeal) ...[
        TGButton(onPressed: sameAppeal ? null : () => showDealAppealUphold(context, kase), label: context.t('ui_uphold_removal'), height: 40, variant: TGButtonVariant.outline),
        TGButton(onPressed: sameAppeal ? null : () => showDealDecide(context, kase), label: context.t('ui_overturn'), height: 40),
      ] else ...[
        if (kase.noEvidence)
          TGButton(key: const Key('admin-deal-no-evidence'), onPressed: () => DealModerationService.instance.removeNoEvidence(kase, actorId: auth.userId, actorRole: auth.role.name), label: context.t('ui_remove_no_evidence'), height: 40, variant: TGButtonVariant.outline),
        TGButton(key: const Key('admin-deal-decide'), onPressed: () => showDealDecide(context, kase), label: context.t('ui_decide'), height: 40),
        TGButton(onPressed: kase.evidenceExtended ? null : () => showDealMoreEvidence(context, kase), label: context.t('ui_request_more_evidence'), height: 40, variant: TGButtonVariant.outline),
        TGButton(onPressed: () => showDealCrossCheck(context, kase), label: context.t('ui_request_crosscheck'), height: 40, variant: TGButtonVariant.outline),
      ],
      TGButton(onPressed: () => showDealContact(context, kase, seller: false), label: context.t('ui_contact_buyer'), height: 40, variant: TGButtonVariant.ghost),
      TGButton(onPressed: () => showDealContact(context, kase, seller: true), label: context.t('ui_contact_seller'), height: 40, variant: TGButtonVariant.ghost),
      TGButton(onPressed: () => DealModerationService.instance.markFlagsReviewed(kase, actorId: auth.userId, actorRole: auth.role.name), label: context.t('ui_mark_flags_reviewed'), height: 40, variant: TGButtonVariant.ghost),
      if (auth.isAdmin) ...[
        TGButton(onPressed: () => showDealAnnul(context, kase), label: context.t('ui_annul'), height: 40, variant: TGButtonVariant.outline),
        TGButton(onPressed: () => showDealWarnSuspend(context, kase, suspend: false), label: context.t('ui_warn'), height: 40, variant: TGButtonVariant.outline),
        TGButton(onPressed: () => showDealWarnSuspend(context, kase, suspend: true), label: context.t('ui_suspend'), height: 40, variant: TGButtonVariant.outline),
      ],
    ];
    if (dense) {
      return Material(
        color: TGColors.adminBar,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [for (final b in buttons) ...[b, const SizedBox(width: 8)]],
            ),
          ),
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}
