import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_models/tg_watermark.dart';
import 'package:twoja_gastromania/tg_services/watermark_service.dart';

// SECURITY: overlay gives no real protection — the raw file URL stays open.
// In production the watermark must be applied on the server while generating
// derivatives, and the original must never be served publicly.

/// Listing photo + low-opacity transparent logo (prototype overlay).
///
/// The mark is decorative: excluded from semantics and hit testing. It is
/// skipped on [kWatermarkExcludedSurfaces] and when the rendered image is
/// narrower than [WatermarkConfig.minImageWidthPx].
class WatermarkedImage extends StatefulWidget {
  const WatermarkedImage({
    super.key,
    required this.url,
    required this.surface,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.fallback,
    this.config,
  });

  final String url;
  final TGImageSurface surface;
  final BoxFit fit;
  final int? cacheWidth;
  final Widget Function(BuildContext context)? fallback;

  /// Overrides the live config (admin preview / tests).
  final WatermarkConfig? config;

  static const markKey = Key('tg-watermark');

  /// Staff-only original pointer (`originals/…`, `originalRef=`). Never render
  /// this URL on public surfaces — fall back to an empty / placeholder image.
  static bool isPrivateOriginalRef(String url) {
    final u = url.trim();
    if (u.isEmpty) return false;
    final lower = u.toLowerCase();
    return lower.startsWith('originals/') ||
        lower.contains('/originals/') ||
        lower.contains('originalref=') ||
        lower.contains('original_ref');
  }

  /// Public listing URL, or empty when [url] is a private original reference.
  static String publicUrl(String url) => isPrivateOriginalRef(url) ? '' : url;

  @override
  State<WatermarkedImage> createState() => _WatermarkedImageState();
}

class _WatermarkedImageState extends State<WatermarkedImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _intrinsic;

  String get _url => WatermarkedImage.publicUrl(widget.url);

  ImageProvider? get _provider {
    final u = _url;
    if (u.startsWith('assets/')) return AssetImage(u);
    if (u.startsWith('http://') || u.startsWith('https://')) return NetworkImage(u);
    if (u.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(u.split(',').last));
      } catch (_) {}
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant WatermarkedImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _intrinsic = null;
      _resolve();
    }
  }

  /// Intrinsic size is only needed when the image is letterboxed.
  void _resolve() {
    if (widget.fit != BoxFit.contain && widget.fit != BoxFit.scaleDown) return;
    final p = _provider;
    if (p == null) return;
    final next = p.resolve(createLocalImageConfiguration(context));
    if (next.key == _stream?.key) return;
    _unlisten();
    _stream = next;
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final s = Size(info.image.width.toDouble(), info.image.height.toDouble());
      if (s != _intrinsic) setState(() => _intrinsic = s);
    }, onError: (_, __) {});
    next.addListener(_listener!);
  }

  void _unlisten() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _listener = null;
  }

  @override
  void dispose() {
    _unlisten();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    final image = TGSmartImage(url: url, fit: widget.fit, cacheWidth: widget.cacheWidth, fallback: widget.fallback);
    if (!watermarkAppliesTo(widget.surface) || url.isEmpty) return image;
    return ListenableBuilder(
      listenable: TGWatermarkService.instance,
      builder: (context, _) {
        final cfg = widget.config ?? TGWatermarkService.instance.config;
        if (!cfg.enabled) return image;
        return LayoutBuilder(builder: (context, c) {
          final box = Size(
            c.hasBoundedWidth ? c.maxWidth : (_intrinsic?.width ?? 0),
            c.hasBoundedHeight ? c.maxHeight : (_intrinsic?.height ?? 0),
          );
          final rect = _paintedRect(box);
          if (rect.width < cfg.minImageWidthPx) return image;
          final markWidth = rect.width * cfg.widthRatio;
          return Stack(
            fit: StackFit.expand,
            children: [
              image,
              Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Align(
                      alignment: cfg.position.alignment,
                      child: Opacity(
                        key: WatermarkedImage.markKey,
                        opacity: cfg.opacity.clamp(0.0, 1.0),
                        child: Image.asset(
                          cfg.markAsset,
                          width: markWidth,
                          height: markWidth,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  /// Area the photo actually covers inside [box] for the current fit.
  Rect _paintedRect(Size box) {
    final full = Offset.zero & box;
    final src = _intrinsic;
    if (src == null || src.isEmpty || (widget.fit != BoxFit.contain && widget.fit != BoxFit.scaleDown)) return full;
    final fitted = applyBoxFit(widget.fit, src, box).destination;
    return Alignment.center.inscribe(fitted, full);
  }
}
