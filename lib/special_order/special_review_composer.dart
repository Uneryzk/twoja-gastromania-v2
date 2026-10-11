import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_services/special_review_service.dart';

Future<void> showSpecialReviewComposer(BuildContext context, {required TGSpecialRequest request}) {
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
      pageBuilder: (ctx, _, __) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Material(
            color: FlutterFlowTheme.of(ctx).secondaryBackground,
            borderRadius: BorderRadius.circular(TGRadius.modal),
            child: SpecialReviewComposerSheet(request: request),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: curved, child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child));
      },
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.9,
      child: SpecialReviewComposerSheet(request: request),
    ),
  );
}

class SpecialReviewComposerSheet extends StatefulWidget {
  const SpecialReviewComposerSheet({super.key, required this.request});
  final TGSpecialRequest request;

  @override
  State<SpecialReviewComposerSheet> createState() => _SpecialReviewComposerSheetState();
}

class _SpecialReviewComposerSheetState extends State<SpecialReviewComposerSheet> {
  final _text = TextEditingController();
  int? _rating;
  int _quality = 0;
  int _communication = 0;
  int _deadline = 0;
  int _quoteAccuracy = 0;
  int? _installation;
  bool _honest = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final needInstall = widget.request.installationNeeded;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Text('Review custom project', style: theme.titleLarge.override(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(widget.request.title, style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                Text(widget.request.requestNo, style: theme.bodySmall.override(color: theme.secondaryText)),
                const SizedBox(height: 16),
                Text('Overall', style: const TextStyle(fontWeight: FontWeight.w800)),
                _StarRow(
                  value: _rating ?? 0,
                  onChanged: (v) => setState(() => _rating = v),
                  groupLabel: 'Overall rating',
                  stagger: reduce ? 0 : 40,
                ),
                const SizedBox(height: 12),
                _sub('Quality', _quality, (v) => setState(() => _quality = v), reduce),
                _sub('Communication', _communication, (v) => setState(() => _communication = v), reduce),
                _sub('Deadline', _deadline, (v) => setState(() => _deadline = v), reduce),
                _sub('Quote accuracy', _quoteAccuracy, (v) => setState(() => _quoteAccuracy = v), reduce),
                if (needInstall) _sub('Installation', _installation ?? 0, (v) => setState(() => _installation = v), reduce),
                const SizedBox(height: 12),
                TextField(
                  controller: _text,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Your review (20–1000 characters)',
                    border: OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  value: _honest,
                  onChanged: (v) => setState(() => _honest = v ?? false),
                  title: const Text('I confirm this review is based on a real completed project.'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                if (_error != null) Text(_error!, style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          TGButton(
            onPressed: () {
              final auth = context.read<FakeAuthState>();
              try {
                if (_rating == null || _quality == 0 || _communication == 0 || _deadline == 0 || _quoteAccuracy == 0) {
                  throw StateError('Rate overall and all sub-scores');
                }
                if (needInstall && (_installation == null || _installation == 0)) {
                  throw StateError('Rate installation');
                }
                if (!_honest) throw StateError('Confirmation required');
                TGSpecialReviewService.instance.submit(
                  requestId: widget.request.id,
                  authorId: auth.userId,
                  authorName: auth.displayName,
                  rating: _rating!,
                  subScores: TGSpecialSubScores(
                    quality: _quality,
                    communication: _communication,
                    deadline: _deadline,
                    quoteAccuracy: _quoteAccuracy,
                    installation: needInstall ? _installation : null,
                  ),
                  text: _text.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Review submitted — awaiting manufacturer response')),
                );
              } catch (e) {
                setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
              }
            },
            label: 'Submit review',
            height: 48,
          ),
        ],
      ),
    );
  }

  Widget _sub(String label, int value, ValueChanged<int> onChanged, bool reduce) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            _StarRow(value: value, onChanged: onChanged, groupLabel: label, stagger: reduce ? 0 : 40),
          ],
        ),
      );
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.value, required this.onChanged, required this.groupLabel, this.stagger = 40});
  final int value;
  final ValueChanged<int> onChanged;
  final String groupLabel;
  final int stagger;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: groupLabel,
      child: Row(
        children: [
          for (var i = 1; i <= 5; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: stagger * i),
              builder: (_, __, child) => child!,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onChanged(i);
                },
                icon: Icon(i <= value ? Icons.star : Icons.star_border, color: TGColors.rating),
              ),
            ),
        ],
      ),
    );
  }
}
