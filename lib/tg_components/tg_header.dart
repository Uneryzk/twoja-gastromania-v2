import 'package:emoji_flag_converter/emoji_flag_converter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
// Also provides `intl` (DateFormat), `FFLocalizations` and `setAppLanguage`.
import 'package:twoja_gastromania/flutter_flow/flutter_flow_util.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_account_sheets.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_chat_dock.dart';
import 'package:twoja_gastromania/products/products_logic.dart';
import 'package:twoja_gastromania/tg_components/tg_search_field.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

/// Page chrome: [TGHeader] is the first child of the body (not `Scaffold.appBar`)
/// so it stays sticky *and* is the first `Twoja Gastromania` text in the tree
/// (the footer brand is further down). A Scaffold appBar is visited after the
/// body, which made `find.text('Twoja Gastromania').first` hit the off-screen footer.
class TGPageScaffold extends StatelessWidget {
  const TGPageScaffold({
    super.key,
    required this.body,
    this.header = const TGHeader(),
    this.floatingActionButton,
    this.backgroundColor,
  });

  final Widget body;
  final Widget header;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? TGColors.background,
      floatingActionButton: floatingActionButton,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: Stack(
              children: [
                body,
                const TGChatDock(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Global sticky header.
///
/// Shows the brand (tap = home), the search box (>= 700 px wide), a language
/// menu and the mock-auth account pill.
class TGHeader extends StatelessWidget implements PreferredSizeWidget {
  const TGHeader({
    super.key,
    this.searchHint,
    this.searchText = '',
    this.onSearch,
  });

  final String? searchHint;

  /// Currently applied search text (kept in sync with the page's URL).
  final String searchText;

  /// Overrides what happens on submit. Defaults to "open /products?q=...".
  final ValueChanged<String>? onSearch;

  static const double height = 64;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final isPhone = w < 520;
    final isCompact = w < 860; // tighter paddings / smaller brand
    final compactRight = w < 1000; // short pill label + flag-only language menu
    final showSearch = w >= 700;
    final auth = context.watch<FakeAuthState>();

    // The right-hand cluster is made of fixed-size children (they can never be
    // squeezed by Flex); exactly one slot (brand on phones, search on desktop)
    // is `Expanded`, so nothing is starved and nothing overflows.
    final right = <Widget>[
      _LanguageMenu(compact: compactRight),
      const SizedBox(width: 8),
      if (!auth.isLoggedIn)
        GestureDetector(
          onLongPress: kDebugMode ? () => showTGDevSwitch(context, auth) : null,
          child: isPhone
              ? TGIconButton(icon: Icons.person, tooltip: context.t('ui_login'), onPressed: () => TGNav.login(context))
              : TGButton(
                  onPressed: () => TGNav.login(context),
                  label: context.t('ui_login'),
                  icon: Icons.person,
                  variant: TGButtonVariant.outline,
                  height: 40,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
        )
      else
        _AccountPill(auth: auth, compact: compactRight, phone: isPhone),
    ];

    return Material(
      color: theme.secondaryBackground,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.tertiary))),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: height,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 24),
                  child: Row(
                    children: [
                      if (showSearch) ...[
                        _BrandMark(compact: isCompact, hideText: false),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: _HeaderSearch(
                                hint: searchHint ?? context.t('ui_search_equipment'),
                                initialText: searchText,
                                onSubmitted: onSearch,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ] else
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _BrandMark(compact: true, hideText: false, expandTitle: true),
                          ),
                        ),
                      ...right,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.compact, required this.hideText, this.expandTitle = false});

  final bool compact;
  final bool hideText;

  /// When true the title may ellipsis inside a bounded parent (phone header).
  final bool expandTitle;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final logoSize = compact ? 36.0 : 42.0;
    final logo = ClipOval(
      child: Image.asset(
        'assets/images/Hand_Shake_LOGO.png',
        width: logoSize,
        height: logoSize,
        cacheWidth: 126,
        fit: BoxFit.cover,
      ),
    );
    final title = Text(
      'Twoja Gastromania',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: theme.titleLarge.override(
        fontSize: compact ? 16 : 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );

    return Semantics(
      button: true,
      label: 'Twoja Gastromania – home',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => TGNav.home(context),
          child: Row(
            mainAxisSize: expandTitle ? MainAxisSize.max : MainAxisSize.min,
            children: [
              logo,
              if (!hideText) ...[
                const SizedBox(width: 10),
                if (expandTitle)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: title,
                    ),
                  )
                else
                  title,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact language switcher (flag + code), replacing the generated dropdown
/// that overflowed in narrow headers.
class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.compact});

  final bool compact;

  static const _flags = {
    'pl': 'PL',
    'en': 'GB',
    'tr': 'TR',
    'de': 'DE',
    'cs': 'CZ',
    'sk': 'SK',
    'uk': 'UA',
    'be': 'BY',
    'lt': 'LT',
    'ru': 'RU',
  };
  static const _names = {
    'pl': 'Polski',
    'en': 'English',
    'tr': 'Türkçe',
    'de': 'Deutsch',
    'cs': 'Čeština',
    'sk': 'Slovenčina',
    'uk': 'Українська',
    'be': 'Беларуская',
    'lt': 'Lietuvių',
    'ru': 'Русский',
  };

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final current = FFLocalizations.of(context).languageCode;

    String flag(String lang) => EmojiConverter.fromAlpha2CountryCode(_flags[lang] ?? 'PL');

    return PopupMenuButton<String>(
      tooltip: context.t('ui_language'),
      color: theme.secondaryBackground,
      offset: const Offset(0, 46),
      constraints: const BoxConstraints(minWidth: 220, maxHeight: 420),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TGRadius.input),
        side: BorderSide(color: theme.tertiary),
      ),
      onSelected: (lang) => setAppLanguage(context, lang),
      itemBuilder: (_) => [
        for (final lang in FFLocalizations.languages())
          PopupMenuItem<String>(
            value: lang,
            child: Row(
              children: [
                Text(flag(lang), style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Text(_names[lang] ?? lang, style: theme.bodyMedium.override(fontWeight: FontWeight.w600))),
                if (lang == current) Icon(Icons.check, size: 18, color: theme.primary),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
        decoration: BoxDecoration(
          color: theme.alternate,
          borderRadius: BorderRadius.circular(TGRadius.input),
          border: Border.all(color: theme.tertiary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag(current), style: const TextStyle(fontSize: 18)),
            if (!compact) ...[
              const SizedBox(width: 8),
              Text(current.toUpperCase(), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
            ],
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: theme.secondaryText),
          ],
        ),
      ),
    );
  }
}

/// Logged-in account pill. Priority: expired listings > expiring ≤5d > other states.
/// Long-press in debug builds opens the 7-scenario developer switch.
class _AccountPill extends StatelessWidget {
  const _AccountPill({required this.auth, required this.compact, required this.phone});

  final FakeAuthState auth;
  final bool compact;
  final bool phone;

  String _label(BuildContext context) {
    final kind = auth.pillKind;
    if (phone) {
      return switch (kind) {
        TGHeaderPillKind.store => context.t('ui_pill_store_short', {
            'used': '${auth.storeActiveUsed}',
            'limit': '${auth.storeActiveLimit}',
          }),
        TGHeaderPillKind.needsAttention => context.t('ui_pill_attention_short'),
        TGHeaderPillKind.expiredListings => context.t('ui_renew'),
        TGHeaderPillKind.expiringListings => '${auth.ownedExpiringSoon.first.daysUntilExpiry()}d',
        TGHeaderPillKind.noListings => context.t('ui_pill_free_short', {'n': '${auth.freeListingsTotal}'}),
        TGHeaderPillKind.freeQuota => context.t('ui_pill_free_short', {'n': '${auth.freeListingsLeft}'}),
        TGHeaderPillKind.noQuota => context.t('ui_pill_zero_free'),
      };
    }
    return switch (kind) {
      TGHeaderPillKind.store => context.t('ui_pill_store', {
          'plan': auth.storePlanLabel,
          'used': '${auth.storeActiveUsed}',
          'limit': '${auth.storeActiveLimit}',
        }),
      TGHeaderPillKind.needsAttention => () {
          final n = auth.ownedNeedsAttention.length;
          return context.t(n == 1 ? 'ui_pill_attention' : 'ui_pill_attention_many', {'n': '$n'});
        }(),
      TGHeaderPillKind.expiredListings => context.t('ui_pill_expired', {'n': '${auth.ownedExpired.length}'}),
      TGHeaderPillKind.expiringListings => () {
          final n = auth.ownedExpiringSoon.length;
          final d = auth.ownedExpiringSoon.map((p) => p.daysUntilExpiry()).reduce((a, b) => a < b ? a : b);
          final key = n == 1 ? 'ui_pill_listing_ends' : 'ui_pill_listings_end';
          return context.t(key, {'n': '$n', 'd': '$d'});
        }(),
      TGHeaderPillKind.noListings => context.t('ui_pill_no_listings'),
      TGHeaderPillKind.freeQuota => context.t('ui_pill_free_remaining', {'n': '${auth.freeListingsLeft}'}),
      TGHeaderPillKind.noQuota => context.t('ui_pill_zero_free'),
    };
  }

  String _tooltip(BuildContext context) {
    final listings = auth.listingTooltipLines();
    final head = switch (auth.pillKind) {
      TGHeaderPillKind.noListings => context.t('ui_tooltip_first_three'),
      TGHeaderPillKind.freeQuota => context.t('ui_tooltip_free_left', {
          'left': '${auth.freeListingsLeft}',
          'total': '${auth.freeListingsTotal}',
        }),
      TGHeaderPillKind.noQuota => context.t('ui_next_listing', {
          'fee': '${TGPricing.listingFeePln}',
          'days': '${TGPricing.listingPeriodDays}',
        }),
      TGHeaderPillKind.store => '${auth.storePlanLabel}: ${auth.storeActiveUsed} of ${auth.storeActiveLimit} listings active',
      TGHeaderPillKind.needsAttention || TGHeaderPillKind.expiredListings || TGHeaderPillKind.expiringListings => listings,
    };
    if (auth.pillKind == TGHeaderPillKind.store || listings.isEmpty) return head;
    if (auth.pillKind == TGHeaderPillKind.needsAttention ||
        auth.pillKind == TGHeaderPillKind.expiredListings ||
        auth.pillKind == TGHeaderPillKind.expiringListings) {
      return listings;
    }
    return '$head\n$listings';
  }

  void _onTap(BuildContext context) {
    switch (auth.pillKind) {
      case TGHeaderPillKind.needsAttention:
        TGNav.dashboardListings(context, filter: 'review');
        return;
      case TGHeaderPillKind.expiredListings:
        TGNav.dashboardListings(context, filter: 'expired');
        return;
      case TGHeaderPillKind.expiringListings:
        TGNav.dashboardListings(context, filter: 'expiring');
        return;
      default:
        showTGAccountSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final kind = auth.pillKind;
    final store = kind == TGHeaderPillKind.store;
    final warn = auth.pillIsProblem;
    final borderColor = warn ? TGColors.rating : (store ? theme.success : theme.primary);
    final label = _label(context);

    return Tooltip(
      message: _tooltip(context),
      child: Semantics(
        button: true,
        label: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onTap(context),
            onLongPress: kDebugMode ? () => showTGDevSwitch(context, auth) : null,
            child: Container(
              height: 40,
              constraints: BoxConstraints(maxWidth: phone ? 148 : compact ? 240 : 300),
              padding: EdgeInsets.only(left: 6, right: compact ? 8 : 10),
              decoration: BoxDecoration(
                color: theme.alternate,
                borderRadius: BorderRadius.circular(TGRadius.pill),
                border: Border.all(color: borderColor, width: 1.6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _leading(theme, store: store, warn: warn),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: theme.bodySmall.override(fontWeight: FontWeight.w700, fontSize: compact ? 12 : 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: theme.secondaryText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading(FlutterFlowTheme theme, {required bool store, required bool warn}) {
    if (store) {
      return Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.shield_outlined, size: 18, color: theme.success));
    }
    if (warn && !phone) {
      final icon = auth.pillKind == TGHeaderPillKind.needsAttention ? Icons.gpp_maybe_outlined : Icons.schedule_rounded;
      return Padding(padding: const EdgeInsets.only(left: 6), child: Icon(icon, size: 18, color: TGColors.rating));
    }
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: theme.primary.withValues(alpha: 0.22), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              auth.userInitials,
              style: theme.labelSmall.override(color: theme.primaryText, fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
          if (phone && auth.mobileBadgeCount > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 14),
                height: 14,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: auth.pillIsProblem ? TGColors.rating : theme.primary,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: theme.secondaryBackground, width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${auth.mobileBadgeCount}',
                  style: theme.labelSmall.override(fontSize: 8, fontWeight: FontWeight.w900, color: TGColors.onCta),
                ),
              ),
            ),
          if (phone && auth.pillIsProblem)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: TGColors.rating, shape: BoxShape.circle, border: Border.all(color: theme.secondaryBackground, width: 1)),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderSearch extends StatefulWidget {
  const _HeaderSearch({required this.hint, required this.initialText, this.onSubmitted});
  final String hint;
  final String initialText;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_HeaderSearch> createState() => _HeaderSearchState();
}

class _HeaderSearchState extends State<_HeaderSearch> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;
  String _query = '';
  List<TGProduct> _all = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  Future<void> _load() async {
    final seed = await TGProductService.instance.getAll();
    if (!mounted) return;
    final owned = context.read<FakeAuthState>().ownedListings;
    setState(() => _all = mergeOwnedListings(seed, owned));
  }

  void _onChanged(String raw) {
    final q = raw.trim();
    _query = q;
    if (TGListingNo.isListingNo(q)) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _submit(String raw) {
    final q = raw.trim();
    if (TGListingNo.isListingNo(q)) {
      final hit = TGListingNo.findPublic(_all, q);
      _hideOverlay();
      if (hit == null) {
        showTGToast(context, context.t('ui_no_listing_number'));
        return;
      }
      context.go(hit.detailPath);
      return;
    }
    (widget.onSubmitted ?? (v) => TGNav.search(context, v))(q);
  }

  void _showOverlay() {
    _hideOverlay();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _overlay = OverlayEntry(
      builder: (ctx) {
        final theme = FlutterFlowTheme.of(context);
        final hit = TGListingNo.findPublic(_all, _query);
        final label = hit == null
            ? context.t('ui_no_listing_number')
            : context.t('ui_go_to_listing_no', {'n': _query});
        return Positioned(
          width: 640,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: const Offset(0, 46),
            child: Material(
              elevation: 8,
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(TGRadius.input),
              child: InkWell(
                onTap: () => _submit(_query),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(label, style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: TGSearchField(
        height: 42,
        hint: widget.hint,
        initialText: widget.initialText,
        onChanged: _onChanged,
        onSubmitted: _submit,
      ),
    );
  }
}
