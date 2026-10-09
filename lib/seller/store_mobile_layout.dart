import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/product_detail/report_listing_sheet.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/seller/store_owner_edit.dart';
import 'package:twoja_gastromania/tg_components/tg_badges.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';

class StoreMobileCoverIdentity extends StatelessWidget {
  const StoreMobileCoverIdentity({
    super.key,
    required this.profile,
    required this.identityKey,
    this.onQuote,
  });

  final TGStoreProfile profile;
  final GlobalKey identityKey;
  final VoidCallback? onQuote;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final open = storeOpenState(profile.hours);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 188,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 140,
                child: _MobileCover(url: profile.coverUrl),
              ),
              Positioned(
                left: 16,
                top: 108,
                child: _MobileLogo(url: profile.logoUrl, name: profile.name),
              ),
            ],
          ),
        ),
        Padding(
          key: identityKey,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(profile.name, style: theme.headlineMedium.override(fontSize: 24, lineHeight: 30 / 24, fontWeight: FontWeight.w800)),
                  if (profile.verified) TGVerifiedSellerBadge(tooltip: context.t('ui_verified_store_tip'), pulse: true),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TGRatingBadge(rating: profile.rating),
                  Text(
                    profile.reviewsCount < 3 ? context.t('ui_new_seller') : context.t('ui_reviews_n', {'n': '${profile.reviewsCount}'}),
                    style: theme.bodySmall.override(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 16, color: theme.secondaryText),
                const SizedBox(width: 4),
                Expanded(child: Text('${profile.city}, ${profile.voivodeship}', style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 4),
              Text(context.t('ui_member_since', {'y': '${profile.memberSince.year}'}), style: theme.bodySmall.override(color: theme.secondaryText)),
              const SizedBox(height: 6),
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: open.open ? theme.success : theme.secondaryText, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    open.open ? '${context.t('ui_open_now')} · ${context.t('ui_closes_at', {'t': open.nextTime})}' : context.t('ui_closed_opens', {'when': '${context.t('ui_day_${open.nextDayKey}_short')} ${open.nextTime}'}),
                    style: theme.bodySmall.override(color: open.open ? theme.success : theme.secondaryText, fontWeight: FontWeight.w800),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              if (profile.categories.isNotEmpty) StoreCategoriesMenu(categories: profile.categories),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(profile.phone, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                ],
              ),
              if (profile.showQuote) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TGButton(
                    onPressed: onQuote ?? () => TGNav.storeQuote(context, profile.publicId),
                    label: context.t('ui_request_quote'),
                    variant: TGButtonVariant.ghost,
                    height: 44,
                  ),
                ),
              ],
              if (!storeOwnerUi(context, profile))
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<String>(
                    key: const Key('report-seller-menu'),
                    tooltip: context.t('ui_report_seller'),
                    onSelected: (v) {
                      if (v == 'report') withStoreOverlay(context, () => showReportFlow(context, TGReportSubject.seller(profile)));
                    },
                    itemBuilder: (_) => [PopupMenuItem(value: 'report', child: Text(context.t('ui_report_seller')))],
                    child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.more_horiz)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontally scrolling category chips (phone identity + listings).
class StoreCategoriesMenu extends StatelessWidget {
  const StoreCategoriesMenu({super.key, required this.categories, this.selected, this.onSelect, this.menuKey});

  final List<TGCategory> categories;
  final TGCategory? selected;
  final ValueChanged<TGCategory>? onSelect;
  final Key? menuKey;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      key: menuKey ?? const Key('store-categories-menu'),
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final on = selected == cat;
          return Material(
            color: on ? theme.secondary : theme.secondary.withValues(alpha: 0.16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TGRadius.pill),
              side: BorderSide(color: theme.secondary.withValues(alpha: on ? 0.9 : 0.45)),
            ),
            child: InkWell(
              key: Key('store-category-${cat.name}'),
              borderRadius: BorderRadius.circular(TGRadius.pill),
              onTap: onSelect == null ? null : () => onSelect!(cat),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text(
                    categoryLabel(cat, t: (k) => context.t(k)),
                    maxLines: 1,
                    style: theme.labelSmall.override(
                      color: on ? const Color(0xFF1A1A1A) : theme.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MobileCover extends StatelessWidget {
  const _MobileCover({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null) Image.asset(url!, fit: BoxFit.cover) else const ColoredBox(color: Color(0xFF1A1A1A)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x99000000)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileLogo extends StatelessWidget {
  const _MobileLogo({this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).alternate,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF252525), width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? Image.asset(url!, fit: BoxFit.cover)
          : Center(child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28))),
    );
  }
}

class StoreMobileContactBar extends StatelessWidget {
  const StoreMobileContactBar({
    super.key,
    required this.profile,
    required this.enabled,
    required this.onCall,
    required this.onMessage,
  });

  final TGStoreProfile profile;
  final bool enabled;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: const Color(0xFF1F1F1F),
      child: Container(
        key: const Key('store-mobile-contact'),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF3A3A3A)))),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                flex: 16,
                child: TGButton(
                  key: const Key('store-mobile-call'),
                  onPressed: enabled ? onCall : null,
                  icon: Icons.phone,
                  label: '${context.t('ui_call')}  ${profile.phone}',
                  height: 48,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 10,
                child: TGButton(
                  key: const Key('store-mobile-message'),
                  onPressed: enabled ? onMessage : null,
                  label: context.t('ui_message'),
                  variant: TGButtonVariant.outline,
                  height: 48,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String storeMobileTabLabel(BuildContext context, {required String name, required int products, required int reviews}) {
  return switch (name) {
    'products' => context.t('ui_products_n', {'n': '$products'}),
    'about' => context.t('ui_about_short'),
    'reviews' => context.t('ui_reviews_n_short', {'n': '$reviews'}),
    _ => name,
  };
}
