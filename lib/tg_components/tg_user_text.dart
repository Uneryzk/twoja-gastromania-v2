import 'package:flutter/material.dart';

/// User-generated copy (listing title/description, messages, reviews, store names).
/// Chrome tests and the language-audit overlay skip this widget.
class TGUserText extends StatelessWidget {
  const TGUserText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textAlign,
    this.semanticsLabel,
    this.strutStyle,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextAlign? textAlign;
  final String? semanticsLabel;
  final StrutStyle? strutStyle;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textAlign: textAlign,
      semanticsLabel: semanticsLabel,
      strutStyle: strutStyle,
    );
  }
}
