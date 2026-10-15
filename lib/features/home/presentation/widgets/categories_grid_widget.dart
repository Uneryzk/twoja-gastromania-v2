import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_hover_card.dart';
import 'package:twoja_gastromania/tg_components/tg_manual_image_field.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_plural.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_home_category.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/home_category_service.dart';

/// Home gastronomy category tiles. Staff (admin / moderator) get a pencil on each card.
class HomeCategoriesGrid extends StatelessWidget {
  const HomeCategoriesGrid({super.key, required this.listingCounts});

  final Map<TGCategory, int> listingCounts;

  @override
  Widget build(BuildContext context) {
    HomeCategoryService.instance.ensureSeeded();
    final rows = HomeCategoryService.instance.active;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 3 : 2;
        final phone = c.maxWidth < 480;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          clipBehavior: Clip.none,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: phone ? 12 : 20,
            mainAxisSpacing: phone ? 12 : 20,
            childAspectRatio: cols == 3 ? 1.35 : (phone ? 0.95 : 1.3),
          ),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];
            return _HomeCategoryCard(
              row: row,
              liveCount: listingCounts[row.category],
              compact: phone,
            );
          },
        );
      },
    );
  }
}

class _HomeCategoryCard extends StatelessWidget {
  const _HomeCategoryCard({required this.row, required this.liveCount, required this.compact});

  final TGHomeCategory row;
  final int? liveCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final title = row.hasTitleOverride ? row.title : context.t(row.titleKey);
    final countLabel = row.hasCountOverride
        ? row.itemCount
        : (liveCount == null ? null : TGPlural.listingsOf(context, liveCount!));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: TGHoverCard(
            semanticLabel: context.t('ui_browse_category', {'title': title}),
            onTap: () => TGNav.category(context, row.category),
            child: Stack(
              fit: StackFit.expand,
              children: [
                TGSmartImage(
                  url: row.imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  fallback: (_) => ColoredBox(color: theme.alternate),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [Colors.black.withValues(alpha: 0.78), Colors.transparent],
                    ),
                  ),
                ),
                Positioned(
                  left: compact ? 10 : 14,
                  right: compact ? 10 : 14,
                  bottom: compact ? 10 : 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 6 : 8),
                              decoration: BoxDecoration(color: theme.secondary, borderRadius: BorderRadius.circular(TGRadius.pill)),
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.titleSmall.override(
                                  color: Colors.white,
                                  fontSize: compact ? 13 : 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.40,
                                  lineHeight: 1.2,
                                ),
                              ),
                            ),
                            if (countLabel != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                countLabel,
                                style: theme.bodySmall.override(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: compact ? 32 : 38,
                        height: compact ? 32 : 38,
                        decoration: BoxDecoration(color: theme.primary, shape: BoxShape.circle),
                        child: Icon(Icons.arrow_forward_rounded, size: compact ? 18 : 20, color: TGColors.onCta),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: HomeCategoryEditButton(
            category: row,
            onPressed: () => showHomeCategoryEditSheet(context, category: row, liveCountLabel: countLabel ?? ''),
          ),
        ),
      ],
    );
  }
}

/// Pencil on a category tile. Hidden for visitors and sellers.
class HomeCategoryEditButton extends StatelessWidget {
  const HomeCategoryEditButton({
    super.key,
    required this.category,
    required this.onPressed,
  });

  final TGHomeCategory category;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    if (!auth.canModerate) return const SizedBox.shrink();
    return Tooltip(
      message: context.t('ui_category_edit'),
      child: Material(
        color: Colors.black.withValues(alpha: 0.78),
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          key: Key('home-category-edit-${category.id}'),
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Semantics(
            button: true,
            label: context.t('ui_category_edit_sem'),
            child: const SizedBox(
              width: 32,
              height: 32,
              child: Icon(Icons.edit_outlined, size: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Staff sheet: title, listing-count label, photo (library / upload / asset path).
Future<void> showHomeCategoryEditSheet(
  BuildContext context, {
  required TGHomeCategory category,
  required String liveCountLabel,
}) {
  final title = category.hasTitleOverride ? category.title : context.t(category.titleKey);
  final count = category.hasCountOverride ? category.itemCount : liveCountLabel;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _HomeCategoryEditSheet(category: category, initialTitle: title, initialCount: count),
    ),
  );
}

class _HomeCategoryEditSheet extends StatefulWidget {
  const _HomeCategoryEditSheet({
    required this.category,
    required this.initialTitle,
    required this.initialCount,
  });

  final TGHomeCategory category;
  final String initialTitle;
  final String initialCount;

  @override
  State<_HomeCategoryEditSheet> createState() => _HomeCategoryEditSheetState();
}

class _HomeCategoryEditSheetState extends State<_HomeCategoryEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _count;
  late String _image;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle);
    _count = TextEditingController(text: widget.initialCount);
    _image = widget.category.imageUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _count.dispose();
    super.dispose();
  }

  void _save() {
    setState(() {
      _saving = true;
      _error = null;
    });
    final auth = context.read<FakeAuthState>();
    final err = HomeCategoryService.instance.save(
      actor: auth,
      category: widget.category.copyWith(
        title: _title.text,
        itemCount: _count.text,
        imageUrl: _image,
      ),
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _error = err;
      });
      return;
    }
    showTGToast(context, context.t('ui_admin_content_saved'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SafeArea(
      child: SizedBox(
        key: const Key('home-category-edit-sheet'),
        height: MediaQuery.sizeOf(context).height * 0.86,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(context.t('ui_category_edit_dialog'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    TGManualImageField(
                      value: _image,
                      onChanged: (v) => setState(() => _image = v),
                      label: context.t('ui_category_photo'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('home-category-edit-title'),
                      controller: _title,
                      decoration: InputDecoration(labelText: context.t('ui_category_name')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('home-category-edit-count'),
                      controller: _count,
                      decoration: InputDecoration(labelText: context.t('ui_category_count')),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(context.t(_error!), style: TextStyle(color: theme.error, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TGButton(
                key: const Key('home-category-edit-save'),
                onPressed: _saving ? null : _save,
                label: _saving ? context.t('ui_saving') : context.t('ui_save'),
                height: 48,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
