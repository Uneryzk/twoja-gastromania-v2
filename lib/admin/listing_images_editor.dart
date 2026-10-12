import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_manual_image_field.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

/// Opens admin/seller image manager for a product or restaurant listing.
Future<void> showListingImagesEditor(
  BuildContext context, {
  TGProduct? product,
  RestaurantListing? restaurant,
}) {
  assert(product != null || restaurant != null);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _ListingImagesEditorSheet(product: product, restaurant: restaurant),
    ),
  );
}

class _ListingImagesEditorSheet extends StatefulWidget {
  const _ListingImagesEditorSheet({this.product, this.restaurant});
  final TGProduct? product;
  final RestaurantListing? restaurant;

  @override
  State<_ListingImagesEditorSheet> createState() => _ListingImagesEditorSheetState();
}

class _ListingImagesEditorSheetState extends State<_ListingImagesEditorSheet> {
  late String _cover;
  late List<String> _gallery;
  late List<RestaurantInventoryItem> _inventory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final r = widget.restaurant;
    if (r != null) {
      _cover = r.imageUrl;
      _gallery = List.of(r.images);
      _inventory = List.of(r.inventory);
    } else {
      _cover = p?.imageUrl ?? '';
      _gallery = List.of(p?.imageUrls ?? const []);
      _inventory = const [];
    }
    if (_gallery.isEmpty && _cover.isNotEmpty) _gallery = [_cover];
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final cover = _cover.trim();
    var gallery = [for (final u in _gallery) u.trim()].where((u) => u.isNotEmpty).toList();
    if (cover.isNotEmpty) {
      gallery = [cover, ...gallery.where((u) => u != cover)];
    }

    if (widget.restaurant != null) {
      final next = widget.restaurant!.copyWith(images: gallery, inventory: _inventory);
      RestaurantService.instance.replace(next);
    }
    if (widget.product != null) {
      final next = widget.product!.copyWith(
        imageUrl: cover,
        imageUrls: gallery,
        photoCount: gallery.isEmpty ? 0 : gallery.length,
      );
      await TGProductService.instance.upsert(next);
      if (!mounted) return;
      final auth = context.read<FakeAuthState>();
      if (auth.ownedListings.any((e) => e.id == next.id)) {
        auth.upsertOwned(next);
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    showTGToast(context, context.t('ui_image_saved'));
    Navigator.pop(context);
  }

  void _setCover(String v) {
    setState(() {
      _cover = v;
      if (v.trim().isEmpty) {
        if (_gallery.isNotEmpty) _gallery = _gallery.sublist(1);
      } else if (_gallery.isEmpty) {
        _gallery = [v];
      } else {
        _gallery = [v, ..._gallery.skip(1)];
      }
    });
  }

  void _setEquipmentImage(int index, String url) {
    setState(() {
      final item = _inventory[index];
      _inventory = [
        for (var i = 0; i < _inventory.length; i++)
          if (i == index) item.copyWith(equipmentImage: url) else _inventory[i],
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final title = widget.restaurant?.title ?? widget.product?.title ?? '';
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('ui_image_manage_title'),
                      style: theme.titleMedium.override(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(color: theme.secondaryText)),
              const SizedBox(height: 8),
              Text(context.t('ui_image_manual_only'), style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.35)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    TGManualImageField(
                      key: const Key('listing-cover-image'),
                      label: context.t('ui_image_cover'),
                      value: _cover,
                      onChanged: _setCover,
                    ),
                    if (widget.restaurant != null && _inventory.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(context.t('ui_image_equipment'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _inventory.length; i++) ...[
                        const SizedBox(height: 12),
                        TGManualImageField(
                          key: Key('equipment-image-${_inventory[i].id}'),
                          label: '${_inventory[i].name}${_inventory[i].brand == null ? '' : ' · ${_inventory[i].brand}'}',
                          value: _inventory[i].equipmentImage,
                          height: 100,
                          onChanged: (v) => _setEquipmentImage(i, v),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TGButton(
                key: const Key('listing-images-save'),
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
