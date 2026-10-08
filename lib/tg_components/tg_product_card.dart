import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_hover_card.dart';
import 'package:twoja_gastromania/tg_components/tg_listing_no_line.dart';
import 'package:twoja_gastromania/tg_core/tg_contact.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

export 'package:twoja_gastromania/tg_models/tg_product.dart' show TGProductCardLayout;

/// Height of the text block under the image of a grid card (at text scale 1).
const double kTGGridInfoHeight = 206;

/// Fixed heights of the list variants (inner content height + padding).
const double kTGListWideHeight = 228;
const double kTGListCompactHeight = 228;

/// Below this available width the list layout switches to the compact row.
const double kTGListWideMinWidth = 720;

/// Text scaling is clamped inside cards so the fixed extents below stay valid
/// for users with large system fonts.
const double _kMaxCardTextScale = 1.25;

/// Vertical room reserved for the card frame (border / gradient ring).
const double _kFrameSlack = 3;

double _cardScale(TextScaler scaler) => scaler.scale(1).clamp(1.0, _kMaxCardTextScale);

/// A marketplace listing card.
///
/// Layouts:
///  * [TGProductCardLayout.grid]  – vertical card, fixed extent
///    (see [TGProductCard.gridExtent]) so it works inside grids and lists alike;
///  * [TGProductCardLayout.list]  – horizontal row (wide or compact depending on
///    the width it is given).
///
/// Micro-interactions shared by all variants: hover/focus lifts the card by
/// [TGMotion.hoverLift] px with a turquoise glow; tapping the phone number
/// copies it and shows a "Number copied" toast.
class TGProductCard extends StatefulWidget {
  const TGProductCard({
    super.key,
    required this.product,
    this.layout = TGProductCardLayout.grid,
    this.onFavoriteChanged,
    this.showSeller = true,
  });

  final TGProduct product;
  final TGProductCardLayout layout;
  final ValueChanged<bool>? onFavoriteChanged;
  final bool showSeller;

  /// Total height of a grid card that is [cardWidth] wide.
  ///
  /// The image height follows the card's *inner* width (the 1 px border, or the
  /// 1.5 px gradient frame of promoted cards, is subtracted on both sides), so a
  /// few pixels of slack are added to keep the cell from ever being too short.
  static double gridExtent(double cardWidth, TextScaler scaler, {bool showSeller = true}) =>
      cardWidth * 3 / 4 + (showSeller ? kTGGridInfoHeight : kTGGridInfoHeight - 28) * _cardScale(scaler) + _kFrameSlack;

  /// Height of the list card for the given available width.
  static double listExtent(double availableWidth) =>
      availableWidth >= kTGListWideMinWidth ? kTGListWideHeight : kTGListCompactHeight;

  @override
  State<TGProductCard> createState() => _TGProductCardState();
}

class _TGProductCardState extends State<TGProductCard> with SingleTickerProviderStateMixin {
  bool _favorite = false;

  late final AnimationController _favController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void dispose() {
    _favController.dispose();
    super.dispose();
  }

  void _open() => context.push(widget.product.detailPath);

  Future<void> _toggleFavorite() async {
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => const _LoginRequiredSheet(),
      );
      return;
    }

    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    setState(() => _favorite = !_favorite);
    if (reduceMotion) {
      _favController.value = _favorite ? 1 : 0;
    } else if (_favorite) {
      _favController.forward(from: 0);
    } else {
      _favController.reverse(from: 1);
    }
    widget.onFavoriteChanged?.call(_favorite);
    if (!mounted) return;
    showTGToast(
      context,
      _favorite ? 'Saved to favorites' : 'Removed from favorites',
      icon: _favorite ? Icons.favorite : Icons.favorite_border,
      iconColor: TGColors.accent,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animateNowy =
        !reduceMotion && product.condition == TGCondition.newItem && _NowyRibbonSession.shouldAnimate(product.id);

    final fav = _FavoriteButton(active: _favorite, controller: _favController, onPressed: _toggleFavorite);

    Widget body;
    if (widget.layout == TGProductCardLayout.grid) {
      body = _GridBody(product: product, favorite: fav, animateNowy: animateNowy, showSeller: widget.showSeller);
    } else {
      body = LayoutBuilder(
        builder: (context, c) => c.maxWidth >= kTGListWideMinWidth
            ? _WideListBody(product: product, favorite: fav, animateNowy: animateNowy, onOpen: _open, showSeller: widget.showSeller)
            : _CompactListBody(product: product, favorite: fav, animateNowy: animateNowy, showSeller: widget.showSeller),
      );
    }

    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1,
      maxScaleFactor: _kMaxCardTextScale,
      child: TGHoverCard(gradientBorder: product.isPromoted, onTap: _open, semanticLabel: product.title, child: body),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid layout
// ---------------------------------------------------------------------------

class _GridBody extends StatelessWidget {
  const _GridBody({required this.product, required this.favorite, required this.animateNowy, this.showSeller = true});

  final TGProduct product;
  final Widget favorite;
  final bool animateNowy;
  final bool showSeller;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final scale = _cardScale(MediaQuery.textScalerOf(context));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ProductImage(imageUrl: product.imageUrl),
              Positioned(top: 10, left: 10, child: _ConditionPill(condition: product.condition, animateIn: animateNowy)),
              Positioned(top: 10, right: 10, child: favorite),
              if (product.isPromoted) const Positioned(left: 10, bottom: 10, child: _PromotedPill()),
              if (product.status == TGListingStatus.expired)
                Positioned(left: 10, bottom: product.isPromoted ? 42 : 10, child: const _InactivePill()),
              Positioned(right: 10, bottom: 10, child: _PhotoCountPill(count: product.photoCount)),
            ],
          ),
        ),
        SizedBox(
          height: (showSeller ? kTGGridInfoHeight : kTGGridInfoHeight - 28) * scale,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleMedium.override(fontSize: 16, fontWeight: FontWeight.w600, lineHeight: 1.3),
                ),
                const SizedBox(height: 8),
                _PriceRow(product: product),
                const SizedBox(height: 8),
                _SpecChips(product: product),
                const Spacer(),
                if (showSeller) ...[
                  _SellerLine(product: product),
                  const SizedBox(height: 6),
                ],
                _ContactRow(product: product),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// List layouts
// ---------------------------------------------------------------------------

class _WideListBody extends StatelessWidget {
  const _WideListBody({required this.product, required this.favorite, required this.animateNowy, required this.onOpen, this.showSeller = true});

  final TGProduct product;
  final Widget favorite;
  final bool animateNowy;
  final VoidCallback onOpen;
  final bool showSeller;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      height: kTGListWideHeight,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 248,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProductImage(imageUrl: product.imageUrl),
                    Positioned(top: 10, left: 10, child: _ConditionPill(condition: product.condition, animateIn: animateNowy)),
                    Positioned(top: 10, right: 10, child: favorite),
                    if (product.isPromoted) const Positioned(left: 10, bottom: 10, child: _PromotedPill()),
                    if (product.status == TGListingStatus.expired)
                      Positioned(left: 10, bottom: product.isPromoted ? 42 : 10, child: const _InactivePill()),
                    Positioned(right: 10, bottom: 10, child: _PhotoCountPill(count: product.photoCount)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.titleLarge.override(fontWeight: FontWeight.w700, lineHeight: 1.2),
                  ),
                  const SizedBox(height: 4),
                  TGListingNoPlain(product: product),
                  const SizedBox(height: 6),
                  Text(
                    product.description ?? '—',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyMedium.override(color: theme.secondaryText, lineHeight: 1.45),
                  ),
                  const SizedBox(height: 10),
                  _SpecChips(product: product),
                  const Spacer(),
                  Row(
                    children: [
                      if (showSeller) Expanded(flex: 3, child: _SellerLine(product: product)),
                      if (showSeller) const SizedBox(width: 12),
                      Flexible(flex: 2, child: _CityLink(product: product)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 196,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PriceRow(product: product, alignEnd: true),
                  const Spacer(),
                  Align(alignment: Alignment.centerRight, child: _PhoneLink(phone: product.phone)),
                  const SizedBox(height: 8),
                  _GhostCTAButton(label: 'View listing', icon: Icons.arrow_forward_rounded, onPressed: onOpen),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactListBody extends StatelessWidget {
  const _CompactListBody({required this.product, required this.favorite, required this.animateNowy, this.showSeller = true});

  final TGProduct product;
  final Widget favorite;
  final bool animateNowy;
  final bool showSeller;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      height: kTGListCompactHeight,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 116,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _ProductImage(imageUrl: product.imageUrl),
                        Positioned(top: 8, left: 8, child: _ConditionPill(condition: product.condition, compact: true, animateIn: animateNowy)),
                        if (product.isPromoted) const Positioned(left: 6, bottom: 6, child: _PromotedPill(compact: true)),
                        if (product.status == TGListingStatus.expired)
                          const Positioned(left: 6, bottom: 6, child: _InactivePill(compact: true)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 32),
                        child: Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleSmall.override(fontWeight: FontWeight.w700, lineHeight: 1.2),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.only(right: 32),
                        child: TGListingNoPlain(product: product),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(right: 32),
                        child: _PriceRow(product: product, compact: true),
                      ),
                      const Spacer(),
                      if (showSeller) ...[
                        _SellerLine(product: product, compact: true),
                        const SizedBox(height: 2),
                      ],
                      _CityLink(product: product, alignEnd: false),
                      const SizedBox(height: 2),
                      _CompactFulfillment(product: product),
                      const SizedBox(height: 4),
                      _PhoneLink(phone: product.phone),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(top: 8, right: 8, child: favorite),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext c, Object e, StackTrace? s) => _imageFallback(c);
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, fit: BoxFit.cover, cacheWidth: 720, errorBuilder: fallback);
    }
    if (imageUrl.startsWith('assets/')) {
      // `cacheWidth` keeps big source files (some are ~3 MB) cheap to decode.
      return Image.asset(imageUrl, fit: BoxFit.cover, cacheWidth: 720, gaplessPlayback: true, errorBuilder: fallback);
    }
    return _imageFallback(context);
  }

  Widget _imageFallback(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      color: theme.alternate,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: theme.secondaryText, size: 28),
    );
  }
}

class _ConditionPill extends StatelessWidget {
  const _ConditionPill({required this.condition, this.animateIn = false, this.compact = false});
  final TGCondition condition;
  final bool animateIn;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isNew = condition == TGCondition.newItem;
    final pill = Container(
      padding: compact ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5) : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isNew ? theme.primary : theme.alternate,
        borderRadius: BorderRadius.circular(TGRadius.pill),
        border: Border.all(color: theme.tertiary.withValues(alpha: 0.65), width: 1),
      ),
      child: Text(
        conditionLabel(condition, t: (k) => context.t(k)),
        style: theme.labelSmall.override(
          color: isNew ? TGColors.onCta : theme.primaryText,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );

    if (!animateIn) return pill;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: 1 - (t * 0.6),
        child: Transform.translate(offset: Offset(-18 * t, 0), child: child),
      ),
      child: pill,
    );
  }
}

/// Plays the "NOWY" slide-in for the first few cards of a session only.
class _NowyRibbonSession {
  static const _max = 8;
  static int _count = 0;
  static final Set<String> _seen = <String>{};

  static bool shouldAnimate(String id) {
    if (_seen.contains(id)) return false;
    if (_count >= _max) return false;
    _seen.add(id);
    _count++;
    return true;
  }
}

class _PhotoCountPill extends StatelessWidget {
  const _PhotoCountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(TGRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined, size: 14, color: theme.primaryText),
          const SizedBox(width: 6),
          Text('$count', style: theme.labelSmall.override(color: theme.primaryText, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _InactivePill extends StatelessWidget {
  const _InactivePill({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: compact ? const EdgeInsets.symmetric(horizontal: 7, vertical: 4) : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.tertiary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(TGRadius.pill),
      ),
      child: Text(
        context.t('ui_inactive'),
        style: theme.labelSmall.override(color: theme.secondaryText, fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    );
  }
}

/// Pink "promoted" badge (design token: accent).
class _PromotedPill extends StatelessWidget {
  const _PromotedPill({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(color: theme.secondary, borderRadius: BorderRadius.circular(TGRadius.pill)),
      child: Text(
        context.t('ui_promoted_badge'),
        style: theme.labelSmall.override(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: compact ? 0.1 : 0.4,
          fontSize: compact ? 9 : 11,
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.active, required this.controller, required this.onPressed});

  final bool active;
  final AnimationController controller;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      button: true,
      label: active ? 'Remove from favorites' : 'Save to favorites',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = Curves.easeOutBack.transform(controller.value);
            return Transform.scale(
              scale: 1 + 0.20 * t,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.secondaryBackground.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                  border: Border.all(color: theme.tertiary.withValues(alpha: 0.55), width: 1),
                ),
                child: Icon(
                  active ? Icons.favorite : Icons.favorite_border,
                  color: active ? theme.secondary : theme.primaryText,
                  size: 18,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Price line. Everything price-related lives inside one scale-down box so it
/// can never overflow the (narrow) card, regardless of discounts or tags.
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product, this.alignEnd = false, this.compact = false});

  final TGProduct product;
  final bool alignEnd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final hasPrice = product.price != null;
    final discounted = hasPrice && product.oldPrice != null && product.oldPrice! > product.price!;
    final unitSuffix = (hasPrice && product.listingType == TGListingType.rent) ? ' / mies.' : '';

    final priceText = hasPrice ? '${formatPln(product.price!)}$unitSuffix' : 'Zapytaj o cenę';
    final priceStyle = theme.titleLarge.override(
      fontSize: compact ? 18 : (hasPrice ? 22 : 18),
      fontWeight: FontWeight.w800,
      lineHeight: 1.0,
      color: hasPrice ? theme.primaryText : theme.secondaryText,
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(priceText, maxLines: 1, style: priceStyle),
        if (discounted) ...[
          const SizedBox(width: 8),
          Text(
            formatPln(product.oldPrice!),
            style: theme.bodySmall.override(
              color: theme.secondaryText,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.local_fire_department, color: theme.secondary, size: 15),
          Text(
            '-${discountPercent(product.oldPrice!, product.price!).toStringAsFixed(0)}%',
            style: theme.bodySmall.override(color: theme.secondary, fontWeight: FontWeight.w800),
          ),
        ],
        if (hasPrice) ...[
          const SizedBox(width: 8),
          _BasisTag(label: product.priceBasis == TGPriceBasis.brutto ? 'BRUTTO' : 'NETTO'),
        ],
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: content,
      ),
    );
  }
}

class _BasisTag extends StatelessWidget {
  const _BasisTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.alternate,
        borderRadius: BorderRadius.circular(TGRadius.pill),
        border: Border.all(color: theme.tertiary.withValues(alpha: 0.55), width: 1),
      ),
      child: Text(label, style: theme.labelSmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700)),
    );
  }
}

/// Specification chips. Rendered in a fixed-height clipped [Wrap] so that only
/// the chips that fit are shown (never half a chip, never an overflow).
class _SpecChips extends StatelessWidget {
  const _SpecChips({required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: double.infinity,
      child: Wrap(
        clipBehavior: Clip.hardEdge,
        spacing: 6,
        runSpacing: 12,
        children: [
          _InlineSpecChip(icon: _powerIcon(product.powerType), label: _powerLabel(context, product.powerType)),
          if (_fulfillmentChip(context, product) case final chip?) chip,
          if (product.warrantyMonths > 0)
            _InlineSpecChip(icon: Icons.verified_outlined, label: context.t('ui_n_months', {'n': '${product.warrantyMonths}'})),
          if (product.negotiable) _InlineSpecChip(icon: Icons.handshake_outlined, label: context.t('ui_negotiable')),
        ],
      ),
    );
  }
}

class _InlineSpecChip extends StatelessWidget {
  const _InlineSpecChip({this.icon, this.leading, required this.label})
      : assert(icon != null || leading != null);
  final IconData? icon;
  final Widget? leading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: theme.alternate,
        borderRadius: BorderRadius.circular(theme.designToken.radius.chip),
        border: Border.all(color: theme.tertiary.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading ?? Icon(icon, size: 15, color: theme.secondaryText),
          const SizedBox(width: 6),
          Text(label, maxLines: 1, style: theme.bodySmall.override(color: theme.primaryText, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Store-with-pin glyph, tinted to match spec-chip icons.
class _PickupStoreIcon extends StatelessWidget {
  const _PickupStoreIcon({this.size = 15});
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = FlutterFlowTheme.of(context).secondaryText;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      child: Image.asset(
        TGAssets.pickupStore,
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );
  }
}

/// Seller name + rating. A green shield marks verified sellers (token: verified).
class _SellerLine extends StatelessWidget {
  const _SellerLine({required this.product, this.compact = false});
  final TGProduct product;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final seller = product.seller;
    final typeLabel = seller.type == TGSellerType.private ? context.t('ui_private') : context.t('ui_store');
    final name = seller.name.trim().isEmpty ? typeLabel : seller.name;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(TGSellerProfileService.instance.pathForSellerId(seller.id)),
      child: Row(
        children: [
          if (seller.verified) ...[
            Tooltip(
              message: 'Verified seller',
              child: Icon(Icons.verified_user, size: 16, color: theme.success),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: compact
                ? Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall.override(fontWeight: FontWeight.w700),
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: name, style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                        TextSpan(
                          text: ' · $typeLabel',
                          style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          if (!compact) ...[
            const SizedBox(width: 8),
            Icon(Icons.star_rounded, color: theme.warning, size: 18),
            const SizedBox(width: 2),
            Text(
              seller.rating.toStringAsFixed(1),
              style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

/// Phone number (tap = copy + "Number copied" toast) and city (tap = filter by city).
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 3, child: _PhoneLink(phone: product.phone)),
        const SizedBox(width: 10),
        Flexible(flex: 2, child: _CityLink(product: product)),
      ],
    );
  }
}

class _PhoneLink extends StatelessWidget {
  const _PhoneLink({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      button: true,
      label: 'Copy phone number $phone',
      child: Tooltip(
        message: 'Click to copy',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => copyPhoneNumber(context, phone),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.call, size: 16, color: theme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    phone,
                    maxLines: 1,
                    softWrap: false,
                    style: theme.bodySmall.override(color: theme.primaryText, fontWeight: FontWeight.w700),
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

class _CityLink extends StatelessWidget {
  const _CityLink({required this.product, this.alignEnd = true});
  final TGProduct product;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Tapping a city narrows the catalogue to that city.
      onTap: () => context.go(TGProductsQueryState(city: product.city).toLocation()),
      child: Row(
        mainAxisSize: alignEnd ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, size: 16, color: theme.secondaryText),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              product.city,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactFulfillment extends StatelessWidget {
  const _CompactFulfillment({required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget line({required Widget icon, required String label}) {
      return Row(
        children: [
          icon,
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    final rows = <Widget>[
      if (product.pickup && product.delivery)
        line(
          icon: Icon(Icons.swap_horiz, size: 14, color: theme.secondaryText),
          label: context.t('ui_buyer_choice'),
        )
      else if (product.pickup)
        line(icon: const _PickupStoreIcon(size: 14), label: context.t('ui_pickup'))
      else if (product.delivery)
        line(
          icon: Icon(Icons.local_shipping_outlined, size: 14, color: theme.secondaryText),
          label: context.t('ui_shipping'),
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          rows[i],
        ],
      ],
    );
  }
}

class _GhostCTAButton extends StatelessWidget {
  const _GhostCTAButton({required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.designToken.radius.input),
            border: Border.all(color: theme.tertiary, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: theme.primaryText),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall.override(color: theme.primaryText, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginRequiredSheet extends StatelessWidget {
  const _LoginRequiredSheet();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final safe = MediaQuery.paddingOf(context);
    return GestureDetector(
      onTap: () => context.pop(),
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + safe.bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 520),
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                borderRadius: BorderRadius.circular(TGRadius.modal),
                border: Border.all(color: theme.tertiary, width: 1),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(TGRadius.input),
                          border: Border.all(color: theme.primary.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Icon(Icons.lock_outline, color: theme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Login required', style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
                      GestureDetector(onTap: () => context.pop(), child: Icon(Icons.close, color: theme.secondaryText)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Please log in to save listings to favorites.',
                    style: theme.bodyMedium.override(color: theme.secondaryText, lineHeight: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(TGRadius.pill),
                              border: Border.all(color: theme.tertiary, width: 1),
                            ),
                            child: Text('Not now', style: theme.titleSmall.override(color: theme.primaryText, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            context.pop();
                            context.goNamed(LoginPageWidget.routeName);
                          },
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: theme.primary, borderRadius: BorderRadius.circular(TGRadius.pill)),
                            child: Text('Login', style: theme.titleSmall.override(color: theme.primaryBtnText, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Formatting helpers (shared with the products page)
// ---------------------------------------------------------------------------

String formatPln(int value) => '${NumberFormat.decimalPattern('pl_PL').format(value)} PLN';

double discountPercent(int oldPrice, int newPrice) {
  if (oldPrice <= 0) return 0;
  return ((oldPrice - newPrice) / oldPrice) * 100;
}

IconData _powerIcon(TGPowerType powerType) => switch (powerType) {
      TGPowerType.gas => Icons.local_fire_department_outlined,
      TGPowerType.other => Icons.extension_outlined,
      TGPowerType.electric => Icons.bolt_outlined,
    };

String _powerLabel(BuildContext context, TGPowerType powerType) => switch (powerType) {
      TGPowerType.gas => context.t('ui_gas'),
      TGPowerType.other => context.t('ui_other'),
      TGPowerType.electric => context.t('ui_electric'),
    };

Widget? _fulfillmentChip(BuildContext context, TGProduct product) {
  if (product.pickup && product.delivery) {
    return _InlineSpecChip(icon: Icons.swap_horiz, label: context.t('ui_buyer_choice'));
  }
  if (product.pickup) {
    return _InlineSpecChip(leading: const _PickupStoreIcon(), label: context.t('ui_pickup'));
  }
  if (product.delivery) {
    return _InlineSpecChip(icon: Icons.local_shipping_outlined, label: context.t('ui_shipping'));
  }
  return null;
}

// ---------------------------------------------------------------------------
// Skeletons (same extents as the real cards so nothing jumps on load)
// ---------------------------------------------------------------------------

class TGProductCardSkeleton extends StatelessWidget {
  const TGProductCardSkeleton({super.key, this.layout = TGProductCardLayout.grid});
  final TGProductCardLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final r = theme.designToken.radius.card;
    final block = theme.alternate;

    Widget bar(double h, {double? w}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(6)),
        );

    final Widget content = layout == TGProductCardLayout.grid
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(aspectRatio: 4 / 3, child: Container(color: block)),
              SizedBox(
                height: kTGGridInfoHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(14),
                      const SizedBox(height: 8),
                      bar(14, w: 150),
                      const SizedBox(height: 14),
                      bar(22, w: 130),
                      const SizedBox(height: 14),
                      Row(children: [bar(26, w: 70), const SizedBox(width: 8), bar(26, w: 70)]),
                      const Spacer(),
                      bar(12, w: 170),
                      const SizedBox(height: 10),
                      bar(12, w: 120),
                    ],
                  ),
                ),
              ),
            ],
          )
        : SizedBox(
            height: kTGListCompactHeight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(width: 116, decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(12))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [bar(14), const SizedBox(height: 8), bar(14, w: 120), const SizedBox(height: 14), bar(20, w: 110)],
                    ),
                  ),
                ],
              ),
            ),
          );

    return TGShimmer(
      borderRadius: BorderRadius.circular(r),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: theme.tertiary, width: 1),
          ),
          child: content,
        ),
      ),
    );
  }
}

class TGShimmer extends StatefulWidget {
  const TGShimmer({super.key, required this.child, required this.borderRadius});
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<TGShimmer> createState() => _TGShimmerState();
}

class _TGShimmerState extends State<TGShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dx = (_controller.value * 2 - 1) * 0.9;
        final highlight = theme.primaryText.withValues(alpha: 0.10);
        final base = theme.primaryText.withValues(alpha: 0.04);
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1 + dx, -0.2),
            end: Alignment(1 + dx, 0.2),
            colors: [base, highlight, base],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds),
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
