import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Search box used by the global header (>= 700 px) and by pages on phones.
///
/// It owns its [TextEditingController]; when the page's committed query changes
/// from the outside (e.g. back button) [initialText] updates the text, unless
/// the user is currently typing.
class TGSearchField extends StatefulWidget {
  const TGSearchField({
    super.key,
    required this.onSubmitted,
    this.initialText = '',
    this.hint,
    this.height = 44,
    this.onChanged,
  });

  final ValueChanged<String> onSubmitted;
  final String initialText;
  final String? hint;
  final double height;
  final ValueChanged<String>? onChanged;

  @override
  State<TGSearchField> createState() => _TGSearchFieldState();
}

class _TGSearchFieldState extends State<TGSearchField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
  }

  void _onText() {
    // Rebuild only to toggle the clear button.
    widget.onChanged?.call(_controller.text);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant TGSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        widget.initialText != _controller.text &&
        !_focus.hasFocus) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(TGRadius.input),
          borderSide: BorderSide(color: c, width: w),
        );

    return SizedBox(
      height: widget.height,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSubmitted,
        style: theme.bodyMedium.override(fontWeight: FontWeight.w600),
        cursorColor: theme.primary,
        decoration: InputDecoration(
          hintText: widget.hint ?? context.t('ui_search_equipment'),
          hintStyle: theme.bodyMedium.override(color: theme.secondaryText, fontWeight: FontWeight.w500),
          isDense: true,
          filled: true,
          fillColor: theme.alternate,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: theme.secondaryText),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: context.t('ui_clear_search'),
                  icon: Icon(Icons.close_rounded, size: 18, color: theme.secondaryText),
                  onPressed: () {
                    _controller.clear();
                    widget.onSubmitted('');
                  },
                ),
          border: border(theme.tertiary),
          enabledBorder: border(theme.tertiary),
          focusedBorder: border(theme.primary, 1.6),
        ),
      ),
    );
  }
}
