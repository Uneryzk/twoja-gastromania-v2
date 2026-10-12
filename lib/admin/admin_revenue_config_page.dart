import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_services/restaurant_lifecycle_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

class AdminRevenueConfigPage extends StatefulWidget {
  const AdminRevenueConfigPage({super.key});

  @override
  State<AdminRevenueConfigPage> createState() => _AdminRevenueConfigPageState();
}

class _AdminRevenueConfigPageState extends State<AdminRevenueConfigPage> {
  late TGRevenueConfig _draft;

  @override
  void initState() {
    super.initState();
    _draft = TGRevenueConfigService.instance.config;
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          TGButton(onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_confirm'), height: 40),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final svc = TGRevenueConfigService.instance;

    return ListView(
      padding: EdgeInsets.all(phone ? 12 : 20),
      children: [
        Text(context.t('ui_admin_revenue_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(context.t('ui_admin_revenue_sub'), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 16),
        Builder(builder: (context) {
          final s = RestaurantLifecycleService.instance.revenueStats();
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: theme.alternate),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('ui_admin_resto_live_data'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(context.t('ui_admin_listing_revenue', {'n': '${s.listingRevenuePln}'})),
                Text(context.t('ui_admin_renew_count', {'n': '${s.renewCount}'})),
                Text(context.t('ui_admin_free_starts', {'f': '${s.freeStartCount}', 'e': '${s.extensionCount}'})),
                Text(context.t('ui_admin_free_paid_conv', {'p': (s.freeToPaidConversion * 100).toStringAsFixed(1)})),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        Text(context.t('ui_admin_phase'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('0')),
            ButtonSegment(value: 1, label: Text('1')),
            ButtonSegment(value: 2, label: Text('2')),
          ],
          selected: {_draft.phase},
          onSelectionChanged: (s) async {
            if (!await _confirm(context.t('ui_admin_change_phase'), context.t('ui_admin_apply_phase', {'n': '${s.first}'}))) return;
            svc.setPhase(s.first, actorId: auth.userId, reason: 'admin phase');
            setState(() => _draft = svc.config);
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: Text(context.t('ui_admin_production_mode')),
          subtitle: Text(context.t('ui_admin_production_mode_sub')),
          value: _draft.productionMode,
          onChanged: (v) async {
            if (!await _confirm(
              context.t('ui_admin_production_mode'),
              v ? context.t('ui_admin_enable_prod') : context.t('ui_admin_disable_prod'),
            )) {
              return;
            }
            svc.setProductionMode(v, actorId: auth.userId, reason: 'admin toggle');
            setState(() => _draft = svc.config);
          },
        ),
        const Divider(height: 32),
        Text(context.t('ui_admin_flags'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        for (final e in [
          ('priorityForSale', _draft.flags.priorityForSale),
          ('marketInsight', _draft.flags.marketInsight),
          ('bulkBilling', _draft.flags.bulkBilling),
          ('sponsorSlots', _draft.flags.sponsorSlots),
          ('auditProgram', _draft.flags.auditProgram),
          ('founderProgram', _draft.flags.founderProgram),
          ('bannerAds', _draft.flags.bannerAds),
        ])
          SwitchListTile(
            title: Text(e.$1),
            value: e.$2,
            onChanged: (v) async {
              if (!await _confirm(
                context.t('ui_admin_flag_set', {'name': e.$1}),
                context.t('ui_admin_flag_confirm', {'name': e.$1, 'v': '$v'}),
              )) {
                return;
              }
              svc.setFlag(e.$1, v, actorId: auth.userId, reason: 'admin flag');
              setState(() => _draft = svc.config);
            },
          ),
        const Divider(height: 32),
        Text(context.t('ui_admin_thresholds'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        ListTile(
          title: Text(context.t('ui_admin_quiet_month', {'n': '${_draft.quietMonthThreshold}'})),
          subtitle: Text(context.t('ui_admin_priority_cap_wave', {
            'cap': '${_draft.priority.capPerSegment}',
            'd': '${_draft.waves.delayHours}',
            'a': '${_draft.waves.delayHoursAsap}',
          })),
        ),
        ListTile(
          title: Text(context.t('ui_admin_gate_rule', {
            'n': '${_draft.priority.gate.minRequests30d}',
            'regions': _draft.priority.gate.openRegions.join(', '),
          })),
        ),
        ListTile(
          title: Text(
            context.t('ui_admin_banner_ads_cfg', {
              'price': '${_draft.bannerAds.adSlotPln14}',
              'inc': '${_draft.bannerAds.enterpriseIncludedSlidesPerMonth}',
              'max': '${_draft.bannerAds.maxLiveHeroSlides}',
            }),
          ),
          subtitle: Text(
            _draft.flags.bannerAds && _draft.phase >= 2
                ? context.t('ui_admin_purchase_visible')
                : context.t('ui_admin_purchase_hidden'),
          ),
        ),
        const SizedBox(height: 16),
        Text(context.t('ui_admin_audit_log_section'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        for (final a in svc.audit.take(12))
          ListTile(
            dense: true,
            title: Text(a.action, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${a.detail ?? ""} ${a.reason ?? ""}'.trim()),
            trailing: Text(a.at.toIso8601String().substring(0, 16), style: theme.bodySmall),
          ),
      ],
    );
  }
}

class AdminRevenueConfigHost extends StatelessWidget {
  const AdminRevenueConfigHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'revenue', child: AdminRevenueConfigPage());
}
