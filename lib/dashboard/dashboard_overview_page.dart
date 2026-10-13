import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/dashboard_shell.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_util.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/account_capabilities.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_services/dashboard_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

/// Loads async sources once (chat threads live in SharedPreferences), shows a
/// skeleton meanwhile and fires `dash_view` when the page is ready.
mixin _DashLoad<T extends StatefulWidget> on State<T> {
  bool loading = true;

  String get dashPage;

  @override
  void initState() {
    super.initState();
    MessagingService.instance.ensureLoaded().whenComplete(() {
      if (!mounted) return;
      setState(() => loading = false);
      final auth = context.read<FakeAuthState>();
      final caps = AccountCapabilities.of(auth);
      TGAnalytics.track('dash_view', {
        'page': dashPage,
        'newUser': caps.isNewUser,
        'actions': TGDashboard.actionItems(auth).length,
        'production': TGRevenueConfigService.instance.productionMode,
      });
    });
  }
}

class DashboardOverviewPage extends StatefulWidget {
  const DashboardOverviewPage({super.key});

  static const routeName = 'DashboardOverview';
  static const routePath = '/dashboard';

  @override
  State<DashboardOverviewPage> createState() => _DashboardOverviewPageState();
}

class _DashboardOverviewPageState extends State<DashboardOverviewPage> with _DashLoad {
  int _period = TGDashboard.defaultKpiPeriod;

  @override
  String get dashPage => 'overview';

  void _setPeriod(int next) {
    if (next == _period) return;
    TGAnalytics.track('kpi_period_change', {'from': _period, 'to': next});
    setState(() => _period = next);
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      current: 'overview',
      child: loading ? const DashSkeleton() : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final caps = AccountCapabilities.of(auth);
    final items = TGDashboard.actionItems(auth);
    final seller = caps.isSeller || caps.hasRestaurantListing || caps.store;
    return Column(
      key: const Key('dash-overview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PageTitle(context.t('dash_overview')),
        if (!TGRevenueConfigService.instance.productionMode) _DevCapsStrip(caps),
        const SizedBox(height: 16),
        _Grid12([
          (8, caps.isNewUser ? const _EmptyState() : _ActionCenter(items: items, limit: 5, surface: 'overview')),
          (4, _QuotaCard(auth: auth, caps: caps)),
        ]),
        if (!caps.isNewUser) ...[
          if (seller) ...[
            const SizedBox(height: DashboardShell.gutter),
            _KpiStrip(kpis: TGDashboard.kpis(auth, _period), period: _period, onPeriod: _setPeriod),
          ],
          const SizedBox(height: DashboardShell.gutter),
          _Grid12([
            if (seller) (4, _ListingsSnapshotCard(snapshot: TGDashboard.listings(auth))),
            (seller ? 4 : 6, _ChargesCard(charges: TGDashboard.upcomingCharges(auth))),
            (seller ? 4 : 6, _MessagesCard(auth: auth)),
          ]),
        ],
      ],
    );
  }
}

class DashboardActionsPage extends StatefulWidget {
  const DashboardActionsPage({super.key});

  static const routeName = 'DashboardActions';
  static const routePath = '/dashboard/actions';

  @override
  State<DashboardActionsPage> createState() => _DashboardActionsPageState();
}

class _DashboardActionsPageState extends State<DashboardActionsPage> with _DashLoad {
  @override
  String get dashPage => 'actions';

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      current: 'actions',
      child: loading
          ? const DashSkeleton()
          : Column(
              key: const Key('dash-actions-page'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PageTitle(context.t('dash_actions')),
                const SizedBox(height: 16),
                _ActionCenter(items: TGDashboard.actionItems(context.watch<FakeAuthState>()), surface: 'actions', showTitle: false),
              ],
            ),
    );
  }
}

/// "Coming in the next step" page for sections that are not built yet.
class DashboardPlaceholderPage extends StatefulWidget {
  const DashboardPlaceholderPage({super.key, required this.item});

  final DashNavItem item;

  @override
  State<DashboardPlaceholderPage> createState() => _DashboardPlaceholderPageState();
}

class _DashboardPlaceholderPageState extends State<DashboardPlaceholderPage> with _DashLoad {
  @override
  String get dashPage => widget.item.id;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return DashboardShell(
      current: widget.item.id,
      child: _DashCard(
        key: const Key('dash-placeholder'),
        title: context.t(widget.item.labelKey),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: TGColors.slaAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(TGRadius.pill),
                border: Border.all(color: TGColors.slaAmber),
              ),
              child: Text(context.t('dash_coming_next'), style: theme.labelMedium.override(color: TGColors.slaAmber, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 12),
            Text(context.t('dash_coming_next_body'), style: theme.bodyMedium.override(color: theme.secondaryText)),
            const SizedBox(height: 16),
            TGButton(
              onPressed: () => context.go(DashboardOverviewPage.routePath),
              label: context.t('dash_back_overview'),
              icon: Icons.arrow_back,
              variant: TGButtonVariant.outline,
              height: 42,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: FlutterFlowTheme.of(context).headlineSmall.override(fontWeight: FontWeight.w800)),
    );
  }
}

/// 12-column row: each entry is (span, child). Stacks below 720 px content width.
class _Grid12 extends StatelessWidget {
  const _Grid12(this.cells);

  final List<(int, Widget)> cells;

  static const double stackBelow = 720;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < stackBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                cells[i].$2,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) const SizedBox(width: DashboardShell.gutter),
              Expanded(flex: cells[i].$1, child: cells[i].$2),
            ],
          ],
        );
      },
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TGColors.surface,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: TGColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ActionCenter extends StatelessWidget {
  const _ActionCenter({required this.items, required this.surface, this.limit, this.showTitle = true});

  final List<ActionItem> items;
  final String surface;
  final int? limit;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<FakeAuthState>().userId;
    return ListenableBuilder(
      listenable: ActionDismissals.instance,
      builder: (context, _) => _build(
        context,
        [for (final i in items) if (!(i.dismissible && ActionDismissals.instance.isDismissed(userId, i.id))) i],
        userId,
      ),
    );
  }

  Widget _build(BuildContext context, List<ActionItem> items, String userId) {
    final theme = FlutterFlowTheme.of(context);
    final shown = limit == null ? items : items.take(limit!).toList();
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: TGColors.cta),
                const SizedBox(width: 10),
                Expanded(child: Text(context.t('dash_ac_empty'), key: const Key('dash-ac-empty'), style: theme.bodyMedium)),
              ],
            ),
          ),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: TGColors.border),
          _ActionRow(item: shown[i], surface: surface, userId: userId),
        ],
      ],
    );
    return _DashCard(
      key: const Key('dash-action-center'),
      title: showTitle ? context.t('dash_actions') : context.t('dash_ac_view_all', {'n': '${items.length}'}),
      trailing: limit != null && items.length > limit!
          ? TextButton(
              key: const Key('dash-ac-view-all'),
              onPressed: () => context.go(DashboardActionsPage.routePath),
              child: Text(context.t('dash_ac_view_all', {'n': '${items.length}'})),
            )
          : null,
      child: body,
    );
  }
}

String _dueLabel(BuildContext context, DateTime due) {
  final diff = due.difference(TGClock.now());
  if (diff.isNegative) {
    final d = (-diff.inHours / 24).ceil().clamp(1, 9999);
    return context.t('dash_overdue', {'n': '$d'});
  }
  if (diff.inHours < 24) return context.t('dash_due_today');
  return context.t('dash_due_in', {'n': '${diff.inDays}'});
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item, required this.surface, required this.userId});

  final ActionItem item;
  final String surface;
  final String userId;

  void _dismiss() {
    TGAnalytics.track('action_item_dismiss', {'id': item.id, 'type': item.type.name, 'surface': surface});
    ActionDismissals.instance.dismiss(userId, item);
  }

  static Color _prioColor(ActionPriority p) => switch (p) {
        ActionPriority.critical => TGColors.error,
        ActionPriority.high => TGColors.slaAmber,
        ActionPriority.medium => TGColors.cta,
        ActionPriority.low => TGColors.textSecondary,
      };

  void _open(BuildContext context) {
    TGAnalytics.track('action_item_click', {
      'id': item.id,
      'type': item.type.name,
      'priority': item.priority.name,
      'surface': surface,
    });
    context.go(item.route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final title = context.t(item.titleKey, item.params);
    final prio = context.t('dash_prio_${item.priority.name}');
    final due = item.dueAt == null ? null : _dueLabel(context, item.dueAt!);
    final color = _prioColor(item.priority);
    final suggestion = item.dismissible ? context.t('uyum_suggestion') : null;
    final row = Semantics(
      button: true,
      label: [prio, if (suggestion != null) suggestion, title, if (due != null) due].join('. '),
      excludeSemantics: true,
      child: InkWell(
        key: Key('dash-action-${item.id}'),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(width: 4, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      [prio, if (suggestion != null) suggestion, if (due != null) due].join(' · '),
                      style: theme.bodySmall.override(color: color, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(context.t(item.ctaKey), style: theme.bodySmall.override(color: TGColors.cta, fontWeight: FontWeight.w800)),
              const Icon(Icons.chevron_right, size: 18, color: TGColors.cta),
            ],
          ),
        ),
      ),
    );
    if (!item.dismissible) return row;
    return Row(
      children: [
        Expanded(child: row),
        IconButton(
          key: Key('dash-action-dismiss-${item.id}'),
          tooltip: context.t('uyum_dismiss'),
          onPressed: _dismiss,
          icon: const Icon(Icons.close, size: 18),
          color: TGColors.textSecondary,
        ),
      ],
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.auth, required this.caps});

  final FakeAuthState auth;
  final AccountCapabilities caps;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final store = auth.storePlan != null;
    final cfg = PricingConfigService.instance.config;
    final lines = <Widget>[
      if (store) ...[
        Text(
          context.t('dash_quota_store', {'plan': auth.storePlanLabel, 'used': '${auth.storeActiveUsed}', 'limit': '${auth.storeActiveLimit}'}),
          style: theme.bodyMedium.override(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(context.t('dash_quota_promoted', {'used': '${auth.storePromotedUsed}', 'limit': '${auth.storePromotedLimit}'}), style: theme.bodySmall),
        if (auth.storePlan == TGStorePlanKind.pro) _GlowCreditsLine(userId: auth.userId),
        Text(context.t('dash_quota_renews', {'date': DateFormat('d MMM y', locale).format(auth.storeRenewsOn)}), style: theme.bodySmall),
      ] else ...[
        Text(
          context.t('dash_quota_free', {'left': '${auth.freeListingsLeft}', 'total': '${auth.freeListingsTotal}'}),
          style: theme.bodyMedium.override(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: auth.freeListingsTotal == 0 ? 0 : auth.freeListingsLeft / auth.freeListingsTotal,
            minHeight: 6,
            color: TGColors.cta,
            backgroundColor: TGColors.border,
          ),
        ),
        const SizedBox(height: 6),
        Text(context.t('dash_quota_free_note', {'days': '${cfg.freeListingDays}'}), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 10),
        _PaidListingOptions(cfg: cfg),
      ],
      if (caps.hasPriority) ...[const SizedBox(height: 6), _Chip(context.t('dash_quota_priority'))],
      if (caps.founderEnrolled) ...[const SizedBox(height: 6), _Chip(context.t('dash_quota_founder'))],
      const SizedBox(height: 14),
      TGButton(
        onPressed: () => TGNav.addProduct(context),
        label: context.t('ui_add_listing'),
        icon: Icons.add,
        height: 42,
      ),
      const SizedBox(height: 8),
      TGButton(
        onPressed: () => TGNav.plans(context),
        label: context.t('dash_quota_manage'),
        icon: Icons.workspace_premium_outlined,
        variant: TGButtonVariant.outline,
        height: 42,
      ),
    ];
    return _DashCard(
      key: const Key('dash-quota'),
      title: context.t('dash_quota_title'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: lines),
    );
  }
}

/// Pro period allowance, e.g. "1/3 Glow credits used".
class _GlowCreditsLine extends StatelessWidget {
  const _GlowCreditsLine({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = PromotionService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final u = svc.proCreditUsage(userId);
        final text = context.t('uyum_glow_used', {'used': '${u.used}', 'total': '${u.total}'});
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Semantics(
            label: text,
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(child: Text(text, key: const Key('dash-quota-glow'), style: theme.bodySmall.override(fontWeight: FontWeight.w700))),
                SizedBox(
                  width: 48,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: u.total == 0 ? 0 : u.used / u.total,
                      minHeight: 4,
                      color: TGColors.cta,
                      backgroundColor: TGColors.border,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Individual sellers: paid listing periods once the free quota is used.
class _PaidListingOptions extends StatelessWidget {
  const _PaidListingOptions({required this.cfg});

  final PricingConfig cfg;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      container: true,
      label: context.t('uyum_paid_options_title'),
      child: Column(
        key: const Key('dash-quota-paid'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(context.t('uyum_paid_options_title'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          for (final d in cfg.listingDurations)
            Padding(
              key: Key('dash-quota-paid-$d'),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('ui_duration_days_price', {'days': '$d', 'fee': '${cfg.listingFeePln(d)}'}),
                      style: theme.bodySmall,
                    ),
                  ),
                  Text(cfg.perDayLabel(cfg.listingFeePln(d), d), style: theme.bodySmall.override(color: theme.secondaryText)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TGRadius.pill),
          border: Border.all(color: TGColors.cta),
        ),
        child: Text(text, style: FlutterFlowTheme.of(context).labelSmall.override(color: TGColors.cta, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis, required this.period, required this.onPeriod});

  final List<DashKpi> kpis;
  final int period;
  final ValueChanged<int> onPeriod;

  static String _labelKey(DashKpiKind k) => switch (k) {
        DashKpiKind.views => 'dash_kpi_views',
        DashKpiKind.contacts => 'dash_kpi_contacts',
        DashKpiKind.favorites => 'dash_kpi_favorites',
        DashKpiKind.deals => 'dash_kpi_deals',
      };

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final periods = Wrap(
      spacing: 6,
      children: [
        for (final p in TGDashboard.kpiPeriods)
          ChoiceChip(
            key: Key('dash-kpi-period-$p'),
            label: Text(context.t('dash_kpi_period', {'n': '$p'})),
            selected: p == period,
            onSelected: (_) => onPeriod(p),
          ),
      ],
    );
    return _DashCard(
      key: const Key('dash-kpis'),
      title: context.t('dash_kpi_title', {'n': '$period'}),
      trailing: periods,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final perRow = c.maxWidth < 520 ? 2 : 4;
              final w = (c.maxWidth - 12 * (perRow - 1)) / perRow;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final k in kpis)
                    SizedBox(
                      width: w,
                      child: Semantics(
                        label: '${context.t(_labelKey(k.kind))}: ${k.enoughData ? k.value : context.t('dash_kpi_no_data')}',
                        excludeSemantics: true,
                        child: Container(
                          key: Key('dash-kpi-${k.kind.name}'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: TGColors.background, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.t(_labelKey(k.kind)), style: theme.bodySmall.override(color: theme.secondaryText)),
                              const SizedBox(height: 6),
                              k.enoughData
                                  ? Text('${k.value}', style: theme.headlineSmall.override(fontWeight: FontWeight.w800))
                                  : Text(context.t('dash_kpi_no_data'), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(context.t('dash_kpi_note'), style: theme.bodySmall.override(color: theme.secondaryText, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ListingsSnapshotCard extends StatelessWidget {
  const _ListingsSnapshotCard({required this.snapshot});

  final DashListingsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final rows = [
      ('active', 'dash_snap_active', snapshot.active),
      ('expiring', 'dash_snap_expiring', snapshot.expiring),
      ('expired', 'dash_snap_expired', snapshot.expired),
      ('review', 'dash_snap_review', snapshot.review),
      ('drafts', 'dash_snap_drafts', snapshot.drafts),
    ];
    return _DashCard(
      key: const Key('dash-snapshot'),
      title: context.t('dash_snap_title'),
      child: snapshot.total == 0
          ? Text(context.t('dash_snap_empty'), style: theme.bodyMedium.override(color: theme.secondaryText))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (filter, key, n) in rows)
                  Semantics(
                    button: true,
                    label: '${context.t(key)}: $n',
                    excludeSemantics: true,
                    child: InkWell(
                      key: Key('dash-snap-$filter'),
                      onTap: () => TGNav.dashboardListings(context, filter: filter),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Expanded(child: Text(context.t(key), style: theme.bodyMedium)),
                            Text('$n', style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ChargesCard extends StatelessWidget {
  const _ChargesCard({required this.charges});

  final List<DashCharge> charges;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return _DashCard(
      key: const Key('dash-charges'),
      title: context.t('dash_charges_title'),
      child: charges.isEmpty
          ? Text(context.t('dash_charges_empty'), style: theme.bodyMedium.override(color: theme.secondaryText))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in charges)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.t(c.labelKey, c.params), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                              Text(DateFormat('d MMM y', locale).format(c.dueAt), style: theme.bodySmall.override(color: theme.secondaryText)),
                            ],
                          ),
                        ),
                        Text('${c.amountPln} PLN', style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MessagesCard extends StatelessWidget {
  const _MessagesCard({required this.auth});

  final FakeAuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final threads = TGDashboard.recentThreads(auth);
    final unread = TGDashboard.unread(auth);
    return _DashCard(
      key: const Key('dash-messages'),
      title: context.t('dash_msg_title'),
      trailing: unread > 0
          ? Text(context.t('dash_msg_unread', {'n': '$unread'}), style: theme.bodySmall.override(color: TGColors.accent, fontWeight: FontWeight.w800))
          : null,
      child: threads.isEmpty
          ? Text(context.t('dash_msg_empty'), style: theme.bodyMedium.override(color: theme.secondaryText))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in threads)
                  Semantics(
                    button: true,
                    label: '${t.otherPartyName(auth.userId)}, ${t.listingTitle}',
                    excludeSemantics: true,
                    child: InkWell(
                      key: Key('dash-thread-${t.id}'),
                      onTap: () => TGNav.messages(context, threadId: t.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.otherPartyName(auth.userId), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                                  Text(t.listingTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(color: theme.secondaryText)),
                                ],
                              ),
                            ),
                            if (t.unreadFor(auth.userId) > 0)
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: TGColors.accent, shape: BoxShape.circle)),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: () => TGNav.messages(context), child: Text(context.t('dash_msg_open'))),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final cards = [
      ('sell', Icons.add_box_outlined, 'dash_empty_sell', context.t('dash_empty_sell_body', {'n': '${PricingConfigService.instance.config.freeListingQuota}'}), '/add-product'),
      ('resto', Icons.storefront_outlined, 'dash_empty_resto', context.t('dash_empty_resto_body'), '${TGNav.restaurantsPath}/new'),
      ('buy', Icons.search, 'dash_empty_buy', context.t('dash_empty_buy_body'), TGNav.productsPath),
      ('special', Icons.design_services_outlined, 'dash_empty_special', context.t('dash_empty_special_body'), '/special-order'),
    ];
    return _DashCard(
      key: const Key('dash-empty'),
      title: context.t('dash_empty_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.t('dash_empty_body'), style: theme.bodyMedium.override(color: theme.secondaryText)),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final perRow = c.maxWidth < 420 ? 1 : 2;
              final w = (c.maxWidth - 12 * (perRow - 1)) / perRow;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (id, icon, title, body, route) in cards)
                    SizedBox(
                      width: w,
                      child: Semantics(
                        button: true,
                        label: '${context.t(title)}. $body',
                        excludeSemantics: true,
                        child: Material(
                          color: TGColors.background,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            key: Key('dash-empty-$id'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => context.go(route),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(icon, color: TGColors.cta),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(context.t(title), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 2),
                                        Text(body, style: theme.bodySmall.override(color: theme.secondaryText)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DevCapsStrip extends StatelessWidget {
  const _DevCapsStrip(this.caps);

  final AccountCapabilities caps;

  @override
  Widget build(BuildContext context) {
    final on = caps.toMap().entries.where((e) => e.value).map((e) => e.key).toList();
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '${context.t('dash_dev_caps')}: ${on.isEmpty ? '—' : on.join(', ')}',
        key: const Key('dash-dev-caps'),
        style: theme.bodySmall.override(color: theme.secondaryText, fontSize: 11),
      ),
    );
  }
}

/// Placeholder blocks while async data loads. The shimmer pulse is skipped when
/// the platform asks for reduced motion.
class DashSkeleton extends StatefulWidget {
  const DashSkeleton({super.key});

  @override
  State<DashSkeleton> createState() => _DashSkeletonState();
}

class _DashSkeletonState extends State<DashSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: TGMotion.skeleton);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (tgReduceMotion(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _box(double h) => FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 0.9).animate(_c),
        child: Container(
          height: h,
          decoration: BoxDecoration(color: TGColors.surfaceHover, borderRadius: BorderRadius.circular(TGRadius.card)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('dash-skeleton'),
      label: context.t('dash_loading'),
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 220, child: _box(28)),
            const SizedBox(height: 16),
            _Grid12([(8, _box(220)), (4, _box(220))]),
            const SizedBox(height: DashboardShell.gutter),
            _box(140),
            const SizedBox(height: DashboardShell.gutter),
            _Grid12([(4, _box(160)), (4, _box(160)), (4, _box(160))]),
          ],
        ),
      ),
    );
  }
}
