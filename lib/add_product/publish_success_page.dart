import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_listing_no_line.dart';
import 'package:twoja_gastromania/tg_components/tg_showcase_section.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

class PublishSuccessPage extends StatefulWidget {
  const PublishSuccessPage({super.key, this.listingId});

  static const routeName = 'PublishSuccess';
  static const routePath = '/add-product/success';

  final String? listingId;

  @override
  State<PublishSuccessPage> createState() => _PublishSuccessPageState();
}

class _PublishSuccessPageState extends State<PublishSuccessPage> with TickerProviderStateMixin {
  late final AnimationController _tick = AnimationController(vsync: this, duration: TGMotion.tick)..forward();
  late final AnimationController _bar = AnimationController(vsync: this, duration: TGMotion.barFill)..forward();

  @override
  void dispose() {
    _tick.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final id = widget.listingId;
    final product = auth.ownedListings.where((p) => p.id == id).firstOrNull ?? auth.ownedActive.firstOrNull;
    final theme = FlutterFlowTheme.of(context);
    final until = product?.expiresAt ?? DateTime.now().add(const Duration(days: 30));
    final untilLabel = DateFormat('d MMM y').format(until);

    final actions = [
      TGButton(
        onPressed: product == null ? null : () => context.go(product.detailPath),
        label: context.t('ui_view_listing'),
        height: 40,
        borderRadius: BorderRadius.circular(TGRadius.pill),
      ),
      TGButton(
        onPressed: () => TGNav.addProduct(context),
        label: context.t('ui_add_another'),
        variant: TGButtonVariant.outline,
        height: 40,
        borderRadius: BorderRadius.circular(TGRadius.pill),
      ),
      TGButton(
        onPressed: () => TGNav.dashboardListings(context),
        label: context.t('ui_go_dashboard'),
        variant: TGButtonVariant.ghost,
        height: 40,
      ),
      TGButton(
        onPressed: product == null
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: 'https://twojagastromania.pl${product.detailPath}'));
                showTGToast(context, context.t('ui_link_copied'));
              },
        label: context.t('ui_copy_link'),
        variant: TGButtonVariant.ghost,
        height: 40,
      ),
    ];

    return TGPageScaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            TGBreadcrumb(
              items: [
                TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                TGBreadcrumbItem(label: context.t('ui_listing_published')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                AnimatedBuilder(
                  animation: _tick,
                  builder: (context, _) => CustomPaint(
                    size: const Size(36, 36),
                    painter: _TickPainter(progress: _tick.value, color: theme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t('ui_listing_live'), style: theme.titleLarge.override(fontWeight: FontWeight.w700, letterSpacing: 0.25)),
                      if (product != null) TGListingNoLine(product: product),
                      Text(context.t('ui_live_until', {'date': untilLabel}), style: theme.bodySmall.override(color: theme.secondaryText)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: AnimatedBuilder(
                      animation: _bar,
                      builder: (context, _) => LinearProgressIndicator(
                        value: _bar.value,
                        minHeight: 6,
                        backgroundColor: TGColors.border,
                        color: theme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (auth.listingPlan == TGListingPlan.free) ...[
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(context.t('ui_free_left_n', {'n': '${auth.freeListingsLeft}'}), style: theme.bodySmall.override(fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 8),
            if (product != null) Expanded(child: TGShowcaseSection(product: product)) else const Spacer(),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: actions),
          ],
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - 4, stroke);
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.34);
    final metrics = path.computeMetrics().first;
    canvas.drawPath(metrics.extractPath(0, metrics.length * progress), stroke);
  }

  @override
  bool shouldRepaint(covariant _TickPainter old) => old.progress != progress || old.color != color;
}
