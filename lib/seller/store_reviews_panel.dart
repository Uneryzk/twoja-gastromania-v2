import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/product_detail/report_listing_sheet.dart';
import 'package:twoja_gastromania/seller/store_owner_edit.dart';
import 'package:twoja_gastromania/seller/write_review_sheet.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_review.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/review_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

class StoreReviewsPanel extends StatefulWidget {
  const StoreReviewsPanel({super.key, required this.profile, this.stickySummary = false});
  final TGStoreProfile profile;
  final bool stickySummary;

  @override
  State<StoreReviewsPanel> createState() => _StoreReviewsPanelState();
}

class _StoreReviewsPanelState extends State<StoreReviewsPanel> {
  TGReviewSort _sort = TGReviewSort.newest;
  int? _starFilter;
  int _visible = 10;
  bool _barsPlayed = false;

  @override
  void initState() {
    super.initState();
    TGReviewService.instance.ensureSeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _barsPlayed = true);
    });
  }

  List<TGStoreReview> _filtered(List<TGStoreReview> all) {
    var list = [...all];
    if (_starFilter != null) list = list.where((r) => r.rating == _starFilter).toList();
    switch (_sort) {
      case TGReviewSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case TGReviewSort.highest:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case TGReviewSort.lowest:
        list.sort((a, b) => a.rating.compareTo(b.rating));
      case TGReviewSort.helpful:
        list.sort((a, b) => b.helpfulCount.compareTo(a.helpfulCount));
    }
    return list;
  }

  Future<void> _write() async {
    final chrome = StoreChromeScope.maybeOf(context);
    if (chrome?.previewVisitor == true) {
      // Preview only — the button looks enabled.
      return;
    }
    final auth = context.read<FakeAuthState>();
    final existing = auth.isLoggedIn ? TGReviewService.instance.byAuthorAndSeller(auth.userId, widget.profile.sellerKey) : null;
    await withStoreOverlay(context, () => showWriteReviewFlow(context, widget.profile, existing: existing));
  }

  @override
  Widget build(BuildContext context) {
    final profile = TGSellerProfileService.instance.bySellerKey(widget.profile.sellerKey) ?? widget.profile;
    return ListenableBuilder(
      listenable: TGReviewService.instance,
      builder: (context, _) {
        final all = TGReviewService.instance.publishedFor(profile.sellerKey);
        final dist = TGReviewService.instance.distribution(profile.sellerKey);
        final filtered = _filtered(all);
        final shown = filtered.take(_visible).toList();
        final wide = MediaQuery.sizeOf(context).width >= 1024;
        final ownerUi = storeOwnerUi(context, profile);
        final preview = StoreChromeScope.maybeOf(context)?.previewVisitor == true;
        final writeEnabled = !ownerUi || preview;
        final summary = _SummaryCard(
          profile: profile,
          dist: dist,
          total: all.length,
          barsPlayed: _barsPlayed,
          selected: _starFilter,
          compact: !wide,
          hideWrite: !wide,
          writeEnabled: writeEnabled,
          onStar: (s) => setState(() {
            _starFilter = _starFilter == s ? null : s;
            _visible = 10;
          }),
          onWrite: writeEnabled ? _write : null,
        );
        final list = _ReviewsList(
          profile: profile,
          reviews: shown,
          total: filtered.length,
          sort: _sort,
          starFilter: _starFilter,
          onSort: (s) => setState(() => _sort = s),
          onStarFilter: (s) => setState(() {
            _starFilter = s;
            _visible = 10;
          }),
          onMore: () => setState(() => _visible += 10),
          empty: all.isEmpty,
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary,
              const SizedBox(height: 12),
              TGButton(key: const Key('write-review'), onPressed: writeEnabled ? _write : null, label: context.t('ui_write_review'), height: 44),
              const SizedBox(height: 20),
              list,
            ],
          );
        }
        final left = widget.stickySummary
            ? Align(alignment: Alignment.topCenter, child: SingleChildScrollView(child: summary))
            : summary;
        final right = widget.stickySummary
            ? ListView(padding: const EdgeInsets.only(bottom: 8), children: [list])
            : list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: left),
            const SizedBox(width: 24),
            Expanded(flex: 8, child: right),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.profile,
    required this.dist,
    required this.total,
    required this.barsPlayed,
    required this.selected,
    required this.onStar,
    required this.onWrite,
    this.compact = false,
    this.hideWrite = false,
    this.writeEnabled = true,
  });

  final TGStoreProfile profile;
  final Map<int, int> dist;
  final int total;
  final bool barsPlayed;
  final int? selected;
  final ValueChanged<int> onStar;
  final VoidCallback? onWrite;
  final bool compact;
  final bool hideWrite;
  final bool writeEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final notEnough = total < 3;
    final maxBar = dist.values.fold<int>(0, (a, b) => a > b ? a : b).clamp(1, 999);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: TGColors.surface, borderRadius: BorderRadius.circular(TGRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notEnough) ...[
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(context.t('ui_not_enough_reviews'), style: theme.titleMedium.override(fontWeight: FontWeight.w800)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: theme.secondary, borderRadius: BorderRadius.circular(TGRadius.pill)),
                  child: Text(context.t('ui_new_seller'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ],
            ),
          ] else ...[
            Text(profile.rating.toStringAsFixed(1), style: theme.displaySmall.override(fontSize: 48, fontWeight: FontWeight.w800, lineHeight: 1.1)),
            const SizedBox(height: 6),
            _GoldStars(rating: profile.rating),
            const SizedBox(height: 6),
            Text(context.t('ui_reviews_n', {'n': '$total'}), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          for (var star = 5; star >= 1; star--)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DistBar(
                star: star,
                count: dist[star] ?? 0,
                max: maxBar,
                total: total,
                selected: selected == star,
                played: barsPlayed,
                onTap: () => onStar(star),
              ),
            ),
          if (!hideWrite) ...[
            const SizedBox(height: 8),
            TGButton(key: const Key('write-review'), onPressed: writeEnabled ? onWrite : null, label: context.t('ui_write_review'), height: 44),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('how-reviews-work'),
              onPressed: () => _showHow(context),
              child: Text(context.t('ui_how_reviews_work')),
            ),
          ),
        ],
      ),
    );
  }

  void _showHow(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
    if (wide) {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: context.t('ui_close'),
        barrierColor: Colors.black54,
        transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
        pageBuilder: (ctx, _, __) => Center(
          child: Material(
            color: TGColors.surface,
            borderRadius: BorderRadius.circular(TGRadius.modal),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.t('ui_how_reviews_work'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 10),
                    Text(context.t('ui_how_reviews_body'), style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 12),
                    TGButton(onPressed: () => Navigator.pop(ctx), label: context.t('ui_done'), height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: TGColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.t('ui_how_reviews_work'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),
              Text(context.t('ui_how_reviews_body'), style: const TextStyle(height: 1.4)),
            ],
          ),
        ),
      );
    }
  }
}

class _GoldStars extends StatelessWidget {
  const _GoldStars({required this.rating, this.size = 22});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rated ${rating.toStringAsFixed(1)} out of 5',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: rating >= i + 1 ? 1 : rating >= i + 0.5 ? 0.5 : 0),
              duration: tgAnim(context, Duration(milliseconds: 40 * (i + 1))),
              builder: (context, v, _) => Icon(
                v >= 1 ? Icons.star_rounded : v >= 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded,
                color: TGColors.rating,
                size: size,
              ),
            ),
        ],
      ),
    );
  }
}

class _DistBar extends StatefulWidget {
  const _DistBar({
    required this.star,
    required this.count,
    required this.max,
    required this.total,
    required this.selected,
    required this.played,
    required this.onTap,
  });
  final int star;
  final int count;
  final int max;
  final int total;
  final bool selected;
  final bool played;
  final VoidCallback onTap;

  @override
  State<_DistBar> createState() => _DistBarState();
}

class _DistBarState extends State<_DistBar> {
  @override
  Widget build(BuildContext context) {
    final frac = widget.max == 0 ? 0.0 : widget.count / widget.max;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: context.t('ui_reviews_with_stars', {'n': '${widget.count}', 's': '${widget.star}'}),
      child: InkWell(
        key: Key('reviews-dist-${widget.star}'),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        focusColor: TGColors.cta.withValues(alpha: 0.16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(width: 14, child: Text('${widget.star}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              const Icon(Icons.star_rounded, size: 12, color: TGColors.rating),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 8,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        return Stack(
                          children: [
                            const ColoredBox(color: TGColors.border, child: SizedBox.expand()),
                            AnimatedContainer(
                              duration: tgAnim(context, const Duration(milliseconds: 400)),
                              curve: Curves.easeOutCubic,
                              width: widget.played ? c.maxWidth * frac : 0,
                              color: widget.selected ? TGColors.cta : TGColors.rating,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 28, child: Text('${widget.count}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewsList extends StatelessWidget {
  const _ReviewsList({
    required this.profile,
    required this.reviews,
    required this.total,
    required this.sort,
    required this.starFilter,
    required this.onSort,
    required this.onStarFilter,
    required this.onMore,
    required this.empty,
  });

  final TGStoreProfile profile;
  final List<TGStoreReview> reviews;
  final int total;
  final TGReviewSort sort;
  final int? starFilter;
  final ValueChanged<TGReviewSort> onSort;
  final ValueChanged<int?> onStarFilter;
  final VoidCallback onMore;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButtonHideUnderline(
              child: DropdownButton<TGReviewSort>(
                key: const Key('review-sort'),
                value: sort,
                items: [
                  DropdownMenuItem(value: TGReviewSort.newest, child: Text(context.t('ui_sort_newest'))),
                  DropdownMenuItem(value: TGReviewSort.highest, child: Text(context.t('ui_sort_highest'))),
                  DropdownMenuItem(value: TGReviewSort.lowest, child: Text(context.t('ui_sort_lowest'))),
                  DropdownMenuItem(value: TGReviewSort.helpful, child: Text(context.t('ui_sort_helpful'))),
                ],
                onChanged: (v) {
                  if (v != null) onSort(v);
                },
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: starFilter,
                hint: Text(context.t('ui_filter_stars')),
                items: [
                  DropdownMenuItem(value: null, child: Text(context.t('ui_all_stars'))),
                  for (var s = 5; s >= 1; s--) DropdownMenuItem(value: s, child: Text('$s')),
                ],
                onChanged: onStarFilter,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (empty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(context.t('ui_no_reviews_yet'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          )
        else if (reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(context.t('ui_no_reviews_filter'), textAlign: TextAlign.center),
          )
        else ...[
          for (final r in reviews) ...[
            _ReviewCard(profile: profile, review: r),
            const SizedBox(height: 12),
          ],
          if (reviews.length < total)
            Align(
              alignment: Alignment.centerLeft,
              child: TGButton(
                key: const Key('review-show-more'),
                onPressed: onMore,
                label: context.t('ui_show_more'),
                variant: TGButtonVariant.outline,
                height: 40,
              ),
            ),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.profile, required this.review});
  final TGStoreProfile profile;
  final TGStoreReview review;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _expanded = false;
  bool _pop = false;

  Future<void> _helpful() async {
    final auth = context.read<FakeAuthState>();
    final key = auth.isLoggedIn ? auth.userId : 'guest';
    final ok = TGReviewService.instance.markHelpful(widget.review.id, key);
    if (!ok) return;
    setState(() => _pop = true);
    await Future<void>.delayed(tgAnim(context, const Duration(milliseconds: 150)));
    if (mounted) setState(() => _pop = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final r = widget.review;
    final isOwner = storeOwnerUi(context, widget.profile);
    final fmt = DateFormat('d MMM yyyy', Localizations.localeOf(context).languageCode);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: TGColors.surface, borderRadius: BorderRadius.circular(TGRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(r.authorName, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
              Text(fmt.format(r.createdAt), style: theme.bodySmall.override(color: theme.secondaryText)),
            ],
          ),
          const SizedBox(height: 6),
          _GoldStars(rating: r.rating.toDouble(), size: 16),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: tgAnim(context, const Duration(milliseconds: 200)),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _ExpandableText(text: r.text, expanded: _expanded, onToggle: () => setState(() => _expanded = !_expanded)),
          ),
          const SizedBox(height: 10),
          Tooltip(
            message: context.t('ui_self_declared_tip'),
            child: Chip(
              avatar: Icon(
                switch (r.declaration) {
                  TGReviewDeclaration.bought => Icons.shopping_bag_outlined,
                  TGReviewDeclaration.contacted => Icons.chat_bubble_outline,
                  TGReviewDeclaration.visited => Icons.storefront_outlined,
                },
                size: 14,
                color: TGColors.textSecondary,
              ),
              label: Text(context.t('ui_decl_chip_${r.declaration.name}'), style: const TextStyle(fontSize: 11)),
              backgroundColor: TGColors.surfaceHover,
              side: const BorderSide(color: TGColors.border),
            ),
          ),
          if (r.listingNo != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _openListing(r.listingNo!),
              child: Text(
                context.t('ui_review_about', {'title': r.listingTitle ?? r.listingNo!, 'n': r.listingNo!}),
                style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AnimatedScale(
                scale: _pop ? 1.12 : 1,
                duration: tgAnim(context, const Duration(milliseconds: 150)),
                child: TextButton(
                  key: Key('review-helpful-${r.id}'),
                  onPressed: _helpful,
                  child: Text(context.t('ui_helpful_n', {'n': '${r.helpfulCount}'})),
                ),
              ),
              TextButton.icon(
                key: Key('review-report-${r.id}'),
                onPressed: () => withStoreOverlay(context, () => showReportFlow(context, TGReportSubject.review(r, widget.profile))),
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: Text(context.t('ui_report')),
              ),
              if (isOwner && r.reply == null)
                TextButton(
                  key: Key('review-reply-${r.id}'),
                  onPressed: () => withStoreOverlay(context, () => showReviewReplyFlow(context, profile: widget.profile, review: r)),
                  child: Text(context.t('ui_reply')),
                ),
            ],
          ),
          if (r.reply != null) ...[
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.only(left: 16),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: TGColors.cta, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('ui_reply_from', {'name': widget.profile.name, 'when': _ago(context, r.reply!.createdAt)}),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(r.reply!.text, style: const TextStyle(height: 1.4, fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openListing(String no) async {
    final all = await TGProductService.instance.getAll();
    final hit = all.where((p) => p.listingNo == no).firstOrNull ??
        TGSellerProfileService.instance.extraListings.where((p) => p.listingNo == no).firstOrNull;
    if (!mounted) return;
    if (hit != null) context.go(hit.detailPath);
  }
}

class _ExpandableText extends StatelessWidget {
  const _ExpandableText({required this.text, required this.expanded, required this.onToggle});
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final overflow = text.length > 220;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, maxLines: expanded ? null : 5, overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis, style: const TextStyle(height: 1.45, fontSize: 14)),
        if (overflow)
          TextButton(
            onPressed: onToggle,
            child: Text(expanded ? context.t('ui_show_less') : context.t('ui_read_more')),
          ),
      ],
    );
  }
}

String _ago(BuildContext context, DateTime at) {
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 60) return context.t('ui_minutes_ago', {'n': '${d.inMinutes.clamp(1, 59)}'});
  if (d.inHours < 24) return context.t('ui_hours_ago', {'n': '${d.inHours}'});
  if (d.inDays == 1) return context.t('ui_yesterday');
  if (d.inDays < 14) return context.t('ui_days_ago', {'n': '${d.inDays}'});
  return DateFormat('d MMM', Localizations.localeOf(context).languageCode).format(at);
}
