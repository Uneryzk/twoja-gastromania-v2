import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/product_detail/pdp_gallery.dart' show openPdpLightbox;
import 'package:twoja_gastromania/product_detail/report_listing_sheet.dart';
import 'package:twoja_gastromania/restaurants/restaurant_card.dart';
import 'package:twoja_gastromania/restaurants/restaurant_detail_sections.dart';
import 'package:twoja_gastromania/restaurants/restaurant_l10n.dart';
import 'package:twoja_gastromania/restaurants/restaurant_message_sheet.dart';
import 'package:twoja_gastromania/restaurants/restaurant_renew_sheet.dart';
import 'package:twoja_gastromania/restaurants/restaurant_transfer_sheet.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_components/tg_special_order_band.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_robots.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/ad_slot_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_lifecycle_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:url_launcher/url_launcher.dart';

class RestaurantDetailPage extends StatefulWidget {
  const RestaurantDetailPage({super.key, required this.segment});

  static const routeName = 'restaurantDetail';
  static const routePath = '/restaurants/:segment';

  final String segment;

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  @override
  void initState() {
    super.initState();
    RestaurantService.instance.addListener(_onSvc);
  }

  @override
  void dispose() {
    RestaurantService.instance.removeListener(_onSvc);
    super.dispose();
  }

  void _onSvc() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final listing = RestaurantService.instance.fromPathSegment(widget.segment);
    return TGPageScaffold(
      header: const TGHeader(),
      body: listing == null ? const _RestoNotFound() : _RestoBody(listing: listing),
    );
  }
}

class _RestoNotFound extends StatelessWidget {
  const _RestoNotFound();

  @override
  Widget build(BuildContext context) {
    setListingRobotsNoIndex(true);
    final theme = FlutterFlowTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('404', style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('This restaurant listing was not found.'),
            const SizedBox(height: 16),
            TGButton(
              onPressed: () => context.go('/restaurants'),
              label: 'Back to restaurants',
              height: 44,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestoBody extends StatefulWidget {
  const _RestoBody({required this.listing});
  final RestaurantListing listing;

  @override
  State<_RestoBody> createState() => _RestoBodyState();
}

class _RestoBodyState extends State<_RestoBody> {
  final _scroll = ScrollController();
  final _galleryController = PageController();
  final _equipKey = GlobalKey();
  int _index = 0;
  int _galleryTab = 0; // 0 photos, 1 floor plan
  bool _favorite = false;
  bool _lightbox = false;
  bool _descOpen = false;
  bool _safetyOpen = false;
  bool _premisesOpen = true;
  bool _leaseOpen = true;
  bool _equipOpen = true;
  bool _copiedPhone = false;
  bool _copiedNo = false;
  Timer? _copyReset;
  bool _viewRecorded = false;
  List<TGProduct> _catalogue = const [];

  RestaurantListing get r {
    return RestaurantService.instance.byId(widget.listing.id) ?? widget.listing;
  }

  bool get _desktop => MediaQuery.sizeOf(context).width >= TGBreakpoints.desktop;
  bool get _keyboardOpen => MediaQuery.viewInsetsOf(context).bottom > 80;

  List<String> get _photos {
    final base = r.images.isEmpty ? <String>[] : List<String>.of(r.images);
    final equip = <String>[];
    for (final item in r.inventory) {
      for (final p in item.photos) {
        if (p.isNotEmpty && !base.contains(p) && !equip.contains(p)) equip.add(p);
      }
    }
    final all = [...base, ...equip];
    return all.isEmpty ? const [''] : all;
  }

  List<String> get _galleryImages {
    if (_galleryTab == 1 && r.floorPlanUrl != null && r.floorPlanUrl!.isNotEmpty) {
      return [r.floorPlanUrl!];
    }
    return _photos;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final auth = context.read<FakeAuthState>();
    final count = auth.isLoggedIn
        ? (auth.userId != r.ownerId && !auth.role.isStaff)
        : true;
    if (!_viewRecorded) {
      _viewRecorded = true;
      RestaurantService.instance.recordView(
        listingId: r.id,
        sessionKey: auth.isLoggedIn ? auth.userId : 'anon-${DateTime.now().day}',
        count: count,
      );
      TGAnalytics.track('resto_detail_view', {'listingNo': r.listingNo, 'status': r.status.key});
    }
    final all = await TGProductService.instance.getAll();
    if (mounted) setState(() => _catalogue = all);
  }

  void _goToGalleryImage(int i) {
    final imgs = _galleryImages;
    if (imgs.isEmpty) return;
    final next = i.clamp(0, imgs.length - 1);
    setState(() => _index = next);
    if (_galleryController.hasClients) {
      final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduce) {
        _galleryController.jumpToPage(next);
      } else {
        _galleryController.animateToPage(next, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  void dispose() {
    _copyReset?.cancel();
    _galleryController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _isOwner {
    final auth = context.read<FakeAuthState>();
    return auth.isLoggedIn && auth.userId == r.ownerId;
  }

  bool get _isStaff => context.read<FakeAuthState>().role.isStaff;

  bool get _contactOk => r.allowsPublicContact && !_isOwner;

  Future<void> _openLightbox([int? i]) async {
    setState(() {
      if (i != null) _index = i;
      _lightbox = true;
    });
    await openPdpLightbox(context: context, images: _galleryImages, index: _index);
    if (mounted) setState(() => _lightbox = false);
  }

  Future<void> _copyListingNo() async {
    await Clipboard.setData(ClipboardData(text: r.listingNo));
    TGAnalytics.track('listing_number_copied', {'listingNo': r.listingNo, 'kind': 'restaurant'});
    setState(() => _copiedNo = true);
    showTGToast(context, 'Listing number copied');
    _copyReset?.cancel();
    _copyReset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copiedNo = false);
    });
  }

  void _recordContact() {
    final auth = context.read<FakeAuthState>();
    final count = !_isOwner && !_isStaff;
    RestaurantService.instance.recordContact(
      listingId: r.id,
      sessionKey: auth.isLoggedIn ? auth.userId : 'anon',
      count: count,
    );
  }

  Future<void> _call() async {
    if (!_contactOk) return;
    TGAnalytics.track('resto_call_click', {'listingNo': r.listingNo, 'mode': 'call'});
    _recordContact();
    await Clipboard.setData(ClipboardData(text: r.phone));
    setState(() => _copiedPhone = true);
    showTGToast(context, 'Phone copied', icon: Icons.phone_rounded);
    final dial = r.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (dial.isNotEmpty) await launchUrl(Uri(scheme: 'tel', path: dial));
    _copyReset?.cancel();
    _copyReset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copiedPhone = false);
    });
  }

  Future<void> _copyPhoneOnly() async {
    if (!_contactOk && !_isOwner) return;
    TGAnalytics.track('resto_call_click', {'listingNo': r.listingNo, 'mode': 'copy'});
    if (_contactOk) _recordContact();
    await Clipboard.setData(ClipboardData(text: r.phone));
    setState(() => _copiedPhone = true);
    showTGToast(context, 'Phone copied', icon: Icons.phone_rounded);
    _copyReset?.cancel();
    _copyReset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copiedPhone = false);
    });
  }

  void _message() {
    if (!_contactOk) return;
    showRestaurantMessageSheet(context, r);
  }

  void _report() {
    TGAnalytics.track('resto_report_open', {'listingNo': r.listingNo});
    showReportFlow(context, TGReportSubject.restaurant(r));
  }

  Future<void> _toggleFavorite() async {
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.t('ui_login_required'), style: FlutterFlowTheme.of(ctx).titleMedium.override(fontWeight: FontWeight.w900)),
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
      return;
    }
    setState(() => _favorite = !_favorite);
    RestaurantService.instance.recordFavorite(
      listingId: r.id,
      userId: auth.userId,
      on: _favorite,
      count: !_isOwner && !_isStaff,
    );
    if (_favorite) showTGToast(context, context.t('ui_saved'), icon: Icons.favorite, iconColor: TGColors.accent);
  }

  void _jumpInventory() {
    TGAnalytics.track('resto_inventory_jump', {'listingNo': r.listingNo});
    final ctx = _equipKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: tgAnim(context, const Duration(milliseconds: 200)),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  String _money(int? n) {
    if (n == null) return '—';
    return '${NumberFormat.decimalPattern('pl').format(n)} PLN';
  }

  String _basisLabel(RestaurantVatBasis b) => switch (b) {
        RestaurantVatBasis.netto => 'NETTO',
        RestaurantVatBasis.brutto => 'BRUTTO',
        RestaurantVatBasis.vatUnspecified => 'VAT not specified',
      };

  int? _monthsLeft() {
    final end = r.leaseEndsAt;
    if (end == null) return null;
    final now = DateTime.now();
    return ((end.year - now.year) * 12 + end.month - now.month).clamp(0, 9999);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final pad = MediaQuery.sizeOf(context).width < TGBreakpoints.phone ? 16.0 : 24.0;
    final owner = _isOwner;
    final canReport = !owner && r.canBeReported;
    final showBar = !_desktop && !_lightbox && !_keyboardOpen && !owner && r.allowsPublicContact;
    final noIndex = !r.isIndexable ||
        r.status == RestaurantListingStatus.removed ||
        r.status == RestaurantListingStatus.sold ||
        r.status == RestaurantListingStatus.expired ||
        r.status == RestaurantListingStatus.pendingAuthorization ||
        r.status == RestaurantListingStatus.underReview ||
        r.isHidden;
    setListingRobotsNoIndex(noIndex);

    final similar = RestaurantService.instance.similarTo(r);
    final more = RestaurantService.instance.moreFromSeller(r);

    return Column(
      children: [
        if (_isStaff)
          Material(
            color: const Color(0xFF2A2A2A),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Moderator view · No. ${r.listingNo} · ${r.status.key}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(pad, 16, pad, showBar ? 88 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TGBreadcrumb(
                                items: [
                                  TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                                  TGBreadcrumbItem(label: 'Restaurants', onTap: () => context.go('/restaurants')),
                                  TGBreadcrumbItem(label: restoLocalizedBusinessType(context, r.businessType)),
                                ],
                              ),
                              if (_statusBanner() != null) ...[
                                const SizedBox(height: 12),
                                _statusBanner()!,
                              ],
                              const SizedBox(height: 14),
                              if (_desktop)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 8,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 845),
                                        child: _leftColumn(theme, canReport, similar, more),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    SizedBox(
                                      width: 411,
                                      child: _StickyPanel(
                                        scroll: _scroll,
                                        topInset: 88,
                                        child: owner
                                              ? _OwnerPanel(
                                                  listing: r,
                                                  onTransfer: () => showRestaurantTransferFlow(context, r),
                                                  onRenew: () => showRestaurantRenewSheet(
                                                    context,
                                                    r,
                                                    early: RestaurantLifecycleService.instance.isRenewEarly(r),
                                                  ),
                                                  onEdit: () => context.go('/restaurants/new?resume=${r.id}'),
                                                  onPromote: () => showRestaurantRenewSheet(context, r, promoteOnly: true),
                                                )
                                            : r.allowsPublicContact
                                                ? _ContactPanel(
                                                    listing: r,
                                                    money: _money,
                                                    basisLabel: _basisLabel,
                                                    monthsLeft: _monthsLeft(),
                                                    copied: _copiedPhone,
                                                    onCall: _call,
                                                    onCopyPhone: _copyPhoneOnly,
                                                    onMessage: _message,
                                                    onReport: canReport ? _report : null,
                                                    onSafety: () => _scrollToSafety(),
                                                  )
                                                : const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                Transform.translate(
                                  offset: Offset(-pad, 0),
                                  child: SizedBox(
                                    width: MediaQuery.sizeOf(context).width,
                                    child: _gallery(theme, canReport, mobile: true),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _titleBlock(theme, mobile: true),
                                const SizedBox(height: 12),
                                _mobilePriceBlock(theme),
                                const SizedBox(height: 12),
                                _sellerStrip(theme),
                                if (r.allowsPublicContact || owner) ...[
                                  const SizedBox(height: 8),
                                  _phoneRow(theme),
                                ],
                                const SizedBox(height: 16),
                                _leftColumn(theme, canReport, similar, more, mobile: true),
                                if (owner) ...[
                                  const SizedBox(height: 16),
                                  _OwnerPanel(
                                    listing: r,
                                    onTransfer: () => showRestaurantTransferFlow(context, r),
                                    onRenew: () => showRestaurantRenewSheet(
                                      context,
                                      r,
                                      early: RestaurantLifecycleService.instance.isRenewEarly(r),
                                    ),
                                    onEdit: () => context.go('/restaurants/new?resume=${r.id}'),
                                    onPromote: () => showRestaurantRenewSheet(context, r, promoteOnly: true),
                                  ),
                                ],
                              ],
                              const SizedBox(height: 28),
                              const TGSpecialOrderBand(),
                              const SizedBox(height: 24),
                              const TGFooter(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (showBar)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Material(
                    elevation: 12,
                    color: theme.secondaryBackground,
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        height: 72,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 16,
                                child: Semantics(
                                  button: true,
                                  label: 'Call ${r.phone}',
                                  child: TGButton(
                                    onPressed: _call,
                                    label: 'Call · ${r.phone}',
                                    height: 52,
                                    borderRadius: BorderRadius.circular(TGRadius.pill),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 10,
                                child: OutlinedButton(
                                  onPressed: _message,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: TGColors.cta,
                                    side: const BorderSide(color: TGColors.cta, width: 2),
                                    minimumSize: const Size(0, 48),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TGRadius.pill)),
                                  ),
                                  child: const Text('Message', style: TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _scrollToSafety() {
    // Soft jump to end of left column safety section — scroll near bottom of first screen content.
    _scroll.animateTo(
      (_scroll.offset + 600).clamp(0, _scroll.position.maxScrollExtent),
      duration: tgAnim(context, const Duration(milliseconds: 200)),
      curve: Curves.easeOutCubic,
    );
  }

  Widget? _statusBanner() {
    final theme = FlutterFlowTheme.of(context);
    String? text;
    if (r.status == RestaurantListingStatus.removed) {
      text = 'This listing was removed.';
    } else if (r.status == RestaurantListingStatus.sold) {
      text = 'This business has been transferred.';
    } else if (r.status == RestaurantListingStatus.expired) {
      text = 'This listing has expired.';
    } else if (r.status == RestaurantListingStatus.pendingAuthorization) {
      text = 'Pending authorization — not publicly listed yet.';
    } else if (r.status == RestaurantListingStatus.underReview || r.isHidden) {
      text = 'This listing is temporarily unavailable.';
    }
    if (text == null) return null;
    return Container(
      key: const Key('resto-noindex'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.alternate),
      ),
      child: Text(text, style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
    );
  }

  Widget _leftColumn(
    FlutterFlowTheme theme,
    bool canReport,
    List<RestaurantListing> similar,
    List<RestaurantListing> more, {
    bool mobile = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!mobile) ...[
          _titleBlock(theme, mobile: false),
          const SizedBox(height: 16),
          _gallery(theme, canReport, mobile: false),
        ],
        RestoInsideChips(listing: r, onJump: _jumpInventory),
        const SizedBox(height: 20),
        RestoKeyFigures(listing: r, money: _money),
        const SizedBox(height: 20),
        RestoDescription(listing: r, open: _descOpen, maxLines: mobile ? 4 : 6, onToggle: () => setState(() => _descOpen = !_descOpen)),
        const SizedBox(height: 20),
        KeyedSubtree(
          key: _equipKey,
          child: mobile
              ? _accordion(
                  title: context.t('ui_equipment_inventory'),
                  open: _equipOpen,
                  onToggle: () => setState(() => _equipOpen = !_equipOpen),
                  child: RestoEquipmentSection(listing: r, catalogue: _catalogue, onPhoto: (urls, i) => openPdpLightbox(context: context, images: urls, index: i)),
                )
              : RestoEquipmentSection(listing: r, catalogue: _catalogue, onPhoto: (urls, i) => openPdpLightbox(context: context, images: urls, index: i)),
        ),
        const SizedBox(height: 20),
        mobile
            ? _accordion(
                title: context.t('ui_the_premises'),
                open: _premisesOpen,
                onToggle: () => setState(() => _premisesOpen = !_premisesOpen),
                child: RestoPremisesTable(listing: r),
              )
            : RestoPremisesTable(listing: r),
        const SizedBox(height: 20),
        mobile
            ? _accordion(
                title: context.t('ui_lease_transfer'),
                open: _leaseOpen,
                onToggle: () => setState(() => _leaseOpen = !_leaseOpen),
                child: RestoLeaseTable(listing: r, money: _money, basisLabel: _basisLabel),
              )
            : RestoLeaseTable(listing: r, money: _money, basisLabel: _basisLabel),
        if (r.costLines.isNotEmpty) ...[
          const SizedBox(height: 20),
          RestoMonthlyCosts(listing: r, money: _money),
        ],
        const SizedBox(height: 20),
        RestoAdditionalInfo(listing: r),
        const SizedBox(height: 20),
        RestoLicencesBlock(listing: r, money: _money),
        const SizedBox(height: 20),
        RestoLocationBlock(listing: r),
        const SizedBox(height: 20),
        mobile
            ? _accordion(
                title: context.t('ui_safety_tips'),
                open: _safetyOpen,
                onToggle: () => setState(() => _safetyOpen = !_safetyOpen),
                child: RestoSafetyTips(onReport: canReport ? _report : null),
              )
            : RestoSafetyTips(onReport: canReport ? _report : null),
        if (similar.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(context.t('ui_similar_listings'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (mobile)
            SizedBox(
              height: 320,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: similar.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => SizedBox(width: 260, child: RestaurantCard(listing: similar[i])),
              ),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [for (final s in similar) SizedBox(width: 260, child: RestaurantCard(listing: s))],
            ),
        ],
        if (more.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(context.t('ui_more_from_seller'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [for (final s in more) SizedBox(width: 260, child: RestaurantCard(listing: s))],
          ),
        ],
      ],
    );
  }

  Widget _accordion({required String title, required bool open, required VoidCallback onToggle, required Widget child}) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          child: Row(
            children: [
              Expanded(child: Text(title, style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
              Icon(open ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
        if (open) ...[const SizedBox(height: 10), child],
      ],
    );
  }

  Widget _titleBlock(FlutterFlowTheme theme, {required bool mobile}) {
    final listedAgo = r.publishedAt == null ? '' : _relative(r.publishedAt!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pill(restoLocalizedBusinessType(context, r.businessType), TGColors.accent),
            if (r.isPromoted) _pill(context.t('ui_promoted_badge'), TGColors.accent),
            _chip(context.t('ui_available_from', {'d': DateFormat('d MMM yyyy').format(r.availableFrom)})),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          restoLocalizedTitle(context, r),
          style: theme.headlineMedium.override(
            fontSize: mobile ? 22 : 32,
            lineHeight: mobile ? 1.27 : 1.25,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (r.venueName != null && r.venueName!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            r.venueName!,
            style: theme.bodyMedium.override(color: theme.secondaryText.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(context.t('ui_listing_no_label', {'n': r.listingNo}), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
            IconButton(
              tooltip: context.t('ui_listing_no_label', {'n': r.listingNo}),
              onPressed: _copyListingNo,
              icon: Icon(_copiedNo ? Icons.check_rounded : Icons.copy_rounded, size: 18, color: TGColors.cta),
              visualDensity: VisualDensity.compact,
            ),
            Text('· ${context.t('ui_listed_ago', {'ago': listedAgo})}', style: theme.bodySmall.override(color: theme.secondaryText)),
          ],
        ),
      ],
    );
  }

  Widget _mobilePriceBlock(FlutterFlowTheme theme) {
    final fee = r.transferFee;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fee.isNone ? context.t('ui_no_transfer_fee') : _money(fee.amountPln),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
          if (!fee.isNone)
            Text(_basisLabel(fee.basis), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            context.t('ui_monthly_rent', {'amount': _money(r.rentMonthly), 'basis': _basisLabel(r.rentBasis)}),
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _sellerStrip(FlutterFlowTheme theme) {
    return Row(
      children: [
        CircleAvatar(radius: 18, backgroundColor: TGColors.cta.withValues(alpha: 0.2), child: Text(r.seller.name.characters.first.toUpperCase())),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.seller.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(r.fullAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(color: theme.secondaryText)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _phoneRow(FlutterFlowTheme theme) {
    if (!r.allowsPublicContact && !_isOwner) return const SizedBox.shrink();
    return Row(
      children: [
        Text(r.phone, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        IconButton(
          onPressed: _copyPhoneOnly,
          icon: Icon(_copiedPhone ? Icons.check_rounded : Icons.copy_rounded, color: TGColors.cta),
        ),
      ],
    );
  }

  Widget _gallery(FlutterFlowTheme theme, bool canReport, {required bool mobile}) {
    final imgs = _galleryImages;
    final h = mobile ? MediaQuery.sizeOf(context).width * 0.66 : 563.0;
    final w = mobile ? MediaQuery.sizeOf(context).width : 845.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _tab(context.t('ui_photos'), 0),
            const SizedBox(width: 12),
            if (r.floorPlanUrl != null) _tab(context.t('ui_floor_plan'), 1),
            const Spacer(),
            if (canReport && mobile)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'report') _report();
                },
                itemBuilder: (_) => [PopupMenuItem(value: 'report', child: Text(context.t('ui_report')))],
                child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.more_horiz)),
              ),
            IconButton(onPressed: _toggleFavorite, icon: Icon(_favorite ? Icons.favorite : Icons.favorite_border, color: _favorite ? TGColors.accent : null)),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Photo gallery, image ${_index + 1} of ${imgs.length}',
          child: GestureDetector(
            onTap: () => _openLightbox(_index),
            child: Container(
              width: w,
              height: h,
              color: const Color(0xFF1A1A1A),
              child: PageView.builder(
                controller: _galleryController,
                itemCount: imgs.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => TGSmartImage(
                  url: imgs[i],
                  fit: BoxFit.contain,
                  fallback: (_) => const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 48)),
                ),
              ),
            ),
          ),
        ),
        if (imgs.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: mobile ? 64 : 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imgs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _goToGalleryImage(i),
                child: Container(
                  width: mobile ? 84 : 96,
                  decoration: BoxDecoration(
                    border: Border.all(color: i == _index ? TGColors.cta : Colors.transparent, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: TGSmartImage(url: imgs[i], fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tab(String label, int i) {
    final on = _galleryTab == i;
    return InkWell(
      onTap: () {
        setState(() {
          _galleryTab = i;
          _index = 0;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_galleryController.hasClients) _galleryController.jumpToPage(0);
        });
      },
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: on ? TGColors.cta : null,
          decoration: on ? TextDecoration.underline : null,
          decorationColor: TGColors.cta,
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
      );

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).primaryBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      );

  String _relative(DateTime at) {
    final d = DateTime.now().difference(at).inDays;
    if (d <= 0) return context.t('ui_today');
    if (d == 1) return context.t('ui_day_ago_1');
    return context.t('ui_days_ago_n', {'n': '$d'});
  }
}

class _StickyPanel extends StatelessWidget {
  const _StickyPanel({required this.scroll, required this.topInset, required this.child});
  final ScrollController scroll;
  final double topInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scroll,
      builder: (_, __) {
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        // Keep panel visually pinned near topInset while the left column scrolls.
        final dy = offset > topInset ? offset - topInset : 0.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: child,
        );
      },
    );
  }
}

class _ContactPanel extends StatelessWidget {
  const _ContactPanel({
    required this.listing,
    required this.money,
    required this.basisLabel,
    required this.monthsLeft,
    required this.copied,
    required this.onCall,
    required this.onCopyPhone,
    required this.onMessage,
    required this.onReport,
    required this.onSafety,
  });

  final RestaurantListing listing;
  final String Function(int?) money;
  final String Function(RestaurantVatBasis) basisLabel;
  final int? monthsLeft;
  final bool copied;
  final VoidCallback onCall;
  final VoidCallback onCopyPhone;
  final VoidCallback onMessage;
  final VoidCallback? onReport;
  final VoidCallback onSafety;

  @override
  Widget build(BuildContext context) {
    final r = listing;
    final fee = r.transferFee;
    final lease = r.leaseEndsAt == null ? null : DateFormat('d MMM yyyy').format(r.leaseEndsAt!);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        border: r.isPromoted
            ? null
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.isPromoted)
            Container(
              height: 2,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(colors: [TGColors.accent, TGColors.cta]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  fee.isNone ? context.t('ui_no_transfer_fee') : money(fee.amountPln),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                ),
                if (!fee.isNone) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      Text(basisLabel(fee.basis), style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w700)),
                      if (r.negotiable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: TGColors.cta.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                          child: Text(context.t('ui_negotiable'), style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800, fontSize: 11)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  context.t('ui_monthly_rent', {'amount': money(r.rentMonthly), 'basis': basisLabel(r.rentBasis)}),
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                if (r.depositPln != null)
                  Text(context.t('ui_deposit_amount', {'amount': money(r.depositPln)}), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                if (lease != null)
                  Text(
                    [
                      context.t('ui_lease_until', {'d': lease}),
                      if (monthsLeft != null) context.t('ui_months_left', {'n': '$monthsLeft'}),
                    ].join(' · '),
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: '${context.t('ui_call_now')} ${r.phone}',
                  child: TGButton(
                    onPressed: onCall,
                    label: context.t('ui_call_now'),
                    height: 52,
                    borderRadius: BorderRadius.circular(TGRadius.pill),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(r.phone, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
                    IconButton(
                      onPressed: onCopyPhone,
                      icon: Icon(copied ? Icons.check_rounded : Icons.copy_rounded, color: TGColors.cta),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onMessage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TGColors.cta,
                    side: const BorderSide(color: TGColors.cta, width: 2),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TGRadius.pill)),
                  ),
                  child: Text(context.t('ui_send_message'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(backgroundColor: TGColors.cta.withValues(alpha: 0.25), child: Text(r.seller.name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r.seller.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(r.fullAddress, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSafety,
                  child: Text('${context.t('ui_safety_tips')} ›', style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800)),
                ),
                if (onReport != null)
                  TextButton.icon(
                    onPressed: onReport,
                    icon: const Icon(Icons.flag_outlined, color: Colors.white70, size: 18),
                    label: Text(context.t('ui_report'), style: const TextStyle(color: Colors.white70)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerPanel extends StatelessWidget {
  const _OwnerPanel({
    required this.listing,
    required this.onTransfer,
    required this.onRenew,
    required this.onEdit,
    required this.onPromote,
  });

  final RestaurantListing listing;
  final VoidCallback onTransfer;
  final VoidCallback onRenew;
  final VoidCallback onEdit;
  final VoidCallback onPromote;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final r = listing;
    final expired = r.status == RestaurantListingStatus.expired;
    final days = r.daysUntilExpiry();
    final daysLeft = days.clamp(0, 999);
    final expiring = r.isExpiringSoon();
    final total = r.source == RestaurantListingSource.paid ? 90 : 30;
    final progress = expired ? 0.0 : (daysLeft / total).clamp(0.0, 1.0);
    final phase = r.source == RestaurantListingSource.freeIntro && !r.freeExtensionGranted
        ? 'Free period · $daysLeft days left'
        : expired
            ? 'Expired ${(-days).clamp(0, 999)} days ago'
            : 'Live · $daysLeft days left';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: expired || expiring ? TGColors.rating : theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('This is your listing', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(phase, style: theme.bodySmall.override(color: expired || expiring ? TGColors.rating : theme.secondaryText)),
          if (!expired) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 6, color: TGColors.cta, backgroundColor: theme.alternate),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Views ${r.engagement.views} · Contacts ${r.engagement.uniqueContacts} · Favorites ${r.engagement.uniqueFavorites}',
            style: theme.bodySmall.override(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
              PopupMenuButton<String>(
                tooltip: 'Promote',
                onSelected: (v) {
                  if (v == 'promote') onPromote();
                  if (v == 'banner') {
                    context.go('/dashboard/advertising?target=${Uri.encodeComponent(listing.detailPath)}');
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'promote', child: Text('Promote listing')),
                  if (AdSlotService.instance.purchaseVisible)
                    const PopupMenuItem(value: 'banner', child: Text('Banner ad')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.primary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Promote', style: TextStyle(color: theme.primary, fontWeight: FontWeight.w700)),
                ),
              ),
              if (!expired)
                OutlinedButton(onPressed: onTransfer, child: const Text('Mark as transferred')),
              if (expiring && !expired) OutlinedButton(onPressed: onRenew, child: const Text('Renew early')),
            ],
          ),
          if (expired) ...[
            const SizedBox(height: 12),
            TGButton(
              onPressed: onRenew,
              label: 'Renew · 149 PLN',
              height: 48,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
          ],
        ],
      ),
    );
  }
}
