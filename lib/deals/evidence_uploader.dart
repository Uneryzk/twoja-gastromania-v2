import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';

Future<void> showEvidenceUploader(BuildContext context, TGPurchaseReview review) {
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('ui_close'),
      barrierColor: Colors.black54,
      pageBuilder: (ctx, _, __) => EvidenceUploaderPage(review: review, desktop: true),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SizedBox(height: MediaQuery.sizeOf(ctx).height, child: EvidenceUploaderPage(review: review, desktop: false)),
  );
}

class EvidenceUploaderPage extends StatefulWidget {
  const EvidenceUploaderPage({super.key, required this.review, required this.desktop});
  final TGPurchaseReview review;
  final bool desktop;

  @override
  State<EvidenceUploaderPage> createState() => _EvidenceUploaderPageState();
}

class _EvidenceUploaderPageState extends State<EvidenceUploaderPage> {
  final _note = TextEditingController();
  bool _honest = false;
  bool _done = false;
  String? _error;
  late final String _code;
  bool _recorded = false;
  int _photos = 0;
  bool _trace = false;
  bool _doc = false;

  @override
  void initState() {
    super.initState();
    _code = '${1000 + Random().nextInt(9000)}';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Widget? _result(FlutterFlowTheme theme) {
    switch (widget.review.state) {
      case TGPurchaseReviewState.confirmedModerator:
        return Text(context.t('ui_review_live_counts'), style: theme.titleSmall.override(fontWeight: FontWeight.w900));
      case TGPurchaseReviewState.notVerified:
        return Text(context.t('ui_review_not_verified_result'), style: theme.titleSmall.override(fontWeight: FontWeight.w900));
      case TGPurchaseReviewState.removed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('ui_review_removed_reason'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(context.t('ui_review_removed_human'), style: theme.bodySmall),
            if (!widget.review.appealed)
              TextButton(
                onPressed: () {
                  DealService.instance.appealRemoved(widget.review, note: 'appeal');
                  setState(() {});
                },
                child: Text(context.t('ui_appeal')),
              ),
          ],
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final obj = DealService.instance.objectionForReview(widget.review.id);
    final due = obj?.evidenceDueAt ?? TGClock.now().add(const Duration(hours: 36));
    final left = due.difference(TGClock.now());
    final amber = left <= const Duration(hours: 6);
    const store = false;
    final body = CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: FocusScope(
        autofocus: true,
        child: Material(
          color: theme.secondaryBackground,
          child: Column(
            children: [
              Material(
                color: amber ? TGColors.slaAmber.withValues(alpha: 0.16) : theme.alternate,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            context.t('ui_evidence_countdown', {'d': DateFormat('d MMM, HH:mm').format(due), 'n': '${left.inHours.clamp(0, 99)}'}),
                            style: theme.bodyMedium.override(fontWeight: FontWeight.w800, color: amber ? TGColors.slaAmber : theme.primaryText),
                          ),
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: _done
                      ? Text(context.t('ui_evidence_sent'), style: theme.titleSmall.override(fontWeight: FontWeight.w900))
                      : _result(theme) ?? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(context.t('ui_evidence_intro'), style: theme.bodySmall.override(color: theme.secondaryText)),
                            if (obj?.evidenceExtendedOnce == true) ...[
                              const SizedBox(height: 8),
                              Text(context.t('ui_moderator_more_evidence', {'d': DateFormat('d MMM').format(due)}), style: theme.bodySmall.override(fontWeight: FontWeight.w800, color: TGColors.slaAmber)),
                            ],
                            const SizedBox(height: 12),
                            _Card(
                              title: context.t('ui_live_video'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_code, style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                                  Text(context.t('ui_live_video_chips'), style: theme.bodySmall),
                                  const SizedBox(height: 8),
                                  TGButton(
                                    onPressed: () {
                                      setState(() => _recorded = true);
                                      DealService.instance.addEvidence(dealId: widget.review.dealId, role: TGEvidenceRole.buyer, type: TGEvidenceType.liveVideo, fileUrl: 'mock://live/$_code', captureCode: _code, durationSec: 12);
                                    },
                                    label: _recorded ? context.t('ui_recorded') : context.t('ui_record_video'),
                                    height: 44,
                                    borderRadius: BorderRadius.circular(TGRadius.pill),
                                  ),
                                  if (widget.desktop) Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.t('ui_continue_on_phone'), style: theme.bodySmall)),
                                  Text(context.t('ui_no_faces'), style: theme.bodySmall.override(color: theme.secondaryText)),
                                ],
                              ),
                            ),
                            _Card(
                              title: context.t('ui_payment_trace'),
                              recommended: !store,
                              child: TGButton(
                                onPressed: () {
                                  setState(() => _trace = true);
                                  DealService.instance.addEvidence(dealId: widget.review.dealId, role: TGEvidenceRole.buyer, type: TGEvidenceType.paymentTrace, fileUrl: 'mock://trace');
                                },
                                label: _trace ? context.t('ui_file_added') : context.t('ui_upload_file'),
                                variant: TGButtonVariant.outline,
                                height: 44,
                                borderRadius: BorderRadius.circular(TGRadius.pill),
                              ),
                            ),
                            _Card(
                              title: context.t('ui_documents'),
                              recommended: store,
                              child: TGButton(
                                onPressed: () {
                                  setState(() => _doc = true);
                                  DealService.instance.addEvidence(dealId: widget.review.dealId, role: TGEvidenceRole.buyer, type: TGEvidenceType.document, fileUrl: 'mock://doc');
                                },
                                label: _doc ? context.t('ui_file_added') : context.t('ui_upload_file'),
                                variant: TGButtonVariant.outline,
                                height: 44,
                                borderRadius: BorderRadius.circular(TGRadius.pill),
                              ),
                            ),
                            _Card(
                              title: context.t('ui_photos_supporting'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.t('ui_photos_alone'), style: theme.bodySmall.override(color: theme.secondaryText)),
                                  TGButton(
                                    onPressed: _photos >= 3
                                        ? null
                                        : () {
                                            setState(() => _photos++);
                                            DealService.instance.addEvidence(dealId: widget.review.dealId, role: TGEvidenceRole.buyer, type: TGEvidenceType.photo, fileUrl: 'mock://photo/$_photos');
                                          },
                                    label: context.t('ui_add_photo_n', {'n': '$_photos/3'}),
                                    variant: TGButtonVariant.ghost,
                                    height: 44,
                                    borderRadius: BorderRadius.circular(TGRadius.pill),
                                  ),
                                ],
                              ),
                            ),
                            TextField(controller: _note, maxLines: 4, maxLength: 1000, decoration: InputDecoration(hintText: context.t('ui_evidence_note'))),
                            CheckboxListTile(
                              value: _honest,
                              onChanged: (v) => setState(() => _honest = v ?? false),
                              title: Text(context.t('ui_evidence_confirm'), style: theme.bodySmall),
                            ),
                            if (_error != null) Text(_error!, style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),
              if (!_done && _result(theme) == null)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
                  child: TGButton(
                    key: const Key('evidence-submit'),
                    onPressed: _honest
                        ? () {
                            final ok = DealService.instance.submitBuyerEvidence(widget.review.dealId, note: _note.text.trim());
                            setState(() {
                              if (ok) {
                                _done = true;
                                _error = null;
                              } else {
                                _error = context.t('ui_photos_alone_error');
                              }
                            });
                          }
                        : null,
                    label: context.t('ui_send_evidence'),
                    height: 48,
                    borderRadius: BorderRadius.circular(TGRadius.pill),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!widget.desktop) return body;
    return Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 720, maxHeight: MediaQuery.sizeOf(context).height * 0.94), child: body));
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.recommended = false});
  final String title;
  final Widget child;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.alternate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.tertiary)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(title, style: theme.bodyMedium.override(fontWeight: FontWeight.w800))),
                if (recommended) Text(context.t('ui_recommended'), style: TextStyle(color: theme.primary, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
