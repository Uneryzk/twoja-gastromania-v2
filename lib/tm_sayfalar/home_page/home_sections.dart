import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/products/products_results.dart' show gridColumnsFor, kTGGridGutter;
import 'package:twoja_gastromania/tg_components/tg_hover_card.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_components/tg_rating_stars.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

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
// Hero carousel (the four ad pages)
// ---------------------------------------------------------------------------

class _HeroSlide {
  const _HeroSlide({required this.image, required this.titleKey, required this.subtitleKey, required this.routeName});

  final String image;
  final String titleKey;
  final String subtitleKey;
  final String routeName;
}

/// Auto-playing carousel; every slide opens one of the ad pages.
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

  late final List<_HeroSlide> _slides = [
    _HeroSlide(image: 'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg', titleKey: 'i8m5wr2h', subtitleKey: '7d6qkq0f', routeName: widget.slideRouteNames[0]),
    _HeroSlide(image: 'assets/images/blog-26.jpg', titleKey: '0y0mdwe3', subtitleKey: 'gn0cgz8h', routeName: widget.slideRouteNames[1]),
    _HeroSlide(image: 'assets/images/17594161762353ebc282350944289b81f72b29ad94_square_thumbnail_405x552.jpg', titleKey: 'z2t2enej', subtitleKey: 'yhrj1i0w', routeName: widget.slideRouteNames[2]),
    _HeroSlide(image: 'assets/images/IMG_3696-scaled.webp', titleKey: 'fd2vmdbm', subtitleKey: 'ghe86x4x', routeName: widget.slideRouteNames[3]),
  ];

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
    _goTo((_index + 1) % _slides.length);
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
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final l10n = FFLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, c) {
        final phone = c.maxWidth < TGBreakpoints.phone;
        final height = (c.maxWidth * (phone ? 0.78 : 0.36)).clamp(280.0, 440.0);
        return MouseRegion(
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
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final s = _slides[i];
                      final title = l10n.getText(s.titleKey);
                      return Semantics(
                        button: true,
                        label: title,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => context.pushNamed(s.routeName),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(s.image, fit: BoxFit.cover, cacheWidth: 1400, gaplessPlayback: true, errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate)),
                                // Scrim keeps the white copy readable on any photo.
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
                                        const SizedBox(height: 8),
                                        Text(
                                          l10n.getText(s.subtitleKey),
                                          maxLines: phone ? 2 : 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.bodyLarge.override(
                                            color: Colors.white.withValues(alpha: 0.88),
                                            fontSize: phone ? 13.5 : 17,
                                            lineHeight: 1.4,
                                          ),
                                        ),
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
                                              Text('Read more', style: theme.bodySmall.override(color: TGColors.onCta, fontWeight: FontWeight.w900)),
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
                      );
                    },
                  ),
                  if (!phone) ...[
                    Positioned(left: 12, top: 0, bottom: 0, child: Center(child: _ArrowButton(icon: Icons.chevron_left_rounded, label: 'Previous slide', onTap: () => _goTo((_index - 1 + _slides.length) % _slides.length)))),
                    Positioned(right: 12, top: 0, bottom: 0, child: Center(child: _ArrowButton(icon: Icons.chevron_right_rounded, label: 'Next slide', onTap: () => _goTo((_index + 1) % _slides.length)))),
                  ],
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _slides.length; i++)
                          Semantics(
                            button: true,
                            selected: i == _index,
                            label: 'Slide ${i + 1}',
                            child: GestureDetector(
                              onTap: () => _goTo(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
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
  const _CategoryData(this.category, this.image, this.titleKey);

  final TGCategory category;
  final String image;
  final String titleKey;
}

const List<_CategoryData> _categories = [
  _CategoryData(TGCategory.cookingEquipment, 'assets/images/pol_pm_Wanna-bemarowa-3X-GN-1-1-Komat-KCB-001-031-2808_2.png', 'ji98dehm'),
  _CategoryData(TGCategory.refrigerationEquipment, 'assets/images/IMG_20200120_131650.jpg', 'swrjjpbp'),
  _CategoryData(TGCategory.warewashing, 'assets/images/oztiryakiler-sanayi-tipi-bulasik-yikama-makinesitouch-ekran-oby-50t-tahliye-pompali-tezgah-alti-bulasik-makineleri-oztiryakiler-52978-19-B.webp', 'lcx4dovc'),
  _CategoryData(TGCategory.foodPreparation, 'assets/images/Food_Prepering_table.jpg', '71nup2wm'),
  _CategoryData(TGCategory.stainlessSteelFurniture, 'assets/images/stainless_steel_table_Food_Preparation_table_gastronomi.jpg', '56pbhr1s'),
  _CategoryData(TGCategory.barAndBeverageEquipment, 'assets/images/Bar_&_Beverage_Equipment.jpg', 'viy2skiv'),
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
        HomeSectionTitle(title: l10n.getText('5w70mdov'), subtitle: l10n.getText('3u75e0ef')),
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
          Image.asset(data.image, fit: BoxFit.cover, cacheWidth: 800, errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate)),
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
// Promoted listings
// ---------------------------------------------------------------------------

/// A row of the currently promoted listings (real catalogue data).
class HomePromotedSection extends StatelessWidget {
  const HomePromotedSection({super.key, required this.products});

  final List<TGProduct> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: context.t('ui_promoted_listings'),
          subtitle: context.t('ui_promoted_listings_sub'),
          action: TextButton.icon(
            onPressed: () => TGNav.products(context),
            icon: Icon(Icons.arrow_forward_rounded, size: 18, color: theme.primary),
            label: Text(context.t('ui_view_all'), style: theme.bodyMedium.override(color: theme.primary, fontWeight: FontWeight.w800)),
            iconAlignment: IconAlignment.end,
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, c) {
            final scaler = MediaQuery.textScalerOf(context);
            final cols = gridColumnsFor(c.maxWidth);
            if (c.maxWidth < TGBreakpoints.phone) {
              const cardW = 292.0;
              return SizedBox(
                height: TGProductCard.gridExtent(cardW, scaler) + 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) => SizedBox(width: cardW, child: TGProductCard(product: products[i])),
                ),
              );
            }
            final cardW = (c.maxWidth - kTGGridGutter * (cols - 1)) / cols;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              clipBehavior: Clip.none,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: kTGGridGutter,
                mainAxisSpacing: kTGGridGutter,
                mainAxisExtent: TGProductCard.gridExtent(cardW, scaler),
              ),
              itemCount: products.length,
              itemBuilder: (_, i) => TGProductCard(product: products[i]),
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
  _StatData('assets/images/Ekran_Resmi_2026-09-03_OS_12.31.31.png', 'dkz7hccx', 76),
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
