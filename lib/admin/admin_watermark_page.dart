import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_watermarked_image.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_watermark.dart';
import 'package:twoja_gastromania/tg_services/watermark_service.dart';

class AdminWatermarkHost extends StatelessWidget {
  const AdminWatermarkHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'watermark', child: AdminWatermarkPage());
}

/// Watermark config, live preview, scope exclusions and the reprocess job.
class AdminWatermarkPage extends StatefulWidget {
  const AdminWatermarkPage({super.key});

  static const routeName = 'AdminWatermark';
  static const routePath = '/admin/watermark';

  @override
  State<AdminWatermarkPage> createState() => _AdminWatermarkPageState();
}

class _AdminWatermarkPageState extends State<AdminWatermarkPage> {
  final _svc = TGWatermarkService.instance;
  late bool _enabled;
  late TGWatermarkPosition _position;
  late final TextEditingController _mark;
  late final TextEditingController _opacity;
  late final TextEditingController _width;
  late final TextEditingController _minWidth;

  @override
  void initState() {
    super.initState();
    final c = _svc.config;
    _enabled = c.enabled;
    _position = c.position;
    _mark = TextEditingController(text: c.markAsset);
    _opacity = TextEditingController(text: '${(c.opacity * 100).round()}');
    _width = TextEditingController(text: '${(c.widthRatio * 100).round()}');
    _minWidth = TextEditingController(text: '${c.minImageWidthPx}');
  }

  @override
  void dispose() {
    _mark.dispose();
    _opacity.dispose();
    _width.dispose();
    _minWidth.dispose();
    super.dispose();
  }

  int _int(TextEditingController c, int fallback) => int.tryParse(c.text.trim()) ?? fallback;

  WatermarkConfig get _draft {
    final c = _svc.config;
    return c.copyWith(
      enabled: _enabled,
      position: _position,
      markAsset: _mark.text.trim().isEmpty ? c.markAsset : _mark.text.trim(),
      opacity: _int(_opacity, (c.opacity * 100).round()).clamp(1, 100) / 100,
      widthRatio: _int(_width, (c.widthRatio * 100).round()).clamp(5, 90) / 100,
      minImageWidthPx: _int(_minWidth, c.minImageWidthPx).clamp(0, 4000),
    );
  }

  void _save() {
    _svc.setConfig(_draft, actorId: context.read<FakeAuthState>().userId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('ui_admin_saved'))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ListenableBuilder(
      listenable: _svc,
      builder: (context, _) {
        final cfg = _svc.config;
        final stale = _svc.running ? null : _svc.staleCount();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Semantics(header: true, child: Text(context.t('wm_admin_title'), style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
            const SizedBox(height: 8),
            Container(
              key: const Key('wm-admin-security'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TGColors.slaAmber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(TGRadius.input),
                border: Border.all(color: TGColors.slaAmber.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: TGColors.slaAmber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.t('wm_security_warning'), style: theme.bodySmall.override(fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(context.t('wm_admin_config', {'v': '${cfg.version}'}), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
            SwitchListTile(
              key: const Key('wm-admin-enabled'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('wm_admin_enabled')),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field('wm-admin-mark', _mark, 'wm_admin_mark', width: 340, number: false),
                _field('wm-admin-opacity', _opacity, 'wm_admin_opacity'),
                _field('wm-admin-width', _width, 'wm_admin_width'),
                _field('wm-admin-min-width', _minWidth, 'wm_admin_min_width'),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<TGWatermarkPosition>(
                    key: const Key('wm-admin-position'),
                    initialValue: _position,
                    decoration: InputDecoration(labelText: context.t('wm_admin_position'), isDense: true),
                    items: [
                      for (final p in TGWatermarkPosition.values) DropdownMenuItem(value: p, child: Text(context.t('wm_pos_${p.wire}'))),
                    ],
                    onChanged: (v) => setState(() => _position = v ?? _position),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(context.t('wm_admin_preview'), style: theme.labelMedium.override(color: theme.secondaryText, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(TGRadius.card),
                  child: SizedBox(
                    key: const Key('wm-admin-live-preview'),
                    width: math.min(360, c.maxWidth),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: WatermarkedImage(url: TGListingImages.fridge700, surface: TGImageSurface.uploadPreview, config: _draft),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TGButton(key: const Key('wm-admin-save'), onPressed: _save, label: context.t('wm_admin_save'), height: 44),
            ),
            const SizedBox(height: 24),
            Text(context.t('wm_admin_excluded_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(context.t('wm_admin_excluded_list'), key: const Key('wm-admin-excluded'), style: theme.bodySmall.override(color: theme.secondaryText)),
            const SizedBox(height: 24),
            Text(context.t('wm_admin_reprocess_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              _svc.running
                  ? context.t('wm_admin_reprocess_running', {'done': '${_svc.done}', 'total': '${_svc.total}'})
                  : context.t('wm_admin_reprocess_stale', {'n': '${stale ?? 0}', 'v': '${cfg.version}'}),
              key: const Key('wm-admin-reprocess-status'),
              style: theme.bodySmall.override(color: theme.secondaryText),
            ),
            const SizedBox(height: 8),
            if (_svc.running || _svc.lastRunAt != null)
              Semantics(
                label: context.t('wm_admin_reprocess_title'),
                value: '${(_svc.progress * 100).round()}%',
                child: LinearProgressIndicator(key: const Key('wm-admin-progress'), value: _svc.progress, minHeight: 8),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TGButton(
                key: const Key('wm-admin-reprocess'),
                onPressed: _svc.running ? null : () => _svc.startReprocess(actorId: context.read<FakeAuthState>().userId),
                label: context.t('wm_admin_reprocess'),
                icon: Icons.autorenew,
                height: 44,
                variant: TGButtonVariant.outline,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _field(String key, TextEditingController c, String label, {double width = 160, bool number = true}) => SizedBox(
        width: width,
        child: TextField(
          key: Key(key),
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: context.t(label), isDense: true),
        ),
      );
}
