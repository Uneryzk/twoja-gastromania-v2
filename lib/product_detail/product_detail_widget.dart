import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/dashboard/renew_sheet.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/product_detail/pdp_gallery.dart';
import 'package:twoja_gastromania/product_detail/pdp_message_sheet.dart';
import 'package:twoja_gastromania/product_detail/pdp_translate.dart';
import 'package:twoja_gastromania/product_detail/report_listing_sheet.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/products/products_logic.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_badges.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_components/tg_rating_stars.dart';
import 'package:twoja_gastromania/tg_components/tg_special_order_band.dart';
import 'package:twoja_gastromania/tg_components/tg_listing_no_line.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_contact.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_robots.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/admin/pdp_moderator_bar.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductDetailPageWidget extends StatefulWidget {
  const ProductDetailPageWidget({super.key, required this.productId});

  static const routeName = 'ProductDetail';
  static const routePath = '/product-detail/:id';

  final String productId;

  @override
  State<ProductDetailPageWidget> createState() => _ProductDetailPageWidgetState();
}

class _ProductDetailPageWidgetState extends State<ProductDetailPageWidget> {
  late Future<({TGProduct? product, List<TGProduct> all})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ProductDetailPageWidget old) {
    super.didUpdateWidget(old);
    if (old.productId != widget.productId) {
      _future = _load();
    }
  }

  Future<({TGProduct? product, List<TGProduct> all})> _load() async {
    final owned = context.read<FakeAuthState>().ownedListings;
    final seed = await TGProductService.instance.getAll();
    ModerationService.instance.ensureSeeded();
    final extras = TGSellerProfileService.instance.extraListings;
    final all = mergeOwnedListings([...seed, ...extras, ...ModerationService.instance.sellerListings], owned);
    TGProduct? match;
    final no = TGListingNo.parseFromPath(widget.productId) ?? (TGListingNo.isListingNo(widget.productId) ? widget.productId : null);
    for (final p in all) {
      if (no != null && p.listingNo == no) {
        match = p;
        break;
      }
      if (p.id == widget.productId) {
        match = p;
        break;
      }
    }
    match ??= TGSellerProfileService.instance.listingById(widget.productId);
    return (product: match, all: all);
  }

  @override
  Widget build(BuildContext context) {
    return TGPageScaffold(
      body: FutureBuilder<({TGProduct? product, List<TGProduct> all})>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _PdpSkeleton();
          }
          final data = snapshot.data;
          final product = data?.product;
          if (product == null) return const _NotFound();
          return _PdpBody(product: product, catalogue: data!.all);
        },
      ),
    );
  }
}

class _PdpBody extends StatefulWidget {
  const _PdpBody({required this.product, required this.catalogue});
  final TGProduct product;
  final List<TGProduct> catalogue;

  @override
  State<_PdpBody> createState() => _PdpBodyState();
}

class _PdpBodyState extends State<_PdpBody> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  int _index = 0;
  bool _favorite = false;
  bool _lightbox = false;
  bool _descOpen = false;
  bool _specsOpen = false;
  bool _safetyOpen = false;
  bool _copied = false;
  Timer? _copiedReset;
  late final AnimationController _favPop = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

  TGProduct get product => widget.product;
  List<String> get images {
    final g = product.gallery;
    return g.isEmpty ? const [''] : g;
  }

  @override
  void dispose() {
    _copiedReset?.cancel();
    _scroll.dispose();
    _favPop.dispose();
    super.dispose();
  }

  bool get _desktop => MediaQuery.sizeOf(context).width >= TGBreakpoints.desktop;
  bool get _keyboardOpen => MediaQuery.viewInsetsOf(context).bottom > 80;

  Future<void> _toggleFavorite() async {
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn) {
      await _askLogin(context.t('ui_login_required'));
      return;
    }
    setState(() => _favorite = !_favorite);
    TGAnalytics.track('favorite_toggle', {...TGAnalytics.listingProps(product), 'on': _favorite});
    if (tgReduceMotion(context)) {
      _favPop.value = _favorite ? 1 : 0;
    } else if (_favorite) {
      _favPop.forward(from: 0);
    } else {
      _favPop.reverse();
    }
    if (_favorite) showTGToast(context, context.t('ui_saved'), icon: Icons.favorite, iconColor: TGColors.accent);
  }

  Future<void> _askLogin(String message) async {
    final theme = FlutterFlowTheme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.secondaryBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ctx.t('ui_login_required'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TGButton(
              onPressed: () {
                Navigator.pop(ctx);
                ctx.goNamed(LoginPageWidget.routeName);
              },
              label: ctx.t('ui_login'),
              height: 44,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLightbox() async {
    setState(() => _lightbox = true);
    await openPdpLightbox(context: context, images: images, index: _index);
    if (mounted) setState(() => _lightbox = false);
  }

  Future<void> _call() async {
    if (!product.allowsPublicContact) return;
    TGAnalytics.track('call_click', TGAnalytics.listingProps(product));
    await copyPhoneNumber(context, product.phone);
    setState(() => _copied = true);
    final dial = product.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (dial.isNotEmpty) {
      await launchUrl(Uri(scheme: 'tel', path: dial));
    }
    _copiedReset?.cancel();
    _copiedReset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _message() {
    if (!product.allowsPublicContact) return;
    showPdpMessageSheet(context, product);
  }

  void _comingSoon() => showTGToast(context, context.t('ui_coming_soon'), icon: Icons.schedule_rounded);

  void _renew() {
    TGAnalytics.track('renew_click', TGAnalytics.listingProps(product));
    showRenewSheet(context, product, early: product.isExpiringSoon && product.status != TGListingStatus.expired);
  }

  void _reportListing() {
    showReportListingFlow(context, product);
  }

  int _daysLeft() => product.daysUntilExpiry().clamp(0, TGPricing.listingPeriodDays);

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.sizeOf(context).width < TGBreakpoints.phone ? 16.0 : 24.0;
    final auth = context.watch<FakeAuthState>();
    final owner = auth.ownsListing(product);
    final canReport = !owner && product.canBeReported;
    final showBar = !_desktop && !_lightbox && !_keyboardOpen && !owner && product.allowsPublicContact;
    final similar = widget.catalogue.where((p) => p.id != product.id && p.category == product.category && p.isPubliclyVisible).take(8).toList();
    final noIndex = product.status == TGListingStatus.removed || product.status == TGListingStatus.underReview || product.isHidden || !product.isPubliclyVisible;
    setListingRobotsNoIndex(noIndex);
    final more = widget.catalogue.where((p) => p.id != product.id && p.seller.id == product.seller.id && p.isPubliclyVisible).take(8).toList();
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    final gallery = PdpGallery(
      product: product,
      images: images,
      index: _index,
      onIndex: (i) => setState(() => _index = i),
      favorite: _favorite,
      onFavorite: _toggleFavorite,
      onLightbox: (i) {
        setState(() => _index = i);
        _openLightbox();
      },
      showThumbnails: _desktop,
      enableLens: _desktop,
      onReport: canReport ? _reportListing : null,
    );

    final info = _InfoColumn(
      product: product,
      showPhone: product.allowsPublicContact || owner,
      showReport: canReport && !_desktop,
      canReport: canReport,
      descOpen: _descOpen,
      specsOpen: _specsOpen,
      safetyOpen: _safetyOpen,
      onToggleDesc: () => setState(() => _descOpen = !_descOpen),
      onToggleSpecs: () => setState(() => _specsOpen = !_specsOpen),
      onToggleSafety: () => setState(() => _safetyOpen = !_safetyOpen),
      onReport: _reportListing,
    );

    return Column(
      children: [
        PdpModeratorBar(product: product),
        Expanded(
          child: Stack(
      children: [
        CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TGBreadcrumb(
                          items: [
                            TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                            TGBreadcrumbItem(label: context.t('ui_products'), onTap: () => TGNav.products(context)),
                            TGBreadcrumbItem(label: categoryLabel(product.category, t: (k) => context.t(k)), onTap: () => TGNav.category(context, product.category)),
                          ],
                        ),
                        if (owner && product.status == TGListingStatus.underReview) ...[
                          const SizedBox(height: 12),
                          _AttentionBanner(),
                        ] else if (product.status == TGListingStatus.removed) ...[
                          const SizedBox(height: 12),
                          _ModerationBanner(key: const Key('pdp-noindex'), text: context.t('ui_listing_removed')),
                        ] else if (product.status == TGListingStatus.underReview || product.isHidden) ...[
                          const SizedBox(height: 12),
                          _ModerationBanner(key: const Key('pdp-noindex'), text: context.t('ui_listing_unavailable')),
                        ] else if (!product.isPubliclyVisible) ...[
                          const SizedBox(height: 12),
                          _InactiveBanner(
                            key: const Key('pdp-noindex'),
                            onRenew: owner && product.status == TGListingStatus.expired ? _renew : null,
                          ),
                        ],
                        const SizedBox(height: 14),
                        if (_desktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    gallery,
                                    const SizedBox(height: 20),
                                    info,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 28),
                              SizedBox(
                                width: 340,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _scroll,
                                      builder: (context, _) {
                                        final shadow = _scroll.hasClients && _scroll.offset > 8;
                                        return _StickyPanel(
                                          elevated: shadow,
                                          child: owner
                                              ? _OwnerBar(product: product, daysLeft: _daysLeft(), onAction: _comingSoon, onRenew: _renew)
                                              : product.allowsPublicContact
                                                  ? _ContactPanel(
                                                      product: product,
                                                      copied: _copied,
                                                      onCall: _call,
                                                      onMessage: _message,
                                                      onReport: canReport ? _reportListing : null,
                                                    )
                                                  : const SizedBox.shrink(),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          // Full-bleed gallery: cancel horizontal page padding.
                          Transform.translate(
                            offset: Offset(-pad, 0),
                            child: SizedBox(width: MediaQuery.sizeOf(context).width, child: gallery),
                          ),
                          const SizedBox(height: 16),
                          info,
                          if (owner) ...[
                            const SizedBox(height: 16),
                            _OwnerBar(product: product, daysLeft: _daysLeft(), onAction: _comingSoon, onRenew: _renew),
                          ],
                        ],
                        if (similar.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _CardRail(title: context.t('ui_similar_listings'), products: similar),
                        ],
                        if (more.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _CardRail(title: context.t('ui_more_from_seller'), products: more),
                        ],
                        const SizedBox(height: 28),
                        const TGSpecialOrderBand(),
                        if (canReport && !_desktop) ...[
                          const SizedBox(height: 12),
                          _ReportListingButton(buttonKey: const Key('pdp-report-footer'), onPressed: _reportListing),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: showBar ? 88 + safeBottom : 48)),
            const SliverToBoxAdapter(child: TGFooter()),
          ],
        ),
        if (showBar)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StickyCallBar(
              product: product,
              copied: _copied,
              onCall: _call,
              onMessage: _message,
            ),
          ),
      ],
          ),
        ),
      ],
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.product,
    required this.showPhone,
    required this.showReport,
    required this.canReport,
    required this.descOpen,
    required this.specsOpen,
    required this.safetyOpen,
    required this.onToggleDesc,
    required this.onToggleSpecs,
    required this.onToggleSafety,
    required this.onReport,
  });

  final TGProduct product;
  final bool showPhone;
  final bool showReport;
  final bool canReport;
  final bool descOpen;
  final bool specsOpen;
  final bool safetyOpen;
  final VoidCallback onToggleDesc;
  final VoidCallback onToggleSpecs;
  final VoidCallback onToggleSafety;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (product.isPromoted) const TGPromotedBadge(),
            if (product.seller.verified) const TGVerifiedSellerBadge(),
            if (product.negotiable)
              const _MiniChip(label: 'do negocjacji'),
            if (product.listingType == TGListingType.rent)
              _MiniChip(label: context.t('ui_rent')),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          product.title,
          style: theme.headlineSmall.override(fontSize: 22, lineHeight: 28 / 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        TGListingNoLine(product: product),
        const SizedBox(height: 12),
        _PriceBlock(product: product),
        const SizedBox(height: 16),
        _SellerStrip(product: product),
        if (showPhone) ...[
          const SizedBox(height: 10),
          _PhoneAlways(phone: product.phone),
        ],
        if (showReport) _ReportListingButton(onPressed: onReport),
        const SizedBox(height: 18),
        _FeaturedSpecs(product: product),
        const SizedBox(height: 20),
        PdpTranslateBlock(
          title: product.title,
          description: product.description ?? '',
          bodyStyle: theme.bodyMedium.override(color: theme.secondaryText, lineHeight: 1.6),
          descOpen: descOpen,
          onToggleDesc: onToggleDesc,
        ),
        const SizedBox(height: 8),
        _SpecTable(product: product, expanded: specsOpen, onToggle: onToggleSpecs),
        const SizedBox(height: 16),
        _LocationDelivery(product: product),
        const SizedBox(height: 12),
        _Accordion(
          title: context.t('ui_safety_tips'),
          open: safetyOpen,
          onToggle: onToggleSafety,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final k in const ['ui_safety_1', 'ui_safety_2', 'ui_safety_3'])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(context.t(k), style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.45))),
                    ],
                  ),
                ),
              if (canReport && safetyOpen) _ReportListingButton(buttonKey: const Key('pdp-report-safety'), onPressed: onReport),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.alternate,
        borderRadius: BorderRadius.circular(TGRadius.pill),
        border: Border.all(color: theme.tertiary),
      ),
      child: Text(label, style: theme.labelSmall.override(fontWeight: FontWeight.w800)),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final hasPrice = product.price != null;
    final rent = hasPrice && product.listingType == TGListingType.rent;
    final main = !hasPrice
        ? context.t('ui_ask_price')
        : '${formatPln(product.price!)}${rent ? ' / mies.' : ''}';

    String? other;
    if (hasPrice) {
      if (product.priceBasis == TGPriceBasis.netto) {
        other = '${formatPln((product.price! * (1 + TGPricing.vatRate)).round())} ${context.t('ui_brutto').toLowerCase()}';
      } else {
        other = '${formatPln(TGPricing.netFromGross(product.price!).round())} ${context.t('ui_netto').toLowerCase()}';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(main, style: theme.headlineMedium.override(fontSize: 28, fontWeight: FontWeight.w800, color: hasPrice ? theme.primaryText : theme.secondaryText)),
            if (hasPrice)
              Tooltip(
                message: product.priceBasis == TGPriceBasis.netto ? context.t('ui_netto_tooltip') : context.t('ui_brutto_tooltip'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.alternate,
                    borderRadius: BorderRadius.circular(TGRadius.pill),
                    border: Border.all(color: theme.tertiary),
                  ),
                  child: Text(product.priceBasis == TGPriceBasis.netto ? 'NETTO' : 'BRUTTO', style: theme.labelSmall.override(fontWeight: FontWeight.w800, color: theme.secondaryText)),
                ),
              ),
          ],
        ),
        if (other != null) ...[
          const SizedBox(height: 4),
          Text(other, style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

class _SellerStrip extends StatelessWidget {
  const _SellerStrip({required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final s = product.seller;
    return InkWell(
      onTap: () => context.push(TGSellerProfileService.instance.pathForSellerId(s.id)),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.alternate,
              child: Text(s.name.isEmpty ? '?' : s.name[0], style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.type == TGSellerType.private ? context.t('ui_private') : s.name, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (s.verified) const TGVerifiedSellerBadge(),
                      TGRatingStars(rating: s.rating, size: 14),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(context.t('ui_visit_store'), style: theme.labelSmall.override(color: theme.primary, fontWeight: FontWeight.w800)),
                Icon(Icons.chevron_right, color: theme.secondaryText),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneAlways extends StatelessWidget {
  const _PhoneAlways({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      onTap: () => copyPhoneNumber(context, phone),
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Icon(Icons.phone, color: theme.primary, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(phone, style: theme.titleSmall.override(fontWeight: FontWeight.w800, color: theme.primary))),
          ],
        ),
      ),
    );
  }
}

class _FeaturedSpecs extends StatelessWidget {
  const _FeaturedSpecs({required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      (Icons.bolt_outlined, switch (product.powerType) { TGPowerType.electric => context.t('ui_electric'), TGPowerType.gas => context.t('ui_gas'), TGPowerType.other => context.t('ui_other') }),
      (Icons.verified_outlined, product.warrantyMonths == 0 ? context.t('ui_warranty_none') : '${product.warrantyMonths} mies.'),
      (Icons.storefront_outlined, product.pickup ? context.t('ui_pickup') : '—'),
      (Icons.local_shipping_outlined, product.delivery ? context.t('ui_delivery') : '—'),
    ];
    Widget cell((IconData, String) e) {
      final theme = FlutterFlowTheme.of(context);
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: theme.alternate,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.tertiary),
        ),
        child: Row(
          children: [
            Icon(e.$1, size: 18, color: theme.secondaryText),
            const SizedBox(width: 8),
            Expanded(child: Text(e.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(fontWeight: FontWeight.w800))),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(children: [Expanded(child: cell(items[0])), const SizedBox(width: 8), Expanded(child: cell(items[1]))]),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: cell(items[2])), const SizedBox(width: 8), Expanded(child: cell(items[3]))]),
      ],
    );
  }
}

class _SpecTable extends StatelessWidget {
  const _SpecTable({required this.product, required this.expanded, required this.onToggle});
  final TGProduct product;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final rows = <(String, String)>[
      (context.t('ui_categories'), categoryLabel(product.category, t: (k) => context.t(k))),
      (context.t('ui_condition'), product.condition == TGCondition.newItem ? context.t('ui_condition_new') : context.t('ui_condition_used')),
      (context.t('ui_listing_type'), product.listingType == TGListingType.rent ? context.t('ui_rent') : context.t('ui_buy')),
      (context.t('ui_power_type'), switch (product.powerType) { TGPowerType.electric => context.t('ui_electric'), TGPowerType.gas => context.t('ui_gas'), TGPowerType.other => context.t('ui_other') }),
      (context.t('ui_warranty_months'), product.warrantyMonths == 0 ? context.t('ui_warranty_none') : '${product.warrantyMonths}'),
      (context.t('ui_delivery'), product.delivery ? context.t('ui_available') : context.t('ui_no')),
      (context.t('ui_pickup'), product.pickup ? context.t('ui_available') : context.t('ui_no')),
      (context.t('ui_location'), '${product.city}, ${product.voivodeship}'),
      (context.t('ui_store'), product.seller.name),
      (context.t('ui_listed_on'), DateFormat('d MMM y').format(product.createdAt)),
      for (final e in product.extra.entries) (e.key, e.value),
    ];
    final visible = expanded ? rows : rows.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('ui_specifications'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: tgAnim(context, const Duration(milliseconds: 200)),
          alignment: Alignment.topCenter,
          child: Table(
            columnWidths: const {0: FlexColumnWidth(4), 1: FlexColumnWidth(6)},
            children: [
              for (var i = 0; i < visible.length; i++)
                TableRow(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.tertiary.withValues(alpha: 0.7)))),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Semantics(
                        header: true,
                        child: Text(visible[i].$1, style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(visible[i].$2, style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onToggle,
            child: Text(expanded ? context.t('ui_show_less') : context.t('ui_show_all_specs')),
          ),
        ),
      ],
    );
  }
}

class _LocationDelivery extends StatelessWidget {
  const _LocationDelivery({required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: theme.tertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_location_delivery'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('${product.city}, ${product.voivodeship}', style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('${context.t('ui_delivery')}: ${product.delivery ? context.t('ui_available') : context.t('ui_no')}'),
          Text('${context.t('ui_pickup')}: ${product.pickup ? context.t('ui_available') : context.t('ui_no')}'),
          if (product.delivery) ...[
            const SizedBox(height: 10),
            Text(context.t('ui_shipping_not_included'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800, color: theme.primary)),
            const SizedBox(height: 4),
            Text(context.t('ui_shipping_arranged'), style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.45)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('pdp-ask-shipping'),
                onPressed: () => showPdpMessageSheet(context, product, initialText: context.t('ui_quick_shipping')),
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: Text(context.t('ui_quick_shipping')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Accordion extends StatelessWidget {
  const _Accordion({required this.title, required this.open, required this.onToggle, required this.child});
  final String title;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Expanded(child: Text(title, style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
                Icon(open ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
          crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: tgAnim(context, const Duration(milliseconds: 200)),
        ),
      ],
    );
  }
}

class _CardRail extends StatelessWidget {
  const _CardRail({required this.title, required this.products});
  final String title;
  final List<TGProduct> products;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    const cardW = 300.0;
    final h = TGProductCard.listExtent(cardW);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        SizedBox(
          height: h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: cardW,
              child: TGProductCard(product: products[i], layout: TGProductCardLayout.list),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportListingButton extends StatelessWidget {
  const _ReportListingButton({this.buttonKey, required this.onPressed});
  final Key? buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: buttonKey ?? const Key('pdp-report-listing'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.flag_outlined, size: 16),
        label: Text(context.t('ui_report_listing')),
      ),
    );
  }
}

class _StickyPanel extends StatelessWidget {
  const _StickyPanel({required this.child, required this.elevated});
  final Widget child;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: tgAnim(context, const Duration(milliseconds: 180)),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: FlutterFlowTheme.of(context).tertiary),
        boxShadow: elevated
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))]
            : const [],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _ContactPanel extends StatelessWidget {
  const _ContactPanel({required this.product, required this.copied, required this.onCall, required this.onMessage, this.onReport});
  final TGProduct product;
  final bool copied;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SellerStrip(product: product),
        if (product.isPubliclyVisible) ...[
          const SizedBox(height: 10),
          _PhoneAlways(phone: product.phone),
        ],
        const SizedBox(height: 14),
        _CallButton(product: product, copied: copied, onPressed: product.isPubliclyVisible ? onCall : null),
        const SizedBox(height: 10),
        TGButton(
          onPressed: product.isPubliclyVisible ? onMessage : null,
          label: context.t('ui_message'),
          variant: TGButtonVariant.outline,
          height: 48,
          borderRadius: BorderRadius.circular(TGRadius.pill),
        ),
        if (onReport != null) ...[
          const SizedBox(height: 8),
          _ReportListingButton(onPressed: onReport!),
        ],
      ],
    );
  }
}

class _OwnerBar extends StatelessWidget {
  const _OwnerBar({required this.product, required this.daysLeft, required this.onAction, required this.onRenew});
  final TGProduct product;
  final int daysLeft;
  final VoidCallback onAction;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final expired = product.status == TGListingStatus.expired;
    final expiring = product.isExpiringSoon;
    final progress = expired ? 0.0 : (daysLeft / TGPricing.listingPeriodDays).clamp(0.0, 1.0);
    final border = expired || expiring ? TGColors.rating : theme.primary.withValues(alpha: 0.5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_your_listing'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            expired
                ? context.t('ui_expired_ago', {'n': '${product.daysSinceExpiry().clamp(0, 999)}'})
                : context.t('ui_days_left_n', {'n': '$daysLeft'}),
            style: theme.bodySmall.override(color: expired || expiring ? TGColors.rating : theme.secondaryText),
          ),
          if (!expired) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.tertiary,
                valueColor: AlwaysStoppedAnimation(expiring ? TGColors.rating : theme.primary),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (expired)
            TGButton(
              onPressed: onRenew,
              label: context.t('ui_renew_pln', {'fee': '${TGPricing.listingFeePln}'}),
              height: 44,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TGButton(
                  onPressed: onAction,
                  label: context.t('ui_edit'),
                  height: 44,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
                TGButton(
                  onPressed: onAction,
                  label: context.t('ui_promote'),
                  variant: TGButtonVariant.outline,
                  height: 44,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
                if (expiring)
                  TGButton(
                    onPressed: onAction,
                    label: context.t('ui_renew_early'),
                    variant: TGButtonVariant.outline,
                    height: 44,
                    borderRadius: BorderRadius.circular(TGRadius.pill),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CallButton extends StatefulWidget {
  const _CallButton({required this.product, required this.copied, required this.onPressed});
  final TGProduct product;
  final bool copied;
  final VoidCallback? onPressed;

  @override
  State<_CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends State<_CallButton> {
  bool _hover = false;
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final enabled = widget.onPressed != null;
    final showPhone = widget.product.isPubliclyVisible;
    final label = widget.copied
        ? context.t('ui_copied_check')
        : (showPhone ? '${context.t('ui_call')}  ${widget.product.phone}' : context.t('ui_call'));
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Focus(
        onFocusChange: (v) => setState(() => _focused = v),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTapDown: enabled ? (_) => setState(() => _down = true) : null,
            onTapUp: enabled ? (_) => setState(() => _down = false) : null,
            onTapCancel: () => setState(() => _down = false),
            onTap: widget.onPressed,
            child: AnimatedScale(
              scale: _down ? 0.98 : 1,
              duration: tgAnim(context, const Duration(milliseconds: 80)),
              child: AnimatedContainer(
                duration: tgAnim(context, const Duration(milliseconds: 140)),
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: enabled ? theme.primary : theme.tertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                  border: _focused ? Border.all(color: theme.primary, width: 2) : null,
                  boxShadow: _hover && enabled
                      ? [BoxShadow(color: theme.primary.withValues(alpha: 0.45), blurRadius: 16, spreadRadius: 1)]
                      : const [],
                ),
                child: Row(
                  children: [
                    Icon(Icons.call, color: enabled ? TGColors.onCta : theme.secondaryText, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(label, maxLines: 1, style: theme.titleSmall.override(color: enabled ? TGColors.onCta : theme.secondaryText, fontWeight: FontWeight.w800)),
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
  }
}

class _StickyCallBar extends StatelessWidget {
  const _StickyCallBar({required this.product, required this.copied, required this.onCall, required this.onMessage});
  final TGProduct product;
  final bool copied;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: TGColors.surface,
      child: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: TGColors.border, width: 1))),
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + safe),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              Expanded(
                flex: 16,
                child: _CallButton(product: product, copied: copied, onPressed: product.isPubliclyVisible ? onCall : null),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 10,
                child: TGButton(
                  onPressed: product.isPubliclyVisible ? onMessage : null,
                  label: context.t('ui_message'),
                  variant: TGButtonVariant.outline,
                  height: 48,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TGColors.rating.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TGColors.rating.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gpp_maybe_outlined, color: TGColors.rating),
          const SizedBox(width: 8),
          Expanded(child: Text(context.t('ui_pdp_needs_attention'), style: theme.titleSmall.override(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _ModerationBanner extends StatelessWidget {
  const _ModerationBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TGColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TGColors.error.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
    );
  }
}

class _InactiveBanner extends StatelessWidget {
  const _InactiveBanner({super.key, this.onRenew});
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TGColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TGColors.error.withValues(alpha: 0.5)),
          ),
          child: Text(context.t('ui_listing_inactive'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        ),
        if (onRenew != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TGButton(
              key: const Key('pdp-renew-inline'),
              onPressed: onRenew,
              label: context.t('ui_renew_pln', {'fee': '${TGPricing.listingFeePln}'}),
              height: 40,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
          ),
        ],
      ],
    );
  }
}

class _PdpSkeleton extends StatefulWidget {
  const _PdpSkeleton();

  @override
  State<_PdpSkeleton> createState() => _PdpSkeletonState();
}

class _PdpSkeletonState extends State<_PdpSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final reduce = tgReduceMotion(context);
    if (reduce) _shimmer.stop();
    Widget box(double h, {double? w}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(color: theme.alternate, borderRadius: BorderRadius.circular(8)),
        );
    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AspectRatio(aspectRatio: 4 / 3, child: box(200)),
        const SizedBox(height: 16),
        box(22, w: 220),
        const SizedBox(height: 12),
        box(28, w: 160),
        const SizedBox(height: 20),
        box(160),
      ],
    );
    if (reduce) return body;
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            final t = _shimmer.value;
            return LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(t, 0),
              colors: [theme.alternate, theme.primaryText.withValues(alpha: 0.18), theme.alternate],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: body,
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      children: [
        CustomPaint(size: const Size(180, 120), painter: _ShelfPainter(color: theme.secondaryText)),
        const SizedBox(height: 16),
        Text(context.t('ui_product_not_found'), textAlign: TextAlign.center, style: theme.titleLarge),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => TGNav.products(context),
          child: Text(context.t('ui_back_to_search')),
        ),
      ],
    );
  }
}

class _ShelfPainter extends CustomPainter {
  _ShelfPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final y = 24.0 + i * 32;
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), p);
      canvas.drawRect(Rect.fromLTWH(28 + i * 36.0, y - 18, 28, 18), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ShelfPainter old) => old.color != color;
}
