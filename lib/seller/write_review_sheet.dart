import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/deals/review_composer.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/seller/store_owner_edit.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';

Future<void> showWriteReviewFlow(BuildContext context, TGStoreProfile profile) async {
  TGAnalytics.track('review_write_open', {'sellerId': profile.sellerKey});
  DealService.instance.ensureSeeded();
  final auth = context.read<FakeAuthState>();
  if (auth.isLoggedIn && storeIsOwner(auth, profile)) {
    showTGToast(context, context.t('ui_review_own_store'));
    return;
  }
  if (!auth.isLoggedIn) {
    final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
    final logged = wide
        ? await showGeneralDialog<bool>(
            context: context,
            barrierDismissible: true,
            barrierLabel: context.t('ui_close'),
            barrierColor: Colors.black54,
            transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
            pageBuilder: (ctx, _, __) => const _LoginDialog(),
            transitionBuilder: (ctx, anim, _, child) {
              final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
              return FadeTransition(opacity: curved, child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child));
            },
          )
        : await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: TGColors.surface,
            sheetAnimationStyle: AnimationStyle(duration: tgAnim(context, const Duration(milliseconds: 250))),
            builder: (ctx) => const Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 28), child: _LoginGate()),
          );
    if (logged != true || !context.mounted) return;
  }
  if (!context.mounted) return;
  final user = context.read<FakeAuthState>();
  final confirmed = DealService.instance.confirmedDealWith(buyerId: user.userId, sellerId: profile.sellerKey);
  final existing = DealService.instance.reviewsForSeller(profile.sellerKey).where((r) => r.authorId == user.userId && r.canEdit).firstOrNull;
  await showReviewComposer(
    context,
    sellerId: profile.sellerKey,
    sellerName: profile.name,
    listingNo: confirmed?.listingNo ?? existing?.listingNo,
    sellerVerified: profile.verified,
  );
}

Future<void> showReviewReplyFlow(BuildContext context, {required TGStoreProfile profile, required TGPurchaseReview review}) {
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
        return FadeTransition(opacity: curved, child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child));
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
      height: MediaQuery.sizeOf(ctx).height * 0.7,
      child: ReviewReplyFlow(profile: profile, review: review, desktop: false),
    ),
  );
}

class _LoginDialog extends StatelessWidget {
  const _LoginDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: TGColors.surface,
        borderRadius: BorderRadius.circular(TGRadius.modal),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: const Padding(padding: EdgeInsets.fromLTRB(24, 24, 24, 20), child: _LoginGate()),
        ),
      ),
    );
  }
}

class _LoginGate extends StatelessWidget {
  const _LoginGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<FakeAuthState>();
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context, false)},
      child: FocusScope(
        autofocus: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: TGColors.cta, size: 36),
            const SizedBox(height: 12),
            Text(context.t('ui_login_required'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            Text(context.t('ui_login_to_review'), textAlign: TextAlign.center, style: const TextStyle(color: TGColors.textSecondary)),
            const SizedBox(height: 16),
            TGButton(
              key: const Key('review-login'),
              onPressed: () {
                auth.logIn();
                Navigator.pop(context, true);
              },
              label: context.t('ui_login'),
              height: 44,
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
                context.goNamed(LoginPageWidget.routeName);
              },
              child: Text(context.t('ui_login')),
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewReplyFlow extends StatefulWidget {
  const ReviewReplyFlow({super.key, required this.profile, required this.review, required this.desktop});
  final TGStoreProfile profile;
  final TGPurchaseReview review;
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
                              DealService.instance.replyToReview(reviewId: widget.review.id, text: _text.text.trim(), actorId: auth.userId);
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
