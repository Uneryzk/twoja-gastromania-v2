import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';
import 'package:twoja_gastromania/tg_services/referral_repository.dart';

/// Optional referral code + consent. Used on every register surface.
class ReferralCodeField extends StatefulWidget {
  const ReferralCodeField({super.key, this.initialCode, this.signupLocked = false, this.applicantUserId});

  final String? initialCode;
  final bool signupLocked;
  final String? applicantUserId;

  @override
  State<ReferralCodeField> createState() => ReferralCodeFieldState();
}

class ReferralCodeFieldState extends State<ReferralCodeField> {
  late final TextEditingController _ctrl;
  TGReferralCodeCheck? _check;
  bool _consent = false;

  @override
  void initState() {
    super.initState();
    final repo = ReferralRepository.instance;
    repo.ensureSeeded();
    final seed = widget.initialCode?.trim().isNotEmpty == true ? widget.initialCode! : repo.sessionCode;
    _ctrl = TextEditingController(text: seed);
    _consent = repo.sessionConsent;
    if (seed.isNotEmpty) {
      repo.setSessionCode(seed);
      _check = widget.signupLocked
          ? const TGReferralCodeCheck(result: TGReferralCodeResult.signupOnly)
          : repo.checkCode(seed, recordFailure: false, applicantUserId: widget.applicantUserId);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final repo = ReferralRepository.instance;
    repo.setSessionCode(raw);
    repo.setSessionConsent(false);
    setState(() {
      _consent = false;
      _check = raw.trim().isEmpty
          ? null
          : widget.signupLocked
              ? const TGReferralCodeCheck(result: TGReferralCodeResult.signupOnly)
              : repo.checkCode(raw, applicantUserId: widget.applicantUserId);
    });
  }

  void _setConsent(bool? v) {
    final on = v ?? false;
    ReferralRepository.instance.setSessionConsent(on);
    setState(() => _consent = on);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final valid = _check?.result == TGReferralCodeResult.valid && !widget.signupLocked;
    final limited = _check?.result == TGReferralCodeResult.rateLimited;
    final unknown = _check?.result == TGReferralCodeResult.unrecognized;
    final signupOnly = widget.signupLocked || _check?.result == TGReferralCodeResult.signupOnly;
    return Column(
      key: const Key('referral-code-field'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('referral-code-input'),
          controller: _ctrl,
          onChanged: _onChanged,
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            labelText: context.t('ref_code_label'),
            hintText: context.t('ref_code_hint'),
            prefixIcon: const Icon(Icons.card_giftcard_outlined),
          ),
        ),
        if (signupOnly && _ctrl.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(context.t('ref_code_signup_only'), key: const Key('referral-code-signup-only'), style: theme.bodySmall.override(color: theme.secondaryText)),
        ] else if (valid) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              context.t('ref_code_valid', {'name': _check!.firstName ?? ''}),
              key: const Key('referral-code-valid'),
              style: theme.bodySmall.override(color: TGColors.verified, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.primaryBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.alternate),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t('ref_consent_draft'), style: theme.labelSmall.override(color: TGColors.slaAmber, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(context.t('ref_consent_body'), style: theme.bodySmall),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    key: const Key('referral-consent'),
                    value: _consent,
                    onChanged: _setConsent,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(context.t('ref_consent_check'), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ] else if (unknown) ...[
          const SizedBox(height: 8),
          Text(context.t('ref_code_unknown'), key: const Key('referral-code-unknown'), style: theme.bodySmall.override(color: theme.secondaryText)),
        ] else if (limited) ...[
          const SizedBox(height: 8),
          Text(context.t('ref_code_limited'), key: const Key('referral-code-limited'), style: theme.bodySmall.override(color: TGColors.slaAmber)),
        ],
      ],
    );
  }
}
