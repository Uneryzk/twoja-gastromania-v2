import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/ads_center_tabs.dart';
import 'package:twoja_gastromania/dashboard/dash3_widgets.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/sponsor_slot_service.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_form.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_banner_calendar.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_ad_slot.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/ad_slot_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';

/// `/dashboard/advertising?tab=promotions|banners|sponsor|credits` — promotion
/// and ad centre. `?target=` opens the hero banner purchase (VITRIN-3).
class AdvertisingPage extends StatefulWidget {
  const AdvertisingPage({super.key, this.prefillTarget, this.tab});

  static const routeName = 'Advertising';
  static const routePath = '/dashboard/advertising';
  static const tabs = ['promotions', 'banners', 'sponsor', 'credits'];

  final String? prefillTarget;
  final String? tab;

  @override
  State<AdvertisingPage> createState() => _AdvertisingPageState();
}

enum _Step { content, preview, dates, pay, done }

class _AdvertisingPageState extends State<AdvertisingPage> {
  _Step _step = _Step.content;
  final _title = TextEditingController();
  String _imageUrl = TGListingImages.heroSlide(2);
  String? _targetUrl;
  TGAdSlotKind _kind = TGAdSlotKind.listing;
  int _duration = AdSlotService.instance.pricing.durations.first;
  DateTime? _startsAt;
  bool _useEntitlement = false;
  bool _paying = false;
  final _formKey = GlobalKey<PaymentFormState>();
  TGAdSlot? _submitted;

  Map<String, TGProduct> _catalogue = const {};

  AdSlotService get _ads => AdSlotService.instance;

  String get _tab {
    if (AdvertisingPage.tabs.contains(widget.tab)) return widget.tab!;
    return widget.prefillTarget != null ? 'banners' : 'promotions';
  }

  @override
  void initState() {
    super.initState();
    _ads.ensureSeeded();
    _ads.addListener(_onAds);
    PromotionService.instance.ensureSeeded();
    TGSponsorSlotService.instance.ensureSeeded();
    PromotionService.instance.addListener(_onAds);
    TGSponsorSlotService.instance.addListener(_onAds);
    TGProductService.instance.getAll().then((all) {
      if (mounted) setState(() => _catalogue = {for (final p in all) p.id: p});
    });
    final pre = widget.prefillTarget;
    if (pre != null && pre.startsWith('/')) {
      _targetUrl = pre;
      if (pre.startsWith('/restaurants/')) {
        _kind = TGAdSlotKind.restaurantListing;
      } else if (pre.startsWith('/seller/')) {
        _kind = TGAdSlotKind.store;
      }
    }
  }

  void _onAds() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ads.removeListener(_onAds);
    PromotionService.instance.removeListener(_onAds);
    TGSponsorSlotService.instance.removeListener(_onAds);
    _title.dispose();
    super.dispose();
  }

  int _price(String ownerId) =>
      _useEntitlement && _ads.canUseEnterpriseEntitlement(ownerId) && _duration == _ads.pricing.enterpriseFreeDays
          ? 0
          : _ads.priceFor(_duration);

  void _go(_Step s) => setState(() => _step = s);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final theme = FlutterFlowTheme.of(context);

    final tab = _tab;
    final banners = tab == 'banners';
    if (banners && _ads.purchaseVisible && phone && _step == _Step.dates) return _phoneDatesScreen(theme, auth);

    final owned = _ads.ownedBy(auth.userId);
    final Widget main = !_ads.purchaseVisible
        ? Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go('/dashboard/listings'),
              child: Text(context.t('ui_ads_back_listings')),
            ),
          )
        : switch (_step) {
      _Step.content => _contentStep(theme, auth),
      _Step.preview => _previewStep(theme, phone: phone),
      _Step.dates => _datesStep(theme, auth, phone: false),
      _Step.pay => _payStep(theme, auth),
      _Step.done => _doneStep(theme),
    };

    final Widget bannerBody = phone
        ? main
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: main),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _reportPanel(theme, auth, owned)),
            ],
          );

    return TGPageScaffold(
      body: Column(
        children: [
          const TGTopNav(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(phone ? 16 : 24, 20, phone ? 16 : 24, 40),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(context.t('ui_ads_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 6),
                        const DashReachNote(),
                        const SizedBox(height: 12),
                        DashTabBar(
                          keyPrefix: 'ads',
                          semanticsLabel: context.t('ui_ads_title'),
                          current: tab,
                          tabs: [for (final t in AdvertisingPage.tabs) (t, context.t('ads_tab_$t'))],
                          onSelect: (t) => context.go('${AdvertisingPage.routePath}?tab=$t'),
                        ),
                        const SizedBox(height: 18),
                        if (banners) ...[
                          if (_ads.purchaseVisible) ...[
                            _stepDots(theme),
                            const SizedBox(height: 18),
                          ],
                          bannerBody,
                          if (phone && owned.isNotEmpty && (_step == _Step.content || !_ads.purchaseVisible)) ...[
                            const SizedBox(height: 28),
                            _reportPanel(theme, auth, owned),
                          ],
                        ] else
                          switch (tab) {
                            'sponsor' => AdsSponsorTab(userId: auth.userId),
                            'credits' => DashCreditsPanel(userId: auth.userId),
                            _ => AdsPromotionsTab(targets: AdsTargets(auth, _catalogue)),
                          },
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepDots(FlutterFlowTheme theme) {
    const total = 4;
    final current = _step.index.clamp(0, total - 1);
    return Semantics(
      label: context.t('ui_banner_step_sem', {'n': '${current + 1}', 'total': '$total'}),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= current ? theme.primary : theme.alternate,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 · content
  // ---------------------------------------------------------------------------

  Widget _contentStep(FlutterFlowTheme theme, FakeAuthState auth) {
    final maxChars = _ads.pricing.titleMaxChars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_ads_banner_content'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(context.t('ui_ads_image_hint'), style: theme.bodySmall),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          maxLength: maxChars,
          decoration: InputDecoration(labelText: context.t('ui_ads_title_field')),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(context.t('ui_ads_image'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        _ImagePicker(selected: _imageUrl, onPicked: (u) => setState(() => _imageUrl = u)),
        const SizedBox(height: 14),
        Text(context.t('ui_ads_target'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        _TargetPicker(
          ownerId: auth.userId,
          selected: _targetUrl,
          onPicked: (url, kind) => setState(() {
            _targetUrl = url;
            _kind = kind;
          }),
        ),
        const SizedBox(height: 16),
        TGButton(
          onPressed: () {
            final t = _title.text.trim();
            if (t.isEmpty || t.length > maxChars) {
              showTGToast(context, context.t('ui_ads_title_required'));
              return;
            }
            if (_targetUrl == null) {
              showTGToast(context, context.t('ui_ads_pick_target'));
              return;
            }
            _go(_Step.preview);
          },
          label: context.t('ui_ads_preview'),
          height: 48,
          borderRadius: BorderRadius.circular(TGRadius.pill),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 · scrim preview
  // ---------------------------------------------------------------------------

  Widget _previewStep(FlutterFlowTheme theme, {required bool phone}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_ads_preview'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        TGBannerPreview(title: _title.text.trim(), imageUrl: _imageUrl, phone: phone),
        const SizedBox(height: 8),
        Text(context.t('ui_ads_target_label', {'url': _targetUrl ?? ''}), style: theme.bodySmall),
        const SizedBox(height: 16),
        Row(
          children: [
            TextButton(onPressed: () => _go(_Step.content), child: Text(context.t('ui_ads_back'))),
            const Spacer(),
            TGButton(
              onPressed: () => _go(_Step.dates),
              label: context.t('ui_banner_choose_dates'),
              height: 44,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 · duration + calendar
  // ---------------------------------------------------------------------------

  Widget _durationPicker(FlutterFlowTheme theme, FakeAuthState auth) {
    final cfg = _ads.pricing;
    final entitlementLeft = _ads.enterpriseRemaining(auth.userId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_banner_duration'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(context.t('ui_longer_cheaper'), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 8),
        for (final key in AdSlotService.instance.pricing.durations)
          RadioListTile<int>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: key,
            groupValue: _duration,
            onChanged: _useEntitlement ? null : (v) => setState(() => _duration = v!),
            title: Text(
              '${DurationFormatter.daysOf(context, key)} · ${cfg.pricePln(key)} PLN',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              PricingConfigService.instance.config.perDayLabel(cfg.pricePln(key), key, unit: context.t('ui_pln_per_day')),
            ),
          ),
        if (entitlementLeft > 0)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('ui_ads_use_entitlement', {'n': '$entitlementLeft'})),
            subtitle: Text(context.t('ui_banner_entitlement_week', {'days': '${cfg.enterpriseFreeDays}'})),
            value: _useEntitlement,
            onChanged: (v) => setState(() {
              _useEntitlement = v;
              if (v) _duration = cfg.enterpriseFreeDays;
            }),
          ),
      ],
    );
  }

  bool get _selectionOk {
    final s = _startsAt;
    return s != null && _ads.windowFree(s, _duration, ignoreHoldOf: context.read<FakeAuthState>().userId);
  }

  void _continueToPayment(FakeAuthState auth) {
    final s = _startsAt;
    if (s == null || !_selectionOk) {
      showTGToast(context, context.t('ui_banner_pick_free_dates'));
      return;
    }
    try {
      _ads.reserve(ownerId: auth.userId, startsAt: s, durationDays: _duration);
      _go(_Step.pay);
    } on StateError catch (e) {
      showTGToast(context, context.t(e.message));
    }
  }

  Widget _datesSummary(FlutterFlowTheme theme, FakeAuthState auth) {
    final s = _startsAt;
    final price = _price(auth.userId);
    return Semantics(
      liveRegion: true,
      child: Text(
        s == null || !_selectionOk
            ? context.t('ui_banner_pick_free_dates')
            : '${tgBannerWindowLabel(context, s, _duration)} · ${price <= 0 ? context.t('ui_banner_free_week') : '$price PLN'}',
        style: theme.bodyMedium.override(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _datesStep(FlutterFlowTheme theme, FakeAuthState auth, {required bool phone}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _durationPicker(theme, auth),
        const SizedBox(height: 16),
        TGBannerCalendar(
          ownerId: auth.userId,
          durationDays: _duration,
          selectedStart: _startsAt,
          onSelect: (d) => setState(() => _startsAt = d),
        ),
        if (!phone) ...[
          const SizedBox(height: 16),
          _datesSummary(theme, auth),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(onPressed: () => _go(_Step.preview), child: Text(context.t('ui_ads_back'))),
              const Spacer(),
              TGButton(
                onPressed: _selectionOk ? () => _continueToPayment(auth) : null,
                label: context.t('ui_ads_continue_payment'),
                height: 44,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 390px: calendar takes the whole screen; CTA sticks to the bottom.
  Widget _phoneDatesScreen(FlutterFlowTheme theme, FakeAuthState auth) {
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.primaryBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: context.t('ui_ads_back'),
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _go(_Step.preview),
        ),
        title: Text(context.t('ui_banner_choose_dates'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [_datesStep(theme, auth, phone: true)],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: TGColors.surface,
            border: Border(top: BorderSide(color: TGColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _datesSummary(theme, auth),
              const SizedBox(height: 8),
              TGButton(
                onPressed: _selectionOk ? () => _continueToPayment(auth) : null,
                label: context.t('ui_ads_continue_payment'),
                height: 48,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4 · payment
  // ---------------------------------------------------------------------------

  Widget _payStep(FlutterFlowTheme theme, FakeAuthState auth) {
    final price = _price(auth.userId);
    final free = price <= 0;
    final hold = _ads.holdFor(auth.userId);
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          free
              ? context.t('ui_ads_confirm_entitlement')
              : context.t('ui_banner_payment', {'price': '$price', 'duration': DurationFormatter.daysOf(context, _duration)}),
          style: theme.titleMedium.override(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        if (_startsAt != null)
          Text(tgBannerWindowLabel(context, _startsAt!, _duration), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        if (hold != null)
          Text(
            context.t('ui_banner_hold_until', {'time': DateFormat('d MMM, HH:mm', locale).format(hold.expiresAt)}),
            style: theme.bodySmall.override(color: theme.secondaryText),
          ),
        const SizedBox(height: 4),
        Text(
          context.t('ui_banner_refund_rule', {'n': '${_ads.pricing.fullRefundDaysBeforeStart}'}),
          style: theme.bodySmall.override(color: theme.secondaryText),
        ),
        const SizedBox(height: 16),
        if (free)
          TGButton(
            onPressed: () => _submit(auth),
            label: context.t('ui_ads_submit_review'),
            height: 48,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          )
        else
          PaymentForm(
            key: _formKey,
            amountPln: price.toDouble(),
            billingKind: TGPaymentKind.banner,
            billingDescription: 'Hero banner · $_duration days',
            onWaitingChanged: (v) => setState(() => _paying = v),
            onPaid: () => _submit(auth),
          ),
        TextButton(
          onPressed: _paying
              ? null
              : () {
                  _ads.releaseHold(auth.userId);
                  _go(_Step.dates);
                },
          child: Text(context.t('ui_ads_back')),
        ),
      ],
    );
  }

  void _submit(FakeAuthState auth) {
    try {
      final slot = _ads.purchaseAndSubmit(
        ownerId: auth.userId,
        kind: _kind,
        targetUrl: _targetUrl!,
        title: _title.text.trim(),
        imageUrl: _imageUrl,
        startsAt: _startsAt!,
        durationDays: _duration,
        useEnterpriseEntitlement: _useEntitlement,
      );
      setState(() {
        _submitted = slot;
        _step = _Step.done;
      });
    } on StateError catch (e) {
      showTGToast(context, context.t(e.message));
      _go(_Step.dates);
    }
  }

  Widget _doneStep(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_ads_submitted'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(context.t('ui_ads_submitted_body', {'id': _submitted?.id ?? ''}), style: theme.bodyMedium),
        const SizedBox(height: 16),
        TGButton(
          onPressed: () => context.go('/dashboard/listings'),
          label: context.t('ui_ads_back_listings'),
          height: 48,
          borderRadius: BorderRadius.circular(TGRadius.pill),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Owner report · cancel · one correction
  // ---------------------------------------------------------------------------

  Future<void> _resubmitDialog(TGAdSlot s, FakeAuthState auth) async {
    final c = TextEditingController(text: s.title);
    var image = s.imageUrl;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(ctx.t('ui_banner_fix_title')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((s.changesNote ?? '').isNotEmpty) Text(s.changesNote!, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                TextField(
                  controller: c,
                  maxLength: _ads.pricing.titleMaxChars,
                  decoration: InputDecoration(labelText: ctx.t('ui_ads_title_field')),
                ),
                _ImagePicker(selected: image, onPicked: (u) => setLocal(() => image = u)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
            TGButton(onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_banner_resubmit'), height: 40),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final err = _ads.resubmit(s.id, ownerId: auth.userId, title: c.text, imageUrl: image);
    if (!mounted) return;
    showTGToast(context, context.t(err ?? 'ui_banner_resubmitted'));
  }

  Future<void> _cancel(TGAdSlot s, FakeAuthState auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('ui_banner_cancel_title')),
        content: Text(
          s.pricePln > 0
              ? ctx.t('ui_banner_cancel_body', {'price': '${s.pricePln}'})
              : ctx.t('ui_banner_cancel_body_free'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_ads_back'))),
          TGButton(onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_banner_cancel_cta'), height: 40),
        ],
      ),
    );
    if (ok != true) return;
    final err = _ads.cancelByOwner(s.id, ownerId: auth.userId);
    if (!mounted) return;
    showTGToast(context, context.t(err ?? 'ui_banner_cancelled'));
  }

  bool _canStop(TGAdSlot s) {
    final now = TGClock.now();
    return s.endsAt.isAfter(now) &&
        (s.status == TGAdSlotStatus.live || (s.status == TGAdSlotStatus.approved && !now.isBefore(s.startsAt)));
  }

  Widget _reportPanel(FlutterFlowTheme theme, FakeAuthState auth, List<TGAdSlot> owned) {
    final locale = Localizations.localeOf(context).languageCode;
    final fmt = DateFormat('d MMM', locale);
    return Material(
      color: TGColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: TGColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(context.t('ui_ads_your_banners'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 12),
            if (owned.isEmpty)
              Text(context.t('ui_ads_none'), style: theme.bodySmall)
            else
              for (final s in owned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        '${context.t('ui_banner_status_${s.status.name}')} · '
                        '${fmt.format(s.startsAt)} – ${fmt.format(s.endsAt.subtract(const Duration(days: 1)))}',
                        style: theme.bodySmall.override(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        context.t('ui_ads_stats', {
                          'status': DurationFormatter.daysOf(context, s.durationDays),
                          'impressions': '${s.impressions}',
                          'clicks': '${s.clicks}',
                        }),
                        style: theme.bodySmall,
                      ),
                      if ((s.refundPln ?? 0) > 0)
                        Text(context.t('ui_banner_refunded', {'price': '${s.refundPln}'}), style: theme.bodySmall),
                      if (s.status == TGAdSlotStatus.rejected && (s.rejectReason ?? '').isNotEmpty)
                        Text(s.rejectReason!, style: theme.bodySmall.override(color: TGColors.error)),
                      if (s.status == TGAdSlotStatus.changesRequested || _ads.canCancel(s) || _canStop(s))
                        Wrap(
                          spacing: 8,
                          children: [
                            if (_canStop(s))
                              TextButton(
                                key: Key('ads-banner-stop-${s.id}'),
                                onPressed: () async {
                                  if (!await confirmStopEarly(context)) return;
                                  final err = _ads.stopByOwner(s.id, ownerId: auth.userId);
                                  if (mounted) showTGToast(context, context.t(err ?? 'ads_stopped'));
                                },
                                child: Text(context.t('ads_stop_cta'), style: const TextStyle(color: TGColors.error)),
                              ),
                            if (s.status == TGAdSlotStatus.changesRequested)
                              TextButton(onPressed: () => _resubmitDialog(s, auth), child: Text(context.t('ui_banner_fix_cta'))),
                            if (_ads.canCancel(s))
                              TextButton(onPressed: () => _cancel(s, auth), child: Text(context.t('ui_banner_cancel_cta'))),
                          ],
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Sponsored hero slide preview at 1920×600 (desktop) with the production scrim.
class TGBannerPreview extends StatelessWidget {
  const TGBannerPreview({super.key, required this.title, required this.imageUrl, required this.phone});
  final String title;
  final String imageUrl;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${context.t('badge.sponsored')}. $title',
      image: true,
      child: AspectRatio(
        aspectRatio: phone ? 16 / 10 : 1920 / 600,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              TGSmartImage(url: imageUrl, fit: BoxFit.cover),
              const DecoratedBox(decoration: BoxDecoration(gradient: tgBannerScrim)),
              Positioned(
                left: 16,
                top: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(TGRadius.pill),
                    border: Border.all(color: Colors.white70),
                  ),
                  child: Text(
                    context.t('badge.sponsored'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                right: 16,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePicker extends StatelessWidget {
  const _ImagePicker({required this.selected, required this.onPicked});
  final String selected;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 4; i++)
          Semantics(
            button: true,
            selected: selected == TGListingImages.heroSlide(i),
            label: context.t('ui_banner_image_n', {'n': '${i + 1}'}),
            child: InkWell(
              onTap: () => onPicked(TGListingImages.heroSlide(i)),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 96,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected == TGListingImages.heroSlide(i) ? TGColors.cta : TGColors.border,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: TGSmartImage(url: TGListingImages.heroSlide(i), fit: BoxFit.cover),
              ),
            ),
          ),
      ],
    );
  }
}

/// Only the buyer's own active content: restaurant transfers, listings, store / manufacturer page.
class _TargetPicker extends StatelessWidget {
  const _TargetPicker({required this.ownerId, required this.selected, required this.onPicked});
  final String ownerId;
  final String? selected;
  final void Function(String url, TGAdSlotKind kind) onPicked;

  @override
  Widget build(BuildContext context) {
    final restos = RestaurantService.instance.ownedBy(ownerId).where((r) => r.status == RestaurantListingStatus.active).toList();
    final store = TGSellerProfileService.instance.bySellerKey(ownerId);
    final isMaker = ManufacturerDevPick.all.any((m) => m.sellerKey == ownerId && !m.forceInactive);

    return FutureBuilder<List<TGProduct>>(
      future: TGProductService.instance.getAll(),
      builder: (context, snap) {
        final products = (snap.data ?? const <TGProduct>[])
            .where((p) => p.seller.id == ownerId && p.isActive)
            .take(12)
            .toList();
        return Column(
          children: [
            for (final r in restos)
              RadioListTile<String>(
                dense: true,
                value: r.detailPath,
                groupValue: selected,
                title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(context.t('ui_ads_restaurant', {'no': r.listingNo})),
                onChanged: (_) => onPicked(r.detailPath, TGAdSlotKind.restaurantListing),
              ),
            for (final p in products)
              RadioListTile<String>(
                dense: true,
                value: p.detailPath,
                groupValue: selected,
                title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(context.t('ui_ads_listing', {'no': '${p.listingNo ?? p.id}'})),
                onChanged: (_) => onPicked(p.detailPath, TGAdSlotKind.listing),
              ),
            if (store != null)
              RadioListTile<String>(
                dense: true,
                value: store.path,
                groupValue: selected,
                title: Text(store.name),
                subtitle: Text(context.t(isMaker ? 'ui_banner_maker_page' : 'ui_ads_store_page')),
                onChanged: (_) => onPicked(store.path, isMaker ? TGAdSlotKind.manufacturer : TGAdSlotKind.store),
              ),
            if (restos.isEmpty && products.isEmpty && store == null) Text(context.t('ui_ads_no_targets')),
          ],
        );
      },
    );
  }
}
