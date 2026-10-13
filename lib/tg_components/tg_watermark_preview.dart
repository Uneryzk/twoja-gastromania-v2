import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_watermarked_image.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_watermark.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/watermark_service.dart';

/// Upload step: "Preview (with logo)" toggle + Regulamin photo-licence notice.
class TGWatermarkUploadPreview extends StatefulWidget {
  const TGWatermarkUploadPreview({super.key, required this.photos, this.surface = 'listing'});

  final List<String> photos;

  /// Analytics only (`listing` / `restaurant`).
  final String surface;

  @override
  State<TGWatermarkUploadPreview> createState() => _TGWatermarkUploadPreviewState();
}

class _TGWatermarkUploadPreviewState extends State<TGWatermarkUploadPreview> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final cover = widget.photos.where((p) => p.trim().isNotEmpty).firstOrNull;
    final enabled = TGWatermarkService.instance.config.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cover != null && enabled)
          SwitchListTile(
            key: const Key('wm-preview-toggle'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(context.t('wm_preview_toggle'), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
            subtitle: Text(context.t('wm_preview_help'), style: theme.bodySmall.override(color: theme.secondaryText)),
            value: _on,
            onChanged: (v) {
              setState(() => _on = v);
              TGAnalytics.track('watermark_preview_toggle', {'on': v, 'surface': widget.surface});
            },
          ),
        if (_on && cover != null && enabled)
          LayoutBuilder(
            builder: (context, c) => ClipRRect(
              borderRadius: BorderRadius.circular(TGRadius.card),
              child: SizedBox(
                key: const Key('wm-upload-preview'),
                width: math.min(360, c.maxWidth),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: WatermarkedImage(url: cover, surface: TGImageSurface.uploadPreview, cacheWidth: TGImageVariant.card.widthPx),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const TGPhotoLicenseNotice(),
      ],
    );
  }
}

/// Regulamin clause: photos are shown with our logo and licensed for platform use.
class TGPhotoLicenseNotice extends StatelessWidget {
  const TGPhotoLicenseNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final draft = kPhotoLicenseClauseIsDraft && !TGRevenueConfigService.instance.productionMode;
    return Row(
      key: const Key('wm-license-notice'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 16, color: theme.secondaryText),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.t('regulamin_photo_license'), style: theme.bodySmall.override(color: theme.secondaryText)),
              if (draft)
                Container(
                  key: const Key('wm-license-draft'),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: TGColors.slaAmber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(TGRadius.pill)),
                  child: Text(context.t('regulamin_photo_license_status'), style: theme.labelSmall.override(color: TGColors.slaAmber, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
