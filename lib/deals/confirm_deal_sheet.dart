import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_sms_gate.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/deals/review_composer.dart';

Future<void> showConfirmDealSheet(BuildContext context, TGDeal deal) {
  DealService.instance.ensureSeeded();
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('ui_close'),
      barrierColor: Colors.black54,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
      pageBuilder: (ctx, _, __) => ConfirmDealSheet(deal: deal, desktop: true),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: curved, child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child));
      },
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: AnimationStyle(duration: tgAnim(context, const Duration(milliseconds: 250))),
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * (MediaQuery.sizeOf(ctx).width <= 400 ? 1 : 0.9),
      child: ConfirmDealSheet(deal: deal, desktop: false),
    ),
  );
}

class ConfirmDealSheet extends StatefulWidget {
  const ConfirmDealSheet({super.key, required this.deal, required this.desktop});
  final TGDeal deal;
  final bool desktop;

  @override
  State<ConfirmDealSheet> createState() => _ConfirmDealSheetState();
}

class _ConfirmDealSheetState extends State<ConfirmDealSheet> with SingleTickerProviderStateMixin {
  bool _sms = false;
  final _smsGate = GlobalKey<TGSmsGateState>();
  String? _smsError;
  bool _declining = false;
  bool _report = false;
  bool _confirmed = false;
  late final AnimationController _tick;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    final auth = context.read<FakeAuthState>();
    _sms = !auth.phoneVerified;
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  Future<void> _yes() async {
    if (_sms) {
      final gate = _smsGate.currentState;
      if (gate == null) return;
      if (!gate.codeSent) {
        gate.send();
        setState(() {});
        return;
      }
      if (!gate.verify()) {
        setState(() => _smsError = gate.error ?? context.t('ui_sms_wrong'));
        return;
      }
      context.read<FakeAuthState>().phoneVerified = true;
      setState(() {
        _sms = false;
        _smsError = null;
      });
      return;
    }
    DealService.instance.confirmByBuyer(widget.deal, buyerId: context.read<FakeAuthState>().userId);
    setState(() => _confirmed = true);
    await _tick.forward();
  }

  void _no() {
    if (!_declining) {
      setState(() => _declining = true);
      return;
    }
    DealService.instance.declineByBuyer(widget.deal, buyerId: context.read<FakeAuthState>().userId, reportSeller: _report);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final deal = widget.deal;
    final daysLeft = deal.reviewWindowEndsAt == null ? 60 : deal.reviewWindowEndsAt!.difference(TGClock.now()).inDays.clamp(0, 60);
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
                    Expanded(child: Text(context.t('ui_confirm_deal'), style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: Icon(Icons.close, color: theme.secondaryText)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _confirmed
                      ? Column(
                          children: [
                            AnimatedBuilder(
                              animation: _tick,
                              builder: (context, _) => CustomPaint(
                                size: const Size(72, 72),
                                painter: _HandshakeTickPainter(progress: _tick.value, color: theme.primary),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(context.t('ui_deal_confirmed'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Text(context.t('ui_review_window_left', {'n': '$daysLeft'}), style: theme.bodySmall.override(color: theme.secondaryText)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: deal.listingSnapshot.imageUrl.isEmpty
                                        ? const ColoredBox(color: TGColors.border)
                                        : Image.asset(deal.listingSnapshot.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: TGColors.border)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(deal.listingSnapshot.title, maxLines: 2, style: theme.bodyMedium.override(fontWeight: FontWeight.w800))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(border: Border.all(color: theme.tertiary), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: theme.primary.withValues(alpha: 0.2),
                                    child: Text(
                                      (deal.listingSnapshot.sellerName ?? 'S')[0],
                                      style: TextStyle(color: theme.primary, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(deal.listingSnapshot.sellerName ?? 'Seller', style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                                        if (deal.listingSnapshot.sellerVerified)
                                          Text(context.t('ui_verified'), style: const TextStyle(color: TGColors.verified, fontSize: 11, fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(context.t('ui_seller_says_sold', {'name': deal.listingSnapshot.sellerName ?? 'The seller'}), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(context.t('ui_confirm_deal_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
                            if (_sms) ...[
                              const SizedBox(height: 16),
                              TGSmsGate(key: _smsGate, intro: context.t('ui_sms_verify')),
                              if (_smsError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(_smsError!, style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
                                ),
                            ],
                            if (_declining) ...[
                              const SizedBox(height: 12),
                              CheckboxListTile(
                                value: _report,
                                onChanged: (v) => setState(() => _report = v ?? false),
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(context.t('ui_report_false_claim'), style: theme.bodySmall),
                              ),
                              Text(context.t('ui_report_false_claim_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
                            ],
                          ],
                        ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
                child: _confirmed
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TGButton(
                            onPressed: () {
                              final deal = widget.deal;
                              Navigator.of(context).maybePop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!context.mounted) return;
                                showReviewComposer(
                                  context,
                                  sellerId: deal.sellerId,
                                  sellerName: deal.listingSnapshot.sellerName ?? 'Technica',
                                  listingNo: deal.listingNo,
                                  sellerVerified: deal.listingSnapshot.sellerVerified,
                                );
                              });
                            },
                            label: context.t('ui_write_review'),
                            height: 48,
                            borderRadius: BorderRadius.circular(TGRadius.pill),
                          ),
                          const SizedBox(height: 8),
                          TGButton(onPressed: () => Navigator.of(context).maybePop(), label: context.t('ui_later'), variant: TGButtonVariant.ghost, height: 48, borderRadius: BorderRadius.circular(TGRadius.pill)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TGButton(
                            key: const Key('confirm-yes'),
                            onPressed: _yes,
                            label: _sms
                                ? ((_smsGate.currentState?.codeSent ?? false) ? context.t('ui_verify_sms') : context.t('ui_send_sms'))
                                : context.t('ui_yes_i_bought'),
                            height: 48,
                            borderRadius: BorderRadius.circular(TGRadius.pill),
                          ),
                          const SizedBox(height: 8),
                          TGButton(onPressed: _no, label: context.t('ui_no_not_me'), variant: TGButtonVariant.outline, height: 48, borderRadius: BorderRadius.circular(TGRadius.pill)),
                          if (!_declining && !_sms)
                            TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(context.t('ui_not_sure_yet'))),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!widget.desktop) return body;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        child: body,
      ),
    );
  }
}

class _HandshakeTickPainter extends CustomPainter {
  _HandshakeTickPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.78, size.height * 0.28);
    final metrics = path.computeMetrics().first;
    canvas.drawPath(metrics.extractPath(0, metrics.length * progress), p);
  }

  @override
  bool shouldRepaint(covariant _HandshakeTickPainter old) => old.progress != progress;
}
