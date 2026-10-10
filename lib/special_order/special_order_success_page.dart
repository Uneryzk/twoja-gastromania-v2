import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

class SpecialOrderSuccessPage extends StatefulWidget {
  const SpecialOrderSuccessPage({super.key, this.requestNo});

  static const routeName = 'SpecialOrderSuccess';
  static const routePath = '/special-order/success';

  final String? requestNo;

  @override
  State<SpecialOrderSuccessPage> createState() => _SpecialOrderSuccessPageState();
}

class _SpecialOrderSuccessPageState extends State<SpecialOrderSuccessPage> with SingleTickerProviderStateMixin {
  AnimationController? _tick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tick ??= AnimationController(vsync: this, duration: TGMotion.of(context, TGMotion.tick))..forward();
  }

  @override
  void dispose() {
    _tick?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final no = widget.requestNo ?? '';
    final req = TGSpecialOrderService.instance.byRequestNo(no);
    final sent = req?.selectedSellerIds.length ?? 0;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final tickMark = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(shape: BoxShape.circle, color: TGColors.cta.withValues(alpha: 0.2)),
      child: const Icon(Icons.check_rounded, size: 40, color: TGColors.cta),
    );

    return TGPageScaffold(
      body: ListView(
        children: [
          const TGTopNav(activeNavId: 'special_order'),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 40, 40, 64),
                child: Column(
                  children: [
                    TGBreadcrumb(
                      items: [
                        TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                        TGBreadcrumbItem(label: context.t('ui_special_order'), onTap: () => context.go('/special-order')),
                        TGBreadcrumbItem(label: context.t('ui_done')),
                      ],
                    ),
                    const SizedBox(height: 36),
                    if (reduce || _tick == null)
                      tickMark
                    else
                      ScaleTransition(
                        scale: CurvedAnimation(parent: _tick!, curve: Curves.easeOutBack),
                        child: tickMark,
                      ),
                    const SizedBox(height: 20),
                    Text(context.t('ui_so_request_sent'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: no));
                          showTGToast(context, context.t('ui_copied_check'));
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(no, style: theme.titleLarge.override(fontWeight: FontWeight.w900)),
                            const SizedBox(width: 8),
                            const Icon(Icons.copy, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.t('ui_so_sent_to_n', {'n': '$sent'}),
                      textAlign: TextAlign.center,
                      style: theme.bodyLarge.override(lineHeight: 1.4),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        TGButton(onPressed: () => context.go('/account/requests/$no'), label: context.t('ui_so_view_request'), height: 48),
                        TGButton(onPressed: () => context.go('/special-order/new'), label: context.t('ui_so_add_another'), variant: TGButtonVariant.outline, height: 48),
                        TGButton(onPressed: () => context.go('/special-order'), label: context.t('ui_so_back_hub'), variant: TGButtonVariant.ghost, height: 48),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const TGFooter(),
        ],
      ),
    );
  }
}
