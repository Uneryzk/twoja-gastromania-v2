import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Mock phone → send SMS → enter 123456. Used by deal confirm and review composer.
class TGSmsGate extends StatefulWidget {
  const TGSmsGate({
    super.key,
    required this.intro,
    this.phoneFieldKey = const Key('sms-phone'),
    this.codeFieldKey = const Key('sms-code'),
  });

  final String intro;
  final Key phoneFieldKey;
  final Key codeFieldKey;

  @override
  State<TGSmsGate> createState() => TGSmsGateState();
}

class TGSmsGateState extends State<TGSmsGate> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool codeSent = false;
  String? error;

  String get digits => _phone.text.replaceAll(RegExp(r'\D'), '');
  bool get hasPhone => digits.length >= 9;

  String get masked {
    final d = digits;
    if (d.length < 6) return '+48 ***';
    return '+48 ${d.substring(0, 3)} *** ${d.substring(d.length - 3)}';
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  bool send() {
    if (!hasPhone) {
      setState(() => error = context.t('ui_sms_phone_short'));
      return false;
    }
    setState(() {
      codeSent = true;
      error = null;
    });
    return true;
  }

  bool verify() {
    if (_code.text.trim() != '123456') {
      setState(() => error = context.t('ui_sms_wrong'));
      return false;
    }
    setState(() => error = null);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.intro, style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (!codeSent) ...[
          TextField(
            key: widget.phoneFieldKey,
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            decoration: InputDecoration(hintText: context.t('ui_sms_phone_hint'), prefixText: '+48 '),
            onChanged: (_) => setState(() => error = null),
          ),
          const SizedBox(height: 6),
          Text(context.t('ui_sms_phone_help'), style: theme.bodySmall.override(color: theme.secondaryText)),
        ] else ...[
          Text(context.t('ui_sms_sent_to', {'n': masked}), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 8),
          TextField(
            key: widget.codeFieldKey,
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            decoration: InputDecoration(hintText: context.t('ui_sms_code_hint')),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                codeSent = false;
                _code.clear();
                error = null;
              }),
              child: Text(context.t('ui_sms_change_number')),
            ),
          ),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(error!, style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}
