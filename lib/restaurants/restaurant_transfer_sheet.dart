import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

enum RestoCloseMode { markTransferred, removeListing }

enum _RestoCloseReason { transferred, noLongerSelling, other }

Future<void> showRestaurantTransferFlow(
  BuildContext context,
  RestaurantListing listing, {
  RestoCloseMode mode = RestoCloseMode.markTransferred,
}) {
  TGAnalytics.track('resto_transfer_mark', {'listingNo': listing.listingNo, 'mode': mode.name, 'step': 'open'});
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
      pageBuilder: (ctx, _, __) => RestaurantTransferSheet(listing: listing, mode: mode, desktop: true),
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
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.9,
      child: RestaurantTransferSheet(listing: listing, mode: mode, desktop: false),
    ),
  );
}

class RestaurantTransferSheet extends StatefulWidget {
  const RestaurantTransferSheet({super.key, required this.listing, required this.mode, required this.desktop});
  final RestaurantListing listing;
  final RestoCloseMode mode;
  final bool desktop;

  @override
  State<RestaurantTransferSheet> createState() => _RestaurantTransferSheetState();
}

class _RestaurantTransferSheetState extends State<RestaurantTransferSheet> {
  _RestoCloseReason? _reason;
  bool? _viaPlatform;
  final Set<String> _removeLinked = {};
  bool _busy = false;
  int _step = 0;

  List<RestaurantInventoryItem> get _linkedActive {
    return widget.listing.inventory
        .where((i) =>
            i.availability == RestaurantInventoryAvailability.maySellSeparately &&
            i.linkedListingNo != null &&
            i.linkedListingNo!.isNotEmpty &&
            i.status == RestaurantInventoryStatus.active)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    if (widget.mode == RestoCloseMode.markTransferred) {
      _reason = _RestoCloseReason.transferred;
      _step = 1;
    }
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final svc = RestaurantService.instance;
    final listing = widget.listing;

    if (_reason == _RestoCloseReason.noLongerSelling || _reason == _RestoCloseReason.other) {
      svc.markRemoved(listing.id);
      TGAnalytics.track('resto_transfer_mark', {'listingNo': listing.listingNo, 'result': 'removed', 'reason': _reason!.name});
      if (mounted) {
        Navigator.pop(context);
        showTGToast(context, 'Listing removed. Fees are not refunded.');
      }
      return;
    }

    if (_viaPlatform == null) {
      setState(() => _busy = false);
      return;
    }

    if (_linkedActive.isNotEmpty && _step < 2) {
      setState(() {
        _step = 2;
        _busy = false;
      });
      return;
    }

    final listingId = listing.id;
    svc.markTransferred(
      listingId: listingId,
      foundViaPlatform: _viaPlatform!,
      removeLinkedListingNos: _removeLinked,
    );
    TGAnalytics.track('resto_transfer_mark', {
      'listingNo': listing.listingNo,
      'result': 'sold',
      'viaPlatform': _viaPlatform,
      'removedLinked': _removeLinked.length,
    });

    if (!mounted) return;
    Navigator.pop(context);
    showTGToast(
      context,
      'Marked as transferred. Fees are not refunded.',
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: 'Undo',
        textColor: TGColors.cta,
        onPressed: () {
          final ok = RestaurantService.instance.undoTransfer(listingId);
          if (ok) showTGToast(context, 'Transfer undone.');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final card = Material(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.desktop ? 560 : double.infinity, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.mode == RestoCloseMode.markTransferred ? 'Mark as transferred' : 'Remove listing',
                      style: theme.titleMedium.override(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: _step == 0
                    ? _reasonStep(theme)
                    : _step == 1
                        ? _platformStep(theme)
                        : _linkedStep(theme),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (_step > (widget.mode == RestoCloseMode.markTransferred ? 1 : 0))
                    TextButton(
                      onPressed: () => setState(() => _step = _step == 2 ? 1 : 0),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  TGButton(
                    onPressed: _canContinue ? _confirm : null,
                    label: _step == 1 && _linkedActive.isNotEmpty ? 'Continue' : 'Confirm',
                    height: 48,
                    borderRadius: BorderRadius.circular(TGRadius.pill),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.desktop) return Center(child: card);
    return Align(alignment: Alignment.bottomCenter, child: card);
  }

  bool get _canContinue {
    if (_busy) return false;
    if (_step == 0) return _reason != null;
    if (_step == 1) return _viaPlatform != null;
    return true;
  }

  Widget _reasonStep(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Why are you closing this listing?', style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (final r in _RestoCloseReason.values)
          RadioListTile<_RestoCloseReason>(
            value: r,
            groupValue: _reason,
            onChanged: (v) => setState(() {
              _reason = v;
              if (v == _RestoCloseReason.transferred) _step = 1;
            }),
            title: Text(switch (r) {
              _RestoCloseReason.transferred => 'Business transferred / sold',
              _RestoCloseReason.noLongerSelling => 'No longer selling',
              _RestoCloseReason.other => 'Other',
            }),
          ),
        const SizedBox(height: 8),
        Text('Fees are not refunded.', style: theme.bodySmall.override(color: theme.secondaryText)),
      ],
    );
  }

  Widget _platformStep(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Did you find the buyer through Twoja Gastromania?', style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Restaurant listings are not a review anchor — no deal or review flow.',
          style: theme.bodySmall.override(color: theme.secondaryText),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _viaPlatform = true),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _viaPlatform == true ? TGColors.cta : theme.alternate, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Yes'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _viaPlatform = false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _viaPlatform == false ? TGColors.cta : theme.alternate, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('No'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Fees are not refunded.', style: theme.bodySmall.override(color: theme.secondaryText)),
      ],
    );
  }

  Widget _linkedStep(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your linked equipment listings', style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Keep (default) or remove when the transfer closes.', style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 12),
        for (final item in _linkedActive)
          CheckboxListTile(
            value: _removeLinked.contains(item.linkedListingNo),
            onChanged: (v) => setState(() {
              if (v == true) {
                _removeLinked.add(item.linkedListingNo!);
              } else {
                _removeLinked.remove(item.linkedListingNo);
              }
            }),
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              'Listing No. ${item.linkedListingNo} · ${_removeLinked.contains(item.linkedListingNo) ? "Remove" : "Keep"}',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        Text(
          'Unchecked = keep. Checked = remove from public catalogue.',
          style: theme.bodySmall.override(color: theme.secondaryText),
        ),
      ],
    );
  }
}
