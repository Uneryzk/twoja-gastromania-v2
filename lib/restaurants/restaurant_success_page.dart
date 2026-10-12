import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/restaurants/restaurant_next_steps_sheet.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_restaurant_showcase.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

class RestaurantSuccessPage extends StatefulWidget {
  const RestaurantSuccessPage({super.key, this.listingId, this.pending = false});

  static const routeName = 'restaurantSuccess';
  static const routePath = '/restaurants/success';

  final String? listingId;
  final bool pending;

  @override
  State<RestaurantSuccessPage> createState() => _RestaurantSuccessPageState();
}

class _RestaurantSuccessPageState extends State<RestaurantSuccessPage> with SingleTickerProviderStateMixin {
  late final AnimationController _tick = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
  late final AnimationController _bar = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
  bool _showcaseDone = false;

  void _openNextSteps() {
    if (!mounted || widget.pending || _showcaseDone) return;
    _showcaseDone = true;
    final r = widget.listingId == null ? null : RestaurantService.instance.byId(widget.listingId!);
    if (r == null) return;
    // After Showcase dismiss/purchase — never stack modals.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showRestaurantNextSteps(context, r);
    });
  }

  @override
  void dispose() {
    _tick.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final r = widget.listingId == null ? null : RestaurantService.instance.byId(widget.listingId!);
    final until = r?.expiresAt;
    return TGPageScaffold(
      header: const TGHeader(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(parent: _tick, curve: Curves.easeOutBack),
                  child: const Icon(Icons.check_circle, size: 72, color: TGColors.cta),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.pending ? 'Submitted for authorization' : 'Your listing is live',
                  style: theme.headlineSmall.override(fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                if (r != null) ...[
                  const SizedBox(height: 8),
                  Text('Listing No. ${r.listingNo}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (until != null && !widget.pending)
                    Text('Live until ${DateFormat('d MMM yyyy').format(until)}', style: theme.bodyMedium),
                  if (widget.pending)
                    const Text(
                      'Upload proof of authorization from your dashboard. The listing stays hidden until approved.',
                      textAlign: TextAlign.center,
                    ),
                ],
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _bar,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: _bar.value, minHeight: 8, color: TGColors.cta),
                  ),
                ),
                const SizedBox(height: 24),
                if (r != null && !widget.pending) ...[
                  TGRestaurantShowcaseSection(
                    listing: r,
                    onDismissed: _openNextSteps,
                    onPurchased: (_) => _openNextSteps(),
                  ),
                  const SizedBox(height: 20),
                ],
                TGButton(
                  onPressed: r == null ? null : () => context.go(r.detailPath),
                  label: 'View listing',
                  height: 48,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
                const SizedBox(height: 8),
                TGButton(
                  onPressed: () => context.go('/restaurants/new'),
                  label: 'Add another',
                  variant: TGButtonVariant.outline,
                  height: 48,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
                TextButton(onPressed: () => context.go('/dashboard/listings'), child: const Text('Go to dashboard')),
                TextButton(
                  onPressed: r == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: 'https://twojagastromania.pl${r.detailPath}'));
                          showTGToast(context, context.t('ui_link_copied'));
                        },
                  child: const Text('Copy link'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
