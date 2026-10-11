import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TGButton(onPressed: () => Navigator.pop(ctx, true), label: 'Confirm', height: 40),
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
        Text('Revenue config', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Phase & flags control Priority, market insight, and production mode.', style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 16),
        Text('Phase', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('0')),
            ButtonSegment(value: 1, label: Text('1')),
            ButtonSegment(value: 2, label: Text('2')),
          ],
          selected: {_draft.phase},
          onSelectionChanged: (s) async {
            if (!await _confirm('Change phase', 'Apply phase ${s.first} presets?')) return;
            svc.setPhase(s.first, actorId: auth.userId, reason: 'admin phase');
            setState(() => _draft = svc.config);
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Production mode'),
          subtitle: const Text('Hides mock manufacturers and requires real stats ≥5'),
          value: _draft.productionMode,
          onChanged: (v) async {
            if (!await _confirm('Production mode', v ? 'Enable production mode?' : 'Disable production mode?')) return;
            svc.setProductionMode(v, actorId: auth.userId, reason: 'admin toggle');
            setState(() => _draft = svc.config);
          },
        ),
        const Divider(height: 32),
        Text('Flags', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        for (final e in [
          ('priorityForSale', _draft.flags.priorityForSale),
          ('marketInsight', _draft.flags.marketInsight),
          ('bulkBilling', _draft.flags.bulkBilling),
          ('sponsorSlots', _draft.flags.sponsorSlots),
          ('auditProgram', _draft.flags.auditProgram),
          ('founderProgram', _draft.flags.founderProgram),
        ])
          SwitchListTile(
            title: Text(e.$1),
            value: e.$2,
            onChanged: (v) async {
              if (!await _confirm('Flag ${e.$1}', 'Set ${e.$1} = $v?')) return;
              svc.setFlag(e.$1, v, actorId: auth.userId, reason: 'admin flag');
              setState(() => _draft = svc.config);
            },
          ),
        const Divider(height: 32),
        Text('Thresholds', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        ListTile(
          title: Text('Quiet month threshold: ${_draft.quietMonthThreshold}'),
          subtitle: Text('Priority seat cap: ${_draft.priority.capPerSegment} · Wave delay ${_draft.waves.delayHours}h / ASAP ${_draft.waves.delayHoursAsap}h'),
        ),
        ListTile(
          title: Text('Gate: ≥${_draft.priority.gate.minRequests30d} requests / 30d in ${_draft.priority.gate.openRegions.join(", ")}'),
        ),
        const SizedBox(height: 16),
        Text('Audit', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
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
