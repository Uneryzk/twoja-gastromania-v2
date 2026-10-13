import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/go_live_checks.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

String _tierName(PromotionTier t) => t.name[0].toUpperCase() + t.name.substring(1);

class _NumField extends StatelessWidget {
  const _NumField({required this.controller, required this.label, this.suffix});
  final TextEditingController controller;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 120,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label, suffixText: suffix, isDense: true),
        ),
      );
}

Widget _card(BuildContext context, {required String title, String? subtitle, required List<Widget> children}) {
  final theme = FlutterFlowTheme.of(context);
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: theme.bodySmall.override(color: theme.secondaryText)),
        ],
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

/// Bold / Glow / Spotlight prices, capacities and the Bold "Sponsored" label
/// (listings, restaurants and manufacturer cards share these packages).
class AdminPromotionSettings extends StatefulWidget {
  const AdminPromotionSettings({super.key, required this.confirm});
  final Future<bool> Function(String title, String body) confirm;

  @override
  State<AdminPromotionSettings> createState() => _AdminPromotionSettingsState();
}

class _AdminPromotionSettingsState extends State<AdminPromotionSettings> {
  late final List<int> _durations = PricingConfigService.instance.config.promotions.durations;
  final Map<(PromotionTier, int), TextEditingController> _price = {};
  final Map<PromotionTier, TextEditingController> _cap = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final p = PricingConfigService.instance.config.promotions;
    for (final t in PromotionTier.values) {
      for (final d in _durations) {
        (_price[(t, d)] ??= TextEditingController()).text = '${p.pricePln(t, d)}';
      }
      (_cap[t] ??= TextEditingController()).text = '${p.maxActive(t)}';
    }
  }

  @override
  void dispose() {
    for (final c in [..._price.values, ..._cap.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final prices = <PromotionTier, Map<int, int>>{};
    for (final e in _price.entries) {
      final v = int.tryParse(e.value.text) ?? 0;
      if (v <= 0) return setState(() => _error = context.t('ui_admin_promo_err_positive'));
      (prices[e.key.$1] ??= {})[e.key.$2] = v;
    }
    int cap(PromotionTier t) => int.tryParse(_cap[t]!.text) ?? 0;
    if (PromotionTier.values.any((t) => cap(t) <= 0)) {
      return setState(() => _error = context.t('ui_admin_promo_err_positive'));
    }
    setState(() => _error = null);
    if (!await widget.confirm(context.t('ui_admin_promo_title'), context.t('ui_admin_promo_confirm'))) return;
    if (!mounted) return;
    final svc = PricingConfigService.instance;
    final next = svc.config.promotions.copyWith(
      prices: prices,
      spotlightMaxActive: cap(PromotionTier.spotlight),
      glowMaxActive: cap(PromotionTier.glow),
      boldMaxActive: cap(PromotionTier.bold),
      labelBold: false,
    );
    svc.setConfig(svc.config.copyWith(promotions: next));
    TGRevenueConfigService.instance.logPricingChange(
      actorId: context.read<FakeAuthState>().userId,
      action: 'Promotion settings updated',
      detail: [
        for (final t in PromotionTier.values)
          '${_tierName(t)} ${[for (final d in _durations) '${d}d ${prices[t]?[d]}'].join('/')} PLN ×${cap(t)}',
      ].join(' · '),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('ui_admin_saved'))));
  }

  @override
  Widget build(BuildContext context) {
    final cfg = PricingConfigService.instance.config;
    final theme = FlutterFlowTheme.of(context);
    return _card(
      context,
      title: context.t('ui_admin_promo_title'),
      subtitle: context.t('ui_admin_promo_sub'),
      children: [
        for (final t in const [PromotionTier.spotlight, PromotionTier.glow, PromotionTier.bold]) ...[
          Text(_tierName(t), style: theme.labelLarge.override(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              for (final d in _durations)
                _NumField(controller: _price[(t, d)]!, label: DurationFormatter.daysOf(context, d), suffix: 'PLN'),
              _NumField(controller: _cap[t]!, label: context.t('ui_admin_promo_capacity')),
              Text(
                cfg.perDayLabel(cfg.promotions.pricePln(t, _durations.last), _durations.last,
                    unit: context.t('ui_pln_per_day')),
                style: theme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(_error!, style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TGButton(onPressed: _save, label: context.t('ui_admin_save_promo'), height: 44),
        ),
      ],
    );
  }
}

/// Project type × region sponsor slot prices (1 week / 2 weeks / 1 month).
class AdminSponsorSlotPricing extends StatefulWidget {
  const AdminSponsorSlotPricing({super.key, required this.confirm});
  final Future<bool> Function(String title, String body) confirm;

  @override
  State<AdminSponsorSlotPricing> createState() => _AdminSponsorSlotPricingState();
}

class _AdminSponsorSlotPricingState extends State<AdminSponsorSlotPricing> {
  late final Map<int, TextEditingController> _c = {
    for (final k in PricingConfigService.instance.config.sponsorSlot.durations)
      k: TextEditingController(text: '${PricingConfigService.instance.config.sponsorSlot.pricePln(k)}'),
  };
  String? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final prices = {for (final e in _c.entries) e.key: int.tryParse(e.value.text) ?? 0};
    if (prices.values.any((v) => v <= 0)) return setState(() => _error = context.t('ui_admin_promo_err_positive'));
    setState(() => _error = null);
    if (!await widget.confirm(context.t('ui_admin_sponsor_pricing'), context.t('ui_admin_promo_confirm'))) return;
    if (!mounted) return;
    final svc = PricingConfigService.instance;
    svc.setConfig(svc.config.copyWith(sponsorSlot: svc.config.sponsorSlot.copyWith(prices: prices)));
    TGRevenueConfigService.instance.logPricingChange(
      actorId: context.read<FakeAuthState>().userId,
      action: 'Sponsor slot prices updated',
      detail: [for (final k in PricingConfigService.instance.config.sponsorSlot.durations) '${k}d ${prices[k]} PLN'].join(' · '),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('ui_admin_saved'))));
  }

  @override
  Widget build(BuildContext context) {
    final cfg = PricingConfigService.instance.config;
    final theme = FlutterFlowTheme.of(context);
    return _card(
      context,
      title: context.t('ui_admin_sponsor_pricing'),
      subtitle: context.t('ui_admin_sponsor_pricing_sub', {'h': '${cfg.sponsorSlot.holdHours}'}),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final k in PricingConfigService.instance.config.sponsorSlot.durations)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NumField(controller: _c[k]!, label: DurationFormatter.daysOf(context, k), suffix: 'PLN'),
                  const SizedBox(height: 4),
                  Text(cfg.perDayLabel(cfg.sponsorSlot.pricePln(k), k, unit: context.t('ui_pln_per_day')),
                      style: theme.bodySmall),
                ],
              ),
          ],
        ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(_error!, style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TGButton(onPressed: _save, label: context.t('ui_admin_save_promo'), height: 44),
        ),
      ],
    );
  }
}

/// Launch readiness list (no audit-program items).
class AdminGoLiveChecks extends StatelessWidget {
  const AdminGoLiveChecks({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([TGRevenueConfigService.instance, PricingConfigService.instance]),
      builder: (context, _) {
        final theme = FlutterFlowTheme.of(context);
        final checks = tgGoLiveChecks();
        final blockers = checks.where((c) => c.blocking && !c.ok).length;
        return _card(
          context,
          title: context.t('ui_golive_title'),
          subtitle: blockers == 0 ? context.t('ui_golive_ready') : context.t('ui_golive_blockers', {'n': '$blockers'}),
          children: [
            for (final c in checks)
              Semantics(
                label: '${context.t(c.labelKey)}: ${context.t(c.ok ? 'ui_golive_ok' : (c.blocking ? 'ui_golive_todo' : 'ui_golive_info'))}',
                excludeSemantics: true,
                child: Padding(
                  key: ValueKey('golive_${c.id}'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        c.ok ? Icons.check_circle : (c.blocking ? Icons.error_outline : Icons.info_outline),
                        size: 18,
                        color: c.ok ? TGColors.verified : (c.blocking ? TGColors.error : theme.secondaryText),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(context.t(c.labelKey), style: theme.bodyMedium)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
