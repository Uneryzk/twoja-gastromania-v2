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
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_listing_no_line.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
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

    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final actions = [
      TGButton(
        onPressed: product == null ? null : () => context.go(product.detailPath),
        label: context.t('ui_view_listing'),
        height: 48,
        borderRadius: BorderRadius.circular(TGRadius.pill),
      ),
      TGButton(
        onPressed: () => TGNav.addProduct(context),
        label: context.t('ui_add_another'),
        variant: TGButtonVariant.outline,
        height: 48,
        borderRadius: BorderRadius.circular(TGRadius.pill),
      ),
      TGButton(
        onPressed: () => TGNav.dashboardListings(context),
        label: context.t('ui_go_dashboard'),
        variant: TGButtonVariant.ghost,
        height: 48,
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
        height: 48,
      ),
    ];
    final content = Column(
      children: [
        TGBreadcrumb(
          items: [
            TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
            TGBreadcrumbItem(label: context.t('ui_listing_published')),
          ],
        ),
        const SizedBox(height: 28),
        AnimatedBuilder(
          animation: _tick,
          builder: (context, _) => CustomPaint(
            size: const Size(72, 72),
            painter: _TickPainter(progress: _tick.value, color: theme.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(context.t('ui_listing_live'), style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (product != null) TGListingNoLine(product: product),
        const SizedBox(height: 8),
        Text(context.t('ui_live_until', {'date': untilLabel}), style: theme.titleSmall.override(color: theme.secondaryText)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: AnimatedBuilder(
            animation: _bar,
            builder: (context, _) => LinearProgressIndicator(
              value: _bar.value,
              minHeight: 8,
              backgroundColor: TGColors.border,
              color: theme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (product != null)
          SizedBox(
            height: TGProductCard.gridExtent(280, MediaQuery.textScalerOf(context)),
            width: 280,
            child: TGProductCard(product: product, layout: TGProductCardLayout.grid),
          ),
        const SizedBox(height: 16),
        if (auth.listingPlan == TGListingPlan.free)
          Text(context.t('ui_free_left_n', {'n': '${auth.freeListingsLeft}'}), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(context.t('ui_email_before_expire'), style: theme.bodySmall.override(color: theme.secondaryText)),
        if (!phone) ...[const SizedBox(height: 20), Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: actions)],
      ],
    );

    return TGPageScaffold(
      body: phone
          ? Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    children: [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: content))],
                  ),
                ),
                Material(
                  color: TGColors.surface,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
                    child: Column(children: [for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: 8), child: SizedBox(width: double.infinity, child: a))]),
                  ),
                ),
              ],
            )
          : ListView(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 0), child: content),
                  ),
                ),
                const SizedBox(height: 64),
                const TGFooter(),
              ],
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
