import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
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
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_components/tg_manufacturer_promote_panel.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/priority_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:twoja_gastromania/tg_services/sponsor_slot_service.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';

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
    TGSponsorSlotService.instance.ensureSeeded();
    final flags = TGRevenueConfigService.instance.flags;
    final labels = <String>[
      'overview',
      'early',
      'analytics',
      'programs',
      'promote',
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
                        Tab(text: context.t('ui_mfr_tab_promote')),
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
                        // Map visible tab index → content (Sponsor tab omitted when its flag is off).
                        final labels = <String>[
                          'overview',
                          'early',
                          'analytics',
                          'programs',
                          'promote',
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
                          'promote' => TGManufacturerPromotePanel(sellerId: sellerId),
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
          name.isNotEmpty ? tgToUpperTr(name.substring(0, 1)) : '?',
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
              Text(
                switch (plan) {
                  TGStorePlanKind.basic => context.t('ui_plan_basic_store'),
                  TGStorePlanKind.pro => context.t('ui_plan_pro_store'),
                  TGStorePlanKind.enterprise => context.t('ui_plan_enterprise_store'),
                  null => '—',
                },
                style: theme.headlineSmall.override(fontWeight: FontWeight.w900),
              ),
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

class _SponsorTab extends StatefulWidget {
  const _SponsorTab({required this.sellerId});
  final String sellerId;
  @override
  State<_SponsorTab> createState() => _SponsorTabState();
}

class _SponsorTabState extends State<_SponsorTab> {
  TGStoreSpecialty? _pickedSpec;
  String? _pickedRegion;
  int _duration = _sponsorDays;
  DateTime? _start;

  TGSponsorSlotService get _svc => TGSponsorSlotService.instance;

  void _pickSegment(TGStoreSpecialty spec, String region) {
    setState(() {
      _pickedSpec = spec;
      _pickedRegion = region;
      _start = _svc.nextAvailableStart(spec, region, _duration, ignoreHoldOf: widget.sellerId);
    });
  }

  void _pickDuration(int d) {
    setState(() {
      _duration = d;
      if (_pickedSpec != null && _pickedRegion != null) {
        final keep = _start != null && _svc.windowFree(_pickedSpec!, _pickedRegion!, _start!, d, ignoreHoldOf: widget.sellerId);
        if (!keep) _start = _svc.nextAvailableStart(_pickedSpec!, _pickedRegion!, d, ignoreHoldOf: widget.sellerId);
      }
    });
  }

  String _window(BuildContext context, DateTime start) {
    final fmt = DateFormat('d MMM', Localizations.localeOf(context).languageCode);
    return '${fmt.format(start)} – ${fmt.format(TGSponsorSlotService.addDays(start, _duration - 1))}';
  }

  Future<void> _chooseDate() async {
    final spec = _pickedSpec, region = _pickedRegion;
    if (spec == null || region == null) return;
    final today = TGSponsorSlotService.dayOf(TGClock.now());
    final last = TGSponsorSlotService.addDays(today, _svc.pricing.horizonDays - 1);
    final initial = _start ?? _svc.nextAvailableStart(spec, region, _duration, ignoreHoldOf: widget.sellerId);
    if (initial == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: last,
      selectableDayPredicate: (d) => _svc.windowFree(spec, region, d, _duration, ignoreHoldOf: widget.sellerId),
    );
    if (picked != null && mounted) setState(() => _start = TGSponsorSlotService.dayOf(picked));
  }

  Future<void> _holdAndPay() async {
    final spec = _pickedSpec, region = _pickedRegion, start = _start;
    if (spec == null || region == null || start == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final TGSponsorHold hold;
    try {
      hold = _svc.hold(sellerId: widget.sellerId, specialty: spec, region: region, startsAt: start, durationDays: _duration);
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(context.t(e.message))));
      setState(() => _start = _svc.nextAvailableStart(spec, region, _duration, ignoreHoldOf: widget.sellerId));
      return;
    }
    final theme = FlutterFlowTheme.of(context);
    final price = _svc.priceForSeller(widget.sellerId, _duration);
    final timeFmt = DateFormat('d MMM HH:mm', Localizations.localeOf(context).languageCode);
    var paid = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.secondaryBackground,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(context.t('ui_mfr_reserve_slot'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 6),
              Text('${context.t('ui_so_spec_${spec.name}')} · $region · ${_window(context, start)}', style: theme.bodySmall),
              Text(context.t('ui_banner_hold_until', {'time': timeFmt.format(hold.expiresAt)}), style: theme.bodySmall),
              FounderPriceRow(sellerId: widget.sellerId, listPrice: _svc.priceFor(_duration)),
              const SizedBox(height: 12),
              PaymentForm(
                amountPln: price.toDouble(),
                billingKind: TGPaymentKind.sponsorSlot,
                billingDescription: 'Sponsor slot · ${spec.name} · $region · $_duration days',
                onPaid: () {
                  try {
                    _svc.purchase(
                      sellerId: widget.sellerId,
                      specialty: spec,
                      region: region,
                      startsAt: start,
                      durationDays: _duration,
                      title: 'Sponsored ${spec.name} · $region',
                      imageUrl: 'assets/images/banner-mutfak-ekipmanlari.jpg',
                    );
                    paid = true;
                    Navigator.pop(ctx);
                    messenger.showSnackBar(SnackBar(content: Text(context.t('ui_mfr_reserved_pending'))));
                  } on StateError catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(context.t(e.message))));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (paid) {
        _pickedSpec = null;
        _pickedRegion = null;
        _start = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = _svc;
    final cfg = PricingConfigService.instance.config;
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final err = svc.eligibilityError(widget.sellerId);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final picked = _pickedSpec != null && _pickedRegion != null;
    final earliest = picked ? svc.nextAvailableStart(_pickedSpec!, _pickedRegion!, _duration, ignoreHoldOf: widget.sellerId) : null;
    final price = svc.priceForSeller(widget.sellerId, _duration);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(context.t('ui_mfr_sponsor_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 6),
        Text(context.t('ui_mfr_sponsor_sub', {'price': '${svc.priceFor(_sponsorDays)}', 'days': '$_sponsorDays'}), style: theme.bodySmall),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: phone ? 2 : 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: phone ? 1.15 : 1.3,
          children: [
            for (final seg in svc.segments)
              Builder(builder: (context) {
                final slot = svc.slotAt(seg.specialty, seg.region);
                final active = svc.activeFor(seg.specialty, seg.region);
                final yours = slot?.sellerId == widget.sellerId &&
                    (slot?.status == TGSponsorSlotStatus.active ||
                        slot?.status == TGSponsorSlotStatus.reserved ||
                        slot?.status == TGSponsorSlotStatus.contentPending);
                final selected = _pickedSpec == seg.specialty && _pickedRegion == seg.region;
                final next = svc.nextAvailableStart(seg.specialty, seg.region, _duration, ignoreHoldOf: widget.sellerId);
                final String label;
                if (yours) {
                  label = slot!.status == TGSponsorSlotStatus.contentPending
                      ? context.t('ui_mfr_slot_review')
                      : context.t('ui_mfr_slot_yours');
                } else if (next == null) {
                  label = context.t('ui_mfr_slot_full');
                } else if (active != null || next.isAfter(TGSponsorSlotService.dayOf(TGClock.now()))) {
                  label = context.t('ui_mfr_slot_from', {'d': TGFounderService.fmtDate(next)});
                } else {
                  label = context.t('ui_mfr_slot_available');
                }
                final segName = context.t('ui_so_spec_${seg.specialty.name}');
                return Semantics(
                  button: next != null,
                  selected: selected,
                  label: '$segName, ${seg.region}, $label',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: next != null ? () => _pickSegment(seg.specialty, seg.region) : null,
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
                          Text(segName,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          Text(seg.region, style: theme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: Text(label,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (selected) const Icon(Icons.check_circle, size: 18, color: TGColors.cta),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(context.t('ui_mfr_slot_duration'), style: theme.labelLarge.override(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in TGSponsorSlotService.instance.pricing.durations)
              ChoiceChip(
                selected: _duration == d,
                onSelected: (_) => _pickDuration(d),
                label: Text(
                  '${DurationFormatter.daysOf(context, d)} · ${svc.priceFor(d)} PLN · '
                  '${cfg.perDayLabel(svc.priceFor(d), d, unit: context.t('ui_pln_per_day'))}',
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (err != null)
          Text(err, style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700))
        else if (picked) ...[
          if (earliest == null)
            Text(context.t('ui_mfr_slot_no_window'), style: theme.bodySmall)
          else ...[
            Text(context.t('ui_banner_next_available', {'window': _window(context, earliest)}), style: theme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _start == null ? '—' : _window(context, _start!),
                    style: theme.bodyMedium.override(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(context.t('ui_mfr_slot_change_date')),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(context.t('ui_mfr_slot_flow'), style: theme.bodySmall),
            const SizedBox(height: 12),
            TGButton(
              onPressed: _start == null ? null : _holdAndPay,
              label: context.t('ui_mfr_reserve_price', {'price': '$price'}),
              height: 48,
            ),
          ],
        ] else
          Text(context.t('ui_mfr_slot_pick_segment'), style: theme.bodySmall),
      ],
    );
  }
}

int get _sponsorDays => PricingConfigService.instance.config.sponsorSlot.durations.first;
