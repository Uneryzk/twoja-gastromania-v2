import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/dash2_widgets.dart';
import 'package:twoja_gastromania/dashboard/dashboard_shell.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_watermarked_image.dart';
import 'package:twoja_gastromania/tg_models/tg_watermark.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_favorite.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/favorites_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key, this.tab});

  static const routeName = 'DashboardFavorites';
  static const routePath = '/dashboard/favorites';

  /// `equipment` (default) | `restaurants`.
  final String? tab;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  Map<String, TGProduct> _catalogue = const {};
  bool _loaded = false;

  FavoriteKind get _kind => widget.tab == 'restaurants' ? FavoriteKind.restaurant : FavoriteKind.equipment;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await TGProductService.instance.getAll();
    if (!mounted) return;
    setState(() {
      _catalogue = {
        for (final p in all) p.id: p,
        for (final p in ModerationService.instance.sellerListings) p.id: p,
      };
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      current: 'favorites',
      child: ListenableBuilder(
        listenable: Listenable.merge([TGFavoritesService.instance, TGPriceHistoryService.instance, RestaurantService.instance]),
        builder: (context, _) {
          final theme = FlutterFlowTheme.of(context);
          final auth = context.watch<FakeAuthState>();
          final favs = TGFavoritesService.instance.forUser(auth.userId, kind: _kind);
          final width = MediaQuery.sizeOf(context).width;
          final cols = width >= TGBreakpoints.desktop ? 2 : 1;
          return Column(
            key: const Key('favorites-page'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(context.t('dash_favorites_title'), style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in const [('equipment', 'dash_fav_tab_equipment'), ('restaurants', 'dash_fav_tab_restaurants')])
                    ChoiceChip(
                      key: Key('fav-tab-${t.$1}'),
                      label: Text(context.t(t.$2)),
                      selected: (widget.tab == 'restaurants' ? 'restaurants' : 'equipment') == t.$1,
                      onSelected: (_) => context.go('${FavoritesPage.routePath}?tab=${t.$1}'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_loaded && _kind == FavoriteKind.equipment)
                const DashSkeletonLine()
              else if (favs.isEmpty)
                Text(context.t('dash_favorites_empty'), key: const Key('favorites-empty'), style: theme.bodyMedium.override(color: theme.secondaryText))
              else
                LayoutBuilder(
                  builder: (context, c) {
                    const gap = 12.0;
                    final w = (c.maxWidth - gap * (cols - 1)) / cols;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final f in favs) SizedBox(width: w, child: _FavCard(fav: f, live: _resolve(f))),
                      ],
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  /// Live state of the saved listing: (active, current price).
  ({bool active, int? price}) _resolve(TGFavorite f) {
    if (f.kind == FavoriteKind.restaurant) {
      final r = RestaurantService.instance.byId(f.listingId);
      return (active: r != null && r.status == RestaurantListingStatus.active && !r.isHidden, price: r?.rentMonthly ?? f.priceAtSave);
    }
    final p = _catalogue[f.listingId];
    return (active: p != null && p.isActive, price: p?.price ?? f.priceAtSave);
  }
}

class DashSkeletonLine extends StatelessWidget {
  const DashSkeletonLine({super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        decoration: BoxDecoration(color: TGColors.surface, borderRadius: BorderRadius.circular(TGRadius.card)),
      );
}

class _FavCard extends StatelessWidget {
  const _FavCard({required this.fav, required this.live});
  final TGFavorite fav;
  final ({bool active, int? price}) live;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final pln = NumberFormat.decimalPattern('pl_PL');
    final change = TGPriceHistoryService.instance.latestSince(fav.listingId, fav.savedAt);
    final card = Material(
      color: TGColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TGRadius.card), side: const BorderSide(color: TGColors.border)),
      child: InkWell(
        key: Key('fav-card-${fav.listingId}'),
        borderRadius: BorderRadius.circular(TGRadius.card),
        onTap: live.active ? () => context.go(fav.path) : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: live.active ? 1 : 0.45,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 56,
                    child: fav.imageUrl.isEmpty
                        ? const ColoredBox(color: TGColors.border)
                        : WatermarkedImage(url: fav.imageUrl, surface: TGImageSurface.favorites, fallback: (_) => const ColoredBox(color: TGColors.border)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fav.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (fav.city.isNotEmpty) fav.city,
                        if (live.price != null)
                          fav.kind == FavoriteKind.restaurant
                              ? '${pln.format(live.price)} PLN ${context.t('ui_per_month')}'
                              : '${pln.format(live.price)} PLN',
                      ].join(' · '),
                      style: theme.bodySmall.override(color: theme.secondaryText),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (!live.active)
                          Container(
                            key: Key('fav-inactive-${fav.listingId}'),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF5A5A5A), borderRadius: BorderRadius.circular(99)),
                            child: Text(context.t('dash_fav_inactive'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        if (change != null)
                          Text(
                            context.t('dash_fav_price_changed', {
                              'd': DateFormat('d MMM', locale).format(change.at),
                              'old': pln.format(change.oldPln),
                              'new': pln.format(change.newPln),
                            }),
                            key: Key('fav-price-change-${fav.listingId}'),
                            style: theme.bodySmall.override(
                              fontWeight: FontWeight.w800,
                              color: change.dropped ? TGColors.cta : TGColors.rating,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('fav-remove-${fav.listingId}'),
                tooltip: context.t('dash_fav_remove'),
                onPressed: () => _remove(context),
                icon: const Icon(Icons.favorite, color: TGColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
    return TGFocusRing(child: card);
  }

  void _remove(BuildContext context) {
    TGFavoritesService.instance.remove(fav.userId, fav.kind, fav.listingId);
    showTGToast(
      context,
      context.t('dash_fav_removed'),
      action: SnackBarAction(label: context.t('ui_undo'), onPressed: () => TGFavoritesService.instance.add(fav)),
    );
  }
}
