import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_sms_gate.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';

Future<void> showReviewComposer(
  BuildContext context, {
  String sellerId = FakeAuthState.mockOwnerId,
  String sellerName = 'Technica',
  String? listingNo,
  bool sellerVerified = true,
}) {
  TGAnalytics.track('review_compose_open', {'sellerId': sellerId, 'listingNo': listingNo});
  DealService.instance.ensureSeeded();
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('ui_close'),
      barrierColor: Colors.black54,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
      pageBuilder: (ctx, _, __) => ReviewComposerSheet(
        sellerId: sellerId,
        sellerName: sellerName,
        listingNo: listingNo,
        sellerVerified: sellerVerified,
        desktop: true,
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
    backgroundColor: Colors.transparent,
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * (MediaQuery.sizeOf(ctx).width <= 400 ? 1 : 0.9),
      child: ReviewComposerSheet(sellerId: sellerId, sellerName: sellerName, listingNo: listingNo, sellerVerified: sellerVerified, desktop: false),
    ),
  );
}

class ReviewComposerSheet extends StatefulWidget {
  const ReviewComposerSheet({
    super.key,
    required this.sellerId,
    required this.sellerName,
    required this.desktop,
    this.listingNo,
    this.sellerVerified = true,
  });
  final String sellerId;
  final String sellerName;
  final String? listingNo;
  final bool sellerVerified;
  final bool desktop;

  @override
  State<ReviewComposerSheet> createState() => _ReviewComposerSheetState();
}

class _ReviewComposerSheetState extends State<ReviewComposerSheet> {
  final _listingNo = TextEditingController();
  final _text = TextEditingController();
  final _smsGate = GlobalKey<TGSmsGateState>();
  TGDealType _type = TGDealType.sale;
  DateTime _month = DateTime(TGClock.now().year, TGClock.now().month);
  int? _rating;
  bool _honest = false;
  bool _smsOk = false;
  bool _busy = false;
  bool _done = false;
  String? _error;
  TGListingHit? _hit;
  TGPurchaseReview? _posted;
  TGPurchaseReview? _existing;

  @override
  void initState() {
    super.initState();
    _listingNo.addListener(_validateNo);
    _text.addListener(() => setState(() {}));
    if (widget.listingNo != null) _listingNo.text = widget.listingNo!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _validateNo();
    });
  }

  @override
  void dispose() {
    _listingNo.dispose();
    _text.dispose();
    super.dispose();
  }

  void _validateNo() {
    final raw = _listingNo.text.replaceAll(RegExp(r'\D'), '');
    if (raw.length != 8) {
      setState(() {
        _hit = null;
        _error = null;
      });
      return;
    }
    final auth = context.read<FakeAuthState>();
    final check = DealService.instance.checkListingNo(listingNo: raw, sellerId: widget.sellerId, authorId: auth.userId);
    final hit = DealService.instance.resolveListing(raw);
    final existing = DealService.instance.existingReview(authorId: auth.userId, listingNo: raw);
    setState(() {
      _hit = check == ListingNoCheck.ok || check == ListingNoCheck.alreadyReviewed ? hit : null;
      _existing = check == ListingNoCheck.alreadyReviewed && existing != null && existing.canEdit ? existing : null;
      if (_existing != null) {
        _rating ??= _existing!.rating;
        if (_text.text.isEmpty) _text.text = _existing!.text;
      }
      _error = switch (check) {
        ListingNoCheck.ok => null,
        ListingNoCheck.alreadyReviewed => _existing != null ? null : context.t('ui_review_already_listing'),
        ListingNoCheck.ownListing => context.t('ui_review_own_listing'),
        ListingNoCheck.removed => context.t('ui_review_listing_removed'),
        _ => context.t('ui_review_wrong_seller'),
      };
      if (check == ListingNoCheck.ok) TGAnalytics.track('listing_no_validated', {'listingNo': raw});
    });
  }

  bool get _canSend {
    final t = _text.text.trim();
    return _hit != null &&
        _error == null &&
        _rating != null &&
        t.length >= 20 &&
        t.length <= 1000 &&
        _honest &&
        (_existing != null || DealService.instance.reviewsPostedToday(context.read<FakeAuthState>().userId) < 3);
  }

  Future<void> _submit() async {
    final auth = context.read<FakeAuthState>();
    if (!auth.phoneVerified && !_smsOk) {
      final gate = _smsGate.currentState;
      if (gate == null) return;
      if (!gate.codeSent) {
        gate.send();
        setState(() {});
        return;
      }
      if (!gate.verify()) {
        setState(() => _error = gate.error ?? context.t('ui_sms_wrong'));
        return;
      }
      auth.phoneVerified = true;
      setState(() {
        _smsOk = true;
        _error = null;
      });
      return;
    }
    if (!_canSend || _busy) return;
    setState(() => _busy = true);
    if (!tgInWidgetTest()) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    TGPurchaseReview? review;
    if (_existing != null) {
      DealService.instance.updateReview(_existing!, rating: _rating!, text: _text.text.trim());
      review = _existing;
    } else {
      review = DealService.instance.submitReviewFirst(
        auth: auth,
        sellerId: widget.sellerId,
        listingNo: _listingNo.text.replaceAll(RegExp(r'\D'), ''),
        dealType: _type,
        dealMonth: _month,
        rating: _rating!,
        text: _text.text.trim(),
      );
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _posted = review;
      _done = review != null;
      if (review == null) _error = context.t('ui_review_limit');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final convos = DealService.instance.conversations.where((c) => c.sellerId == widget.sellerId).toList();
    final nos = {for (final c in convos) c.listingNo}.toList();
    final body = CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: FocusScope(
        autofocus: true,
        child: Material(
          color: theme.secondaryBackground,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: widget.desktop ? BorderRadius.circular(16) : const BorderRadius.vertical(top: Radius.circular(16)),
            side: BorderSide(color: theme.tertiary),
          ),
          child: Column(
            children: [
              if (!widget.desktop) ...[
                const SizedBox(height: 10),
                Container(width: 42, height: 4, decoration: BoxDecoration(color: theme.tertiary, borderRadius: BorderRadius.circular(99))),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(child: Text(_existing != null ? context.t('ui_edit_review') : context.t('ui_review_a_purchase'), style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: Icon(Icons.close, color: theme.secondaryText)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _done ? _Success(review: _posted) : _form(theme, auth, nos),
                ),
              ),
              if (!_done)
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
                  child: TGButton(
                    key: const Key('review-submit'),
                    onPressed: _busy ? null : _submit,
                    label: !auth.phoneVerified && !_smsOk
                        ? ((_smsGate.currentState?.codeSent ?? false) ? context.t('ui_verify_sms') : context.t('ui_send_sms'))
                        : context.t('ui_post_review'),
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
    return Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * 0.92), child: body));
  }

  Widget _form(FlutterFlowTheme theme, FakeAuthState auth, List<String> nos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.sellerName, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        if (widget.sellerVerified) Text(context.t('ui_verified'), style: const TextStyle(color: TGColors.verified, fontSize: 11, fontWeight: FontWeight.w800)),
        if (!auth.phoneVerified && !_smsOk) ...[
          const SizedBox(height: 12),
          TGSmsGate(key: _smsGate, intro: context.t('ui_sms_verify_review'), phoneFieldKey: const Key('review-sms-phone'), codeFieldKey: const Key('review-sms')),
        ],
        if (auth.phoneVerified || _smsOk) ...[
        const SizedBox(height: 12),
        Text(context.t('ui_listing_no_header'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        TextField(
          key: const Key('review-listing-no'),
          controller: _listingNo,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
          decoration: InputDecoration(hintText: context.t('ui_listing_no_hint')),
        ),
        Text(context.t('ui_listing_no_help'), style: theme.bodySmall.override(color: theme.secondaryText)),
        if (nos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(context.t('ui_listings_messaged', {'n': '${nos.length}'}), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: [
              for (final n in nos.take(4))
                ChoiceChip(label: Text(n), selected: _listingNo.text == n, onSelected: (_) => setState(() => _listingNo.text = n)),
            ],
          ),
        ],
        if (_hit != null) ...[
          const SizedBox(height: 10),
          _Mini(hit: _hit!),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, key: const Key('review-error'), style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 14),
        Text(context.t('ui_deal_kind'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        Row(
          children: [
            Expanded(child: _Seg(label: context.t('ui_bought'), selected: _type == TGDealType.sale, onTap: () => setState(() => _type = TGDealType.sale))),
            const SizedBox(width: 8),
            Expanded(child: _Seg(label: context.t('ui_rented'), selected: _type == TGDealType.rental, onTap: () => setState(() => _type = TGDealType.rental))),
          ],
        ),
        const SizedBox(height: 10),
        Text(context.t('ui_deal_month'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        DropdownButton<DateTime>(
          value: _month,
          isExpanded: true,
          items: [
            for (var i = 0; i < 12; i++)
              DropdownMenuItem(
                value: DateTime(TGClock.now().year, TGClock.now().month - i),
                child: Text(DateFormat('MMMM y').format(DateTime(TGClock.now().year, TGClock.now().month - i))),
              ),
          ],
          onChanged: (v) => setState(() => _month = v ?? _month),
        ),
        const SizedBox(height: 8),
        Text(context.t('ui_your_rating'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: context.t('ui_your_rating'),
          child: Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: _rating == i,
                  button: true,
                  child: IconButton(
                    key: Key('review-star-$i'),
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(_rating != null && i <= _rating! ? Icons.star : Icons.star_border, color: TGColors.rating),
                  ),
                ),
            ],
          ),
        ),
        TextField(
          key: const Key('review-text'),
          controller: _text,
          maxLines: 5,
          maxLength: 1000,
          decoration: InputDecoration(hintText: context.t('ui_review_text_hint'), counterText: '${_text.text.trim().length}/1000'),
        ),
        CheckboxListTile(
          key: const Key('review-honest'),
          value: _honest,
          onChanged: (v) => setState(() => _honest = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(context.t('ui_review_honest'), style: theme.bodySmall),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: theme.alternate, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('ui_review_info_box'), style: theme.bodySmall),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(context.t('ui_how_reviews_work')),
                    content: Text(context.t('ui_how_reviews_body')),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('ui_close')))],
                  ),
                ),
                child: Text(context.t('ui_how_reviews_work')),
              ),
            ],
          ),
        ),
        ],
      ],
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({this.review});
  final TGPurchaseReview? review;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      children: [
        Icon(Icons.check_circle, color: theme.primary, size: 40),
        const SizedBox(height: 10),
        Text(
          review?.state == TGPurchaseReviewState.pendingCheck ? context.t('ui_review_pending_check') : context.t('ui_review_posted_awaiting'),
          style: theme.titleSmall.override(fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.hit});
  final TGListingHit hit;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: hit.imageUrl.isEmpty ? const ColoredBox(color: TGColors.border) : Image.asset(hit.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: TGColors.border)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hit.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
              if (hit.price != null) Text('${hit.price} PLN', style: theme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: selected ? theme.primary.withValues(alpha: 0.16) : theme.alternate,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99), side: BorderSide(color: selected ? theme.primary : theme.tertiary)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(label, textAlign: TextAlign.center, style: theme.bodySmall.override(fontWeight: FontWeight.w800, color: selected ? theme.primary : theme.primaryText)),
        ),
      ),
    );
  }
}
