import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart';
import 'package:twoja_gastromania/seller/store_owner_edit.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

class FoundersPage extends StatefulWidget {
  const FoundersPage({super.key});

  static const routeName = 'Founders';
  static const routePath = '/founders';

  @override
  State<FoundersPage> createState() => _FoundersPageState();
}

class _FoundersPageState extends State<FoundersPage> {
  @override
  void initState() {
    super.initState();
    TGFounderService.instance.ensureSeeded();
    TGAnalytics.track('founder_page_view', {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final pad = phone ? 16.0 : 24.0;
    final svc = TGFounderService.instance;
    final cfg = svc.cfg;
    final enabled = TGRevenueConfigService.instance.flags.founderProgram;

    return TGPageScaffold(
      body: ListView(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 20, pad, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TGBreadcrumb(items: [
                      TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                      const TGBreadcrumbItem(label: 'Founding manufacturers'),
                    ]),
                    const SizedBox(height: 16),
                    Text('Founding manufacturers', style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(svc.spotsLabel(), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Text(
                      'A real-quota program for manufacturers. Free Pro-level Special Order access for ${cfg.freeMonths} months, then tiered discounts on promote packs, Priority, and sponsor slots based on qualified listings. No badge is awarded. We do not guarantee any number of views or requests.',
                      style: theme.bodyMedium.override(lineHeight: 1.45),
                    ),
                    const SizedBox(height: 20),
                    _RulesCard(phone: phone),
                    const SizedBox(height: 24),
                    if (!enabled)
                      Text('Program is not open in this phase.', style: theme.bodyMedium.override(fontWeight: FontWeight.w800))
                    else
                      TGButton(
                        onPressed: () => _openApply(context),
                        label: svc.quotaFull ? 'Join waitlist' : 'Apply',
                        height: 48,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const TGFooter(),
        ],
      ),
    );
  }

  Future<void> _openApply(BuildContext context) async {
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn) {
      context.goNamed(LoginPageWidget.routeName);
      return;
    }
    final profile = TGSellerProfileService.instance.bySellerKey(auth.userId);
    if (profile == null || !profile.isStore) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manufacturer account required')));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      builder: (ctx) => _ApplySheet(sellerId: auth.userId),
    );
    setState(() {});
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.phone});
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final cfg = TGFounderService.instance.cfg;
    final rows = [
      ('Free months', '${cfg.freeMonths} months Pro-level Special Order tools (and Priority if for sale)'),
      ('≥5 qualified', '20% off promote / Priority / sponsor slot'),
      ('≥10 qualified', '40% off the same items'),
      ('Not discounted', 'Store plans, standard listing fee (${PricingConfigService.instance.config.defaultListingFeePln} PLN), Renew'),
      ('Ends', 'All program discounts end on programEndsAt'),
      ('Badge', 'No badge is awarded.'),
    ];
    if (phone) {
      return Column(
        children: [
          for (final r in rows)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: theme.tertiary), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(r.$2, style: theme.bodySmall),
                ],
              ),
            ),
        ],
      );
    }
    return DataTable(
      columns: [
        DataColumn(label: Semantics(header: true, child: const Text('Topic'))),
        DataColumn(label: Semantics(header: true, child: const Text('Rule'))),
      ],
      rows: [
        for (final r in rows)
          DataRow(cells: [
            DataCell(Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w800))),
            DataCell(Text(r.$2)),
          ]),
      ],
    );
  }
}

class _ApplySheet extends StatefulWidget {
  const _ApplySheet({required this.sellerId});
  final String sellerId;

  @override
  State<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<_ApplySheet> {
  late final TextEditingController _nip;
  late final TextEditingController _company;
  bool _callDone = false;
  bool _understood = false;
  DateTime _callAt = TGClock.now().add(const Duration(days: 2));
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = TGSellerProfileService.instance.bySellerKey(widget.sellerId)!;
    _nip = TextEditingController(text: p.nip ?? '');
    _company = TextEditingController(text: p.name);
  }

  @override
  void dispose() {
    _nip.dispose();
    _company.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final p = TGSellerProfileService.instance.bySellerKey(widget.sellerId)!;
    final pct = storeProfileCompleteness(p);
    final projects = p.projects.length;
    final cfg = TGFounderService.instance.cfg;
    final ends = DateTime(TGClock.now().year, TGClock.now().month + cfg.programMonths, TGClock.now().day);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Text('Apply', style: theme.titleLarge.override(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  TextField(controller: _company, decoration: const InputDecoration(labelText: 'Company')),
                  TextField(controller: _nip, decoration: const InputDecoration(labelText: 'NIP')),
                  const SizedBox(height: 12),
                  Text('Profile completion: $pct%', style: const TextStyle(fontWeight: FontWeight.w800)),
                  LinearProgressIndicator(value: pct / 100, minHeight: 8, color: theme.primary, backgroundColor: theme.alternate),
                  const SizedBox(height: 8),
                  Text('Reference projects: $projects', style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (projects < 3)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go(p.path);
                      },
                      child: const Text('Add projects in store gallery'),
                    ),
                  CheckboxListTile(
                    value: _callDone,
                    onChanged: (v) => setState(() => _callDone = v ?? false),
                    title: Text('Feedback call scheduled (${TGFounderService.fmtDate(_callAt)})'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: TGClock.now(),
                        lastDate: TGClock.now().add(const Duration(days: 60)),
                        initialDate: _callAt,
                      );
                      if (picked != null) setState(() => _callAt = picked);
                    },
                    child: const Text('Pick call date (mock calendar)'),
                  ),
                  CheckboxListTile(
                    value: _understood,
                    onChanged: (v) => setState(() => _understood = v ?? false),
                    title: Text(
                      'I understand the discount ends on ${TGFounderService.fmtDate(ends)} and that the program includes no badge and no guaranteed number of requests.',
                      style: theme.bodySmall.override(lineHeight: 1.35),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_error != null) Text(_error!, style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            TGButton(
              onPressed: () {
                try {
                  TGFounderService.instance.apply(
                    sellerId: widget.sellerId,
                    nip: _nip.text,
                    companyName: _company.text,
                    profilePct: pct,
                    projects: projects,
                    feedbackCallAt: _callAt,
                    understood: _understood && _callDone,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Under review')));
                } catch (e) {
                  setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
                }
              },
              label: 'Apply',
              height: 48,
            ),
          ],
        ),
      ),
    );
  }
}
