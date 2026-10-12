import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/products/products_results.dart' show kTGGridGutter;
import 'package:twoja_gastromania/tg_components/tg_hover_card.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_components/tg_rating_stars.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/restaurants/restaurant_l10n.dart';
import 'package:twoja_gastromania/tg_models/tg_ad_slot.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/ad_slot_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

/// Section heading used on the home page.
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({super.key, required this.title, this.subtitle, this.action});

  final String title;
  final String? subtitle;

  /// Optional trailing link, e.g. "View all".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: theme.headlineSmall.override(fontSize: phone ? 24 : 32, fontWeight: FontWeight.w900)),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: theme.bodyMedium.override(color: theme.secondaryText, lineHeight: 1.45, fontSize: phone ? 14 : 16)),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero carousel (organic ad pages + up to 3 sponsored AdSlots)
// ---------------------------------------------------------------------------

class _HeroSlide {
  const _HeroSlide.organic({required this.image, required this.titleKey, required this.subtitleKey, required this.routeName})
      : sponsored = false,
        ad = null,
        title = null,
        targetUrl = null;

  const _HeroSlide.sponsored({required this.ad, required this.image, required this.title, required this.targetUrl})
      : sponsored = true,
        titleKey = null,
        subtitleKey = null,
        routeName = null;

  final bool sponsored;
  final TGAdSlot? ad;
  final String image;
  final String? titleKey;
  final String? subtitleKey;
  final String? routeName;
  final String? title;
  final String? targetUrl;
}

/// Auto-playing carousel; organic slides open ad pages; sponsored open targetUrl.
class HomeHeroCarousel extends StatefulWidget {
  const HomeHeroCarousel({super.key, required this.slideRouteNames});

  /// Route names of the ad pages, in slide order.
  final List<String> slideRouteNames;

  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel> {
  static const Duration _autoPlayEvery = Duration(seconds: 6);

  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _paused = false;
  final Set<String> _impressed = {};

  List<_HeroSlide> _organic() => [
        _HeroSlide.organic(image: TGListingImages.heroSlide(0), titleKey: 'i8m5wr2h', subtitleKey: '7d6qkq0f', routeName: widget.slideRouteNames[0]),
        _HeroSlide.organic(image: TGListingImages.heroSlide(1), titleKey: '0y0mdwe3', subtitleKey: 'gn0cgz8h', routeName: widget.slideRouteNames[1]),
        _HeroSlide.organic(image: TGListingImages.heroSlide(2), titleKey: 'z2t2enej', subtitleKey: 'yhrj1i0w', routeName: widget.slideRouteNames[2]),
        _HeroSlide.organic(image: TGListingImages.heroSlide(3), titleKey: 'fd2vmdbm', subtitleKey: 'ghe86x4x', routeName: widget.slideRouteNames[3]),
      ];

  /// Organic slides unchanged; sponsored interleaved between them (max 3).
  List<_HeroSlide> _compose() {
    final organic = _organic();
    final ads = AdSlotService.instance.liveSlides;
    if (ads.isEmpty) return organic;
    final out = <_HeroSlide>[];
    var si = 0;
    for (var i = 0; i < organic.length; i++) {
      out.add(organic[i]);
      if (si < ads.length && si < 3) {
        final a = ads[si++];
        out.add(_HeroSlide.sponsored(ad: a, image: a.imageUrl, title: a.title, targetUrl: a.targetUrl));
      }
    }
    while (si < ads.length && si < 3) {
      final a = ads[si++];
      out.add(_HeroSlide.sponsored(ad: a, image: a.imageUrl, title: a.title, targetUrl: a.targetUrl));
    }
    return out;
  }

  void _recordImpression(_HeroSlide s) {
    final id = s.ad?.id;
    if (id == null || _impressed.contains(id)) return;
    _impressed.add(id);
    AdSlotService.instance.recordImpression(id);
  }

  @override
  void initState() {
    super.initState();
    AdSlotService.instance.ensureSeeded();
    AdSlotService.instance.addListener(_onAds);
  }

  void _onAds() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the OS "reduce motion" setting: no auto-advance then.
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _timer?.cancel();
    _timer = reduce ? null : Timer.periodic(_autoPlayEvery, (_) => _advance());
  }

  void _advance() {
    if (_paused || !mounted || !_controller.hasClients) return;
    final n = _compose().length;
    if (n == 0) return;
    _goTo((_index + 1) % n);
  }

  void _goTo(int i) {
    if (!_controller.hasClients) return;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _controller.jumpToPage(i);
    } else {
      _controller.animateToPage(i, duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    AdSlotService.instance.removeListener(_onAds);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _openSlide(_HeroSlide s) {
    if (s.sponsored) {
      final id = s.ad?.id;
      if (id != null) AdSlotService.instance.recordClick(id);
      final url = s.targetUrl;
      if (url != null && url.isNotEmpty) context.go(url);
      return;
    }
    context.pushNamed(s.routeName!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final l10n = FFLocalizations.of(context);
    final slides = _compose();
    if (_index >= slides.length) _index = 0;
    if (slides.isNotEmpty) _recordImpression(slides[_index]);

    return LayoutBuilder(
      builder: (context, c) {
        final phone = c.maxWidth < TGBreakpoints.phone;
        final height = (c.maxWidth * (phone ? 0.78 : 0.36)).clamp(280.0, 440.0);
        return Semantics(
          label: 'Homepage hero carousel',
          child: MouseRegion(
            onEnter: (_) => _paused = true,
            onExit: (_) => _paused = false,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TGRadius.card),
              child: SizedBox(
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _controller,
                      itemCount: slides.length,
                      onPageChanged: (i) {
                        setState(() => _index = i);
                        if (i < slides.length) _recordImpression(slides[i]);
                      },
                      itemBuilder: (context, i) {
                        final s = slides[i];
                        String title;
                        if (s.sponsored) {
                          final segment = (s.targetUrl ?? '').split('/').where((e) => e.isNotEmpty).lastOrNull ?? '';
                          final listing = RestaurantService.instance.fromPathSegment(segment);
                          title = listing != null
                              ? restoLocalizedShortTitle(context, listing)
                              : (context.t('ad_title_${s.ad?.id ?? ''}').isNotEmpty
                                  ? context.t('ad_title_${s.ad?.id ?? ''}')
                                  : (s.title ?? ''));
                        } else {
                          title = l10n.getText(s.titleKey!);
                        }
                        final label = s.sponsored ? '${l10n.getText('ui_sponsored')}. $title' : title;
                        return Focus(
                          child: Builder(
                            builder: (ctx) {
                              final focused = Focus.of(ctx).hasFocus;
                              return Semantics(
                                button: true,
                                label: label,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _openSlide(s),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: focused ? Border.all(color: TGColors.cta, width: 2) : null,
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (s.sponsored)
                                            TGSmartImage(url: s.image, fit: BoxFit.cover, cacheWidth: 1400)
                                          else
                                            Image.asset(
                                              s.image,
                                              fit: BoxFit.cover,
                                              cacheWidth: 1400,
                                              gaplessPlayback: true,
                                              errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate),
                                            ),
                                          if (s.sponsored)
                                            const DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                  colors: [Color(0xE0121212), Color(0x00000000)],
                                                ),
                                              ),
                                            )
                                          else
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [Colors.black.withValues(alpha: 0.82), Colors.black.withValues(alpha: 0.35), Colors.transparent],
                                                  stops: const [0, 0.55, 1],
                                                ),
                                              ),
                                            ),
                                          if (s.sponsored)
                                            Positioned(
                                              left: phone ? 18 : 36,
                                              top: phone ? 16 : 20,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(TGRadius.pill),
                                                  border: Border.all(color: Colors.white70),
                                                ),
                                                child: Text(
                                                  l10n.getText('ui_sponsored'),
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            left: phone ? 18 : 36,
                                            right: phone ? 18 : 120,
                                            bottom: phone ? 48 : 52,
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 680),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    title,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: theme.headlineMedium.override(
                                                      color: Colors.white,
                                                      fontSize: phone ? 24 : 38,
                                                      fontWeight: FontWeight.w900,
                                                      lineHeight: 1.1,
                                                    ),
                                                  ),
                                                  if (!s.sponsored) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      l10n.getText(s.subtitleKey!),
                                                      maxLines: phone ? 2 : 3,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: theme.bodyLarge.override(
                                                        color: Colors.white.withValues(alpha: 0.88),
                                                        fontSize: phone ? 13.5 : 17,
                                                        lineHeight: 1.4,
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 14),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: theme.primary,
                                                      borderRadius: BorderRadius.circular(TGRadius.pill),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          s.sponsored ? context.t('ui_view') : context.t('ui_read_more'),
                                                          style: theme.bodySmall.override(color: TGColors.onCta, fontWeight: FontWeight.w900),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        const Icon(Icons.arrow_forward_rounded, size: 16, color: TGColors.onCta),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    if (!phone) ...[
                      Positioned(left: 12, top: 0, bottom: 0, child: Center(child: _ArrowButton(icon: Icons.chevron_left_rounded, label: 'Previous slide', onTap: () => _goTo((_index - 1 + slides.length) % slides.length)))),
                      Positioned(right: 12, top: 0, bottom: 0, child: Center(child: _ArrowButton(icon: Icons.chevron_right_rounded, label: 'Next slide', onTap: () => _goTo((_index + 1) % slides.length)))),
                    ],
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < slides.length; i++)
                            Semantics(
                              button: true,
                              selected: i == _index,
                              label: 'Slide ${i + 1}${slides[i].sponsored ? ', Sponsored' : ''}',
                              child: GestureDetector(
                                onTap: () => _goTo(i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ? 0 : 220),
                                    width: i == _index ? 26 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: i == _index ? theme.primary : Colors.white.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(TGRadius.pill),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: Colors.white, size: 28)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category cards -> /products?cat=...
// ---------------------------------------------------------------------------

class _CategoryData {
  const _CategoryData(this.category, this.titleKey, this.image);

  final TGCategory category;
  final String titleKey;

  /// Local `assets/images/…` path (FlutterFlow originals).
  final String image;
}

/// Featured category tiles — local assets from [TGListingImages.categoryCoverUrls] only.
final List<_CategoryData> _categories = [
  for (final e in TGListingImages.categoryCoverUrls.entries)
    _CategoryData(
      e.key,
      switch (e.key) {
        TGCategory.cookingEquipment => 'ji98dehm',
        TGCategory.refrigerationEquipment => 'swrjjpbp',
        TGCategory.warewashing => 'lcx4dovc',
        TGCategory.foodPreparation => '71nup2wm',
        TGCategory.stainlessSteelFurniture => '56pbhr1s',
        TGCategory.barAndBeverageEquipment => 'viy2skiv',
      },
      e.value,
    ),
];

/// "Featured Offers": one card per category. Tapping a card opens `/products`
/// filtered to that category.
class HomeCategorySection extends StatelessWidget {
  const HomeCategorySection({super.key, required this.listingCounts});

  /// Number of listings per category (empty until the catalogue has loaded).
  final Map<TGCategory, int> listingCounts;

  @override
  Widget build(BuildContext context) {
    final l10n = FFLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(title: context.t('ui_gastronomy_categories'), subtitle: l10n.getText('3u75e0ef')),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 3 : 2;
            final phone = c.maxWidth < 480;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              clipBehavior: Clip.none, // hover glow paints outside the grid
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: phone ? 12 : 20,
                mainAxisSpacing: phone ? 12 : 20,
                childAspectRatio: cols == 3 ? 1.35 : (phone ? 0.95 : 1.3),
              ),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final d = _categories[i];
                return _CategoryCard(
                  data: d,
                  title: l10n.getText(d.titleKey),
                  count: listingCounts[d.category],
                  compact: phone,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.data, required this.title, required this.count, required this.compact});

  final _CategoryData data;
  final String title;
  final int? count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return TGHoverCard(
      semanticLabel: 'Browse $title',
      onTap: () => TGNav.category(context, data.category),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            data.image,
            fit: BoxFit.cover,
            cacheWidth: 800,
            errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [Colors.black.withValues(alpha: 0.78), Colors.transparent],
              ),
            ),
          ),
          Positioned(
            left: compact ? 10 : 14,
            right: compact ? 10 : 14,
            bottom: compact ? 10 : 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pink accent badge (design token: accent).
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 6 : 8),
                        decoration: BoxDecoration(color: theme.secondary, borderRadius: BorderRadius.circular(TGRadius.pill)),
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleSmall.override(color: Colors.white, fontSize: compact ? 13 : 16, fontWeight: FontWeight.w800, lineHeight: 1.15),
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          count == 1 ? '1 listing' : '$count listings',
                          style: theme.bodySmall.override(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: compact ? 32 : 38,
                  height: compact ? 32 : 38,
                  decoration: BoxDecoration(color: theme.primary, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_forward_rounded, size: compact ? 18 : 20, color: TGColors.onCta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Promoted / featured listings (private-seller first catalogue strip)
// ---------------------------------------------------------------------------

/// Homepage featured products:
/// - desktop: 5 cards wide
/// - ≤5: static row · 6–10: two rows · >10: auto-scroll (2s) + manual
class HomePromotedSection extends StatefulWidget {
  const HomePromotedSection({super.key, required this.products});

  final List<TGProduct> products;

  @override
  State<HomePromotedSection> createState() => _HomePromotedSectionState();
}

class _HomePromotedSectionState extends State<HomePromotedSection> {
  static const int _desktopVisible = 5;
  static const Duration _autoEvery = Duration(seconds: 2);

  final ScrollController _scroll = ScrollController();
  Timer? _timer;
  bool _paused = false;
  bool _timerArmed = false;
  double _cardStep = 0;

  @override
  void didUpdateWidget(covariant HomePromotedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products.length != widget.products.length) {
      _timerArmed = false;
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _armTimer(bool reduce) {
    if (_timerArmed) return;
    _timerArmed = true;
    _timer?.cancel();
    if (reduce || widget.products.length <= 10) {
      _timer = null;
      return;
    }
    _timer = Timer.periodic(_autoEvery, (_) => _advance());
  }

  void _advance() {
    if (_paused || !mounted || !_scroll.hasClients || _cardStep <= 0) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    var next = _scroll.offset + _cardStep;
    if (next > max + 1) next = 0;
    _scroll.animateTo(next.clamp(0.0, max), duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  void _nudge(double dir) {
    if (!_scroll.hasClients || _cardStep <= 0) return;
    final max = _scroll.position.maxScrollExtent;
    final next = (_scroll.offset + dir * _cardStep).clamp(0.0, max);
    _scroll.animateTo(next, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    if (products.isEmpty) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: context.t('ui_promoted_listings'),
          subtitle: context.t('ui_promoted_listings_sub'),
          action: TextButton(
            onPressed: () => TGNav.products(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.t('ui_view_all'), style: theme.bodyMedium.override(color: theme.primary, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 18, color: theme.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, c) {
            final scaler = MediaQuery.textScalerOf(context);
            final phone = c.maxWidth < TGBreakpoints.phone;
            if (phone) {
              const cardW = 292.0;
              return SizedBox(
                height: TGProductCard.gridExtent(cardW, scaler) + 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.hardEdge,
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) => SizedBox(width: cardW, child: TGProductCard(product: products[i])),
                ),
              );
            }

            final n = products.length;
            // 6–10 → two static rows of up to 5.
            if (n <= 10) {
              final row1 = products.take(_desktopVisible).toList();
              final row2 = n > _desktopVisible ? products.skip(_desktopVisible).take(_desktopVisible).toList() : const <TGProduct>[];
              final cardW = (c.maxWidth - kTGGridGutter * (_desktopVisible - 1)) / _desktopVisible;
              final h = TGProductCard.gridExtent(cardW, scaler);
              Widget row(List<TGProduct> items) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: kTGGridGutter),
                        SizedBox(width: cardW, height: h, child: TGProductCard(product: items[i])),
                      ],
                    ],
                  );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row(row1),
                  if (row2.isNotEmpty) ...[const SizedBox(height: kTGGridGutter), row(row2)],
                ],
              );
            }

            // >10 → horizontal carousel, 5 visible, auto 2s + manual.
            final cardW = (c.maxWidth - kTGGridGutter * (_desktopVisible - 1)) / _desktopVisible;
            _cardStep = cardW + kTGGridGutter;
            final h = TGProductCard.gridExtent(cardW, scaler);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _armTimer(reduce);
            });
            return MouseRegion(
              onEnter: (_) => _paused = true,
              onExit: (_) => _paused = false,
              child: Stack(
                children: [
                  SizedBox(
                    height: h + 16,
                    child: ListView.separated(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(width: kTGGridGutter),
                      itemBuilder: (_, i) => SizedBox(width: cardW, height: h, child: TGProductCard(product: products[i])),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 12,
                    child: Center(
                      child: _ArrowButton(
                        icon: Icons.chevron_left_rounded,
                        label: 'Previous',
                        onTap: () => _nudge(-1),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 12,
                    child: Center(
                      child: _ArrowButton(
                        icon: Icons.chevron_right_rounded,
                        label: 'Next',
                        onTap: () => _nudge(1),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Best sellers
// ---------------------------------------------------------------------------

class _BestSeller {
  const _BestSeller(this.name, this.logo, this.rating, this.products, this.path);

  final String name;
  final String logo;
  final double rating;
  final int products;
  final String path;
}

const List<_BestSeller> _bestSellers = [
  _BestSeller('Technica', 'assets/images/TECHNICA.png', 4.0, 3, '/seller/2931-technica'),
  _BestSeller('Gastrosilesia.pl', 'assets/images/Gastrosilesia-pl.png', 4.5, 8, '/seller/1847-gastrosilesia'),
  _BestSeller('EK', 'assets/images/Untitled-2_Topaz_Gigapixel_2x_scale.png', 3.5, 5, '/seller/4102-ek'),
  _BestSeller('RM', 'assets/images/RM.png', 4.5, 2, '/seller/5518-rm'),
  _BestSeller('PrimeGastro', 'assets/images/PRIMEGASTRO.png', 3.5, 2, '/seller/1048-primegastro'),
];

/// Horizontally scrolling verified-seller cards.
class HomeBestSellers extends StatefulWidget {
  const HomeBestSellers({super.key});

  @override
  State<HomeBestSellers> createState() => _HomeBestSellersState();
}

class _HomeBestSellersState extends State<HomeBestSellers> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final l10n = FFLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;

    Widget arrow(IconData icon, String label, double delta) => Semantics(
          button: true,
          label: label,
          child: IconButton.outlined(
            onPressed: () => _scrollBy(delta),
            icon: Icon(icon, color: theme.primaryText),
            style: IconButton.styleFrom(side: BorderSide(color: theme.tertiary)),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: l10n.getText('88t2wvuj'),
          subtitle: l10n.getText('21twf2jq').replaceAll(RegExp(r'\s+'), ' '),
          action: wide
              ? Row(mainAxisSize: MainAxisSize.min, children: [arrow(Icons.chevron_left_rounded, 'Scroll left', -520), const SizedBox(width: 8), arrow(Icons.chevron_right_rounded, 'Scroll right', 520)])
              : null,
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 330,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: _bestSellers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (context, i) => SizedBox(width: 232, child: _SellerCard(seller: _bestSellers[i])),
          ),
        ),
      ],
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.seller});
  final _BestSeller seller;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final l10n = FFLocalizations.of(context);
    return TGHoverCard(
      semanticLabel: '${seller.name}, verified seller, ${seller.products} products',
      onTap: () => context.push(seller.path),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Verified badge (design token: verified green).
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(TGRadius.input),
                  border: Border.all(color: theme.success.withValues(alpha: 0.55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user, size: 16, color: theme.success),
                    const SizedBox(width: 6),
                    Text(l10n.getText('iudua9mi'), style: theme.labelSmall.override(color: theme.primaryText, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Logos are designed for light backgrounds.
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(TGRadius.input)),
                padding: const EdgeInsets.all(10),
                child: Image.asset(seller.logo, fit: BoxFit.contain, cacheWidth: 400, errorBuilder: (_, __, ___) => Icon(Icons.storefront, color: theme.secondaryText, size: 40)),
              ),
            ),
            const SizedBox(height: 12),
            TGRatingStars(rating: seller.rating, size: 20),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(l10n.getText('g89e8jcq'), style: theme.bodyMedium.override(color: theme.secondaryText, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('${seller.products}', style: theme.bodyLarge.override(fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

class _StatData {
  const _StatData(this.image, this.titleKey, this.value);

  final String image;
  final String titleKey;
  final int value;
}

const List<_StatData> _stats = [
  _StatData('assets/images/24_saat.png', 'dkz7hccx', 76),
  _StatData('assets/images/Bussiness.png', 'p15aunky', 465),
  _StatData('assets/images/Product_list.png', 'b81eez74', 1426),
  _StatData('assets/images/24_saat.png', 'eio1zib0', 181),
];

class HomeStatsSection extends StatelessWidget {
  const HomeStatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = FFLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 4 : 2;
        final desktop = c.maxWidth >= 900;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: desktop ? 214 : 196,
          ),
          itemCount: _stats.length,
          itemBuilder: (context, i) => HomeStatCard(
            imageAsset: _stats[i].image,
            title: l10n.getText(_stats[i].titleKey).replaceAll(RegExp(r'\s+'), ' ').trim(),
            targetValue: _stats[i].value,
            large: desktop,
          ),
        );
      },
    );
  }
}

class HomeStatCard extends StatelessWidget {
  const HomeStatCard({super.key, required this.imageAsset, required this.title, required this.targetValue, this.large = true});

  final String imageAsset;
  final String title;
  final int targetValue;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final avatar = large ? 84.0 : 64.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: theme.tertiary),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(
            child: Image.asset(imageAsset, width: avatar, height: avatar, fit: BoxFit.cover, cacheWidth: 260, errorBuilder: (_, __, ___) => SizedBox(width: avatar, height: avatar)),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.titleMedium.override(fontSize: large ? 16 : 14, fontWeight: FontWeight.w800, lineHeight: 1.15),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedCountUpText(
              target: targetValue,
              duration: const Duration(milliseconds: 1100),
              textStyle: theme.bodyMedium.override(color: theme.primary, fontSize: large ? 22 : 18, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

/// Counts up from 0 to [target] when first shown.
class AnimatedCountUpText extends StatelessWidget {
  const AnimatedCountUpText({super.key, required this.target, required this.duration, required this.textStyle});

  final int target;
  final Duration duration;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduce ? target.toDouble() : 0, end: target.toDouble()),
      duration: reduce ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Text(value.round().toString(), style: textStyle),
    );
  }
}
