import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';

Future<void> showSellerRespondSheet(BuildContext context, TGSellerModerationCase kase) {
  return _sheet(context, _RespondBody(kase: kase));
}

Future<void> showSellerRemovalSheet(BuildContext context, TGSellerModerationCase kase) {
  return _sheet(context, _RemovalBody(kase: kase));
}

Future<void> showSellerAppealSheet(BuildContext context, TGSellerModerationCase kase) {
  return _sheet(context, _AppealBody(kase: kase));
}

Future<void> _sheet(BuildContext context, Widget child) {
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: TGColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TGRadius.modal)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Padding(padding: const EdgeInsets.all(20), child: child)),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TGColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(TGRadius.modal))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
      child: child,
    ),
  );
}

class _RespondBody extends StatefulWidget {
  const _RespondBody({required this.kase});
  final TGSellerModerationCase kase;

  @override
  State<_RespondBody> createState() => _RespondBodyState();
}

class _RespondBodyState extends State<_RespondBody> {
  final _text = TextEditingController();
  final _evidence = <String>[];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.read<FakeAuthState>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_respond'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(context.t('ui_content_review_notice'), style: theme.bodyMedium.override(color: theme.secondaryText)),
        const SizedBox(height: 12),
        TextField(key: const Key('seller-respond-text'), controller: _text, maxLines: 5, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: context.t('ui_your_response'))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final e in _evidence) Chip(label: Text(e.split('/').last), onDeleted: () => setState(() => _evidence.remove(e))),
            if (_evidence.length < 3)
              ActionChip(label: Text(context.t('ui_add_evidence')), onPressed: () => setState(() => _evidence.add('assets/images/image.png'))),
          ],
        ),
        const SizedBox(height: 14),
        TGButton(
          key: const Key('seller-respond-send'),
          onPressed: _text.text.trim().isEmpty
              ? null
              : () {
                  ModerationService.instance.respondAsSeller(listingNo: widget.kase.listing.listingNo ?? widget.kase.listing.id, message: _text.text.trim(), evidence: _evidence, actorId: auth.userId);
                  Navigator.pop(context);
                  showTGToast(context, context.t('ui_response_sent'));
                },
          label: context.t('ui_send_response'),
          height: 44,
        ),
      ],
    );
  }
}

class _RemovalBody extends StatelessWidget {
  const _RemovalBody({required this.kase});
  final TGSellerModerationCase kase;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_statement_of_reasons'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text(kase.removalRule ?? kase.shortReason ?? context.t('ui_removed_badge'), style: const TextStyle(fontWeight: FontWeight.w800, color: TGColors.error)),
        const SizedBox(height: 8),
        Text(kase.removalExplanation ?? context.t('ui_content_review_notice')),
        if (kase.decidedByHuman && kase.decidedAt != null) ...[
          const SizedBox(height: 10),
          Text(
            context.t('ui_human_decision', {
              'd': DateFormat('d MMMM y', Localizations.localeOf(context).languageCode).format(kase.decidedAt!),
            }),
            style: theme.bodySmall.override(color: theme.secondaryText),
          ),
        ],
        if (kase.finalRemoval) ...[
          const SizedBox(height: 8),
          Text(context.t('ui_removed_final'), style: const TextStyle(fontWeight: FontWeight.w800, color: TGColors.error)),
        ],
        const SizedBox(height: 16),
        if (!kase.appealed && !kase.finalRemoval)
          TGButton(
            key: const Key('seller-appeal-from-details'),
            onPressed: () {
              Navigator.pop(context);
              showSellerAppealSheet(context, kase);
            },
            label: context.t('ui_appeal'),
            height: 44,
          )
        else if (kase.appealed)
          Text(context.t('ui_appeal_used'), style: theme.bodySmall.override(color: theme.secondaryText)),
      ],
    );
  }
}

class _AppealBody extends StatefulWidget {
  const _AppealBody({required this.kase});
  final TGSellerModerationCase kase;

  @override
  State<_AppealBody> createState() => _AppealBodyState();
}

class _AppealBodyState extends State<_AppealBody> {
  final _text = TextEditingController();
  final _evidence = <String>[];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<FakeAuthState>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_appeal'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 8),
        TextField(key: const Key('seller-appeal-text'), controller: _text, maxLines: 5, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: context.t('ui_appeal_hint'))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final e in _evidence) Chip(label: Text(e.split('/').last), onDeleted: () => setState(() => _evidence.remove(e))),
            if (_evidence.length < 3)
              ActionChip(key: const Key('seller-appeal-evidence'), label: Text(context.t('ui_add_evidence')), onPressed: () => setState(() => _evidence.add('assets/images/image.png'))),
          ],
        ),
        const SizedBox(height: 12),
        TGButton(
          key: const Key('seller-appeal-send'),
          onPressed: _text.text.trim().length < 20
              ? null
              : () {
                  ModerationService.instance.appealAsSeller(
                    listingNo: widget.kase.listing.listingNo ?? widget.kase.listing.id,
                    statement: _text.text.trim(),
                    actorId: auth.userId,
                    evidence: _evidence,
                  );
                  Navigator.pop(context);
                  showTGToast(context, context.t('ui_appeal_sent'));
                },
          label: context.t('ui_submit_appeal'),
          height: 44,
        ),
      ],
    );
  }
}
