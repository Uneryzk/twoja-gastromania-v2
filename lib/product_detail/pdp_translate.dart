import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_services/translation_service.dart';

/// Listing copy stays in the original language until the buyer taps Translate.
class PdpTranslateBlock extends StatefulWidget {
  const PdpTranslateBlock({
    super.key,
    required this.title,
    required this.description,
    required this.bodyStyle,
    required this.descOpen,
    required this.onToggleDesc,
  });

  final String title;
  final String description;
  final TextStyle bodyStyle;
  final bool descOpen;
  final VoidCallback onToggleDesc;

  @override
  State<PdpTranslateBlock> createState() => _PdpTranslateBlockState();
}

class _PdpTranslateBlockState extends State<PdpTranslateBlock> {
  String? _target;
  bool _busy = false;
  String? _titleTx;
  String? _descTx;

  String get _blob => '${widget.title} ${widget.description}';
  String get _src => TranslationService.instance.detectLanguage(_blob);

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final desc = _target == null ? widget.description : (_descTx ?? widget.description);
    final titleTx = _target == null ? null : _titleTx;
    final src = _src;
    final buttons = <Widget>[];
    if (_busy) {
      buttons.add(Text(context.t('ui_translating'), style: theme.bodySmall.override(color: theme.primary, fontWeight: FontWeight.w800)));
    } else if (_target != null) {
      buttons.add(_link(context, context.t('ui_show_original'), () => setState(() => _target = null)));
    } else {
      if (src != 'en') {
        buttons.add(_link(context, context.t('ui_translate_to_en'), () => _go('en'), key: const Key('pdp-translate')));
      }
      if (src != 'tr') {
        buttons.add(_link(context, context.t('ui_translate_to_tr'), () => _go('tr'), key: const Key('pdp-translate-tr')));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(context.t('ui_description'), style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
            if (buttons.isNotEmpty) Wrap(spacing: 8, children: buttons),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: tgAnim(context, const Duration(milliseconds: 200)),
          child: Column(
            key: ValueKey(_target ?? 'orig'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((titleTx ?? '').isNotEmpty) ...[
                Text(titleTx!, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
              ],
              Text(
                desc.isEmpty ? '—' : desc,
                maxLines: widget.descOpen ? 99 : 4,
                overflow: TextOverflow.ellipsis,
                style: widget.bodyStyle,
              ),
            ],
          ),
        ),
        if (widget.description.length > 140)
          TextButton(
            onPressed: widget.onToggleDesc,
            child: Text(widget.descOpen ? context.t('ui_show_less') : context.t('ui_show_more')),
          ),
      ],
    );
  }

  Widget _link(BuildContext context, String label, VoidCallback onTap, {Key? key}) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      key: key,
      onTap: onTap,
      child: Text(label, style: theme.bodySmall.override(color: theme.primary, fontWeight: FontWeight.w800)),
    );
  }

  Future<void> _go(String lang) async {
    if (_busy) return;
    setState(() => _busy = true);
    final svc = TranslationService.instance;
    final title = await svc.translate(widget.title, targetLang: lang);
    final desc = await svc.translate(widget.description, targetLang: lang);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _target = lang;
      _titleTx = title;
      _descTx = desc;
    });
  }
}
