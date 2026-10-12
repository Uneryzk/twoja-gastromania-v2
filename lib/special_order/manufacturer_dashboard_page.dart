import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/payment/payment_form.dart';
import 'package:twoja_gastromania/tg_components/founder_price_row.dart';
import 'package:twoja_gastromania/tg_services/audit_service.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/priority_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:twoja_gastromania/tg_services/sponsor_slot_service.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';

class ManufacturerDashboardPage extends StatefulWidget {
  const ManufacturerDashboardPage({super.key, this.tab});

  static const routeName = 'ManufacturerDashboard';
  static const routePath = '/dashboard/manufacturer';

  final String? tab;

  @override
  State<ManufacturerDashboardPage> createState() => _ManufacturerDashboardPageState();
}

class _ManufacturerDashboardPageState extends State<ManufacturerDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int _analyticsDays = 30;

  @override
  void initState() {
    super.initState();
    TGSpecialOrderService.instance.ensureSeeded();
    TGPriorityService.instance.ensureSeeded();
    TGFounderService.instance.ensureSeeded();
    TGAuditService.instance.ensureSeeded();
    TGSponsorSlotService.instance.ensureSeeded();
    final flags = TGRevenueConfigService.instance.flags;
    final labels = <String>[
      'overview',
      'early',
      'analytics',
      'programs',
      if (flags.auditProgram) 'audit',
      if (flags.sponsorSlots) 'sponsor',
    ];
    final want = widget.tab ?? 'overview';
    final initial = labels.indexOf(want).clamp(0, labels.length - 1);
    _tabs = TabController(length: labels.length, vsync: this, initialIndex: initial);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final pad = phone ? 16.0 : 24.0;
    final sellerId = auth.userId;
    final profile = TGSellerProfileService.instance.bySellerKey(sellerId);
    final plan = profile?.plan ?? auth.storePlan;
    TGFounderService.instance.listingResolver = (id) => id == sellerId ? auth.ownedListings : const [];

    return TGPageScaffold(
      body: ListView(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 20, pad, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TGBreadcrumb(items: [
                      TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                      TGBreadcrumbItem(label: context.t('ui_mfr_title')),
                    ]),
                    const SizedBox(height: 12),
                    _ManufacturerIdentityHeader(profile: profile, sellerId: sellerId),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TGButton(
                          onPressed: () => context.go('/dashboard/leads'),
                          label: context.t('ui_mfr_open_leads'),
                          height: 40,
                        ),
                        if (profile != null)
                          TGButton(
                            onPressed: () => context.go(profile.path),
                            label: context.t('ui_mfr_view_store'),
                            variant: TGButtonVariant.outline,
                            height: 40,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TabBar(
                      controller: _tabs,
                      isScrollable: true,
                      labelColor: theme.primaryText,
                      indicatorColor: theme.primary,
                      tabs: [
                        Tab(text: context.t('ui_mfr_tab_overview')),
                        Tab(text: context.t('ui_mfr_tab_early')),
                        Tab(text: context.t('ui_mfr_tab_analytics')),
                        Tab(text: context.t('ui_mfr_tab_programs')),
                        if (TGRevenueConfigService.instance.flags.auditProgram) Tab(text: context.t('ui_mfr_tab_audit')),
                        if (TGRevenueConfigService.instance.flags.sponsorSlots) Tab(text: context.t('ui_mfr_tab_sponsor')),
                      ],
                      onTap: (i) {
                        if (i == 2) TGAnalytics.track('analytics_view', {'sellerId': sellerId});
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _tabs,
                      builder: (_, __) {
                        final flags = TGRevenueConfigService.instance.flags;
                        // Map visible tab index → content (Audit/Sponsor tabs omitted when flags off).
                        final labels = <String>[
                          'overview',
                          'early',
                          'analytics',
                          'programs',
                          if (flags.auditProgram) 'audit',
                          if (flags.sponsorSlots) 'sponsor',
                        ];
                        final key = _tabs.index < labels.length ? labels[_tabs.index] : 'overview';
                        return switch (key) {
                          'early' => _EarlyTab(sellerId: sellerId, plan: plan),
                          'analytics' => _AnalyticsTab(
                              sellerId: sellerId,
                              plan: plan,
                              days: _analyticsDays,
                              onDays: (d) => setState(() => _analyticsDays = d),
                            ),
                          'programs' => _ProgramsTab(sellerId: sellerId, listings: auth.ownedListings),
                          'audit' => _AuditTab(sellerId: sellerId),
                          'sponsor' => _SponsorTab(sellerId: sellerId),
                          _ => _OverviewTab(sellerId: sellerId, plan: plan),
                        };
                      },
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
}

class _ManufacturerIdentityHeader extends StatelessWidget {
  const _ManufacturerIdentityHeader({required this.profile, required this.sellerId});
  final TGStoreProfile? profile;
  final String sellerId;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final name = profile?.name ?? sellerId;
    final logo = profile?.logoUrl;
    final cover = profile?.coverUrl;
    final rating = profile?.rating;
    final reviews = profile?.reviewsCount ?? 0;
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cover != null && cover.isNotEmpty)
            SizedBox(
              height: phone ? 120 : 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, theme.primaryBackground.withValues(alpha: 0.85)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            color: theme.secondaryBackground,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                _MfrLogo(url: logo, name: name, size: phone ? 56 : 72),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t('ui_mfr_title'), style: theme.labelSmall.override(color: theme.secondaryText, fontWeight: FontWeight.w800)),
                      Text(name, style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                      if (rating != null && reviews > 0)
                        Text(
                          '${rating.toStringAsFixed(1)} · ${context.t('ui_reviews_n', {'n': '$reviews'})}',
                          style: theme.bodySmall.override(fontWeight: FontWeight.w700),
                        ),
                      if (profile?.specialties.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final s in profile!.specialties.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: theme.primary),
                                ),
                                child: Text(
                                  context.t('ui_so_spec_${s.name}'),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: theme.primary),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MfrLogo extends StatelessWidget {
  const _MfrLogo({required this.url, required this.name, required this.size});
  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final child = url != null && url!.isNotEmpty
        ? Image.asset(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback(theme))
        : _fallback(theme);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.tertiary),
        color: theme.alternate,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _fallback(FlutterFlowTheme theme) => Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.4, color: theme.primary),
        ),
      );
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.sellerId, required this.plan});
  final String sellerId;
  final TGStorePlanKind? plan;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final prio = TGPriorityService.instance.priorityFor(sellerId);
    final matching = TGPriorityService.instance.matchingRequestsThisMonth(sellerId);
    final threshold = TGRevenueConfigService.instance.config.quietMonthThreshold;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('ui_mfr_store_plan'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(plan?.name.toUpperCase() ?? '—', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
              TextButton(onPressed: () => context.go('/plans'), child: Text(context.t('ui_mfr_manage_plan'))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('ui_mfr_priority'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(_priorityLabel(context, prio), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
              if (prio.isActive && prio.source == TGPrioritySource.addon && !prio.cancelAtPeriodEnd)
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(context.t('ui_mfr_cancel_priority')),
                        content: Text(context.t('ui_mfr_cancel_priority_body')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('ui_mfr_keep'))),
                          TGButton(onPressed: () => Navigator.pop(ctx, true), label: context.t('ui_mfr_confirm_cancel'), height: 40),
                        ],
                      ),
                    );
                    if (ok == true) TGPriorityService.instance.cancelAtPeriodEnd(sellerId);
                  },
                  child: Text(context.t('ui_mfr_cancel_priority')),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('ui_mfr_matching_month', {'n': '$matching'}), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                context.t('ui_mfr_credit_note', {'n': '$matching', 't': '$threshold'}),
                style: theme.bodySmall.override(color: theme.secondaryText),
              ),
              if (!reduce)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 400),
                  builder: (_, v, child) => Opacity(opacity: v, child: child),
                  child: const SizedBox(height: 4),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _priorityLabel(BuildContext context, TGSellerPriority p) {
    if (p.status == TGPriorityStatus.waitlist) return context.t('ui_mfr_prio_waitlist');
    if (p.source == TGPrioritySource.enterprise) return context.t('ui_mfr_prio_enterprise');
    if (p.source == TGPrioritySource.founderFree) {
      final until = p.nextBillingAt;
      final untilLabel = until == null ? '' : context.t('ui_mfr_prio_until', {'d': TGFounderService.fmtDate(until)});
      return context.t('ui_mfr_prio_founder', {'until': untilLabel});
    }
    if (p.isActive) {
      final next = p.nextBillingAt;
      final billing = next == null ? '' : context.t('ui_mfr_prio_next_billing', {'d': TGFounderService.fmtDate(next)});
      final cancel = p.cancelAtPeriodEnd ? context.t('ui_mfr_prio_cancels') : '';
      return context.t('ui_mfr_prio_active', {'billing': billing, 'cancel': cancel});
    }
    return context.t('ui_mfr_prio_none');
  }
}

class _EarlyTab extends StatelessWidget {
  const _EarlyTab({required this.sellerId, required this.plan});
  final String sellerId;
  final TGStorePlanKind? plan;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGSpecialOrderService.instance;
    final hasPrio = TGPriorityService.instance.hasPrioritySeat(sellerId);
    final leads = svc.leadsForSeller(sellerId);
    final early = leads.where((r) {
      final via = svc.viaFor(r.id, sellerId);
      return via == TGLeadAccessVia.priorityPool || via == TGLeadAccessVia.enterprisePool;
    }).toList();
    final reduce = MediaQuery.disableAnimationsOf(context);

    if (hasPrio) {
      if (early.isEmpty) return Text(context.t('ui_mfr_no_early'), style: theme.bodyMedium);
      return Column(
        children: [
          for (final r in early)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: reduce ? 1 : 0, end: 1),
              duration: Duration(milliseconds: reduce ? 0 : 200),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: ListTile(
                title: Text(r.requestNo, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(r.title),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: theme.primary), borderRadius: BorderRadius.circular(20)),
                  child: Text(context.t('ui_mfr_early_chip'), style: TextStyle(color: theme.primary, fontWeight: FontWeight.w800)),
                ),
                onTap: () => context.go('/dashboard/leads?id=${r.requestNo}'),
              ),
            ),
        ],
      );
    }

    final pending = svc.pendingEarlyAccessCount(sellerId);
    final eta = svc.earliestPendingVisibleIn(sellerId);
    final hours = eta?.inHours.clamp(1, 99) ?? 24;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('ui_mfr_early_delay', {'h': '$hours'}),
          style: theme.bodyMedium.override(lineHeight: 1.45),
        ),
        if (pending > 0) ...[
          const SizedBox(height: 12),
          Text(context.t('ui_mfr_early_pending', {'n': '$pending'}), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        ],
        const SizedBox(height: 16),
        if (TGRevenueConfigService.instance.flags.priorityForSale)
          TGButton(
            onPressed: () {
              TGAnalytics.track('priority_view', {'from': 'mfr_early'});
              context.go('/plans#priority');
            },
            label: context.t('ui_mfr_see_priority'),
            height: 44,
          ),
      ],
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({required this.sellerId, required this.plan, required this.days, required this.onDays});
  final String sellerId;
  final TGStorePlanKind? plan;
  final int days;
  final ValueChanged<int> onDays;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final unlocked = plan == TGStorePlanKind.enterprise || TGPriorityService.instance.hasPrioritySeat(sellerId);
    if (!unlocked) {
      return Text(context.t('ui_mfr_analytics_locked'), style: theme.titleMedium.override(fontWeight: FontWeight.w900));
    }
    final a = TGSpecialOrderService.instance.sellerAnalytics(sellerId, days: days);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final hasData = a.viewed + a.quoted + a.won > 0;
    if (!hasData) return Text(context.t('ui_mfr_no_data'), style: theme.bodyMedium.override(fontWeight: FontWeight.w700));

    double pct(int n, int d) => d == 0 ? 0 : n / d;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 30, label: Text(context.t('ui_mfr_days_n', {'n': '30'}))),
            ButtonSegment(value: 90, label: Text(context.t('ui_mfr_days_n', {'n': '90'}))),
          ],
          selected: {days},
          onSelectionChanged: (s) => onDays(s.first),
        ),
        const SizedBox(height: 16),
        Text(context.t('ui_mfr_funnel'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _FunnelBar(label: context.t('ui_mfr_viewed'), value: a.viewed, max: a.viewed.clamp(1, 999), reduce: reduce),
        _FunnelBar(
          label: context.t('ui_mfr_quoted', {'pct': (pct(a.quoted, a.viewed) * 100).toStringAsFixed(0)}),
          value: a.quoted,
          max: a.viewed.clamp(1, 999),
          reduce: reduce,
        ),
        _FunnelBar(
          label: context.t('ui_mfr_won', {'pct': (pct(a.won, a.quoted) * 100).toStringAsFixed(0)}),
          value: a.won,
          max: a.quoted.clamp(1, 999),
          reduce: reduce,
        ),
        const SizedBox(height: 16),
        Text(context.t('ui_mfr_loss_reasons'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        if (a.losses.isEmpty)
          Text(context.t('ui_mfr_no_data'), style: theme.bodySmall)
        else
          for (final e in a.losses.entries)
            _FunnelBar(label: e.key.name, value: e.value, max: a.losses.values.fold(1, (a, b) => a > b ? a : b), reduce: reduce),
        const SizedBox(height: 12),
        Text(
          context.t('ui_mfr_median_response', {
            'v': a.medianResponseHours == null ? '—' : '${a.medianResponseHours!.toStringAsFixed(1)} h',
          }),
          style: theme.bodyMedium.override(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _FunnelBar extends StatelessWidget {
  const _FunnelBar({required this.label, required this.value, required this.max, required this.reduce});
  final String label;
  final int value;
  final int max;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label · $value', style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value / max),
              duration: Duration(milliseconds: reduce ? 0 : 400),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: theme.alternate,
                color: theme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.tertiary),
      ),
      child: child,
    );
  }
}

class _ProgramsTab extends StatelessWidget {
  const _ProgramsTab({required this.sellerId, required this.listings});
  final String sellerId;
  final List listings;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGFounderService.instance..ensureSeeded();
    final f = svc.founderFor(sellerId);
    final app = svc.applicationFor(sellerId);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final products = listings.whereType<TGProduct>().toList();

    if (!f.enrolled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            app == null ? 'Not enrolled in the Founder program.' : 'Application: ${app.status.name}',
            style: theme.bodyMedium.override(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TGButton(onPressed: () => context.go('/founders'), label: 'View Founding manufacturers', height: 44),
        ],
      );
    }

    final eval = svc.evaluateSellerListings(sellerId, listings: products);
    final q = eval.where((e) => e.qualified).length;
    final cfg = svc.cfg;
    final target5 = cfg.tiers.isNotEmpty ? cfg.tiers.first.qualified : 5;
    final target10 = cfg.tiers.length > 1 ? cfg.tiers[1].qualified : 10;
    final progress = (q / target10).clamp(0.0, 1.0);
    final discountPct = (cfg.discountForQualified(q) * 100).round();
    final sellerSavings = svc.savingsFor(sellerId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qualified listings $q / $target5 for 20% · $target10 for 40%',
                style: theme.titleSmall.override(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Semantics(
                label: 'Founder progress',
                value: 'Qualified listings $q of $target10 for 40 percent',
                // role=progressbar + aria-valuetext via Semantics value
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: Duration(milliseconds: reduce ? 0 : 400),
                    builder: (_, v, __) => Stack(
                      children: [
                        LinearProgressIndicator(
                          value: v,
                          minHeight: 14,
                          backgroundColor: theme.alternate,
                          color: theme.primary,
                        ),
                        Positioned.fill(
                          child: Row(
                            children: [
                              Expanded(
                                flex: target5,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(width: 2, color: theme.primaryText.withValues(alpha: 0.4)),
                                ),
                              ),
                              Expanded(flex: (target10 - target5).clamp(1, 999), child: const SizedBox()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Current tier: ${discountPct == 0 ? '0%' : '$discountPct%'}',
                style: theme.bodyMedium.override(fontWeight: FontWeight.w800),
              ),
              if (f.programEndsAt != null)
                Text('Founder discount ends ${TGFounderService.fmtDate(f.programEndsAt!)}', style: theme.bodySmall),
              if (f.freeUntil != null && f.isInFreeMonths(TGClock.now()))
                Text(
                  'Free access until ${TGFounderService.fmtDate(f.freeUntil!)}',
                  style: theme.bodySmall.override(fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Listings', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        for (final info in eval)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(info.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(info.qualified ? 'Qualifies for founder tier' : info.reasons.join(' · ')),
            trailing: info.qualified
                ? null
                : TextButton(onPressed: () => context.go('/dashboard/listings'), child: const Text('Fix')),
          ),
        const SizedBox(height: 12),
        Text('Savings history', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        if (sellerSavings.isEmpty)
          Text('No discounted purchases yet.', style: theme.bodySmall)
        else
          for (final s in sellerSavings.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${s.listPrice} → ${s.paidPrice} PLN (−${(s.discountPct * 100).round()}%)'),
            ),
      ],
    );
  }
}

class _AuditTab extends StatefulWidget {
  const _AuditTab({required this.sellerId});
  final String sellerId;
  @override
  State<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<_AuditTab> {
  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGAuditService.instance;
    final app = svc.latestFor(widget.sellerId);
    final err = svc.eligibilityError(widget.sellerId);
    final reduce = MediaQuery.disableAnimationsOf(context);
    const stages = ['Applied', 'Paid', 'Documents & video', 'In review', 'Approved/Rejected'];
    double progressFor(TGAuditApplicationStatus? s) => switch (s) {
          null => 0,
          TGAuditApplicationStatus.applied => 0.2,
          TGAuditApplicationStatus.paid => 0.4,
          TGAuditApplicationStatus.docs => 0.6,
          TGAuditApplicationStatus.inReview ||
          TGAuditApplicationStatus.liveVisitRequested ||
          TGAuditApplicationStatus.visitScheduled ||
          TGAuditApplicationStatus.visitDone =>
            0.8,
          TGAuditApplicationStatus.approved || TGAuditApplicationStatus.rejected || TGAuditApplicationStatus.revoked => 1.0,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_mfr_audit_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(
          context.t('ui_mfr_audit_pitch', {'fee': '${TGAuditService.feePln}', 'renewal': '${TGAuditService.renewalPln}'}),
          style: theme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(context.t('ui_mfr_audit_no_refund'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (final line in const [
          'KRS/NIP verification',
          'Workshop address',
          'Workshop and equipment video (file or YouTube/Vimeo link)',
          'Liability insurance (OC)',
          '3 references',
          'Sample project documentation',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [Icon(Icons.check, size: 16, color: theme.primary), const SizedBox(width: 8), Expanded(child: Text(line))]),
          ),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progressFor(app?.status)),
          duration: Duration(milliseconds: reduce ? 0 : 250),
          builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 8, color: theme.primary, backgroundColor: theme.alternate),
        ),
        const SizedBox(height: 6),
        Text(stages.join(' → '), style: theme.bodySmall),
        if (app != null) ...[
          const SizedBox(height: 8),
          Text('Status: ${app.status.name}${app.validUntil != null ? " · valid until ${TGFounderService.fmtDate(app.validUntil!)}" : ""}', style: const TextStyle(fontWeight: FontWeight.w800)),
          if (app.decisionNote != null) Text(app.decisionNote!, style: theme.bodySmall),
          if (app.status == TGAuditApplicationStatus.liveVisitRequested)
            Text('Please schedule a short verification call (10–15 min, not recorded) within 7 days.', style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 16),
        if (err != null)
          Text(err, style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700))
        else if (app == null || app.status == TGAuditApplicationStatus.rejected)
          TGButton(
            onPressed: () => _startApply(context, svc, freeReapply: app?.status == TGAuditApplicationStatus.rejected && !(app?.reapplyUsed ?? false)),
            label: app?.status == TGAuditApplicationStatus.rejected && !(app?.reapplyUsed ?? false) ? 'Fix and re-apply (free once)' : 'Apply',
            height: 48,
          )
        else if (app.status == TGAuditApplicationStatus.paid || app.status == TGAuditApplicationStatus.docs)
          TGButton(
            onPressed: () => _openDocsVideo(context, svc, app),
            label: 'Documents & workshop video',
            height: 48,
          )
        else if (app.status == TGAuditApplicationStatus.liveVisitRequested)
          TGButton(
            onPressed: () {
              svc.scheduleLiveVisit(app.id, TGClock.now().add(const Duration(days: 2)));
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visit scheduled (mock calendar)')));
            },
            label: 'Schedule video call',
            height: 48,
          )
        else
          Text('Application in progress.', style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _startApply(BuildContext context, TGAuditService svc, {required bool freeReapply}) async {
    final theme = FlutterFlowTheme.of(context);
    final created = svc.apply(sellerId: widget.sellerId, freeReapply: freeReapply);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.secondaryBackground,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(freeReapply ? 'Free re-apply — no refund on later rejection' : 'Audit fee — no refund if rejected', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (freeReapply)
              TGButton(
                onPressed: () {
                  svc.markPaid(created.id);
                  Navigator.pop(ctx);
                  _openDocsVideo(context, svc, created);
                },
                label: 'Continue (no charge)',
                height: 48,
              )
            else
              PaymentForm(
                amountPln: TGAuditService.feePln.toDouble(),
                onPaid: () {
                  svc.markPaid(created.id);
                  Navigator.pop(ctx);
                  _openDocsVideo(context, svc, created);
                },
              ),
          ],
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _openDocsVideo(BuildContext context, TGAuditService svc, TGAuditApplication app) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _AuditDocsVideoSheet(
          application: app,
          onDone: () {
            Navigator.pop(ctx);
            setState(() {});
          },
        ),
      ),
    );
    setState(() {});
  }
}

class _AuditDocsVideoSheet extends StatefulWidget {
  const _AuditDocsVideoSheet({required this.application, required this.onDone});
  final TGAuditApplication application;
  final VoidCallback onDone;

  @override
  State<_AuditDocsVideoSheet> createState() => _AuditDocsVideoSheetState();
}

class _AuditDocsVideoSheetState extends State<_AuditDocsVideoSheet> {
  TGAuditVideoKind _kind = TGAuditVideoKind.file;
  final _link = TextEditingController();
  final _address = TextEditingController();
  String? _fileUrl;
  double _uploadProgress = 0;
  String? _error;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final v = widget.application.workshopVideo;
    _kind = v?.kind ?? TGAuditVideoKind.file;
    _link.text = v?.linkUrl ?? '';
    _fileUrl = v?.fileUrl;
    _address.text = widget.application.workshopAddress.isEmpty ? 'Workshop address' : widget.application.workshopAddress;
    if (v == null || !v.challengeValid) {
      TGAuditService.instance.regenerateCode(widget.application.id);
    }
  }

  @override
  void dispose() {
    _link.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGAuditService.instance;
    final app = svc.latestFor(widget.application.sellerId) ?? widget.application;
    final code = app.workshopVideo?.challengeCode ?? '----';
    final reduce = MediaQuery.disableAnimationsOf(context);
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Text('Documents & workshop video', style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                TextField(controller: _address, decoration: const InputDecoration(labelText: 'Workshop address', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                Text('Documents: KRS/CEIDG, OC policy PDF, ≥3 references, sample project (mock attached)', style: theme.bodySmall),
                const SizedBox(height: 16),
                Text('Verification code', style: const TextStyle(fontWeight: FontWeight.w800)),
                AnimatedOpacity(
                  opacity: 1,
                  duration: Duration(milliseconds: reduce ? 0 : 150),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: theme.primary, width: 2), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Text(code, style: theme.headlineSmall.override(fontWeight: FontWeight.w900, letterSpacing: 4)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            svc.regenerateCode(app.id);
                            setState(() {});
                          },
                          child: const Text('New code'),
                        ),
                      ],
                    ),
                  ),
                ),
                Text('Valid 72 hours', style: theme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final chip in const [
                      'Show the code on paper with today\'s date',
                      'the building or sign with the company name and street number',
                      'the workshop interior',
                      'your main machines (running if possible)',
                      'a nameplate or serial number',
                    ])
                      Chip(label: Text(chip, style: const TextStyle(fontSize: 11))),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Don\'t show customer documents. Avoid showing employees\' faces where possible.', style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Text('Workshop & equipment video', style: const TextStyle(fontWeight: FontWeight.w800)),
                RadioListTile<TGAuditVideoKind>(
                  value: TGAuditVideoKind.file,
                  groupValue: _kind,
                  onChanged: (v) => setState(() => _kind = v!),
                  title: const Text('Upload a video file (recommended)'),
                  subtitle: const Text('MP4/MOV, 60–180 s, ≤300 MB'),
                ),
                RadioListTile<TGAuditVideoKind>(
                  value: TGAuditVideoKind.link,
                  groupValue: _kind,
                  onChanged: (v) => setState(() => _kind = v!),
                  title: const Text('Add a video link'),
                  subtitle: const Text('YouTube/Vimeo unlisted/private only. The link must stay available during the review and while the badge is valid.'),
                ),
                if (_kind == TGAuditVideoKind.file) ...[
                  if (phone)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _mockUpload,
                            icon: const Icon(Icons.videocam_outlined),
                            label: const Text('Record video'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _mockUpload,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Choose file'),
                          ),
                        ),
                      ],
                    )
                  else
                    OutlinedButton.icon(onPressed: _mockUpload, icon: const Icon(Icons.upload_file), label: Text(_fileUrl == null ? 'Choose MP4/MOV' : 'Replace video')),
                  if (_uploading || _fileUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(value: _uploading ? _uploadProgress : 1, color: theme.primary),
                          ),
                          const SizedBox(width: 12),
                          Text(_uploading ? 'Uploading… ${(_uploadProgress * 100).round()}%' : 'Uploaded (mock)', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ] else
                  TextField(
                    controller: _link,
                    decoration: const InputDecoration(labelText: 'YouTube / Vimeo URL', border: OutlineInputBorder()),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          TGButton(
            onPressed: () {
              try {
                final video = app.workshopVideo!;
                if (_kind == TGAuditVideoKind.file) {
                  if (_fileUrl == null) throw StateError('Please add your workshop video.');
                  svc.submitDocumentsAndVideo(
                    app.id,
                    workshopAddress: _address.text.trim(),
                    docs: const ['mock://krs.pdf', 'mock://oc.pdf', 'mock://refs.pdf', 'mock://sample.pdf'],
                    video: video.copyWith(kind: TGAuditVideoKind.file, fileUrl: _fileUrl, durationSec: 120, submittedAt: TGClock.now()),
                  );
                } else {
                  final err = TGAuditService.validateVideoLink(_link.text);
                  if (err != null) throw StateError(err);
                  svc.submitDocumentsAndVideo(
                    app.id,
                    workshopAddress: _address.text.trim(),
                    docs: const ['mock://krs.pdf', 'mock://oc.pdf', 'mock://refs.pdf', 'mock://sample.pdf'],
                    video: video.copyWith(
                      kind: TGAuditVideoKind.link,
                      linkUrl: _link.text.trim(),
                      host: TGAuditService.hostFromLink(_link.text),
                      submittedAt: TGClock.now(),
                    ),
                  );
                }
                svc.submitForReview(app.id);
                widget.onDone();
              } catch (e) {
                setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
              }
            },
            label: 'Submit for review',
            height: 48,
          ),
        ],
      ),
    );
  }

  Future<void> _mockUpload() async {
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _error = null;
    });
    for (var i = 1; i <= 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
      setState(() => _uploadProgress = i / 10);
    }
    setState(() {
      _uploading = false;
      _fileUrl = 'mock://workshop/${widget.application.workshopVideo?.challengeCode ?? "vid"}.mp4';
    });
  }
}

class _SponsorTab extends StatefulWidget {
  const _SponsorTab({required this.sellerId});
  final String sellerId;
  @override
  State<_SponsorTab> createState() => _SponsorTabState();
}

class _SponsorTabState extends State<_SponsorTab> {
  TGStoreSpecialty? _pickedSpec;
  String? _pickedRegion;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGSponsorSlotService.instance;
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final err = svc.eligibilityError(widget.sellerId);
    final price = svc.priceForSeller(widget.sellerId);
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_mfr_sponsor_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(context.t('ui_mfr_sponsor_sub', {'price': '${TGSponsorSlotService.pricePln}'}), style: theme.bodySmall),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: phone ? 2 : 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.3,
          children: [
            for (final seg in svc.segments)
              Builder(builder: (context) {
                final slot = svc.slotAt(seg.specialty, seg.region);
                final active = svc.activeFor(seg.specialty, seg.region);
                final yours = active?.sellerId == widget.sellerId;
                final selected = _pickedSpec == seg.specialty && _pickedRegion == seg.region;
                final String label;
                if (yours) {
                  label = context.t('ui_mfr_slot_yours');
                } else if (active != null) {
                  label = context.t('ui_mfr_slot_booked', {'d': TGFounderService.fmtDate(active.endsAt!)});
                } else if (slot?.status == TGSponsorSlotStatus.contentPending) {
                  label = context.t('ui_mfr_slot_review');
                } else {
                  label = context.t('ui_mfr_slot_available');
                }
                return InkWell(
                  onTap: active == null
                      ? () => setState(() {
                            _pickedSpec = seg.specialty;
                            _pickedRegion = seg.region;
                          })
                      : null,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: reduce ? 0 : 150),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: selected ? theme.primary : theme.tertiary, width: selected ? 2 : 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('ui_so_spec_${seg.specialty.name}'),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(seg.region, style: theme.bodySmall),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                            if (selected) const Icon(Icons.check_circle, size: 18, color: TGColors.cta),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
        const SizedBox(height: 16),
        if (err != null)
          Text(err, style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700))
        else if (_pickedSpec != null && _pickedRegion != null)
          TGButton(
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: theme.secondaryBackground,
                builder: (ctx) => Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(ctx).bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.t('ui_mfr_reserve_slot'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
                      FounderPriceRow(sellerId: widget.sellerId, listPrice: TGSponsorSlotService.pricePln),
                      const SizedBox(height: 12),
                      PaymentForm(
                        amountPln: price.toDouble(),
                        onPaid: () {
                          try {
                            svc.reserve(
                              sellerId: widget.sellerId,
                              specialty: _pickedSpec!,
                              region: _pickedRegion!,
                              title: 'Sponsored ${_pickedSpec!.name} · $_pickedRegion',
                              imageUrl: 'assets/images/banner-mutfak-ekipmanlari.jpg',
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('ui_mfr_reserved_pending'))));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              );
              setState(() {});
            },
            label: context.t('ui_mfr_reserve_price', {'price': '$price'}),
            height: 48,
          ),
      ],
    );
  }
}
