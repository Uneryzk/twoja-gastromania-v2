import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_consent.dart';
import 'package:twoja_gastromania/tg_services/special_consent_service.dart';

const kSoConsentRed = Color(0xFFFF5252);

/// 2 px turquoise ring while [child] (or anything inside it) has keyboard focus.
class TGFocusRing extends StatefulWidget {
  const TGFocusRing({super.key, required this.child, this.radius = 12});

  final Widget child;
  final double radius;

  @override
  State<TGFocusRing> createState() => _TGFocusRingState();
}

class _TGFocusRingState extends State<TGFocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (v) => setState(() => _focused = v),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: _focused ? TGColors.cta : Colors.transparent, width: 2),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Red legal warning. Title and body come pre-capitalised from l10n in the
/// active locale; the icon and title carry the meaning without colour.
class SoConsentWarningBox extends StatelessWidget {
  const SoConsentWarningBox({super.key, this.locale});

  /// Defaults to the active app language.
  final String? locale;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final l = locale;
    final title = l == null ? context.t('so_consent_warning_title') : TGSpecialConsentService.line(l, 'so_consent_warning_title');
    final body = l == null ? context.t('so_consent_warning_body') : TGSpecialConsentService.line(l, 'so_consent_warning_body');
    return Semantics(
      key: const Key('so-consent-warning'),
      container: true,
      label: '$title. $body',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSoConsentRed.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kSoConsentRed, width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.gavel_rounded, color: kSoConsentRed, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: kSoConsentRed, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            title,
                            style: theme.titleSmall.override(color: kSoConsentRed, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: theme.bodyMedium.override(color: kSoConsentRed, fontWeight: FontWeight.w800, lineHeight: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Failed proof deliveries for [requestId] with a manual "Resend".
class SoConsentDeliveryBanner extends StatelessWidget {
  const SoConsentDeliveryBanner({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final svc = TGSpecialConsentService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final failed = svc.failedFor(requestId);
        if (failed.isEmpty) return const SizedBox.shrink();
        final theme = FlutterFlowTheme.of(context);
        final channels = failed
            .map((d) => context.t(d.channel == TGConsentChannel.email ? 'so_consent_channel_email' : 'so_consent_channel_sms'))
            .join(', ');
        final message = context.t('so_consent_delivery_failed', {'channels': channels, 'n': '${TGSpecialConsentService.maxAttempts}'});
        return Container(
          key: Key('so-consent-delivery-failed-$requestId'),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: TGColors.slaAmber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: TGColors.slaAmber),
          ),
          child: Row(
            children: [
              const Icon(Icons.sms_failed_outlined, color: TGColors.slaAmber, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: theme.bodySmall.override(fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              TGFocusRing(
                child: TGButton(
                  key: Key('so-consent-resend-$requestId'),
                  onPressed: () {
                    final ok = svc.resend(requestId);
                    final msg = context.t(ok ? 'so_consent_resent' : 'so_consent_resend_failed');
                    SemanticsService.sendAnnouncement(View.of(context), msg, Directionality.of(context));
                    showTGToast(context, msg);
                  },
                  label: context.t('so_consent_resend'),
                  icon: Icons.refresh,
                  variant: TGButtonVariant.ghost,
                  height: 36,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
