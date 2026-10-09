import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/product_detail/pdp_message_sheet.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/product_detail/report_listing_sheet.dart';
import 'package:twoja_gastromania/seller/seller_profile_panels.dart';
import 'package:twoja_gastromania/seller/store_reviews_panel.dart';
import 'package:twoja_gastromania/seller/seller_profile_query.dart';
import 'package:twoja_gastromania/seller/store_mobile_layout.dart';
import 'package:twoja_gastromania/seller/store_owner_edit.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_badges.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_rating_stars.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_contact.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_robots.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/review_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SellerProfilePageWidget extends StatefulWidget {
  const SellerProfilePageWidget({super.key, required this.sellerId});

  static const routeName = 'SellerProfile';
  static const routePath = '/seller/:id';

  final String sellerId;

  @override
  State<SellerProfilePageWidget> createState() => _SellerProfilePageWidgetState();
}

class _SellerProfilePageWidgetState extends State<SellerProfilePageWidget> {
  late Future<({TGStoreProfile? profile, List<TGProduct> listings})> _future;
  final _scroll = ScrollController();
  final _identityKey = GlobalKey();
  final _chrome = StoreChromeController();
  bool _compact = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant SellerProfilePageWidget old) {
    super.didUpdateWidget(old);
    if (old.sellerId != widget.sellerId) {
      _future = _load();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _chrome.dispose();
    super.dispose();
  }

  Future<({TGStoreProfile? profile, List<TGProduct> listings})> _load() async {
    if (!tgInWidgetTest()) await Future<void>.delayed(TGMotion.skeleton);
    final profile = TGSellerProfileService.instance.resolve(widget.sellerId);
    if (profile == null) return (profile: null, listings: const <TGProduct>[]);
    TGAnalytics.track('store_view', {'id': profile.publicId, 'slug': profile.slug, 'status': profile.status.name});
    final listings = await TGSellerProfileService.instance.publicListings(profile);
    return (profile: profile, listings: listings);
  }

  void _onScroll() {
    final box = _identityKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final gone = box.localToGlobal(Offset.zero).dy + box.size.height < 80;
    if (gone != _compact) setState(() => _compact = gone);
  }

  TGStoreQuery get _query {
    final uri = GoRouterState.of(context).uri;
    return TGStoreQuery.fromQuery(uri.queryParameters);
  }

  void _go(TGStoreQuery q, String path) {
    final loc = q.toLocation(path);
    if (GoRouterState.of(context).uri.toString() != loc) context.go(loc);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.sizeOf(context).width < TGBreakpoints.phone ? 16.0 : 24.0;
    return TGPageScaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([TGSellerProfileService.instance, TGReviewService.instance]),
        builder: (context, _) => FutureBuilder<({TGStoreProfile? profile, List<TGProduct> listings})>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _StoreSkeleton();
          }
          final profile = TGSellerProfileService.instance.resolve(widget.sellerId) ?? snap.data?.profile;
          final listings = snap.data?.listings ?? const <TGProduct>[];
          if (profile == null) {
            setListingRobotsNoIndex(true);
            return _NotFound(pad: pad);
          }
          setListingRobotsNoIndex(!profile.isLive);
          if (profile.status == TGStoreStatus.suspended) {
            return _Suspended(pad: pad);
          }
          return StoreChromeScope(
            notifier: _chrome,
            child: _StoreBody(
              profile: profile,
              listings: listings,
              query: _query,
              pad: pad,
              scroll: _scroll,
              identityKey: _identityKey,
              compact: _compact,
              copied: _copied,
              chrome: _chrome,
              onCopied: (v) => setState(() => _copied = v),
              onQuery: (q) => _go(q, profile.path),
            ),
          );
        },
      ),
      ),
    );
  }
}

class _StoreBody extends StatelessWidget {
  const _StoreBody({
    required this.profile,
    required this.listings,
    required this.query,
    required this.pad,
    required this.scroll,
    required this.identityKey,
    required this.compact,
    required this.copied,
    required this.chrome,
    required this.onCopied,
    required this.onQuery,
  });

  final TGStoreProfile profile;
  final List<TGProduct> listings;
  final TGStoreQuery query;
  final double pad;
  final ScrollController scroll;
  final GlobalKey identityKey;
  final bool compact;
  final bool copied;
  final StoreChromeController chrome;
  final ValueChanged<bool> onCopied;
  final ValueChanged<TGStoreQuery> onQuery;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: chrome,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final isStore = profile.isStore;
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < TGBreakpoints.desktop;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final owner = storeIsOwner(auth, profile);
    final ownerUi = owner && !chrome.previewVisitor;
    final contactLooksOn = profile.isLive && (!ownerUi || chrome.previewVisitor);
    final tabs = <TGStoreTab>[
      TGStoreTab.products,
      if (isStore && profile.showAbout) TGStoreTab.about,
      TGStoreTab.reviews,
    ];
    var tab = query.tab;
    if (!tabs.contains(tab)) tab = TGStoreTab.products;
    final bottomPad = mobile && isStore && profile.isLive ? 88.0 : 64.0;

    void selectTab(TGStoreTab t) {
      TGAnalytics.track('store_tab_change', {'tab': t.name, 'seller': profile.publicId});
      onQuery(query.copyWith(tab: t, page: 1));
    }

    Future<void> onCall() async {
      if (chrome.previewVisitor) {
        showTGToast(context, context.t('ui_preview_only'));
        return;
      }
      await withStoreOverlay(context, () => _call(context, profile, onCopied));
    }

    Future<void> onMessage() async {
      if (chrome.previewVisitor) {
        showTGToast(context, context.t('ui_preview_only'));
        return;
      }
      await withStoreOverlay(context, () => _message(context, profile, listings));
    }

    final scroller = CustomScrollView(
      controller: scroll,
      slivers: [
        if (owner)
          SliverToBoxAdapter(
            child: StoreOwnerBar(
              profile: profile,
              preview: chrome.previewVisitor,
              onPreview: chrome.setPreview,
              onEdit: () {
                if (mobile) {
                  showStoreEditFlow(context, profile);
                } else {
                  chrome.setEditing(!chrome.editing);
                }
              },
            ),
          ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (auth.isAdmin) _AdminBar(profile: profile),
                        if (owner && profile.incompleteSetup) _OnboardingBanner(),
                        TGBreadcrumb(
                          items: [
                            TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                            TGBreadcrumbItem(label: context.t('ui_sellers'), onTap: () => TGNav.verifiedSellers(context)),
                            TGBreadcrumbItem(label: profile.name),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (!profile.isLive) ...[
                          _StatusBanner(text: context.t('ui_store_inactive')),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (isStore && mobile)
                StoreEditableRegion(
                  section: TGStoreEditSection.cover,
                  editing: chrome.editing,
                  onEdit: (s) => showStoreEditFlow(context, profile, section: s),
                  child: StoreMobileCoverIdentity(
                    profile: profile,
                    identityKey: identityKey,
                    onQuote: profile.showQuote
                        ? () {
                            TGAnalytics.track('store_quote_click', {'seller': profile.publicId});
                            TGNav.storeQuote(context, profile.publicId);
                          }
                        : null,
                  ),
                )
              else if (isStore)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: _CoverIdentity(
                        profile: profile,
                        listings: listings,
                        identityKey: identityKey,
                        copied: copied,
                        onCopied: onCopied,
                        editing: chrome.editing,
                        ownerUi: ownerUi,
                        contactEnabled: contactLooksOn,
                        onEdit: (s) => showStoreEditFlow(context, profile, section: s),
                        onCall: onCall,
                        onMessage: onMessage,
                      ),
                    ),
                  ),
                )
              else
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: _PrivateHeader(
                        profile: profile,
                        listings: listings,
                        copied: copied,
                        onCopied: onCopied,
                      ),
                    ),
                  ),
                ),
              if (ownerUi && mobile)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: [
                      StoreCompletenessCard(profile: profile),
                      const SizedBox(height: 12),
                      StorePlanCard(profile: profile),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (profile.isLive)
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabsDelegate(
              tabs: tabs,
              active: tab,
              compact: !mobile && compact,
              mobile: mobile,
              profile: profile,
              listingsCount: listings.length,
              onSelect: selectTab,
              onCall: !mobile && contactLooksOn ? onCall : null,
            ),
          ),
        if (tab == TGStoreTab.reviews && width >= 1024)
          SliverFillRemaining(
            hasScrollBody: true,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 24, pad, 24),
                  child: StoreReviewsPanel(profile: profile, stickySummary: true),
                ),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 24, pad, bottomPad),
                  child: GestureDetector(
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      final i = tabs.indexOf(tab);
                      if (v < -200 && i < tabs.length - 1) selectTab(tabs[i + 1]);
                      if (v > 200 && i > 0) selectTab(tabs[i - 1]);
                    },
                    child: AnimatedSwitcher(
                      duration: tgAnim(context, TGMotion.fade),
                      child: KeyedSubtree(
                        key: ValueKey(tab),
                        child: !profile.isLive
                            ? _InactiveExtras(profile: profile)
                            : switch (tab) {
                                TGStoreTab.products => StoreProductsPanel(profile: profile, listings: listings, query: query, onQuery: onQuery, hideSeller: isStore),
                                TGStoreTab.about => StoreAboutPanel(profile: profile, editing: chrome.editing, onEdit: (s) => showStoreEditFlow(context, profile, section: s)),
                                TGStoreTab.reviews => StoreReviewsPanel(profile: profile),
                              },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: TGFooter()),
      ],
    );

    final showBar = mobile && isStore && profile.isLive && !chrome.overlayOpen && !keyboard;
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        final i = tabs.indexOf(tab);
        if (v < -220 && i < tabs.length - 1) selectTab(tabs[i + 1]);
        if (v > 220 && i > 0) selectTab(tabs[i - 1]);
      },
      child: Stack(
        children: [
          scroller,
          if (showBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StoreMobileContactBar(
                profile: profile,
                enabled: contactLooksOn,
                onCall: onCall,
                onMessage: onMessage,
              ),
            ),
        ],
      ),
    );
  }
}

class _CoverIdentity extends StatelessWidget {
  const _CoverIdentity({
    required this.profile,
    required this.listings,
    required this.identityKey,
    required this.copied,
    required this.onCopied,
    required this.editing,
    required this.ownerUi,
    required this.contactEnabled,
    required this.onEdit,
    required this.onCall,
    required this.onMessage,
  });
  final TGStoreProfile profile;
  final List<TGProduct> listings;
  final GlobalKey identityKey;
  final bool copied;
  final ValueChanged<bool> onCopied;
  final bool editing;
  final bool ownerUi;
  final bool contactEnabled;
  final ValueChanged<TGStoreEditSection> onEdit;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final muted = !profile.isLive;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        StoreEditableRegion(
          section: TGStoreEditSection.cover,
          editing: editing,
          onEdit: onEdit,
          child: Opacity(
            opacity: muted ? 0.45 : 1,
            child: _Cover(url: profile.coverUrl),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 184),
          child: LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < TGBreakpoints.desktop;
              final identity = KeyedSubtree(
                key: identityKey,
                child: StoreEditableRegion(
                  section: TGStoreEditSection.logo,
                  editing: editing,
                  onEdit: onEdit,
                  child: Opacity(opacity: muted ? 0.7 : 1, child: _IdentityBlock(profile: profile)),
                ),
              );
              final contact = Column(
                children: [
                  if (ownerUi) ...[
                    StoreCompletenessCard(profile: profile),
                    const SizedBox(height: 12),
                    StorePlanCard(profile: profile),
                    const SizedBox(height: 12),
                  ],
                  _ContactCard(
                    profile: profile,
                    listings: listings,
                    copied: copied,
                    onCopied: onCopied,
                    enabled: contactEnabled,
                    onCall: onCall,
                    onMessage: onMessage,
                  ),
                ],
              );
              if (stacked) {
                return Column(children: [identity, const SizedBox(height: 16), contact]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 8, child: identity),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: contact),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 240,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              Image.asset(url!, fit: BoxFit.cover)
            else
              CustomPaint(painter: _CoverFallbackPainter()),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x8C000000)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverFallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1A1A1A));
    final p = Paint()
      ..color = const Color(0xFF2E2E2E)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({required this.profile});
  final TGStoreProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final open = storeOpenState(profile.hours);
    final extraCats = profile.categories.length > 4 ? profile.categories.length - 4 : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Logo(url: profile.logoUrl, name: profile.name, size: 128),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(profile.name, style: theme.headlineMedium.override(fontSize: 36, lineHeight: 44 / 36, fontWeight: FontWeight.w800)),
            if (profile.verified) TGVerifiedSellerBadge(tooltip: context.t('ui_verified_store_tip'), pulse: true),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TGRatingBadge(rating: profile.rating),
            TGRatingStars(rating: profile.rating),
            if (profile.reviewsCount < 3)
              _MiniTag(context.t('ui_new_seller'), theme.secondary)
            else
              Text(context.t('ui_reviews_n', {'n': '${profile.reviewsCount}'}), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_on_outlined, size: 16, color: theme.secondaryText),
              const SizedBox(width: 4),
              Text('${profile.city}, ${profile.voivodeship}', style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700)),
            ]),
            Text(context.t('ui_member_since', {'y': '${profile.memberSince.year}'}), style: theme.bodySmall.override(color: theme.secondaryText)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: open.open ? theme.success : theme.secondaryText, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                open.open ? '${context.t('ui_open_now')} · ${context.t('ui_closes_at', {'t': open.nextTime})}' : context.t('ui_closed_opens', {'when': '${context.t('ui_day_${open.nextDayKey}_short')} ${open.nextTime}'}),
                style: theme.bodySmall.override(color: open.open ? theme.success : theme.secondaryText, fontWeight: FontWeight.w800),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat in profile.categories.take(4))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: theme.secondary.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(TGRadius.pill), border: Border.all(color: theme.secondary.withValues(alpha: 0.45))),
                child: Text(categoryLabel(cat, t: (k) => context.t(k)), style: theme.labelSmall.override(color: theme.secondary, fontWeight: FontWeight.w800)),
              ),
            if (extraCats > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: theme.alternate, borderRadius: BorderRadius.circular(TGRadius.pill)),
                child: Text('+$extraCats', style: theme.labelSmall.override(fontWeight: FontWeight.w800)),
              ),
            if (profile.acceptsSpecialOrder)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(TGRadius.pill), border: Border.all(color: theme.primary, width: 1.4)),
                child: Text(context.t('ui_custom_orders'), style: theme.labelSmall.override(color: theme.primary, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: FlutterFlowTheme.of(context).labelSmall.override(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.w900)),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.url, required this.name, required this.size, this.ring = true});
  final String? url;
  final String name;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final child = url != null
        ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset(url!, width: size, height: size, fit: BoxFit.cover))
        : Center(child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.alternate,
        borderRadius: BorderRadius.circular(16),
        border: ring ? Border.all(color: const Color(0xFF252525), width: 4) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.profile,
    required this.listings,
    required this.copied,
    required this.onCopied,
    required this.enabled,
    this.onCall,
    this.onMessage,
  });
  final TGStoreProfile profile;
  final List<TGProduct> listings;
  final bool copied;
  final ValueChanged<bool> onCopied;
  final bool enabled;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.tertiary)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CallNowButton(
            phone: profile.phone,
            copied: copied,
            enabled: enabled,
            onPressed: enabled ? (onCall ?? () => _call(context, profile, onCopied)) : null,
          ),
          if (enabled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text(profile.phone, style: theme.titleSmall.override(fontSize: 20, fontWeight: FontWeight.w800))),
                IconButton(
                  tooltip: context.t('ui_call_now'),
                  onPressed: onCall ?? () => _call(context, profile, onCopied),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          TGButton(
            onPressed: enabled ? (onMessage ?? () => _message(context, profile, listings)) : null,
            label: context.t('ui_message'),
            variant: TGButtonVariant.outline,
            height: 48,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
          if (enabled && profile.showQuote) ...[
            const SizedBox(height: 8),
            TGButton(
              onPressed: () {
                TGAnalytics.track('store_quote_click', {'seller': profile.publicId});
                TGNav.storeQuote(context, profile.publicId);
              },
              label: context.t('ui_request_quote'),
              variant: TGButtonVariant.ghost,
              height: 44,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _ShareButton(profile: profile),
              const Spacer(),
              _ReportSellerMenu(profile: profile),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallNowButton extends StatefulWidget {
  const _CallNowButton({required this.phone, required this.copied, required this.enabled, this.onPressed});
  final String phone;
  final bool copied;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  State<_CallNowButton> createState() => _CallNowButtonState();
}

class _CallNowButtonState extends State<_CallNowButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final label = widget.copied ? context.t('ui_copied_check') : context.t('ui_call_now');
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: '${context.t('ui_call_now')} ${widget.phone}',
      child: Focus(
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return MouseRegion(
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
                onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
                onTapCancel: () => setState(() => _down = false),
                onTap: widget.onPressed,
                child: AnimatedScale(
                  scale: _down ? 0.98 : 1,
                  duration: tgAnim(context, const Duration(milliseconds: 120)),
                  child: AnimatedContainer(
                    duration: tgAnim(context, const Duration(milliseconds: 160)),
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.enabled ? theme.primary : theme.tertiary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(TGRadius.pill),
                      boxShadow: _hover && widget.enabled ? [BoxShadow(color: theme.primary.withValues(alpha: 0.45), blurRadius: 16)] : const [],
                      border: focused ? Border.all(color: theme.primary, width: 2) : null,
                    ),
                    child: Text(label, style: theme.titleSmall.override(color: widget.enabled ? TGColors.onCta : theme.secondaryText, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.profile});
  final TGStoreProfile profile;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: context.t('ui_share'),
      onSelected: (v) async {
        if (v != 'copy') return;
        TGAnalytics.track('store_share', {'seller': profile.publicId});
        final uri = Uri.base.replace(path: profile.path, query: '');
        await Clipboard.setData(ClipboardData(text: uri.toString()));
        if (context.mounted) showTGToast(context, context.t('ui_copy_link'));
      },
      itemBuilder: (_) => [PopupMenuItem(value: 'copy', child: Text(context.t('ui_copy_link')))],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.share_outlined, size: 16),
            const SizedBox(width: 6),
            Text(context.t('ui_share'), style: FlutterFlowTheme.of(context).bodySmall.override(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _PrivateHeader extends StatelessWidget {
  const _PrivateHeader({required this.profile, required this.listings, required this.copied, required this.onCopied});
  final TGStoreProfile profile;
  final List<TGProduct> listings;
  final bool copied;
  final ValueChanged<bool> onCopied;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Logo(url: profile.logoUrl, name: profile.name, size: 96, ring: false),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.name, style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(context.t('ui_private_seller'), style: theme.bodyMedium.override(color: theme.secondaryText, fontWeight: FontWeight.w700)),
                  Text(context.t('ui_member_since', {'y': '${profile.memberSince.year}'})),
                  Text(context.t('ui_active_listings_n', {'n': '${listings.length}'})),
                ],
              ),
              const SizedBox(height: 12),
              Text(profile.phone, style: theme.titleSmall.override(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 180,
                    child: _CallNowButton(phone: profile.phone, copied: copied, enabled: true, onPressed: () => _call(context, profile, onCopied)),
                  ),
                  SizedBox(
                    width: 160,
                    child: TGButton(onPressed: () => _message(context, profile, listings), label: context.t('ui_message'), variant: TGButtonVariant.outline, height: 48, borderRadius: BorderRadius.circular(TGRadius.pill)),
                  ),
                  _ReportSellerMenu(profile: profile),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  _TabsDelegate({required this.tabs, required this.active, required this.compact, required this.profile, required this.listingsCount, required this.onSelect, this.onCall, this.mobile = false});

  final List<TGStoreTab> tabs;
  final TGStoreTab active;
  final bool compact;
  final bool mobile;
  final TGStoreProfile profile;
  final int listingsCount;
  final ValueChanged<TGStoreTab> onSelect;
  final VoidCallback? onCall;

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: const Color(0xFF252525),
      child: Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF3A3A3A)))),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: AnimatedSwitcher(
              duration: tgAnim(context, TGMotion.slide),
              child: compact
                  ? Row(
                      key: const ValueKey('compact'),
                      children: [
                        _Logo(url: profile.logoUrl, name: profile.name, size: 36, ring: false),
                        const SizedBox(width: 10),
                        Flexible(child: Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
                        if (profile.verified) ...[const SizedBox(width: 8), const TGVerifiedSellerBadge()],
                        const SizedBox(width: 16),
                        Expanded(child: _TabList(tabs: tabs, active: active, listingsCount: listingsCount, reviewsCount: profile.reviewsCount, onSelect: onSelect, short: mobile, isStore: profile.isStore)),
                        if (onCall != null)
                          TGButton(
                            onPressed: onCall,
                            label: MediaQuery.sizeOf(context).width >= 900 ? '${context.t('ui_call_now')}  ${profile.phone}' : context.t('ui_call_now'),
                            height: 40,
                            borderRadius: BorderRadius.circular(TGRadius.pill),
                          ),
                      ],
                    )
                  : _TabList(key: const ValueKey('full'), tabs: tabs, active: active, listingsCount: listingsCount, reviewsCount: profile.reviewsCount, onSelect: onSelect, short: mobile, isStore: profile.isStore),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabsDelegate old) => old.active != active || old.compact != compact || old.listingsCount != listingsCount || old.mobile != mobile;
}

class _TabList extends StatelessWidget {
  const _TabList({super.key, required this.tabs, required this.active, required this.listingsCount, required this.reviewsCount, required this.onSelect, this.short = false, this.isStore = true});
  final List<TGStoreTab> tabs;
  final TGStoreTab active;
  final int listingsCount;
  final int reviewsCount;
  final ValueChanged<TGStoreTab> onSelect;
  final bool short;
  final bool isStore;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    String label(TGStoreTab t) => short
        ? (t == TGStoreTab.products && !isStore
            ? context.t('ui_active_listings')
            : storeMobileTabLabel(context, name: t.name, products: listingsCount, reviews: reviewsCount))
        : switch (t) {
            TGStoreTab.products => isStore
                ? '${context.t('ui_active_products')} ($listingsCount)'
                : context.t('ui_active_listings'),
            TGStoreTab.about => context.t('ui_about_business'),
            TGStoreTab.reviews => '${context.t('ui_reviews')} ($reviewsCount)',
          };
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final i = tabs.indexOf(active);
        if (event.logicalKey == LogicalKeyboardKey.arrowRight && i < tabs.length - 1) {
          onSelect(tabs[i + 1]);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft && i > 0) {
          onSelect(tabs[i - 1]);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onSelect(t),
                    child: Semantics(
                      selected: t == active,
                      button: true,
                      child: AnimatedContainer(
                        duration: tgAnim(context, TGMotion.slide),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: t == active ? theme.primary : Colors.transparent, width: 2)),
                        ),
                        alignment: Alignment.center,
                        height: 52,
                        child: Text(label(t), style: theme.bodyMedium.override(fontWeight: FontWeight.w800, color: t == active ? theme.primaryText : theme.secondaryText)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBar extends StatelessWidget {
  const _AdminBar({required this.profile});
  final TGStoreProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('seller-admin-bar'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: TGColors.adminBar, borderRadius: BorderRadius.circular(12), border: Border.all(color: TGColors.border)),
      child: Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(onPressed: () => _edit(context), child: Text(context.t('ui_edit_seller_admin'))),
          TextButton(
            onPressed: () {
              context.read<FakeAuthState>().actAsSeller(profile.sellerKey);
              showTGToast(context, context.t('ui_act_as_seller'));
            },
            child: Text(context.t('ui_act_as_seller')),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final desc = TextEditingController(text: profile.description);
    final nip = TextEditingController(text: profile.nip ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('ui_edit_seller_admin')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: desc, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
              TextField(controller: nip, decoration: const InputDecoration(labelText: 'NIP')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              TGSellerProfileService.instance.patch(profile.publicId, (p) => p.copyWith(description: desc.text, nip: nip.text));
              Navigator.pop(ctx);
            },
            child: Text(context.t('ui_save_template').contains('template') ? 'Save' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class _OnboardingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('seller-onboarding-banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: FlutterFlowTheme.of(context).primary)),
      child: Text(context.t('ui_complete_store_setup'), style: FlutterFlowTheme.of(context).bodyMedium.override(fontWeight: FontWeight.w800)),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: FlutterFlowTheme.of(context).alternate, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: FlutterFlowTheme.of(context).titleSmall.override(fontWeight: FontWeight.w900)),
    );
  }
}

class _InactiveExtras extends StatelessWidget {
  const _InactiveExtras({required this.profile});
  final TGStoreProfile profile;

  @override
  Widget build(BuildContext context) {
    final others = TGSellerProfileService.instance.bestSellers.where((p) => p.publicId != profile.publicId).take(3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('ui_similar_stores'), style: FlutterFlowTheme.of(context).titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            for (final s in others)
              TGButton(
                onPressed: () => context.go(s.path),
                label: s.name,
                variant: TGButtonVariant.outline,
                height: 40,
              ),
          ],
        ),
      ],
    );
  }
}

class _StoreSkeleton extends StatelessWidget {
  const _StoreSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double h, double w) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(color: FlutterFlowTheme.of(context).alternate, borderRadius: BorderRadius.circular(8)),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Shimmer(child: bar(16, 220)),
                const SizedBox(height: 18),
                _Shimmer(child: Container(height: 240, decoration: BoxDecoration(color: FlutterFlowTheme.of(context).alternate, borderRadius: BorderRadius.circular(16)))),
                const SizedBox(height: 24),
                Row(children: [_Shimmer(child: bar(128, 128)), const SizedBox(width: 20), Expanded(child: _Shimmer(child: bar(36, 280)))]),
                const SizedBox(height: 28),
                Wrap(spacing: 20, runSpacing: 20, children: List.generate(4, (_) => _Shimmer(child: Container(width: 280, height: 220, decoration: BoxDecoration(color: FlutterFlowTheme.of(context).alternate, borderRadius: BorderRadius.circular(16)))))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: TGMotion.skeleton)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return widget.child;
    return FadeTransition(opacity: Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)), child: widget.child);
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.pad});
  final double pad;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 48, pad, 64),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/images/stainless_steel_table_Food_Preparation_table_gastronomi.jpg', height: 180, fit: BoxFit.cover),
              ),
              const SizedBox(height: 24),
              Text(context.t('ui_store_not_found'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              TGButton(onPressed: () => TGNav.products(context), label: context.t('ui_back_to_search'), height: 46, borderRadius: BorderRadius.circular(TGRadius.pill)),
            ],
          ),
        ),
        const TGFooter(),
      ],
    );
  }
}

class _Suspended extends StatelessWidget {
  const _Suspended({required this.pad});
  final double pad;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 64, pad, 64),
          child: Center(child: Text(context.t('ui_store_suspended'), style: FlutterFlowTheme.of(context).headlineSmall.override(fontWeight: FontWeight.w900))),
        ),
        const TGFooter(),
      ],
    );
  }
}

class _ReportSellerMenu extends StatelessWidget {
  const _ReportSellerMenu({required this.profile});
  final TGStoreProfile profile;

  @override
  Widget build(BuildContext context) {
    if (storeOwnerUi(context, profile)) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      key: const Key('report-seller-menu'),
      tooltip: context.t('ui_report_seller'),
      onSelected: (v) {
        if (v == 'report') withStoreOverlay(context, () => showReportFlow(context, TGReportSubject.seller(profile)));
      },
      itemBuilder: (_) => [PopupMenuItem(value: 'report', child: Text(context.t('ui_report_seller')))],
      child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.more_horiz)),
    );
  }
}

Future<void> _call(BuildContext context, TGStoreProfile profile, ValueChanged<bool> onCopied) async {
  TGAnalytics.track('store_call_click', {'seller': profile.publicId});
  final mobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  if (mobile) {
    final dial = profile.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    await launchUrl(Uri(scheme: 'tel', path: dial));
  }
  if (!context.mounted) return;
  await copyPhoneNumber(context, profile.phone);
  onCopied(true);
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  onCopied(false);
}

Future<void> _message(BuildContext context, TGStoreProfile profile, List<TGProduct> listings) async {
  TGAnalytics.track('store_message_click', {'seller': profile.publicId});
  final auth = context.read<FakeAuthState>();
  if (!auth.isLoggedIn) {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.t('ui_login'), style: FlutterFlowTheme.of(context).titleMedium.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TGButton(onPressed: () => context.goNamed(LoginPageWidget.routeName), label: context.t('ui_login'), height: 46),
          ],
        ),
      ),
    );
    return;
  }
  if (listings.isEmpty) {
    showTGToast(context, context.t('ui_coming_next'));
    return;
  }
  await showPdpMessageSheet(context, listings.first);
}
