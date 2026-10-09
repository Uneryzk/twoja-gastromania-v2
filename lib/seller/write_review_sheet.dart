import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_review.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/review_service.dart';

Future<void> showWriteReviewFlow(BuildContext context, TGStoreProfile profile, {TGStoreReview? existing}) {
  TGAnalytics.track('review_write_open', {'sellerId': profile.sellerKey, 'edit': existing != null});
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('ui_close'),
      barrierColor: Colors.black54,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
      pageBuilder: (ctx, _, __) => WriteReviewFlow(profile: profile, desktop: true, existing: existing),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    sheetAnimationStyle: AnimationStyle(duration: tgAnim(context, const Duration(milliseconds: 250))),
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.9,
      child: WriteReviewFlow(profile: profile, desktop: false, existing: existing),
    ),
  );
}

Future<void> showReviewReplyFlow(BuildContext context, {required TGStoreProfile profile, required TGStoreReview review}) {
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('ui_close'),
      barrierColor: Colors.black54,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
      pageBuilder: (ctx, _, __) => ReviewReplyFlow(profile: profile, review: review, desktop: true),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: AnimationStyle(duration: tgAnim(context, const Duration(milliseconds: 250))),
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.9,
      child: ReviewReplyFlow(profile: profile, review: review, desktop: false),
    ),
  );
}

class WriteReviewFlow extends StatefulWidget {
  const WriteReviewFlow({super.key, required this.profile, required this.desktop, this.existing});
  final TGStoreProfile profile;
  final bool desktop;
  final TGStoreReview? existing;

  @override
  State<WriteReviewFlow> createState() => _WriteReviewFlowState();
}

class _WriteReviewFlowState extends State<WriteReviewFlow> {
  int? _rating;
  TGReviewDeclaration? _declaration;
  final _text = TextEditingController();
  final _listingNo = TextEditingController();
  bool _honest = false;
  bool _submitting = false;
  bool _tick = false;
  bool _done = false;
  String? _error;

  bool get _editLocked =>
      widget.existing != null && !widget.existing!.canEditAt(DateTime.now());

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _rating = ex.rating;
      _declaration = ex.declaration;
      _text.text = ex.text;
      _listingNo.text = ex.listingNo ?? '';
      _honest = true;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _listingNo.dispose();
    super.dispose();
  }

  bool get _ok {
    final t = _text.text.trim();
    return _rating != null && _declaration != null && t.length >= 20 && t.length <= 1000 && _honest;
  }

  Future<void> _submit() async {
    if (_submitting || !_ok) return;
    setState(() {
      _submitting = true;
      _tick = false;
      _error = null;
    });
    if (!tgInWidgetTest()) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _tick = true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (!mounted) return;
    final auth = context.read<FakeAuthState>();
    final result = TGReviewService.instance.submit(
      store: widget.profile,
      auth: auth,
      rating: _rating!,
      text: _text.text.trim(),
      declaration: _declaration!,
      listingNo: _listingNo.text.trim().isEmpty ? null : _listingNo.text.trim(),
      editing: widget.existing != null,
    );
    setState(() {
      _submitting = false;
      _tick = false;
      if (result.block == TGReviewBlock.ownStore) {
        _error = context.t('ui_review_own_store');
      } else if (result.block == TGReviewBlock.sameIdentity) {
        _error = context.t('ui_review_same_identity');
      } else if (result.block == TGReviewBlock.alreadyReviewed && result.existing != null) {
        _error = context.t('ui_already_reviewed', {
          'd': DateFormat('d MMM', Localizations.localeOf(context).languageCode).format(result.existing!.createdAt),
        });
      } else if (result.ok) {
        _done = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final count = _text.text.trim().length;
    final body = CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context)},
      child: FocusScope(
        autofocus: true,
        child: FocusTraversalGroup(
          child: Material(
            color: TGColors.surface,
            borderRadius: widget.desktop ? BorderRadius.circular(TGRadius.modal) : const BorderRadius.vertical(top: Radius.circular(TGRadius.modal)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.desktop ? 560 : double.infinity,
                maxHeight: MediaQuery.sizeOf(context).height * (widget.desktop ? 0.86 : 1),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.existing != null ? context.t('ui_edit_review') : context.t('ui_write_review'),
                            style: theme.titleMedium.override(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 18)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _done
                          ? Semantics(
                              liveRegion: true,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, color: TGColors.cta, size: 40),
                                    const SizedBox(height: 12),
                                    Text(context.t('ui_review_published'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                  ],
                                ),
                              ),
                            )
                          : !auth.isLoggedIn
                              ? _LoginGate(onLogin: auth.logIn)
                              : _editLocked
                                  ? Semantics(
                                      liveRegion: true,
                                      child: Center(
                                        child: Text(
                                          context.t('ui_already_reviewed_closed', {
                                            'd': DateFormat('d MMM', Localizations.localeOf(context).languageCode).format(widget.existing!.createdAt),
                                          }),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                                        ),
                                      ),
                                    )
                                  : ListView(
                                      children: [
                                        Text(widget.profile.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 12),
                                        _StarPicker(
                                          value: _rating,
                                          onChanged: (v) => setState(() => _rating = v),
                                        ),
                                        const SizedBox(height: 14),
                                        Text(context.t('ui_review_declaration'), style: const TextStyle(fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 8),
                                        Semantics(
                                          container: true,
                                          explicitChildNodes: true,
                                          label: context.t('ui_review_declaration'),
                                          child: Column(
                                            children: [
                                              for (final d in TGReviewDeclaration.values)
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 8),
                                                  child: _RadioCard(
                                                    selected: _declaration == d,
                                                    label: context.t('ui_decl_${d.name}'),
                                                    onTap: () => setState(() => _declaration = d),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          key: const Key('review-listing-no'),
                                          controller: _listingNo,
                                          decoration: InputDecoration(labelText: context.t('ui_listing_no_optional')),
                                        ),
                                        const SizedBox(height: 10),
                                        Semantics(
                                          identifier: 'review-text-field',
                                          hint: count > 0 && count < 20 ? context.t('ui_review_text_hint') : null,
                                          child: TextField(
                                            key: const Key('review-text'),
                                            controller: _text,
                                            maxLines: 6,
                                            onChanged: (_) => setState(() {}),
                                            decoration: InputDecoration(
                                              hintText: context.t('ui_review_text_hint'),
                                              counterText: '$count / 1000',
                                              errorText: count > 0 && count < 20 ? context.t('ui_review_text_hint') : null,
                                            ),
                                          ),
                                        ),
                                        if (count > 0 && count < 20)
                                          Offstage(
                                            child: Semantics(
                                              identifier: 'review-text-error',
                                              liveRegion: true,
                                              child: Text(context.t('ui_review_text_hint')),
                                            ),
                                          ),
                                        CheckboxListTile(
                                          key: const Key('review-honest'),
                                          value: _honest,
                                          onChanged: (v) => setState(() => _honest = v ?? false),
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(context.t('ui_review_honest')),
                                        ),
                                      ],
                                    ),
                    ),
                    if (_error != null)
                      Semantics(
                        identifier: 'review-form-error',
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_error!, style: const TextStyle(color: TGColors.error, fontSize: 12)),
                        ),
                      ),
                    if (!_done) ...[
                      const SizedBox(height: 12),
                      if (auth.isLoggedIn && !_editLocked)
                        Semantics(
                          identifier: 'review-submit',
                          hint: _error,
                          child: TGButton(
                            key: const Key('review-submit'),
                            onPressed: _submitting || !_ok ? null : _submit,
                            label: _submitting ? '…' : context.t('ui_publish_review'),
                            height: 44,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                    ] else
                      TGButton(onPressed: () => Navigator.pop(context), label: context.t('ui_done'), height: 44),
                    if (_submitting || _tick)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Center(
                          child: _tick
                              ? TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.6, end: 1),
                                  duration: tgAnim(context, const Duration(milliseconds: 400)),
                                  curve: Curves.easeOutBack,
                                  builder: (context, v, child) => Transform.scale(scale: v, child: child),
                                  child: const Icon(Icons.check_circle, color: TGColors.cta, size: 28),
                                )
                              : const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: TGColors.cta)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.desktop) return Center(child: body);
    return body;
  }
}

class _LoginGate extends StatelessWidget {
  const _LoginGate({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, color: TGColors.cta, size: 36),
          const SizedBox(height: 12),
          Text(context.t('ui_login_required'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          Text(context.t('ui_login_to_review'), textAlign: TextAlign.center, style: const TextStyle(color: TGColors.textSecondary)),
          const SizedBox(height: 16),
          TGButton(key: const Key('review-login'), onPressed: onLogin, label: context.t('ui_login'), height: 44),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.goNamed(LoginPageWidget.routeName);
            },
            child: Text(context.t('ui_login')),
          ),
        ],
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: context.t('ui_rating'),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final n = int.tryParse(event.logicalKey.keyLabel);
          if (n != null && n >= 1 && n <= 5) {
            onChanged(n);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Row(
          children: [
            for (var i = 1; i <= 5; i++)
              Semantics(
                inMutuallyExclusiveGroup: true,
                checked: value == i,
                selected: value == i,
                button: true,
                label: '$i',
                child: IconButton(
                  key: Key('review-star-$i'),
                  tooltip: '$i',
                  onPressed: () => onChanged(i),
                  icon: Icon(
                    (value ?? 0) >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: TGColors.rating,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RadioCard extends StatelessWidget {
  const _RadioCard({required this.selected, required this.label, required this.onTap});
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      focusColor: TGColors.cta.withValues(alpha: 0.16),
      child: AnimatedContainer(
        duration: tgAnim(context, const Duration(milliseconds: 150)),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TGColors.surfaceHover,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? TGColors.cta : TGColors.border, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
            if (selected)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: tgAnim(context, const Duration(milliseconds: 150)),
                curve: Curves.easeOutBack,
                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                child: const Icon(Icons.check_circle, color: TGColors.cta, size: 20),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class ReviewReplyFlow extends StatefulWidget {
  const ReviewReplyFlow({super.key, required this.profile, required this.review, required this.desktop});
  final TGStoreProfile profile;
  final TGStoreReview review;
  final bool desktop;

  @override
  State<ReviewReplyFlow> createState() => _ReviewReplyFlowState();
}

class _ReviewReplyFlowState extends State<ReviewReplyFlow> {
  final _text = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _text.text.trim().length;
    final ok = count >= 1 && count <= 500;
    final body = CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context)},
      child: FocusScope(
        autofocus: true,
        child: Material(
          color: TGColors.surface,
          borderRadius: widget.desktop ? BorderRadius.circular(TGRadius.modal) : const BorderRadius.vertical(top: Radius.circular(TGRadius.modal)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.desktop ? 560 : double.infinity, maxHeight: MediaQuery.sizeOf(context).height * 0.8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(context.t('ui_reply'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 18)),
                    ],
                  ),
                  if (_done)
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Center(child: Text(context.t('ui_reply_sent'), style: const TextStyle(fontWeight: FontWeight.w800))),
                      ),
                    )
                  else ...[
                    Text(widget.review.authorName, style: const TextStyle(color: TGColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('review-reply-text'),
                        controller: _text,
                        maxLines: 6,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(hintText: context.t('ui_reply_hint'), counterText: '$count / 500'),
                      ),
                    ),
                    TGButton(
                      key: const Key('review-reply-submit'),
                      onPressed: ok
                          ? () {
                              final auth = context.read<FakeAuthState>();
                              TGReviewService.instance.reply(reviewId: widget.review.id, text: _text.text.trim(), actorId: auth.userId);
                              setState(() => _done = true);
                            }
                          : null,
                      label: context.t('ui_send'),
                      height: 44,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.desktop) return Center(child: body);
    return body;
  }
}
