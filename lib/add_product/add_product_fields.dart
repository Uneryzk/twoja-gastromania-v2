import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

class WizardCard extends StatelessWidget {
  const WizardCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: TGColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TGRadius.card),
        side: BorderSide(color: theme.tertiary),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

class WizardLabel extends StatelessWidget {
  const WizardLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: theme.bodyMedium.override(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}

class WizardHelp extends StatelessWidget {
  const WizardHelp(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: theme.bodySmall.override(fontSize: 13, color: TGColors.textSecondary)),
    );
  }
}

class WizardError extends StatelessWidget {
  const WizardError(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: TGColors.error),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: TGColors.error, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class WizardField extends StatelessWidget {
  const WizardField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hint,
    this.suffix,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.enabled = true,
    this.error,
    this.onEditingComplete,
    this.autofillHints,
    this.errorId,
    this.dense = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? suffix;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? error;
  final VoidCallback? onEditingComplete;
  final Iterable<String>? autofillHints;
  final String? errorId;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: maxLines == 1 ? (dense ? 44 : 48) : null,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
            autofillHints: autofillHints,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: theme.bodyMedium.override(color: enabled ? theme.primaryText : theme.secondaryText),
            cursorColor: theme.primary,
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              suffixText: suffix,
              suffixStyle: theme.bodySmall.override(fontWeight: FontWeight.w700, fontSize: dense ? 11 : 13),
              filled: true,
              fillColor: enabled ? TGColors.surfaceHover : TGColors.surfaceHover.withValues(alpha: 0.5),
              contentPadding: EdgeInsets.symmetric(horizontal: dense ? 8 : 14, vertical: maxLines == 1 ? 0 : 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(TGRadius.input),
                borderSide: BorderSide(color: error != null ? TGColors.error : TGColors.border),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(TGRadius.input),
                borderSide: const BorderSide(color: TGColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(TGRadius.input),
                borderSide: BorderSide(color: error != null ? TGColors.error : theme.primary, width: 2),
              ),
            ),
          ),
        ),
        if (error != null) WizardError(error!, key: errorId == null ? null : Key(errorId!)),
      ],
    );
  }
}

class WizardSegmented<T> extends StatelessWidget {
  const WizardSegmented({super.key, required this.value, required this.options, required this.onChanged, this.large = false});
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TGColors.surfaceHover,
        borderRadius: BorderRadius.circular(TGRadius.input),
        border: Border.all(color: TGColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(options[i].$1),
                child: AnimatedContainer(
                  duration: TGMotion.quick,
                  height: large ? 56 : 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == options[i].$1 ? theme.primary.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(TGRadius.input),
                    border: value == options[i].$1 ? Border.all(color: theme.primary, width: 2) : null,
                  ),
                  child: Text(
                    options[i].$2,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.titleSmall.override(
                      fontWeight: FontWeight.w800,
                      color: value == options[i].$1 ? theme.primary : theme.primaryText,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WizardRadioCard extends StatefulWidget {
  const WizardRadioCard({
    super.key,
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.compact = false,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<WizardRadioCard> createState() => _WizardRadioCardState();
}

class _WizardRadioCardState extends State<WizardRadioCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: TGMotion.quick,
          padding: EdgeInsets.all(widget.compact ? 10 : 14),
          decoration: BoxDecoration(
            color: TGColors.surfaceHover,
            borderRadius: BorderRadius.circular(TGRadius.card),
            border: Border.all(
              color: _focused ? TGColors.cta : (widget.selected ? theme.primary : TGColors.border),
              width: _focused || widget.selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[widget.leading!, SizedBox(width: widget.compact ? 8 : 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.titleSmall.override(fontWeight: FontWeight.w800, fontSize: widget.compact ? 13 : null)),
                    if (widget.subtitle != null)
                      Text(widget.subtitle!, maxLines: widget.compact ? 1 : 2, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(color: theme.secondaryText, fontSize: widget.compact ? 11 : null)),
                  ],
                ),
              ),
              if (widget.selected) Icon(Icons.check_circle, size: widget.compact ? 18 : 24, color: theme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class WizardDropdown extends StatelessWidget {
  const WizardDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.dense = false,
  });

  final String? value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      height: dense ? 44 : 48,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        isDense: true,
        hint: hint == null ? null : Text(hint!, overflow: TextOverflow.ellipsis),
        items: [
          for (final e in items)
            DropdownMenuItem(value: e.$1, child: Text(e.$2, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: TGColors.surfaceHover,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: 0),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(TGRadius.input), borderSide: const BorderSide(color: TGColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(TGRadius.input), borderSide: BorderSide(color: theme.primary, width: 2)),
        ),
      ),
    );
  }
}
