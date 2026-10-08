import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/product_detail/pdp_share.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_contact.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// Full-bleed PDP gallery: swipe on mobile, lens + thumbs on desktop.
class PdpGallery extends StatefulWidget {
  const PdpGallery({
    super.key,
    required this.product,
    required this.images,
    required this.index,
    required this.onIndex,
    required this.favorite,
    required this.onFavorite,
    required this.onLightbox,
    this.showThumbnails = false,
    this.enableLens = false,
    this.onReport,
  });

  final TGProduct product;
  final List<String> images;
  final int index;
  final ValueChanged<int> onIndex;
  final bool favorite;
  final VoidCallback onFavorite;
  final ValueChanged<int> onLightbox;
  final bool showThumbnails;
  final bool enableLens;
  final VoidCallback? onReport;

  @override
  State<PdpGallery> createState() => _PdpGalleryState();
}

class _PdpGalleryState extends State<PdpGallery> {
  late final PageController _pages = PageController(initialPage: widget.index);
  Offset? _lensLocal;
  bool _lensHover = false;

  @override
  void didUpdateWidget(covariant PdpGallery old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && _pages.hasClients && (_pages.page?.round() ?? widget.index) != widget.index) {
      final d = tgAnim(context, const Duration(milliseconds: 200));
      if (d == Duration.zero) {
        _pages.jumpToPage(widget.index);
      } else {
        _pages.animateToPage(widget.index, duration: d, curve: Curves.easeOut);
      }
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _preloadNeighbors(int index) {
    final images = widget.images;
    for (final i in [index - 1, index + 1]) {
      if (i < 0 || i >= images.length) continue;
      final p = images[i];
      if (p.startsWith('assets/')) {
        precacheImage(AssetImage(p), context);
      } else if (p.startsWith('http')) {
        precacheImage(NetworkImage(p), context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final images = widget.images;
    final n = images.length.clamp(1, 99);
    final idx = widget.index.clamp(0, n - 1);
    final reduce = tgReduceMotion(context);

    return Column(
      children: [
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'carousel. ${context.t('ui_image_n_of_m', {'n': '${idx + 1}', 'm': '$n'})}',
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.showThumbnails ? TGRadius.card : 0),
              child: ColoredBox(
                color: theme.alternate,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MouseRegion(
                      cursor: widget.enableLens ? SystemMouseCursors.zoomIn : SystemMouseCursors.basic,
                      onEnter: widget.enableLens ? (_) => setState(() => _lensHover = true) : null,
                      onExit: widget.enableLens
                          ? (_) => setState(() {
                                _lensHover = false;
                                _lensLocal = null;
                              })
                          : null,
                      onHover: widget.enableLens ? (e) => setState(() => _lensLocal = e.localPosition) : null,
                      child: PageView.builder(
                        controller: _pages,
                        physics: const BouncingScrollPhysics(),
                        itemCount: n,
                        onPageChanged: (i) {
                          widget.onIndex(i);
                          _preloadNeighbors(i);
                        },
                        itemBuilder: (context, i) {
                          final child = PdpPhoto(url: images[i], fit: BoxFit.contain);
                          final faded = reduce
                              ? child
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  child: KeyedSubtree(key: ValueKey(images[i]), child: child),
                                );
                          return GestureDetector(
                            onTap: () => widget.onLightbox(i),
                            child: faded,
                          );
                        },
                      ),
                    ),
                    if (widget.enableLens && _lensHover && _lensLocal != null)
                      _LensOverlay(url: images[idx], local: _lensLocal!),
                    Positioned(top: 12, left: 12, child: _StatusPills(product: widget.product)),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          _RoundIcon(
                            icon: widget.favorite ? Icons.favorite : Icons.favorite_border,
                            color: widget.favorite ? TGColors.accent : null,
                            tooltip: widget.favorite ? context.t('ui_saved') : context.t('ui_saved'),
                            onPressed: widget.onFavorite,
                          ),
                          const SizedBox(width: 8),
                          _RoundIcon(
                            icon: Icons.ios_share_rounded,
                            tooltip: context.t('ui_share'),
                            onPressed: () => showPdpShareMenu(context, widget.product),
                          ),
                          if (!widget.showThumbnails && widget.onReport != null) ...[
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              key: const Key('pdp-report-overflow'),
                              tooltip: context.t('ui_report_listing'),
                              color: theme.secondaryBackground,
                              onSelected: (v) {
                                if (v == 'report') widget.onReport!();
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(value: 'report', child: Text(ctx.t('ui_report_listing'))),
                              ],
                              child: const Material(
                                color: Color(0x73000000),
                                shape: CircleBorder(),
                                child: SizedBox(width: 44, height: 44, child: Icon(Icons.more_horiz, color: Colors.white, size: 22)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: Column(
                        children: [
                          if (n > 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < n; i++)
                                  Container(
                                    width: i == idx ? 8 : 6,
                                    height: i == idx ? 8 : 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i == idx ? theme.primary : theme.primaryText.withValues(alpha: 0.45),
                                    ),
                                  ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(TGRadius.pill),
                            ),
                            child: Text(
                              '${idx + 1} / $n',
                              style: theme.labelSmall.override(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.showThumbnails && n > 1) ...[
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: _NavChevron(
                          icon: Icons.chevron_left_rounded,
                          onPressed: idx > 0 ? () => widget.onIndex(idx - 1) : null,
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: _NavChevron(
                          icon: Icons.chevron_right_rounded,
                          onPressed: idx < n - 1 ? () => widget.onIndex(idx + 1) : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.showThumbnails && n > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: n,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final active = i == idx;
                return Semantics(
                  button: true,
                  label: context.t('ui_image_n_of_m', {'n': '${i + 1}', 'm': '$n'}),
                  child: _Thumb(
                    url: images[i],
                    active: active,
                    onTap: () => widget.onIndex(i),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusPills extends StatelessWidget {
  const _StatusPills({required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final used = product.condition == TGCondition.used;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Pill(
          label: conditionLabel(used ? TGCondition.used : TGCondition.newItem, t: (k) => context.t(k)),
          bg: used ? theme.alternate : theme.primary,
          fg: used ? theme.primaryText : TGColors.onCta,
        ),
        if (product.isPromoted)
          _Pill(label: context.t('ui_promoted_badge'), bg: theme.secondary, fg: Colors.white),
        if (product.status == TGListingStatus.sold)
          _Pill(label: 'SOLD', bg: TGColors.error, fg: Colors.white),
        if (product.status == TGListingStatus.expired)
          _Pill(label: 'EXPIRED', bg: theme.tertiary, fg: theme.primaryText),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(TGRadius.pill)),
      child: Text(label, style: FlutterFlowTheme.of(context).labelSmall.override(color: fg, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
    );
  }
}

class _RoundIcon extends StatefulWidget {
  const _RoundIcon({required this.icon, required this.onPressed, this.tooltip, this.color});
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;

  @override
  State<_RoundIcon> createState() => _RoundIconState();
}

class _RoundIconState extends State<_RoundIcon> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final child = Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(widget.icon, color: widget.color ?? Colors.white, size: 22),
                if (_focused)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.primary, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return widget.tooltip == null ? child : Tooltip(message: widget.tooltip!, child: child);
  }
}

class _NavChevron extends StatelessWidget {
  const _NavChevron({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) return const SizedBox.shrink();
    return Center(
      child: Material(
        color: Colors.black.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: Colors.white)),
        ),
      ),
    );
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({required this.url, required this.active, required this.onTap});
  final String url;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: tgAnim(context, const Duration(milliseconds: 150)),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.active ? theme.primary : theme.tertiary, width: widget.active ? 2 : 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PdpPhoto(url: widget.url, fit: BoxFit.cover),
                if (_hover && !widget.active) ColoredBox(color: Colors.white.withValues(alpha: 0.16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LensOverlay extends StatelessWidget {
  const _LensOverlay({required this.url, required this.local});
  final String url;
  final Offset local;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const size = 160.0;
        final x = (local.dx - size / 2).clamp(0.0, c.maxWidth - size);
        final y = (local.dy - size / 2).clamp(0.0, c.maxHeight - size);
        final ax = ((local.dx / c.maxWidth) * 2 - 1).clamp(-1.0, 1.0);
        final ay = ((local.dy / c.maxHeight) * 2 - 1).clamp(-1.0, 1.0);
        return Positioned(
          left: x,
          top: y,
          child: IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                border: Border.all(color: TGColors.cta, width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
              ),
              clipBehavior: Clip.antiAlias,
              child: Transform.scale(
                scale: 2,
                alignment: Alignment(ax, ay),
                child: PdpPhoto(url: url, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PdpPhoto extends StatelessWidget {
  const PdpPhoto({super.key, required this.url, this.fit = BoxFit.contain});
  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext c, Object e, StackTrace? s) => const _PhotoFallback();
    if (url.startsWith('http')) {
      return Image.network(url, fit: fit, errorBuilder: fallback, gaplessPlayback: true);
    }
    if (url.startsWith('assets/')) {
      return Image.asset(url, fit: fit, errorBuilder: fallback, gaplessPlayback: true, cacheWidth: 1200);
    }
    return const _PhotoFallback();
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ColoredBox(
      color: theme.alternate,
      child: Center(child: Icon(Icons.image_outlined, size: 48, color: theme.secondaryText)),
    );
  }
}

Future<void> showPdpShareMenu(BuildContext context, TGProduct product) async {
  TGAnalytics.track('share_click', TGAnalytics.listingProps(product));
  final url = Uri.base.replace(path: product.detailPath, query: '').toString();
  final shared = await tryNavigatorShare(title: product.title, text: product.title, url: url);
  if (shared || !context.mounted) return;

  final theme = FlutterFlowTheme.of(context);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.secondaryBackground,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      return SafeArea(
        child: ListTile(
          leading: const Icon(Icons.link),
          title: Text(ctx.t('ui_copy_link')),
          onTap: () async {
            Navigator.pop(ctx);
            await copyTextWithToast(context, url, message: context.t('ui_link_copied'));
          },
        ),
      );
    },
  );
}

Future<void> openPdpLightbox({
  required BuildContext context,
  required List<String> images,
  required int index,
}) async {
  TGAnalytics.track('gallery_open', {'index': index, 'count': images.length});
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 220)),
      reverseTransitionDuration: tgAnim(context, const Duration(milliseconds: 180)),
      pageBuilder: (ctx, a, sa) => _Lightbox(images: images, initial: index),
      transitionsBuilder: (ctx, a, sa, child) {
        if (tgReduceMotion(ctx)) return child;
        final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
        );
      },
    ),
  );
}

class _Lightbox extends StatefulWidget {
  const _Lightbox({required this.images, required this.initial});
  final List<String> images;
  final int initial;

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late final TransformationController _transform = TransformationController();
  late int _index = widget.initial;
  double _drag = 0;

  @override
  void dispose() {
    _pages.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _doubleTap() {
    final m = _transform.value;
    final scale = m.getMaxScaleOnAxis();
    _transform.value = scale > 1.2 ? Matrix4.identity() : (Matrix4.identity()..scaleByDouble(2, 2, 2, 1));
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.images.length;
    return Shortcuts(
      shortcuts: {LogicalKeySet(LogicalKeyboardKey.escape): const _DismissIntent()},
      child: Actions(
        actions: {_DismissIntent: CallbackAction<_DismissIntent>(onInvoke: (_) { _close(); return null; })},
        child: Focus(
          autofocus: true,
          child: Material(
            color: Colors.black,
            child: SafeArea(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pages,
                    itemCount: n,
                    onPageChanged: (i) => setState(() {
                      _index = i;
                      _transform.value = Matrix4.identity();
                    }),
                    itemBuilder: (context, i) {
                      return GestureDetector(
                        onDoubleTap: _doubleTap,
                        onVerticalDragUpdate: (d) {
                          if (_transform.value.getMaxScaleOnAxis() > 1.05) return;
                          setState(() => _drag += d.delta.dy);
                        },
                        onVerticalDragEnd: (d) {
                          if (_drag > 80) {
                            _close();
                          } else {
                            setState(() => _drag = 0);
                          }
                        },
                        child: Transform.translate(
                          offset: Offset(0, _drag.clamp(0, 240)),
                          child: InteractiveViewer(
                            transformationController: _transform,
                            minScale: 1,
                            maxScale: 4,
                            child: Center(child: PdpPhoto(url: widget.images[i], fit: BoxFit.contain)),
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      iconSize: 28,
                      color: Colors.white,
                      onPressed: _close,
                      icon: const Icon(Icons.close),
                      tooltip: context.t('ui_close'),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Text(
                      '${_index + 1} / $n',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}
