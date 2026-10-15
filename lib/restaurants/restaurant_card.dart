import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_watermarked_image.dart';
import 'package:twoja_gastromania/tg_models/tg_favorite.dart';
import 'package:twoja_gastromania/tg_services/favorites_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_models/tg_watermark.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_card_title.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_components/tg_user_text.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/restaurants/restaurant_l10n.dart';
import 'package:twoja_gastromania/tg_core/tg_promo_visibility.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

enum RestaurantCardVariant { grid, list, compact }

class RestaurantCard extends StatefulWidget {
  const RestaurantCard({
    super.key,
    required this.listing,
    this.variant = RestaurantCardVariant.grid,
    this.onTap,
    this.promotionTier,
    this.promotionId,
    this.isPromoRepeat = false,
    this.previewAsStandard = false,
  });

  final RestaurantListing listing;
  final RestaurantCardVariant variant;
  final VoidCallback? onTap;
  final PromotionTier? promotionTier;
  final String? promotionId;
  final bool isPromoRepeat;

  /// Draft / wizard / free-preview cards: ignore live promotions and never bold the title.
  final bool previewAsStandard;

  @override
  State<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<RestaurantCard> {
  bool _hover = false;
  bool _fav = false;

  RestaurantListing get r => widget.listing;

  bool get _isFav {
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn) return _fav;
    return TGFavoritesService.instance.isFavorite(auth.userId, FavoriteKind.restaurant, r.id);
  }

  void _toggleFav() {
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn) {
      setState(() => _fav = !_fav);
      return;
    }
    final on = !_isFav;
    TGFavoritesService.instance.setRestaurant(auth.userId, r, on: on);
    RestaurantService.instance.recordFavorite(
      listingId: r.id,
      userId: auth.userId,
      on: on,
      count: auth.userId != r.ownerId && !auth.role.isStaff,
    );
    setState(() {});
  }

  PromotionTier? get _tier {
    if (widget.previewAsStandard) return null;
    if (widget.promotionTier != null) return widget.promotionTier;
    return PromotionService.instance.effectiveRestaurantPromo(r)?.tier;
  }

  String? get _promoId {
    if (widget.promotionId != null) return widget.promotionId;
    return PromotionService.instance.effectiveRestaurantPromo(r)?.id;
  }

  bool get _titleBold {
    final t = _tier;
    return t == PromotionTier.bold || t == PromotionTier.spotlight;
  }

  bool get _neon {
    final t = _tier;
    return t == PromotionTier.glow || t == PromotionTier.spotlight || (r.isPromoted && t == null);
  }

  void _open() {
    final promo = PromotionService.instance.effectiveRestaurantPromo(r);
    tgTrackPromoClick(
      context: context,
      promotionId: _promoId ?? promo?.id,
      ownerId: promo?.ownerId ?? r.ownerId,
    );
    TGAnalytics.track('resto_card_click', {'listingNo': r.listingNo, 'id': r.id});
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    context.go(r.detailPath);
  }

  Future<void> _copyPhone() async {
    await Clipboard.setData(ClipboardData(text: r.phone));
    TGAnalytics.track('resto_call_click', {'listingNo': r.listingNo, 'mode': 'copy'});
    if (!mounted) return;
    showTGToast(context, context.t('ui_phone_copied'), icon: Icons.phone_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = tgReduceMotion(context);
    final body = switch (widget.variant) {
      RestaurantCardVariant.grid => _grid(context, reduce),
      RestaurantCardVariant.list => _list(context, reduce),
      RestaurantCardVariant.compact => _compact(context),
    };
    final promo = PromotionService.instance.effectiveRestaurantPromo(r);
    final trackId = _promoId ?? promo?.id;
    if (trackId == null) return body;
    return TGPromoVisibility(
      onQualified: () => tgTrackPromoImpression(
        context: context,
        promotionId: trackId,
        ownerId: promo?.ownerId ?? r.ownerId,
        isRepeat: widget.isPromoRepeat,
      ),
      child: body,
    );
  }

  Widget _grid(BuildContext context, bool reduce) {
    final theme = FlutterFlowTheme.of(context);
    final neon = _neon;
    final strong = _tier == PromotionTier.spotlight;
    final fill = neon
        ? Color.alphaBlend(const Color(0xFFE91E8C).withValues(alpha: 0.08), TGColors.surface)
        : TGColors.surface;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: reduce ? 0 : 180),
        // Soft lift kept inside the card bounds via clip — avoids bleeding into next homepage section.
        transform: Matrix4.translationValues(0, _hover && !reduce ? -4 : 0, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            width: neon ? 2 : 1,
            color: neon ? Colors.transparent : TGColors.border,
          ),
          gradient: neon
              ? const LinearGradient(colors: [Color(0xFFE91E8C), Color(0xFF14B8A6)])
              : null,
          boxShadow: [
            if (neon) ...[
              BoxShadow(
                color: const Color(0xFFE91E8C).withValues(alpha: strong ? 0.45 : 0.32),
                blurRadius: strong ? 18 : 12,
              ),
              BoxShadow(
                color: const Color(0xFF14B8A6).withValues(alpha: strong ? 0.28 : 0.18),
                blurRadius: strong ? 14 : 10,
              ),
            ],
            if (_hover && !reduce)
              BoxShadow(
                color: (neon ? const Color(0xFFE91E8C) : const Color(0xFF14B8A6)).withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: neon
            ? DecoratedBox(
                decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(14)),
                child: _gridInner(theme),
              )
            : _gridInner(theme),
      ),
    );
  }

  Widget _gridInner(FlutterFlowTheme theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _open,
        focusColor: TGColors.cta.withValues(alpha: 0.15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: WatermarkedImage(url: r.imageUrl, surface: TGImageSurface.listingGrid, cacheWidth: 640),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _pill(restoLocalizedBusinessType(context, r.businessType), const Color(0xFFE91E8C)),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      tooltip: context.t('ui_favourite'),
                      onPressed: _toggleFav,
                      icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border, color: _isFav ? const Color(0xFFE91E8C) : Colors.white),
                    ),
                  ),
                  if (_tier == PromotionTier.glow || _tier == PromotionTier.spotlight || (r.isPromoted && _tier == null))
                    Positioned(left: 10, bottom: 10, child: _featuredPill(context)),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: _pill('${r.photoCount}', Colors.black54, icon: Icons.photo_camera_outlined),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restoLocalizedTitle(context, r),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TGListingCardTitle.style(color: theme.primaryText, paid: _titleBold),
                  ),
                  if (r.venueName != null && r.venueName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    TGUserText(
                      r.venueName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodySmall.override(color: theme.secondaryText.withValues(alpha: 0.75), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 14, color: theme.secondaryText),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          r.district == null || r.district!.isEmpty ? r.city : '${r.city} · ${r.district}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall.override(color: theme.secondaryText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _metricRow(theme),
                  if (r.negotiable) ...[
                    const SizedBox(height: 8),
                    _pill(context.t('ui_negotiable'), theme.alternate),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: _specChips(theme).take(4).toList()),
                  const SizedBox(height: 10),
                  _sellerRow(theme),
                  const SizedBox(height: 8),
                  _phoneRow(theme, desktopCopy: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, bool reduce) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: TGColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _open,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TGColors.border),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 280, height: 210, child: WatermarkedImage(url: r.imageUrl, surface: TGImageSurface.listingCard, cacheWidth: 560)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restoLocalizedTitle(context, r),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TGListingCardTitle.style(color: theme.primaryText, paid: _titleBold),
                    ),
                    const SizedBox(height: 6),
                    TGUserText(r.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(color: theme.secondaryText)),
                    const SizedBox(height: 8),
                    Text(context.t('ui_listing_no', {'n': r.listingNo}), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: _specChips(theme)),
                    const SizedBox(height: 10),
                    _sellerRow(theme),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _metricColumn(theme),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        TGAnalytics.track('resto_call_click', {'listingNo': r.listingNo, 'mode': 'call'});
                        _copyPhone();
                      },
                      style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: TGColors.onCta),
                      child: Semantics(label: '${context.t('ui_call')} ${r.phone}', child: Text(context.t('ui_call'))),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: _open, child: Text(context.t('ui_message'))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compact(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final fee = r.transferFee.isNone
        ? context.t('ui_no_transfer_fee')
        : '${context.t('ui_transfer_fee')} ${NumberFormat.decimalPattern('pl_PL').format(r.transferFee.amountPln ?? 0)}';
    return Material(
      color: TGColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 128,
                  height: 128,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      WatermarkedImage(url: r.imageUrl, surface: TGImageSurface.listingCard, cacheWidth: 256),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: _pill(restoLocalizedBusinessType(context, r.businessType), const Color(0xFFE91E8C), compact: true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restoLocalizedTitle(context, r),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TGListingCardTitle.style(color: Colors.white, paid: _titleBold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_area(r.totalAreaM2)} · ${NumberFormat.decimalPattern('pl_PL').format(r.rentMonthly)} ${context.t('ui_per_month')} · $fee',
                      maxLines: 2,
                      style: theme.bodySmall.override(fontWeight: FontWeight.w600, color: const Color(0xFFE8E8E8)),
                    ),
                    const SizedBox(height: 4),
                    Text(r.city, style: theme.bodySmall.override(color: const Color(0xFFB8B8B8))),
                    Text(
                      r.posterRole == RestaurantPosterRole.owner ? context.t('resto_poster_owner') : context.t('resto_poster_agent'),
                      style: theme.bodySmall.override(fontWeight: FontWeight.w600, color: const Color(0xFFE8E8E8)),
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      label: '${context.t('ui_call')} ${r.phone}',
                      value: r.phone,
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Text(
                                  context.t('ui_call'),
                                  style: theme.bodySmall.override(
                                    fontWeight: FontWeight.w700,
                                    color: theme.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  r.phone,
                                  style: theme.bodySmall.override(
                                    fontWeight: FontWeight.w800,
                                    color: theme.primaryText,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Semantics(
                            label: '${context.t('ui_call')} ${r.phone}',
                            button: true,
                            child: Material(
                              color: TGColors.cta,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _copyPhone,
                                child: const SizedBox(width: 44, height: 44, child: Icon(Icons.phone, color: TGColors.onCta, size: 20)),
                              ),
                            ),
                          ),
                        ],
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
  }

  Widget _metricRow(FlutterFlowTheme theme) {
    return Row(
      children: [
        Expanded(child: _metricBox(theme, context.t('ui_area_label'), _area(r.totalAreaM2), null)),
        const SizedBox(width: 6),
        Expanded(
          child: _metricBox(
            theme,
            context.t('ui_rent_label'),
            '${_pln(r.rentMonthly)} ${context.t('ui_per_month')}',
            _vatLabel(context, r.rentBasis),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _metricBox(
            theme,
            context.t('ui_transfer_fee'),
            r.transferFee.isNone ? context.t('ui_no_transfer_fee') : _pln(r.transferFee.amountPln ?? 0),
            r.transferFee.isNone ? null : _vatLabel(context, r.transferFee.basis),
          ),
        ),
      ],
    );
  }

  Widget _metricColumn(FlutterFlowTheme theme) => Column(
        children: [
          _metricBox(theme, context.t('ui_area_label'), _area(r.totalAreaM2), null, tall: true),
          const SizedBox(height: 6),
          _metricBox(
            theme,
            context.t('ui_rent_label'),
            '${_pln(r.rentMonthly)} ${context.t('ui_per_month')}',
            _vatLabel(context, r.rentBasis),
            tall: true,
          ),
          const SizedBox(height: 6),
          _metricBox(
            theme,
            context.t('ui_transfer_fee'),
            r.transferFee.isNone ? context.t('ui_no_transfer_fee') : _pln(r.transferFee.amountPln ?? 0),
            r.transferFee.isNone ? null : _vatLabel(context, r.transferFee.basis),
            tall: true,
          ),
        ],
      );

  Widget _metricBox(FlutterFlowTheme theme, String label, String value, String? vat, {bool tall = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: tall ? 10 : 8),
      decoration: BoxDecoration(color: theme.primaryBackground, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.bodySmall.override(fontSize: 10, color: theme.secondaryText))),
              if (vat != null) Text(vat, style: theme.bodySmall.override(fontSize: 9, fontWeight: FontWeight.w800, color: theme.secondaryText)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.titleSmall.override(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  List<Widget> _specChips(FlutterFlowTheme theme) {
    final chips = <Widget>[];
    if (r.seats != null && r.seats! > 0) {
      chips.add(_tipChip(theme, context.t('ui_seats_n', {'n': '${r.seats}'})));
    }
    if (r.leaseType == RestaurantLeaseType.indefinite) {
      chips.add(_tipChip(theme, context.t('ui_indefinite_lease')));
    } else if (r.leaseEndsAt != null) {
      chips.add(_tipChip(theme, context.t('ui_lease_until_year', {'y': '${r.leaseEndsAt!.year}'})));
    }
    if ((r.terraceM2 ?? 0) > 0) chips.add(_tipChip(theme, context.t('ui_feat_terrace')));
    if (r.details.garden.hasGarden) chips.add(_tipChip(theme, context.t('ui_garden')));
    final inv = r.inventoryIncludedCount;
    if (inv > 0) chips.add(_tipChip(theme, context.t('ui_items_included_n', {'n': '$inv'})));
    if (r.alcoholPermit.inPlace) chips.add(_tipChip(theme, context.t('ui_alcohol_permit')));
    chips.add(_tipChip(theme, context.t('ui_available_from', {'d': _fmtDay(context, r.availableFrom)})));
    return chips;
  }

  Widget _sellerRow(FlutterFlowTheme theme) {
    // Transfers are individual: show role (+ first name), never a store brand.
    final role = r.posterRole == RestaurantPosterRole.owner
        ? context.t('resto_poster_owner')
        : context.t('resto_poster_agent');
    final roleLabel = role.isEmpty ? (r.posterRole == RestaurantPosterRole.owner ? 'Owner' : 'Agent') : role;
    return Text(
      roleLabel,
      style: theme.bodySmall.override(fontWeight: FontWeight.w700, color: theme.secondaryText),
    );
  }

  Widget _phoneRow(FlutterFlowTheme theme, {required bool desktopCopy}) {
    return Semantics(
      label: '${context.t('ui_call')} ${r.phone}',
      value: r.phone,
      child: InkWell(
        onTap: desktopCopy ? _copyPhone : null,
        child: Row(
          children: [
            Icon(Icons.phone, size: 14, color: theme.secondaryText),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${r.phone} · ${r.city}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall.override(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, {IconData? icon, bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: Colors.white), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: Colors.white, fontSize: compact ? 10 : 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _featuredPill(BuildContext context) {
    final label = context.t('badge.featured');
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFFE91E8C), borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _tipChip(FlutterFlowTheme theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: TGColors.border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: theme.bodySmall.override(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  static String _pln(int v) => NumberFormat.decimalPattern('pl_PL').format(v);
  static String _area(double m2) => '${NumberFormat.decimalPattern('pl_PL').format(m2.round())} m²';
  static String _vatLabel(BuildContext context, RestaurantVatBasis b) => switch (b) {
        RestaurantVatBasis.netto => context.t('ui_netto'),
        RestaurantVatBasis.brutto => context.t('ui_brutto'),
        RestaurantVatBasis.vatUnspecified => context.t('ui_vat_na'),
      };
  static String _fmtDay(BuildContext context, DateTime d) =>
      DateFormat('d MMM', Localizations.localeOf(context).toString()).format(d);
}
