# Twoja Gastromania

A new Flutter project.

## Getting Started

FlutterFlow projects are built to run on the Flutter _stable_ release.

## Listing photo watermark (WATERMARK-1)

> **Security warning:** Overlay gives no real protection; the raw file URL stays open.
> In production the watermark must be applied on the server while generating
> derivatives, and the original must never be served publicly.
>
> **Güvenlik uyarısı:** Overlay gerçek koruma sağlamaz; ham dosya adresi açık kalır.
> Üretimde filigran sunucuda türev üretiminde uygulanmalı ve orijinal herkese açık sunulmamalı.

- `WatermarkConfig` (`lib/tg_models/tg_watermark.dart`) is edited at `/admin/watermark`
  (enabled, version, mark asset, opacity 0.12, width ratio 0.22, position, min width 200 px).
  A visual change bumps the version; "Reprocess images" moves every photo to it.
- `WatermarkedImage` (`lib/tg_components/tg_watermarked_image.dart`) is the prototype overlay
  used on listing grids/cards, the detail gallery, the lightbox (scales with zoom), share
  previews and the upload "Preview (with logo)". The mark is excluded from semantics and is
  skipped below `minImageWidthPx`.
- Never watermarked: special-order files (DXF/DWG/PDF/drawings), legal documents, message
  attachments, avatars, store logo/cover, banner/hero, ad slots and sponsor slots.
- `ListingImage` keeps `originalRef` private: it is absent from `toJson()` (public API shape)
  and only returned to admin/moderator roles. pHash is computed from the original, and the
  moderation photo comparison matches on originals.
- The Regulamin photo-licence clause (`regulamin_photo_license`) is a DRAFT pending legal
  review and blocks go-live until approved.
