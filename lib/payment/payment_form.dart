import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twoja_gastromania/add_product/add_product_draft.dart';
import 'package:twoja_gastromania/add_product/add_product_fields.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_invoice.dart';

class PaymentForm extends StatefulWidget {
  const PaymentForm({
    super.key,
    required this.amountPln,
    required this.onPaid,
    this.compactOtherMethods = false,
    this.autofocusBlik = true,
    this.onCancelWait,
    this.onWaitingChanged,
    this.showPayButton = true,
  });

  final double amountPln;
  final VoidCallback onPaid;
  final bool compactOtherMethods;
  final bool autofocusBlik;
  final VoidCallback? onCancelWait;
  final ValueChanged<bool>? onWaitingChanged;
  final bool showPayButton;

  @override
  State<PaymentForm> createState() => PaymentFormState();
}

class PaymentFormState extends State<PaymentForm> with SingleTickerProviderStateMixin {
  TGPayMethod _method = TGPayMethod.blik;
  bool _showOther = false;
  bool _waiting = false;
  int _secondsLeft = 30;
  String? _error;
  bool _terms = false;
  bool _faktura = false;
  bool _saveCard = false;

  final _blik = List.generate(6, (_) => TextEditingController());
  final _blikFocus = List.generate(6, (_) => FocusNode());
  final _card = TextEditingController();
  final _mm = TextEditingController();
  final _cvc = TextEditingController();
  final _holder = TextEditingController();
  final _nip = TextEditingController();
  final _company = TextEditingController();
  final _address = TextEditingController();
  Timer? _tick;
  Timer? _resolve;
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  bool get waiting => _waiting;

  TGInvoiceBuyer? get invoiceBuyer {
    if (!_faktura) return null;
    return TGInvoiceBuyer(nip: _nip.text.trim(), companyName: _company.text.trim(), address: _address.text.trim());
  }

  void tryPay() => _pay();

  @override
  void initState() {
    super.initState();
    if (widget.autofocusBlik) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _blikFocus.first.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _resolve?.cancel();
    _shake.dispose();
    for (final c in _blik) {
      c.dispose();
    }
    for (final f in _blikFocus) {
      f.dispose();
    }
    _card.dispose();
    _mm.dispose();
    _cvc.dispose();
    _holder.dispose();
    _nip.dispose();
    _company.dispose();
    _address.dispose();
    super.dispose();
  }

  String get _blikCode => _blik.map((c) => c.text).join();

  bool get _canPay {
    if (!_terms || _waiting) return false;
    if (_faktura && (!isValidNip(_nip.text) || _company.text.trim().isEmpty || _address.text.trim().isEmpty)) {
      return false;
    }
    return switch (_method) {
      TGPayMethod.blik => _blikCode.length == 6,
      TGPayMethod.przelewy24 => true,
      TGPayMethod.card => luhnValid(_card.text) && _mm.text.length == 5 && _cvc.text.length >= 3 && _holder.text.trim().length >= 2,
    };
  }

  void _clearBlik() {
    for (final c in _blik) {
      c.clear();
    }
    _blikFocus.first.requestFocus();
  }

  void _onBlikChanged(int i, String v) {
    if (v.length > 1) {
      final digits = v.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 6) {
        for (var k = 0; k < 6; k++) {
          _blik[k].text = digits[k];
        }
        _blikFocus.last.requestFocus();
        setState(() {});
        return;
      }
      _blik[i].text = digits.isEmpty ? '' : digits[0];
    }
    if (v.length == 1 && i < 5) _blikFocus[i + 1].requestFocus();
    if (v.isEmpty && i > 0) _blikFocus[i - 1].requestFocus();
    setState(() {});
  }

  void _pay() {
    if (!_canPay) return;
    setState(() {
      _error = null;
    });
    switch (_method) {
      case TGPayMethod.blik:
        final outcome = resolveBlik(_blikCode);
        if (outcome == TGBlikOutcome.incorrect) {
          setState(() => _error = context.t('ui_blik_code_incorrect'));
          TGAnalytics.emit('payment_failed', {'reason': 'incorrect'});
          _shake.forward(from: 0);
          _clearBlik();
          return;
        }
        _startWait(() {
          if (!mounted) return;
          if (outcome == TGBlikOutcome.success) {
            TGAnalytics.emit('payment_success', {'method': 'blik'});
            widget.onPaid();
          } else if (outcome == TGBlikOutcome.declined) {
            TGAnalytics.emit('payment_failed', {'reason': 'declined'});
            setState(() {
              _waiting = false;
              _error = context.t('ui_payment_declined');
            });
            widget.onWaitingChanged?.call(false);
          } else {
            TGAnalytics.emit('payment_failed', {'reason': 'no_confirmation'});
            setState(() {
              _waiting = false;
              _error = context.t('ui_no_confirmation');
            });
            widget.onWaitingChanged?.call(false);
          }
        });
      case TGPayMethod.przelewy24:
        _startWait(() {
          if (mounted) widget.onPaid();
        }, seconds: 2, delay: const Duration(milliseconds: 1500));
      case TGPayMethod.card:
        _open3ds();
    }
  }

  Future<void> _open3ds() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = FlutterFlowTheme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.secondaryBackground,
          title: Text(ctx.t('ui_3ds_title')),
          content: Text(ctx.t('ui_3ds_body')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_decline'))),
            TextButton(key: const Key('payment-3ds-approve'), onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.t('ui_approve'))),
          ],
        );
      },
    );
    if (ok == true && mounted) widget.onPaid();
    if (ok == false && mounted) setState(() => _error = context.t('ui_payment_declined'));
  }

  void _startWait(VoidCallback onDone, {int seconds = 30, Duration delay = const Duration(milliseconds: 1200)}) {
    _tick?.cancel();
    _resolve?.cancel();
    setState(() {
      _waiting = true;
      _secondsLeft = seconds;
      _error = null;
    });
    widget.onWaitingChanged?.call(true);
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) {
        t.cancel();
        setState(() {
          _waiting = false;
          _error = context.t('ui_no_confirmation');
        });
        widget.onWaitingChanged?.call(false);
        _resolve?.cancel();
      }
    });
    _resolve = Timer(delay, () {
      _tick?.cancel();
      if (mounted) onDone();
    });
  }

  void _cancelWait() {
    _tick?.cancel();
    _resolve?.cancel();
    setState(() => _waiting = false);
    widget.onWaitingChanged?.call(false);
    widget.onCancelWait?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (_waiting) {
      final amber = _secondsLeft <= 10;
      final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
      final body = Column(
        mainAxisAlignment: phone ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          SizedBox(
            width: phone ? 56 : 36,
            height: phone ? 56 : 36,
            child: CircularProgressIndicator(color: amber ? TGColors.rating : theme.primary, strokeWidth: 3),
          ),
          const SizedBox(height: 14),
          Text(
            phone ? context.t('ui_open_bank') : context.t('ui_confirm_bank'),
            textAlign: TextAlign.center,
            style: theme.titleSmall.override(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '$_secondsLeft s',
            style: theme.headlineSmall.override(color: amber ? TGColors.rating : theme.primaryText, fontWeight: FontWeight.w900),
          ),
          TextButton(key: const Key('payment-cancel'), onPressed: _cancelWait, child: Text(context.t('ui_cancel'))),
        ],
      );
      return Semantics(
        liveRegion: true,
        child: phone
            ? SizedBox.expand(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: body)))
            : WizardCard(child: body),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _methodCard(
          method: TGPayMethod.blik,
          title: 'BLIK',
          subtitle: context.t('ui_blik_pay_sub'),
        ),
        if (_method == TGPayMethod.blik) ...[
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final t = _shake.value;
              final dx = (t == 0 || t == 1) ? 0.0 : 8 * (t < 0.25 || (t > 0.5 && t < 0.75) ? 1 : -1) * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: _blikRow(),
          ),
          WizardHelp(context.t('ui_blik_help')),
        ],
        if (widget.compactOtherMethods && !_showOther)
          TextButton(
            onPressed: () => setState(() => _showOther = true),
            child: Text(context.t('ui_other_methods')),
          )
        else ...[
          const SizedBox(height: 10),
          _methodCard(
            method: TGPayMethod.przelewy24,
            title: 'Przelewy24',
            subtitle: context.t('ui_p24_sub'),
          ),
          const SizedBox(height: 10),
          _methodCard(
            method: TGPayMethod.card,
            title: context.t('ui_card'),
            subtitle: context.t('ui_card_brands'),
          ),
          if (_method == TGPayMethod.card) ...[
            const SizedBox(height: 12),
            _cardFields(),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          WizardError(_error!),
          if (_error == context.t('ui_no_confirmation'))
            TextButton(
              onPressed: _pay,
              child: Text(context.t('ui_try_again')),
            ),
        ],
        const SizedBox(height: 16),
        Text(context.t('ui_b2b_invoice'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        _toggle(
          key: const Key('payment-faktura'),
          value: _faktura,
          label: context.t('ui_need_faktura'),
          onChanged: (v) => setState(() => _faktura = v),
        ),
        if (_faktura) ...[
          const SizedBox(height: 8),
          WizardLabel(context.t('ui_nip')),
          WizardField(
            key: const Key('payment-nip'),
            controller: _nip,
            hint: context.t('ui_nip'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          WizardLabel(context.t('ui_company_name')),
          WizardField(key: const Key('payment-company'), controller: _company, hint: context.t('ui_company_name'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          WizardLabel(context.t('ui_address')),
          WizardField(key: const Key('payment-address'), controller: _address, hint: context.t('ui_address'), maxLines: 2, onChanged: (_) => setState(() {})),
        ],
        const SizedBox(height: 8),
        _toggle(
          key: const Key('payment-terms'),
          value: _terms,
          label: context.t('ui_accept_regulamin'),
          onChanged: (v) => setState(() => _terms = v),
        ),
        if (widget.showPayButton) ...[
          const SizedBox(height: 16),
          TGButton(
            key: const Key('payment-pay'),
            onPressed: _canPay ? _pay : null,
            label: context.t('ui_pay_amount', {'amount': formatMoneyPln(widget.amountPln)}),
            height: 48,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
        ],
      ],
    );
  }

  Widget _methodCard({required TGPayMethod method, required String title, required String subtitle}) {
    return WizardRadioCard(
      selected: _method == method,
      title: title,
      subtitle: subtitle,
      onTap: () {
        setState(() => _method = method);
        TGAnalytics.emit('payment_method_selected', {'method': method.name});
      },
    );
  }

  Widget _blikRow() {
    const gap = 8.0;
    const boxW = 48.0;
    const boxH = 56.0;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            SizedBox(
              width: boxW,
              height: boxH,
              child: TextField(
                key: Key('payment-blik-$i'),
                controller: _blik[i],
                focusNode: _blikFocus[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                autofillHints: i == 0 ? const [AutofillHints.oneTimeCode] : null,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(i == 0 ? 6 : 1)],
                onChanged: (v) => _onBlikChanged(i, v),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: TGColors.surfaceHover,
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(TGRadius.input), borderSide: const BorderSide(color: TGColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(TGRadius.input), borderSide: const BorderSide(color: TGColors.cta, width: 2)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardFields() {
    final brand = cardBrand(_card.text);
    return Column(
      children: [
        WizardField(
          key: const Key('payment-card'),
          controller: _card,
          hint: context.t('ui_card_number'),
          keyboardType: TextInputType.number,
          suffix: switch (brand) {
            TGCardBrand.visa => 'Visa',
            TGCardBrand.mastercard => 'MC',
            TGCardBrand.amex => 'Amex',
            TGCardBrand.unknown => null,
          },
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(19)],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: WizardField(controller: _mm, hint: 'MM/YY', keyboardType: TextInputType.number, inputFormatters: [_ExpiryFormatter()])),
            const SizedBox(width: 8),
            Expanded(child: WizardField(controller: _cvc, hint: 'CVC', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)])),
          ],
        ),
        const SizedBox(height: 8),
        WizardField(controller: _holder, hint: context.t('ui_cardholder')),
        _toggle(value: _saveCard, label: context.t('ui_save_card'), onChanged: (v) => setState(() => _saveCard = v)),
      ],
    );
  }

  Widget _toggle({required bool value, required String label, required ValueChanged<bool> onChanged, Key? key}) {
    return InkWell(
      key: key,
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: TGColors.cta,
          ),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final d = next.text.replaceAll(RegExp(r'\D'), '');
    final clipped = d.length > 4 ? d.substring(0, 4) : d;
    final text = clipped.length >= 3 ? '${clipped.substring(0, 2)}/${clipped.substring(2)}' : clipped;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
