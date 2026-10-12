import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_core/tg_file_pick.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Admin/seller control: set listing or equipment image via upload, URL, or asset library.
class TGManualImageField extends StatefulWidget {
  const TGManualImageField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.height = 140,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final double height;

  @override
  State<TGManualImageField> createState() => _TGManualImageFieldState();
}

class _TGManualImageFieldState extends State<TGManualImageField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);
  bool _busy = false;

  @override
  void didUpdateWidget(covariant TGManualImageField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _ctrl.text != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    setState(() => _busy = true);
    final dataUrl = await pickImageAsDataUrl();
    if (!mounted) return;
    setState(() => _busy = false);
    if (dataUrl == null || dataUrl.isEmpty) return;
    _ctrl.text = dataUrl;
    widget.onChanged(dataUrl);
  }

  Future<void> _pickLibrary() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => _AssetLibraryDialog(selected: widget.value),
    );
    if (picked == null || !mounted) return;
    _ctrl.text = picked;
    widget.onChanged(picked);
  }

  void _applyPath() {
    final v = _ctrl.text.trim();
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final url = widget.value.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(TGRadius.card),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: url.isEmpty
                ? ColoredBox(
                    color: TGColors.surfaceHover,
                    child: Center(
                      child: Text(context.t('ui_image_none'), style: theme.bodySmall.override(color: theme.secondaryText)),
                    ),
                  )
                : TGSmartImage(url: url, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: context.t('ui_image_path_hint'),
            labelText: context.t('ui_image_path_or_url'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(TGRadius.input)),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _applyPath(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TGButton(
              key: const Key('manual-image-apply'),
              onPressed: _busy ? null : _applyPath,
              label: context.t('ui_image_apply'),
              variant: TGButtonVariant.outline,
              height: 40,
            ),
            TGButton(
              key: const Key('manual-image-upload'),
              onPressed: _busy ? null : _upload,
              label: _busy ? context.t('ui_saving') : context.t('ui_image_upload'),
              height: 40,
            ),
            TGButton(
              key: const Key('manual-image-library'),
              onPressed: _busy ? null : _pickLibrary,
              label: context.t('ui_image_from_library'),
              variant: TGButtonVariant.ghost,
              height: 40,
            ),
            if (url.isNotEmpty)
              TextButton(
                key: const Key('manual-image-clear'),
                onPressed: () {
                  _ctrl.clear();
                  widget.onChanged('');
                },
                child: Text(context.t('ui_image_clear')),
              ),
          ],
        ),
      ],
    );
  }
}

class _AssetLibraryDialog extends StatelessWidget {
  const _AssetLibraryDialog({required this.selected});
  final String selected;

  @override
  Widget build(BuildContext context) {
    const assets = TGListingImages.listingPool;
    return AlertDialog(
      title: Text(context.t('ui_image_from_library')),
      content: SizedBox(
        width: 520,
        height: 420,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemCount: assets.length,
          itemBuilder: (context, i) {
            final a = assets[i];
            final sel = a == selected;
            return InkWell(
              onTap: () => Navigator.pop(context, a),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? TGColors.cta : TGColors.border, width: sel ? 2 : 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: TGSmartImage(url: a, fit: BoxFit.cover),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('ui_cancel'))),
      ],
    );
  }
}
