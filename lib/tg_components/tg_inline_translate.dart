import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/translation_service.dart';

/// Shows [text] in its original language with EN / TR translate actions.
class TGInlineTranslate extends StatefulWidget {
  const TGInlineTranslate({
    super.key,
    required this.text,
    this.style,
    this.compact = false,
    this.enKey,
    this.trKey,
  });

  final String text;
  final TextStyle? style;
  final bool compact;
  final Key? enKey;
  final Key? trKey;

  @override
  State<TGInlineTranslate> createState() => _TGInlineTranslateState();
}

class _TGInlineTranslateState extends State<TGInlineTranslate> {
  String? _target;
  bool _busy = false;
  final _cache = <String, String>{};

  @override
  void didUpdateWidget(covariant TGInlineTranslate old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _target = null;
      _cache.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final src = TranslationService.instance.detectLanguage(widget.text);
    final displayed = _target == null ? widget.text : (_cache[_target] ?? widget.text);
    final buttons = <Widget>[];
    if (_busy) {
      buttons.add(Text(context.t('ui_translating'), style: const TextStyle(fontSize: 11, color: TGColors.cta, fontWeight: FontWeight.w800)));
    } else if (_target != null) {
      buttons.add(_link(context.t('ui_show_original'), () => setState(() => _target = null)));
    } else {
      if (src != 'en') {
        buttons.add(_link(context.t('ui_translate_to_en'), () => _go('en'), key: widget.enKey ?? const Key('translate-en')));
      }
      if (src != 'tr') {
        buttons.add(_link(context.t('ui_translate_to_tr'), () => _go('tr'), key: widget.trKey ?? const Key('translate-tr')));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (buttons.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(spacing: 8, children: buttons),
          ),
        AnimatedSwitcher(
          duration: tgAnim(context, const Duration(milliseconds: 200)),
          child: Text(
            displayed,
            key: ValueKey('${_target ?? 'orig'}-${displayed.hashCode}'),
            style: widget.style,
          ),
        ),
      ],
    );
  }

  Widget _link(String label, VoidCallback onTap, {Key? key}) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Text(label, style: TextStyle(fontSize: widget.compact ? 10 : 11, fontWeight: FontWeight.w800, color: TGColors.cta)),
    );
  }

  Future<void> _go(String lang) async {
    if (_busy) return;
    if (_cache[lang] != null) {
      setState(() => _target = lang);
      return;
    }
    setState(() => _busy = true);
    final out = await TranslationService.instance.translate(widget.text, targetLang: lang);
    if (!mounted) return;
    setState(() {
      _cache[lang] = out;
      _target = lang;
      _busy = false;
    });
  }
}
