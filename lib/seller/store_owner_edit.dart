import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

enum TGStoreEditSection { cover, logo, description, taxonomy, hours, address, links, projects }

const _kUploadPool = <String>[
  'assets/images/blog-26.jpg',
  'assets/images/Food_Prepering_table.jpg',
  'assets/images/images.jpeg',
  'assets/images/TECHNICA.png',
  'assets/images/GASTROPL.png',
  'assets/images/Gastrosilesia-pl.png',
];

int storeProfileCompleteness(TGStoreProfile p) {
  final items = [
    p.coverUrl != null,
    p.logoUrl != null,
    p.description.trim().length >= 80,
    p.hours.of('sat') != 'closed',
    p.address != null && p.address!.isNotEmpty,
    p.projects.length >= 3,
    p.acceptsSpecialOrder,
    p.social.youtube != null,
    p.services.length >= 3,
    p.website != null,
  ];
  return ((items.where((e) => e).length / items.length) * 100).round();
}

List<String> storeProfileTips(BuildContext context, TGStoreProfile p) {
  final tips = <String>[];
  if (p.projects.length < 3) tips.add(context.t('ui_tip_project_photos'));
  if (p.hours.of('sat') == 'closed') tips.add(context.t('ui_tip_opening_hours'));
  if (p.description.trim().length < 160) tips.add(context.t('ui_tip_description'));
  return tips.take(3).toList();
}

bool storeIsOwner(FakeAuthState auth, TGStoreProfile profile) =>
    auth.isLoggedIn && auth.userId == profile.sellerKey;

class StoreChromeController extends ChangeNotifier {
  bool overlayOpen = false;
  bool previewVisitor = false;
  bool editing = false;

  void setOverlay(bool v) {
    if (overlayOpen == v) return;
    overlayOpen = v;
    notifyListeners();
  }

  void setPreview(bool v) {
    previewVisitor = v;
    if (v) editing = false;
    notifyListeners();
  }

  void setEditing(bool v) {
    editing = v;
    if (v) previewVisitor = false;
    notifyListeners();
  }
}

class StoreChromeScope extends InheritedNotifier<StoreChromeController> {
  const StoreChromeScope({super.key, required StoreChromeController super.notifier, required super.child});

  static StoreChromeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreChromeScope>()?.notifier;
}

Future<T?> withStoreOverlay<T>(BuildContext context, Future<T?> Function() run) async {
  final chrome = StoreChromeScope.maybeOf(context);
  final already = chrome?.overlayOpen ?? false;
  if (!already) chrome?.setOverlay(true);
  try {
    return await run();
  } finally {
    if (!already) chrome?.setOverlay(false);
  }
}

bool storeOwnerUi(BuildContext context, TGStoreProfile profile) {
  final auth = context.watch<FakeAuthState>();
  final chrome = StoreChromeScope.maybeOf(context);
  return storeIsOwner(auth, profile) && chrome?.previewVisitor != true;
}

class StoreOwnerBar extends StatelessWidget {
  const StoreOwnerBar({
    super.key,
    required this.profile,
    required this.preview,
    required this.onPreview,
    required this.onEdit,
  });

  final TGStoreProfile profile;
  final bool preview;
  final ValueChanged<bool> onPreview;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: TGColors.cta.withValues(alpha: 0.14),
      child: Container(
        key: const Key('store-owner-bar'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TGColors.cta, width: 1))),
        child: Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(context.t('ui_viewing_your_store'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
            TextButton(
              key: const Key('store-edit'),
              onPressed: onEdit,
              child: Text(context.t('ui_edit_store'), style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w900)),
            ),
            TextButton(
              key: const Key('store-preview-visitor'),
              onPressed: () {
                final next = !preview;
                TGAnalytics.track('store_preview_toggle', {'on': next, 'seller': profile.sellerKey});
                onPreview(next);
              },
              child: Text(preview ? context.t('ui_exit_preview') : context.t('ui_preview_as_visitor')),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreCompletenessCard extends StatefulWidget {
  const StoreCompletenessCard({super.key, required this.profile});
  final TGStoreProfile profile;

  @override
  State<StoreCompletenessCard> createState() => _StoreCompletenessCardState();
}

class _StoreCompletenessCardState extends State<StoreCompletenessCard> {
  @override
  void initState() {
    super.initState();
    final pct = storeProfileCompleteness(widget.profile);
    TGAnalytics.track('store_profile_completeness', {'pct': pct, 'seller': widget.profile.sellerKey});
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final pct = storeProfileCompleteness(profile);
    final tips = storeProfileTips(context, profile);
    return Container(
      key: const Key('store-completeness'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: TGColors.surface, borderRadius: BorderRadius.circular(TGRadius.card), border: Border.all(color: TGColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_store_profile_pct', {'n': '$pct'}), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: pct / 100, minHeight: 8, color: TGColors.cta, backgroundColor: TGColors.border),
          ),
          const SizedBox(height: 10),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('· $tip', style: const TextStyle(color: TGColors.textSecondary, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class StorePlanCard extends StatelessWidget {
  const StorePlanCard({super.key, required this.profile});
  final TGStoreProfile profile;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final renew = DateFormat('d MMM', Localizations.localeOf(context).languageCode).format(auth.storeRenewsOn);
    final pro = profile.plan == TGStorePlanKind.pro || profile.plan == TGStorePlanKind.enterprise;
    final line = pro
        ? context.t('ui_plan_promoted', {'used': '${auth.storePromotedUsed}', 'max': '${auth.storePromotedLimit}'})
        : context.t('ui_plan_basic_line', {'plan': auth.storePlanLabel, 'used': '${auth.storeActiveUsed}', 'max': '${auth.storeActiveLimit}', 'd': renew});
    return Container(
      key: const Key('store-plan-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: TGColors.surface, borderRadius: BorderRadius.circular(TGRadius.card), border: Border.all(color: TGColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          TGButton(
            onPressed: () => TGNav.plans(context),
            label: context.t('ui_upgrade'),
            variant: TGButtonVariant.outline,
            height: 40,
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('store-stats-dashboard'),
            onPressed: () => TGNav.dashboardListings(context),
            child: Text(context.t('ui_see_stats_dashboard')),
          ),
        ],
      ),
    );
  }
}

class StoreEditableRegion extends StatelessWidget {
  const StoreEditableRegion({
    super.key,
    required this.section,
    required this.editing,
    required this.child,
    required this.onEdit,
  });

  final TGStoreEditSection section;
  final bool editing;
  final Widget child;
  final ValueChanged<TGStoreEditSection> onEdit;

  @override
  Widget build(BuildContext context) {
    if (!editing) return child;
    return AnimatedOpacity(
      opacity: 1,
      duration: tgAnim(context, const Duration(milliseconds: 150)),
      child: CustomPaint(
        painter: _DashedRectPainter(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
        children: [
          child,
          Positioned(
            top: 4,
            right: 4,
            child: TGButton(
              key: Key('store-region-edit-${section.name}'),
              onPressed: () => onEdit(section),
              label: context.t('ui_edit'),
              variant: TGButtonVariant.ghost,
              height: 36,
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TGColors.cta
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dash = 6.0, gap = 4.0;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, (d + dash).clamp(0, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> showStoreEditFlow(BuildContext context, TGStoreProfile profile, {TGStoreEditSection? section}) async {
  await withStoreOverlay(context, () => _showStoreEditFlow(context, profile, section: section));
}

Future<void> _showStoreEditFlow(BuildContext context, TGStoreProfile profile, {TGStoreEditSection? section}) async {
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide && section != null) {
    await _openSection(context, profile, section);
    return;
  }
  if (!wide) {
    await Navigator.of(context).push<void>(
      PageRouteBuilder(
        fullscreenDialog: true,
        transitionDuration: tgAnim(context, const Duration(milliseconds: 250)),
        pageBuilder: (ctx, _, __) => _MobileSectionList(profile: profile),
      ),
    );
    return;
  }
  await _openSection(context, profile, section ?? TGStoreEditSection.description);
}

Future<void> _openSection(BuildContext context, TGStoreProfile profile, TGStoreEditSection section) {
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('ui_close'),
      barrierColor: Colors.black54,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
      pageBuilder: (ctx, _, __) => _SectionEditor(profile: profile, section: section, desktop: true),
      transitionBuilder: (ctx, anim, _, child) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: c, child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(c), child: child));
      },
    );
  }
  return Navigator.of(context).push<void>(
    PageRouteBuilder(
      fullscreenDialog: true,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 250)),
      pageBuilder: (ctx, _, __) => _SectionEditor(profile: profile, section: section, desktop: false),
    ),
  );
}

class _MobileSectionList extends StatelessWidget {
  const _MobileSectionList({required this.profile});
  final TGStoreProfile profile;

  @override
  Widget build(BuildContext context) {
    final live = TGSellerProfileService.instance.bySellerKey(profile.sellerKey) ?? profile;
    final sections = [
      TGStoreEditSection.cover,
      TGStoreEditSection.logo,
      TGStoreEditSection.description,
      TGStoreEditSection.taxonomy,
      TGStoreEditSection.hours,
      TGStoreEditSection.address,
      TGStoreEditSection.links,
      if (live.plan == TGStorePlanKind.pro || live.plan == TGStorePlanKind.enterprise) TGStoreEditSection.projects,
    ];
    return Scaffold(
      backgroundColor: TGColors.background,
      appBar: AppBar(
        title: Text(context.t('ui_edit_store')),
        backgroundColor: TGColors.surface,
      ),
      body: ListView(
        children: [
          for (final s in sections)
            ListTile(
              key: Key('store-section-${s.name}'),
              title: Text(_sectionTitle(context, s), style: const TextStyle(fontWeight: FontWeight.w800)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSection(context, live, s),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: TGColors.textSecondary),
            title: Text(context.t('ui_legal_locked'), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${live.legalName ?? '—'} · NIP ${live.nip ?? '—'}'),
          ),
        ],
      ),
    );
  }
}

class _SectionEditor extends StatefulWidget {
  const _SectionEditor({required this.profile, required this.section, required this.desktop});
  final TGStoreProfile profile;
  final TGStoreEditSection section;
  final bool desktop;

  @override
  State<_SectionEditor> createState() => _SectionEditorState();
}

class _SectionEditorState extends State<_SectionEditor> {
  late TGStoreProfile _draft = widget.profile;
  bool _saving = false;
  bool _saved = false;
  String? _error;
  bool _uploading = false;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saved = false;
      _error = null;
    });
    if (!tgInWidgetTest()) await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    TGSellerProfileService.instance.patch(_draft.publicId, (_) => _draft);
    TGAnalytics.track('store_edit_save', {'section': widget.section.name, 'seller': _draft.sellerKey});
    setState(() {
      _saving = false;
      _saved = true;
    });
    if (tgInWidgetTest()) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _pickImage({required bool square}) async {
    setState(() => _uploading = true);
    if (!tgInWidgetTest()) await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final pick = _kUploadPool[(square ? 3 : 0) % _kUploadPool.length];
    setState(() {
      _uploading = false;
      _draft = square ? _draft.copyWith(logoUrl: pick) : _draft.copyWith(coverUrl: pick);
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context)},
      child: FocusScope(
        autofocus: true,
        child: Material(
          color: TGColors.surface,
          borderRadius: widget.desktop ? BorderRadius.circular(TGRadius.modal) : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.desktop ? 560 : double.infinity, maxHeight: MediaQuery.sizeOf(context).height * (widget.desktop ? 0.86 : 1)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(_sectionTitle(context, widget.section), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 18)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: _fields()),
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: AnimatedOpacity(
                        opacity: _saving || _saved ? 1 : 0,
                        duration: tgAnim(context, const Duration(milliseconds: 150)),
                        child: Text(
                          _saving ? context.t('ui_saving') : _saved ? context.t('ui_saved_check') : '',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: TGColors.cta),
                        ),
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!, style: const TextStyle(color: TGColors.error, fontSize: 12)),
                    ),
                  TGButton(key: const Key('store-edit-save'), onPressed: _saving ? null : _save, label: context.t('ui_save'), height: 44),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.desktop) return Center(child: body);
    return Scaffold(backgroundColor: TGColors.surface, body: SafeArea(child: body));
  }

  Widget _fields() {
    switch (widget.section) {
      case TGStoreEditSection.cover:
        return _imageField(square: false, url: _draft.coverUrl, hint: context.t('ui_cover_hint'));
      case TGStoreEditSection.logo:
        return _imageField(square: true, url: _draft.logoUrl, hint: context.t('ui_logo_hint'));
      case TGStoreEditSection.description:
        return TextFormField(
          key: const Key('store-edit-description'),
          maxLines: 8,
          initialValue: _draft.description,
          onChanged: (v) => _draft = _draft.copyWith(description: v),
          decoration: InputDecoration(hintText: context.t('ui_store_description')),
        );
      case TGStoreEditSection.taxonomy:
        return ListView(
          children: [
            Text(context.t('ui_categories'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in TGCategory.values)
                  FilterChip(
                    label: Text(categoryLabel(c, t: (k) => context.t(k))),
                    selected: _draft.categories.contains(c),
                    onSelected: (on) {
                      final next = [..._draft.categories];
                      on ? next.add(c) : next.remove(c);
                      setState(() => _draft = _draft.copyWith(categories: next));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _draft.brands.join(', '),
              onChanged: (v) => _draft = _draft.copyWith(brands: v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()),
              decoration: InputDecoration(labelText: context.t('ui_brands')),
            ),
            const SizedBox(height: 12),
            for (final s in TGStoreService.values)
              CheckboxListTile(
                value: _draft.services.contains(s),
                title: Text(s.name),
                onChanged: (on) {
                  final next = [..._draft.services];
                  (on ?? false) ? next.add(s) : next.remove(s);
                  setState(() => _draft = _draft.copyWith(services: next));
                },
              ),
          ],
        );
      case TGStoreEditSection.hours:
        return ListView(
          children: [
            for (final day in kStoreDayKeys)
              _HoursRow(
                day: day,
                value: _draft.hours.of(day),
                onChanged: (v) => setState(() => _draft = _draft.copyWith(hours: _draft.hours.withDay(day, v))),
              ),
          ],
        );
      case TGStoreEditSection.address:
        return ListView(
          children: [
            TextFormField(
              initialValue: _draft.city,
              onChanged: (v) => _draft = _draft.copyWith(city: v),
              decoration: InputDecoration(labelText: context.t('ui_city'), hintText: 'Gliwice, Katowice, Chorzów'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _draft.address ?? '',
              onChanged: (v) => _draft = _draft.copyWith(address: v),
              decoration: InputDecoration(labelText: context.t('ui_address')),
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              decoration: BoxDecoration(color: TGColors.surfaceHover, borderRadius: BorderRadius.circular(12), border: Border.all(color: TGColors.cta)),
              alignment: Alignment.center,
              child: Text('${_draft.city} · pin', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      case TGStoreEditSection.links:
        return ListView(
          children: [
            TextFormField(
              initialValue: _draft.website ?? '',
              onChanged: (v) => _draft = _draft.copyWith(website: v),
              decoration: InputDecoration(labelText: context.t('ui_website')),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _draft.social.facebook ?? '',
              onChanged: (v) => _draft = _draft.copyWith(social: _draft.social.copyWith(facebook: v, clearFacebook: v.trim().isEmpty)),
              decoration: const InputDecoration(labelText: 'Facebook'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: _draft.social.instagram ?? '',
              onChanged: (v) => _draft = _draft.copyWith(social: _draft.social.copyWith(instagram: v, clearInstagram: v.trim().isEmpty)),
              decoration: const InputDecoration(labelText: 'Instagram'),
            ),
            const Divider(height: 28),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(context.t('ui_legal_locked')),
              subtitle: Text('${_draft.legalName ?? '—'} · NIP ${_draft.nip ?? '—'}'),
            ),
          ],
        );
      case TGStoreEditSection.projects:
        return ListView(
          children: [
            Text(context.t('ui_projects_limit'), style: const TextStyle(color: TGColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            for (var i = 0; i < _draft.projects.length; i++)
              ListTile(
                title: Text(_draft.projects[i].title),
                subtitle: Text('${_draft.projects[i].photos.length} photos'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    final next = [..._draft.projects]..removeAt(i);
                    setState(() => _draft = _draft.copyWith(projects: next));
                  },
                ),
              ),
            TGButton(
              onPressed: _draft.projects.length >= 8
                  ? null
                  : () {
                      final next = [
                        ..._draft.projects,
                        TGStoreProject(title: 'New project', city: _draft.city, year: 2026, photos: const ['assets/images/blog-26.jpg'], description: ''),
                      ];
                      setState(() => _draft = _draft.copyWith(projects: next));
                    },
              label: context.t('ui_add_project'),
              variant: TGButtonVariant.outline,
              height: 40,
            ),
          ],
        );
    }
  }

  Widget _imageField({required bool square, required String? url, required String hint}) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: hint,
          child: InkWell(
            onTap: () => _pickImage(square: square),
            onFocusChange: (_) {},
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): () => _pickImage(square: square),
                const SingleActivator(LogicalKeyboardKey.space): () => _pickImage(square: square),
              },
              child: Focus(
                child: AnimatedContainer(
                  duration: tgAnim(context, const Duration(milliseconds: 150)),
                  height: square ? 160 : 140,
                  width: double.infinity,
                  decoration: BoxDecoration(color: TGColors.surfaceHover, borderRadius: BorderRadius.circular(12), border: Border.all(color: TGColors.cta, width: 2)),
                  alignment: Alignment.center,
                  child: _uploading
                      ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: TGColors.cta))
                      : url == null
                          ? Text(hint, textAlign: TextAlign.center)
                          : ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset(url, fit: BoxFit.cover, width: double.infinity, height: square ? 160 : 140)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(hint, style: const TextStyle(color: TGColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({required this.day, required this.value, required this.onChanged});
  final String day;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final closed = value == 'closed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(context.t('ui_day_$day'), style: const TextStyle(fontWeight: FontWeight.w800))),
          Switch(value: !closed, onChanged: (on) => onChanged(on ? '08:00-16:00' : 'closed')),
          if (!closed)
            Expanded(
              child: TextFormField(
                initialValue: value,
                onChanged: onChanged,
                decoration: const InputDecoration(hintText: '08:00-16:00'),
              ),
            ),
        ],
      ),
    );
  }
}

String _sectionTitle(BuildContext context, TGStoreEditSection s) => switch (s) {
      TGStoreEditSection.cover => context.t('ui_cover'),
      TGStoreEditSection.logo => context.t('ui_logo'),
      TGStoreEditSection.description => context.t('ui_store_description'),
      TGStoreEditSection.taxonomy => context.t('ui_categories'),
      TGStoreEditSection.hours => context.t('ui_opening_hours'),
      TGStoreEditSection.address => context.t('ui_address'),
      TGStoreEditSection.links => context.t('ui_links'),
      TGStoreEditSection.projects => context.t('ui_references'),
    };
