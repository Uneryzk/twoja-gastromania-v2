import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/restaurant_post_publish_service.dart';

/// Post-publish Next steps — desktop modal / mobile 90% sheet. Max 2 shows.
Future<void> showRestaurantNextSteps(BuildContext context, RestaurantListing listing) async {
  final svc = RestaurantPostPublishService.instance..ensureSeeded();
  if (!svc.canShowNextSteps(listing.id)) return;
  svc.recordSheetView(listing.id);

  final wide = MediaQuery.sizeOf(context).width >= 700;
  final phone390 = MediaQuery.sizeOf(context).width <= 400;
  final body = _NextStepsBody(listing: listing);

  if (wide) {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Maybe later',
      barrierColor: Colors.black54,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 250)),
      pageBuilder: (ctx, _, __) => Shortcuts(
        shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
        child: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                Navigator.pop(ctx);
                svc.dismissSheet(listing.id, foreverCards: true);
                return null;
              },
            ),
          },
          child: FocusScope(
            autofocus: true,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Material(
                  color: FlutterFlowTheme.of(ctx).secondaryBackground,
                  borderRadius: BorderRadius.circular(TGRadius.modal),
                  child: body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    sheetAnimationStyle: AnimationStyle(duration: tgAnim(context, const Duration(milliseconds: 250))),
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * (phone390 ? 0.9 : 0.85),
      child: body,
    ),
  );
}

class _NextStepsBody extends StatelessWidget {
  const _NextStepsBody({required this.listing});
  final RestaurantListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final svc = RestaurantPostPublishService.instance;
    final freeLeft = auth.freeListingsLeft;
    final showEquip = listing.inventory.any((i) => i.status == RestaurantInventoryStatus.active);
    final equipCopy = svc.equipmentCardCopy(listing, freeLeft: freeLeft);
    final shrink = listing.equipmentIncluded == RestaurantEquipmentIncluded.all;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your listing is live!', style: theme.titleLarge.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            'Buyers decide faster when they see the full picture. Add what you like and skip the rest.',
            style: theme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _Card(
                  title: 'Add details · 2 min',
                  body:
                      'Garden / alcohol permit / play area and more. Filters look at this information; a listing without it doesn’t show up in those filters.',
                  cta: 'Add details',
                  onTap: () {
                    svc.dismissCard(listing.id, 'details');
                    Navigator.pop(context);
                    context.go('/restaurants/${listing.listingNo}/details');
                  },
                ),
                if (showEquip) ...[
                  const SizedBox(height: 12),
                  _Card(
                    title: shrink ? 'Selling some items separately?' : 'Sell items separately',
                    body: equipCopy.resolveOf(context),
                    cta: 'Open equipment',
                    dense: shrink,
                    onTap: () {
                      svc.dismissCard(listing.id, 'equipment');
                      Navigator.pop(context);
                      context.go('/dashboard/listings?equip=${listing.id}');
                    },
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              svc.dismissSheet(listing.id, foreverCards: true);
              Navigator.pop(context);
            },
            child: const Text('Maybe later'),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
    this.dense = false,
  });
  final String title;
  final String body;
  final String cta;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: theme.primaryBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: TGColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(dense ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(body, style: theme.bodySmall),
              const SizedBox(height: 10),
              TGButton(
                onPressed: onTap,
                label: cta,
                height: 40,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
