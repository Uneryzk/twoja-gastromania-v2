import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';

/// Loads `http(s)` via [Image.network], `assets/` via [Image.asset], else fallback.
class TGSmartImage extends StatelessWidget {
  const TGSmartImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.fallback,
  });

  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final Widget Function(BuildContext context)? fallback;

  @override
  Widget build(BuildContext context) {
    Widget fb(BuildContext c, Object e, StackTrace? s) =>
        fallback?.call(c) ?? _defaultFallback(c);

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(url, fit: fit, cacheWidth: cacheWidth, gaplessPlayback: true, errorBuilder: fb);
    }
    if (url.startsWith('assets/')) {
      return Image.asset(url, fit: fit, cacheWidth: cacheWidth, gaplessPlayback: true, errorBuilder: fb);
    }
    return fallback?.call(context) ?? _defaultFallback(context);
  }

  Widget _defaultFallback(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ColoredBox(
      color: theme.alternate,
      child: Center(child: Icon(Icons.image_outlined, color: theme.secondaryText, size: 28)),
    );
  }
}
