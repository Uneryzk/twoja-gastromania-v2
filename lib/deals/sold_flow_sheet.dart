import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';

enum SoldFlowMode { markSold, removeListing }

Future<void> showSoldFlow(BuildContext context, TGProduct listing, {SoldFlowMode mode = SoldFlowMode.markSold}) {
  TGAnalytics.track('sold_flow_open', {'listingId': listing.id, 'mode': mode.name});
  DealService.instance.ensureSeeded();
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  final phone390 = MediaQuery.sizeOf(context).width <= 400;
  if (wide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('ui_close'),
      barrierColor: Colors.black54,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
      pageBuilder: (ctx, _, __) => SoldFlowSheet(listing: listing, mode: mode, desktop: true),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    sheetAnimationStyle: AnimationStyle(duration: tgAnim(context, const Duration(milliseconds: 250))),
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * (phone390 ? 1 : 0.9),
      child: SoldFlowSheet(listing: listing, mode: mode, desktop: false),
    ),
  );
}

enum _SoldStep { reason, platform, buyer, done }

class SoldFlowSheet extends StatefulWidget {
  const SoldFlowSheet({super.key, required this.listing, required this.mode, required this.desktop});
  final TGProduct listing;
  final SoldFlowMode mode;
  final bool desktop;

  @override
  State<SoldFlowSheet> createState() => _SoldFlowSheetState();
}

class _SoldFlowSheetState extends State<SoldFlowSheet> {
  late _SoldStep _step;
  TGSoldReason? _reason;
  bool? _onPlatform;
  TGOffPlatformReason? _offReason;
  int _buyerTab = 0;
  String? _conversationBuyerId;
  TGDealIdentifierType _lookupType = TGDealIdentifierType.account;
  final _lookup = TextEditingController();
  String? _lookupResult;
  String? _lookupMasked;
  TGDealAccount? _lookupMatch;
  TGDeal? _created;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final skip = widget.mode == SoldFlowMode.markSold;
    _reason = skip ? TGSoldReason.sold : null;
    _step = skip ? _SoldStep.platform : _SoldStep.reason;
  }

  @override
  void dispose() {
    _lookup.dispose();
    super.dispose();
  }

  void _go(_SoldStep next) => setState(() => _step = next);

  Future<void> _finish({TGDealAccount? buyer, TGDealIdentifierType type = TGDealIdentifierType.conversation, String? masked}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = context.read<FakeAuthState>();
    final reason = _reason ?? TGSoldReason.sold;
    final deal = await DealService.instance.finalizeSold(
      auth: auth,
      listing: widget.listing,
      reason: reason,
      buyer: buyer,
      identifierType: type,
      identifierMasked: masked,
    );
    final sc = ModerationService.instance.sellerCaseFor(widget.listing.listingNo);
    if (sc != null) {
      sc.soldNudge = false;
      sc.soldResolved = true;
    }
    setState(() {
      _created = deal;
      _busy = false;
      _step = _SoldStep.done;
    });
  }

  Future<void> _continue() async {
    switch (_step) {
      case _SoldStep.reason:
        if (_reason == null) return;
        if (_reason == TGSoldReason.noLongerSelling || _reason == TGSoldReason.other) {
          await _finish();
        } else {
          _go(_SoldStep.platform);
        }
      case _SoldStep.platform:
        if (_onPlatform == null) return;
        TGAnalytics.track('sold_platform_answer', {'yes': _onPlatform, 'listingId': widget.listing.id});
        if (_onPlatform == false) {
          await _finish();
        } else {
          _go(_SoldStep.buyer);
        }
      case _SoldStep.buyer:
        if (_buyerTab == 0) {
          final conv = DealService.instance.conversationsFor(widget.listing.listingNo ?? '').where((c) => c.id == _conversationBuyerId || c.buyerId == _conversationBuyerId).firstOrNull;
          final id = _conversationBuyerId;
          if (id == null) return;
          final acc = DealService.instance.accountById(conv?.buyerId ?? id);
          await _finish(buyer: acc, type: TGDealIdentifierType.conversation, masked: acc?.displayName);
        } else {
          await _sendLookup();
        }
      case _SoldStep.done:
        Navigator.of(context).maybePop();
    }
  }

  Future<void> _sendLookup() async {
    final auth = context.read<FakeAuthState>();
    final deals = DealService.instance;
    if (_lookupResult != null) {
      await _finish(buyer: _lookupMatch, type: _lookupType, masked: _lookupMasked);
      return;
    }
    final masked = _maskQuery(_lookupType, _lookup.text);
    if (deals.lookupsUsed(auth.userId) >= 5) {
      setState(() {
        _lookupResult = kNeutralMatchCopy;
        _lookupMasked = masked;
        _lookupMatch = null;
      });
      return;
    }
    deals.lookupNeutral(auth.userId, type: _lookupType, query: _lookup.text);
    final match = deals.matchDirectory(type: _lookupType, query: _lookup.text);
    setState(() {
      _lookupResult = kNeutralMatchCopy;
      _lookupMasked = masked;
      _lookupMatch = match;
    });
  }

  String _maskQuery(TGDealIdentifierType type, String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '***';
    return switch (type) {
      TGDealIdentifierType.phone => maskPhone(t),
      TGDealIdentifierType.email => maskEmail(t),
      _ => '${t[0]}***',
    };
  }

  void _closeAndToast() {
    final auth = context.read<FakeAuthState>();
    final removed = _reason == TGSoldReason.noLongerSelling || _reason == TGSoldReason.other;
    Navigator.of(context).maybePop();
    showTGToast(
      context,
      removed ? context.t('ui_listing_taken_down') : context.t('ui_listing_marked_sold'),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: context.t('ui_undo'),
        textColor: TGColors.cta,
        onPressed: () => DealService.instance.undoLastSold(auth),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final convos = DealService.instance.conversationsFor(widget.listing.listingNo ?? '');
    final body = CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: FocusScope(
        autofocus: true,
        child: Material(
          color: theme.secondaryBackground,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: widget.desktop ? BorderRadius.circular(16) : const BorderRadius.vertical(top: Radius.circular(16)),
            side: BorderSide(color: theme.tertiary),
          ),
          child: Column(
            children: [
              if (!widget.desktop) ...[
                const SizedBox(height: 10),
                Container(width: 42, height: 4, decoration: BoxDecoration(color: theme.tertiary, borderRadius: BorderRadius.circular(99))),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(child: Text(widget.mode == SoldFlowMode.markSold ? context.t('ui_mark_sold') : context.t('ui_remove_listing'), style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
                    IconButton(tooltip: context.t('ui_close'), icon: Icon(Icons.close, color: theme.secondaryText), onPressed: () => Navigator.of(context).maybePop()),
                  ],
                ),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: _ListingMini(listing: widget.listing)),
              _StepDots(step: _step, skipReason: widget.mode == SoldFlowMode.markSold),
              Expanded(
                child: AnimatedSwitcher(
                  duration: tgAnim(context, const Duration(milliseconds: 200)),
                  transitionBuilder: (child, anim) {
                    final offset = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim);
                    return SlideTransition(position: offset, child: FadeTransition(opacity: anim, child: child));
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: switch (_step) {
                        _SoldStep.reason => _ReasonStep(value: _reason, onChanged: (v) => setState(() => _reason = v)),
                        _SoldStep.platform => _PlatformStep(
                            onPlatform: _onPlatform,
                            offReason: _offReason,
                            onPlatformChanged: (v) => setState(() => _onPlatform = v),
                            onOffReason: (v) => setState(() => _offReason = v),
                          ),
                        _SoldStep.buyer => _BuyerStep(
                            convos: convos,
                            tab: _buyerTab,
                            onTab: (i) => setState(() => _buyerTab = i),
                            selectedId: _conversationBuyerId,
                            onSelect: (id) => setState(() => _conversationBuyerId = id),
                            lookupType: _lookupType,
                            onType: (t) => setState(() => _lookupType = t),
                            lookup: _lookup,
                            onLookupChanged: () => setState(() {}),
                            result: _lookupResult,
                            masked: _lookupMasked,
                            lookupsUsed: DealService.instance.lookupsUsed(context.read<FakeAuthState>().userId),
                            onSkip: () => _finish(),
                          ),
                        _SoldStep.done => _DoneStep(deal: _created, reason: _reason ?? TGSoldReason.sold),
                      },
                    ),
                  ),
                ),
              ),
              _StickyBar(
                label: _primaryLabel,
                enabled: !_busy && _canContinue,
                onPressed: _step == _SoldStep.done ? _closeAndToast : _continue,
                secondary: _step == _SoldStep.done && _created != null
                    ? TGButton(
                        onPressed: () {
                          Navigator.of(context).maybePop();
                          TGNav.dashboardDeals(context);
                        },
                        label: context.t('ui_go_to_deals'),
                        variant: TGButtonVariant.outline,
                        height: 48,
                        borderRadius: BorderRadius.circular(TGRadius.pill),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
    if (!widget.desktop) return body;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        child: body,
      ),
    );
  }

  bool get _canContinue => switch (_step) {
        _SoldStep.reason => _reason != null,
        _SoldStep.platform => _onPlatform != null,
        _SoldStep.buyer => _buyerTab == 0 ? _conversationBuyerId != null : _lookup.text.trim().isNotEmpty,
        _SoldStep.done => true,
      };

  String get _primaryLabel {
    if (_step == _SoldStep.done) return context.t('ui_done');
    if (_step == _SoldStep.reason && (_reason == TGSoldReason.noLongerSelling || _reason == TGSoldReason.other)) {
      return context.t('ui_remove_listing');
    }
    if (_step == _SoldStep.platform && _onPlatform == false) return context.t('ui_mark_sold');
    if (_step == _SoldStep.buyer && _buyerTab == 1 && _lookupResult != null) return context.t('ui_mark_sold');
    return context.t('ui_continue');
  }
}

class _StickyBar extends StatelessWidget {
  const _StickyBar({required this.label, required this.enabled, required this.onPressed, this.secondary});
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FlutterFlowTheme.of(context).secondaryBackground,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TGButton(key: const Key('sold-continue'), onPressed: enabled ? onPressed : null, label: label, height: 48, borderRadius: BorderRadius.circular(TGRadius.pill)),
            if (secondary != null) ...[const SizedBox(height: 8), secondary!],
          ],
        ),
      ),
    );
  }
}

class _ListingMini extends StatelessWidget {
  const _ListingMini({required this.listing});
  final TGProduct listing;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: listing.imageUrl.isEmpty
                ? const ColoredBox(color: TGColors.border)
                : Image.asset(listing.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: TGColors.border)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(listing.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              if (listing.listingNo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: theme.alternate, borderRadius: BorderRadius.circular(99), border: Border.all(color: theme.tertiary)),
                  child: Text(context.t('ui_listing_no_chip', {'n': listing.listingNo!}), style: theme.bodySmall.override(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.skipReason});
  final _SoldStep step;
  final bool skipReason;

  @override
  Widget build(BuildContext context) {
    final steps = [
      if (!skipReason) _SoldStep.reason,
      _SoldStep.platform,
      _SoldStep.buyer,
      _SoldStep.done,
    ];
    final i = steps.indexOf(step).clamp(0, steps.length - 1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var n = 0; n < steps.length; n++) ...[
            if (n > 0) Container(width: 16, height: 2, color: n <= i ? TGColors.cta : TGColors.border),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: n <= i ? TGColors.cta : TGColors.border),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReasonStep extends StatelessWidget {
  const _ReasonStep({required this.value, required this.onChanged});
  final TGSoldReason? value;
  final ValueChanged<TGSoldReason> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.t('ui_what_happened'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('ui_what_happened'), style: FlutterFlowTheme.of(context).titleSmall.override(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          RadioGroup<TGSoldReason>(
            groupValue: value,
            onChanged: (v) { if (v != null) onChanged(v); },
            child: Column(
              children: [
                for (final r in TGSoldReason.values)
                  _RadioCard(
                    value: r,
                    selected: value == r,
                    title: context.t(switch (r) {
                      TGSoldReason.sold => 'ui_reason_sold',
                      TGSoldReason.rented => 'ui_reason_rented',
                      TGSoldReason.noLongerSelling => 'ui_reason_no_longer',
                      TGSoldReason.other => 'ui_sold_reason_other',
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformStep extends StatelessWidget {
  const _PlatformStep({required this.onPlatform, required this.offReason, required this.onPlatformChanged, required this.onOffReason});
  final bool? onPlatform;
  final TGOffPlatformReason? offReason;
  final ValueChanged<bool> onPlatformChanged;
  final ValueChanged<TGOffPlatformReason> onOffReason;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_found_buyer_here'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(context.t('ui_found_buyer_help'), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _YesNoCard(key: const Key('sold-yes'), label: context.t('ui_yes'), selected: onPlatform == true, onTap: () => onPlatformChanged(true))),
            const SizedBox(width: 10),
            Expanded(child: _YesNoCard(key: const Key('sold-no'), label: context.t('ui_no'), selected: onPlatform == false, onTap: () => onPlatformChanged(false))),
          ],
        ),
        if (onPlatform == false) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in TGOffPlatformReason.values)
                ChoiceChip(
                  selected: offReason == r,
                  label: Text(context.t(switch (r) {
                    TGOffPlatformReason.alreadyKnew => 'ui_sold_already_knew',
                    TGOffPlatformReason.anotherWebsite => 'ui_sold_other_site',
                    TGOffPlatformReason.other => 'ui_sold_reason_other',
                  })),
                  onSelected: (_) => onOffReason(r),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _YesNoCard extends StatelessWidget {
  const _YesNoCard({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return _FocusRing(
      radius: 16,
      child: Material(
        color: selected ? theme.primary.withValues(alpha: 0.12) : theme.alternate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? theme.primary : theme.tertiary, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Column(
              children: [
                AnimatedScale(
                  scale: selected ? 1 : 0.6,
                  duration: tgAnim(context, const Duration(milliseconds: 150)),
                  child: Icon(Icons.check_circle, color: selected ? theme.primary : Colors.transparent, size: 22),
                ),
                const SizedBox(height: 6),
                Text(label, style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuyerStep extends StatelessWidget {
  const _BuyerStep({
    required this.convos,
    required this.tab,
    required this.onTab,
    required this.selectedId,
    required this.onSelect,
    required this.lookupType,
    required this.onType,
    required this.lookup,
    required this.onLookupChanged,
    required this.result,
    required this.masked,
    required this.lookupsUsed,
    required this.onSkip,
  });
  final List<TGDealConversation> convos;
  final int tab;
  final ValueChanged<int> onTab;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final TGDealIdentifierType lookupType;
  final ValueChanged<TGDealIdentifierType> onType;
  final TextEditingController lookup;
  final VoidCallback onLookupChanged;
  final String? result;
  final String? masked;
  final int lookupsUsed;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_who_bought'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _Seg(key: const Key('sold-tab-convos'), label: context.t('ui_people_messaged', {'n': '${convos.length}'}), selected: tab == 0, onTap: () => onTab(0))),
            const SizedBox(width: 8),
            Expanded(child: _Seg(key: const Key('sold-tab-lookup'), label: context.t('ui_find_by_account'), selected: tab == 1, onTap: () => onTab(1))),
          ],
        ),
        const SizedBox(height: 12),
        if (tab == 0)
          RadioGroup<String>(
            groupValue: selectedId,
            onChanged: (v) { if (v != null) onSelect(v); },
            child: Column(
              children: [
                for (final c in convos)
                  _RadioCard(
                    value: c.buyerId,
                    selected: selectedId == c.buyerId,
                    title: c.buyerName,
                    subtitle: context.t('ui_messaged_on', {'d': DateFormat('d MMM').format(c.lastMessageAt)}),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.primary.withValues(alpha: 0.2),
                      child: Text(c.buyerName.isEmpty ? '?' : c.buyerName[0], style: TextStyle(color: theme.primary, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          )
        else ...[
          Wrap(
            spacing: 6,
            children: [
              for (final t in [TGDealIdentifierType.account, TGDealIdentifierType.phone, TGDealIdentifierType.email])
                ChoiceChip(
                  selected: lookupType == t,
                  label: Text(context.t(switch (t) {
                    TGDealIdentifierType.account => 'ui_account_name',
                    TGDealIdentifierType.phone => 'ui_phone',
                    TGDealIdentifierType.email => 'ui_email',
                    _ => 'ui_account_name',
                  })),
                  onSelected: (_) => onType(t),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('sold-lookup'),
            controller: lookup,
            onChanged: (_) => onLookupChanged(),
            keyboardType: lookupType == TGDealIdentifierType.phone ? TextInputType.phone : lookupType == TGDealIdentifierType.email ? TextInputType.emailAddress : TextInputType.text,
            decoration: InputDecoration(hintText: context.t('ui_lookup_hint')),
          ),
          const SizedBox(height: 8),
          Text(context.t('ui_lookup_privacy'), style: theme.bodySmall.override(color: theme.secondaryText)),
          if (lookupsUsed >= 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(context.t('ui_lookup_limit'), style: theme.bodySmall.override(color: TGColors.rating, fontWeight: FontWeight.w700)),
            ),
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result == kNeutralMatchCopy ? context.t('ui_lookup_neutral') : result!, style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                    if (masked != null) Text(masked!, style: theme.bodySmall.override(color: theme.secondaryText)),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(key: const Key('sold-skip-buyer'), onPressed: onSkip, child: Text(context.t('ui_dont_know_buyer'))),
        ),
      ],
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.deal, required this.reason});
  final TGDeal? deal;
  final TGSoldReason reason;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final removed = reason == TGSoldReason.noLongerSelling || reason == TGSoldReason.other;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle, color: theme.primary, size: 40),
        const SizedBox(height: 10),
        Text(removed ? context.t('ui_listing_taken_down') : context.t('ui_listing_marked_sold'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        if (deal != null) ...[
          const SizedBox(height: 8),
          Text(context.t('ui_request_sent_buyer'), style: theme.bodyMedium),
          const SizedBox(height: 6),
          Text(context.t('ui_deal_no', {'n': deal!.id}), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 12),
        Text(context.t('ui_slots_not_returned'), style: theme.bodySmall.override(color: theme.secondaryText)),
      ],
    );
  }
}

class _RadioCard<T> extends StatelessWidget {
  const _RadioCard({required this.value, required this.selected, required this.title, this.subtitle, this.leading});
  final T value;
  final bool selected;
  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _FocusRing(
        radius: 12,
        child: Material(
          color: selected ? theme.primary.withValues(alpha: 0.1) : theme.alternate,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: selected ? theme.primary : theme.tertiary, width: selected ? 2 : 1),
          ),
          child: RadioListTile<T>(
            value: value,
            title: Text(title, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
            subtitle: subtitle == null ? null : Text(subtitle!, style: theme.bodySmall),
            secondary: leading,
            activeColor: theme.primary,
          ),
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: selected ? theme.primary.withValues(alpha: 0.16) : theme.alternate,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99), side: BorderSide(color: selected ? theme.primary : theme.tertiary)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(label, textAlign: TextAlign.center, maxLines: 2, style: theme.bodySmall.override(fontWeight: FontWeight.w800, color: selected ? theme.primary : theme.primaryText)),
        ),
      ),
    );
  }
}

class _FocusRing extends StatelessWidget {
  const _FocusRing({required this.child, this.radius = 12});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Focus(
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: tgAnim(context, const Duration(milliseconds: 120)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: focused ? const [BoxShadow(color: TGColors.cta, blurRadius: 0, spreadRadius: 2)] : const [],
            ),
            child: child,
          );
        },
      ),
    );
  }
}
