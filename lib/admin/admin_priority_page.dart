import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/priority_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

class AdminPriorityPage extends StatefulWidget {
  const AdminPriorityPage({super.key});

  @override
  State<AdminPriorityPage> createState() => _AdminPriorityPageState();
}

class _AdminPriorityPageState extends State<AdminPriorityPage> {
  @override
  void initState() {
    super.initState();
    TGPriorityService.instance.ensureSeeded();
  }

  Future<String?> _reason(String title) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Reason'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TGButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), label: 'Confirm', height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final prio = TGPriorityService.instance;
    final cfg = TGRevenueConfigService.instance;
    final segments = prio.allSegments();
    final cap = cfg.config.priority.capPerSegment;

    return ListView(
      padding: EdgeInsets.all(phone ? 12 : 20),
      children: [
        Text('Priority seats', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('All counts are from real matching requests — no promised volume.', style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 16),
        Text('Segments', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (phone)
          for (final s in segments) _segmentCard(context, s.specialty, s.region, prio, cfg, auth, cap)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Specialty')),
                DataColumn(label: Text('Region')),
                DataColumn(label: Text('30d req')),
                DataColumn(label: Text('Seats')),
                DataColumn(label: Text('Waitlist')),
                DataColumn(label: Text('Gate')),
                DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final s in segments)
                  DataRow(cells: [
                    DataCell(Text(s.specialty.name)),
                    DataCell(Text(s.region)),
                    DataCell(Text('${prio.matchingRequests30d(s.specialty, s.region)}')),
                    DataCell(Text('${prio.seatsTaken(s.specialty, s.region)}/$cap')),
                    DataCell(Text('${prio.waitlistCount(s.specialty, s.region)}')),
                    DataCell(Text(prio.segmentSaleOpen(s.specialty, s.region) ? 'Open' : 'Closed')),
                    DataCell(Row(children: [
                      TextButton(
                        onPressed: () async {
                          final reason = await _reason('Open gate');
                          if (reason == null || reason.isEmpty) return;
                          cfg.overrideSegmentGate(specialty: s.specialty, region: s.region, open: true, reason: reason, actorId: auth.userId);
                          setState(() {});
                        },
                        child: const Text('Open'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final reason = await _reason('Close gate');
                          if (reason == null || reason.isEmpty) return;
                          cfg.overrideSegmentGate(specialty: s.specialty, region: s.region, open: false, reason: reason, actorId: auth.userId);
                          setState(() {});
                        },
                        child: const Text('Close'),
                      ),
                    ])),
                  ]),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text('Subscribers', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        for (final e in prio.bySeller.entries)
          ListTile(
            title: Text(
              TGSellerProfileService.instance.bySellerKey(e.key)?.name ?? e.key,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${e.value.status.name} · ${e.value.source?.name ?? "—"} · next ${e.value.nextBillingAt?.toIso8601String().substring(0, 10) ?? "—"} · quiet credits ${e.value.quietMonthCredits.length}',
            ),
            trailing: IconButton(
              tooltip: 'Grant seat',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () async {
                final profile = TGSellerProfileService.instance.bySellerKey(e.key);
                if (profile == null || profile.specialties.isEmpty) return;
                final reason = await _reason('Grant seat');
                if (reason == null || reason.isEmpty) return;
                prio.grantSeatManual(
                  sellerId: e.key,
                  specialty: profile.specialties.first,
                  region: profile.voivodeship,
                  actorId: auth.userId,
                  reason: reason,
                );
                setState(() {});
              },
            ),
          ),
      ],
    );
  }

  Widget _segmentCard(
    BuildContext context,
    TGStoreSpecialty specialty,
    String region,
    TGPriorityService prio,
    TGRevenueConfigService cfg,
    FakeAuthState auth,
    int cap,
  ) {
    final theme = FlutterFlowTheme.of(context);
    final req = prio.matchingRequests30d(specialty, region);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: theme.tertiary), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${specialty.name} × $region', style: const TextStyle(fontWeight: FontWeight.w900)),
          Text('30d: $req · seats ${prio.seatsTaken(specialty, region)}/$cap · wait ${prio.waitlistCount(specialty, region)}'),
          Text(prio.segmentSaleOpen(specialty, region) ? 'Gate open' : 'Gate closed'),
        ],
      ),
    );
  }
}

class AdminPriorityHost extends StatelessWidget {
  const AdminPriorityHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'priority', child: AdminPriorityPage());
}
