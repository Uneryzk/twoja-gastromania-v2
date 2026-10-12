import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_form.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_ad_slot.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/ad_slot_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

/// `/dashboard/advertising` — Banner ad purchase + reporting (RESTO-5).
class AdvertisingPage extends StatefulWidget {
  const AdvertisingPage({super.key, this.prefillTarget});

  static const routeName = 'Advertising';
  static const routePath = '/dashboard/advertising';

  final String? prefillTarget;

  @override
  State<AdvertisingPage> createState() => _AdvertisingPageState();
}

class _AdvertisingPageState extends State<AdvertisingPage> {
  int _step = 0; // 0 content · 1 preview · 2 pay · 3 done
  final _title = TextEditingController();
  String _imageUrl = TGListingImages.heroSlide(2);
  String? _targetUrl;
  TGAdSlotKind _kind = TGAdSlotKind.restaurantListing;
  DateTime _startsAt = TGClock.now();
  bool _useEntitlement = false;
  bool _paying = false;
  final _formKey = GlobalKey<PaymentFormState>();
  TGAdSlot? _submitted;

  @override
  void initState() {
    super.initState();
    AdSlotService.instance.ensureSeeded();
    if (widget.prefillTarget != null && widget.prefillTarget!.startsWith('/')) {
      _targetUrl = widget.prefillTarget;
      if (_targetUrl!.startsWith('/restaurants/')) {
        _kind = TGAdSlotKind.restaurantListing;
      } else if (_targetUrl!.startsWith('/seller/')) {
        _kind = TGAdSlotKind.store;
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final ads = AdSlotService.instance;
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final theme = FlutterFlowTheme.of(context);

    if (!ads.purchaseVisible) {
      return TGPageScaffold(
        body: Column(
          children: [
            const TGTopNav(),
            Expanded(
              child: Center(
                child: TextButton(
                  onPressed: () => context.go('/dashboard/listings'),
                  child: Text(context.t('ui_ads_back_listings')),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final owned = ads.ownedBy(auth.userId);
    final entitlementLeft = ads.enterpriseRemaining(auth.userId);
    final price = _useEntitlement && ads.canUseEnterpriseEntitlement(auth.userId) ? 0 : ads.pricePln;

    Widget body;
    if (phone) {
      body = _step == 0
          ? _contentStep(theme, auth, entitlementLeft, phone: true)
          : _step == 1
              ? _previewStep(theme, phone: true)
              : _step == 2
                  ? _payStep(theme, price, auth)
                  : _doneStep(theme);
    } else {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _step <= 1
                ? (_step == 0 ? _contentStep(theme, auth, entitlementLeft, phone: false) : _previewStep(theme, phone: false))
                : (_step == 2 ? _payStep(theme, price, auth) : _doneStep(theme)),
          ),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: _reportPanel(theme, owned)),
        ],
      );
    }

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
                        Text(context.t('ui_ads_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(
                          context.t('ui_ads_reach_note'),
                          style: theme.bodyMedium.override(color: theme.secondaryText),
                        ),
                        if (phone) ...[
                          const SizedBox(height: 12),
                          _stepDots(theme),
                        ],
                        const SizedBox(height: 18),
                        body,
                        if (phone && owned.isNotEmpty && _step == 0) ...[
                          const SizedBox(height: 28),
                          _reportPanel(theme, owned),
                        ],
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
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              decoration: BoxDecoration(
                color: i <= _step ? theme.primary : theme.alternate,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
      ],
    );
  }

  Widget _contentStep(FlutterFlowTheme theme, FakeAuthState auth, int entitlementLeft, {required bool phone}) {
    final ads = AdSlotService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_ads_banner_content'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(context.t('ui_ads_image_hint'), style: theme.bodySmall),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          maxLength: 60,
          decoration: InputDecoration(labelText: context.t('ui_ads_title_field')),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(context.t('ui_ads_image'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 4; i++)
              GestureDetector(
                onTap: () => setState(() => _imageUrl = TGListingImages.heroSlide(i)),
                child: Container(
                  width: 96,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _imageUrl == TGListingImages.heroSlide(i) ? TGColors.cta : TGColors.border, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: TGSmartImage(url: TGListingImages.heroSlide(i), fit: BoxFit.cover),
                ),
              ),
          ],
        ),
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
        const SizedBox(height: 14),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('ui_ads_start_date')),
          subtitle: Text(DateFormat('d MMM yyyy').format(_startsAt)),
          trailing: TextButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _startsAt,
                firstDate: TGClock.now(),
                lastDate: TGClock.now().add(const Duration(days: 60)),
              );
              if (d != null) setState(() => _startsAt = d);
            },
            child: Text(context.t('ui_ads_change')),
          ),
        ),
        if (ads.canUseEnterpriseEntitlement(auth.userId) || entitlementLeft > 0)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('ui_ads_use_entitlement', {'n': '$entitlementLeft'})),
            subtitle: Text(context.t('ui_ads_entitlement_sub')),
            value: _useEntitlement && ads.canUseEnterpriseEntitlement(auth.userId),
            onChanged: (v) => setState(() => _useEntitlement = v),
          ),
        const SizedBox(height: 16),
        TGButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) {
              showTGToast(context, context.t('ui_ads_title_required'));
              return;
            }
            if (_targetUrl == null) {
              showTGToast(context, context.t('ui_ads_pick_target'));
              return;
            }
            setState(() => _step = 1);
          },
          label: context.t('ui_ads_preview'),
          height: 48,
          borderRadius: BorderRadius.circular(TGRadius.pill),
        ),
      ],
    );
  }

  Widget _previewStep(FlutterFlowTheme theme, {required bool phone}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_ads_preview'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: phone ? 16 / 10 : 1920 / 600,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                TGSmartImage(url: _imageUrl, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xE0121212), Color(0x00000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(TGRadius.pill),
                      border: Border.all(color: Colors.white70),
                    ),
                    child: Text(context.t('ui_sponsored'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  right: 16,
                  child: Text(
                    _title.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(context.t('ui_ads_target_label', {'url': _targetUrl ?? ''}), style: theme.bodySmall),
        Text(
          context.t('ui_ads_duration', {'date': DateFormat('d MMM yyyy').format(_startsAt.add(const Duration(days: 14)))}),
          style: theme.bodySmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            TextButton(onPressed: () => setState(() => _step = 0), child: Text(context.t('ui_ads_back'))),
            const Spacer(),
            TGButton(
              onPressed: () => setState(() => _step = 2),
              label: context.t('ui_ads_continue_payment'),
              height: 44,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
          ],
        ),
      ],
    );
  }

  Widget _payStep(FlutterFlowTheme theme, int price, FakeAuthState auth) {
    final free = price <= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          free ? context.t('ui_ads_confirm_entitlement') : context.t('ui_ads_payment', {'price': '$price'}),
          style: theme.titleMedium.override(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          context.t('ui_ads_reach_note'),
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
            onWaitingChanged: (v) => setState(() => _paying = v),
            onPaid: () => _submit(auth),
          ),
        if (_paying) const SizedBox(height: 8),
        TextButton(onPressed: _paying ? null : () => setState(() => _step = 1), child: Text(context.t('ui_ads_back'))),
      ],
    );
  }

  void _submit(FakeAuthState auth) {
    try {
      final slot = AdSlotService.instance.purchaseAndSubmit(
        ownerId: auth.userId,
        kind: _kind,
        targetUrl: _targetUrl!,
        title: _title.text.trim(),
        imageUrl: _imageUrl,
        startsAt: _startsAt,
        useEnterpriseEntitlement: _useEntitlement,
      );
      setState(() {
        _submitted = slot;
        _step = 3;
      });
    } catch (e) {
      showTGToast(context, e.toString());
    }
  }

  Widget _doneStep(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_ads_submitted'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          context.t('ui_ads_submitted_body', {'id': _submitted?.id ?? ''}),
          style: theme.bodyMedium,
        ),
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

  Widget _reportPanel(FlutterFlowTheme theme, List<TGAdSlot> owned) {
    return Material(
      color: TGColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: TGColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('ui_ads_your_banners'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              context.t('ui_ads_reach_note'),
              style: theme.bodySmall.override(color: theme.secondaryText),
            ),
            const SizedBox(height: 12),
            if (owned.isEmpty)
              Text(context.t('ui_ads_none'), style: theme.bodySmall)
            else
              for (final s in owned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        context.t('ui_ads_stats', {
                          'status': s.status.name,
                          'impressions': '${s.impressions}',
                          'clicks': '${s.clicks}',
                        }),
                        style: theme.bodySmall,
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

class _TargetPicker extends StatelessWidget {
  const _TargetPicker({required this.ownerId, required this.selected, required this.onPicked});
  final String ownerId;
  final String? selected;
  final void Function(String url, TGAdSlotKind kind) onPicked;

  @override
  Widget build(BuildContext context) {
    final restos = RestaurantService.instance.ownedBy(ownerId).where((r) => r.status == RestaurantListingStatus.active).toList();
    final store = TGSellerProfileService.instance.bySellerKey(ownerId);

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
                onChanged: (_) => onPicked(p.detailPath, TGAdSlotKind.custom),
              ),
            if (store != null)
              RadioListTile<String>(
                dense: true,
                value: store.path,
                groupValue: selected,
                title: Text(store.name),
                subtitle: Text(context.t('ui_ads_store_page')),
                onChanged: (_) => onPicked(store.path, TGAdSlotKind.store),
              ),
            if (restos.isEmpty && products.isEmpty && store == null)
              Text(context.t('ui_ads_no_targets')),
          ],
        );
      },
    );
  }
}
