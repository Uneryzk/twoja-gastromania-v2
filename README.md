# Twoja Gastromania

A new Flutter project.

## Referral / representative panel (GROWTH-2)

> **This is only a UI filter, not real security; production requires
> server-side authorization.**
>
> **Bu yalnızca arayüz filtresidir, gerçek güvenlik değildir; üretimde
> sunucu tarafı yetkilendirme şart.**

All representative queries go through `ReferralRepository` (`lib/tg_services/referral_repository.dart`) and take `repId`. Phone, email, messages, payment method and invoices never appear on representative DTOs. Mock representatives (`Marek-IND2026`, `Piotr-CORP2026`, `Anna-OPS2026`) are seeded only outside Production Mode.

`pdf` / `printing` are not in `pubspec.yaml`; reports use a printable on-screen preview instead of generating a PDF file. Share links are 128-bit tokens, 14 days (`TGReferralConfig.shareLinkDays`), revokeable, and opened at `/r/:token` with a noindex marker.

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

## How to add new copy (I18N-2)

Chrome (buttons, labels, empty states, notifications, timeline) lives in
`lib/flutter_flow/tg_l10n.dart` — there is no ARB file.

1. Add a key with **English, Polish and Turkish** (use `_l` for all ten marketplace
   languages, or `_d(en, pl:, tr:)` when the other eight may copy English for now).
2. Put `{placeholders}` in every language with the **same names**.
3. For counts use ICU `{n, plural, ...}` via `TGPlural` / `DurationFormatter`.
   Polish needs `one` / `few` / `many` / `other`; Turkish and English need `one` /
   `other`. Never write `'$n days'` or `'$count listings'` in Dart.
4. In widgets call `context.t('ui_your_key', {'n': '$n'})`. Do not put a visible
   English (or Polish/Turkish) sentence in `Text('...')`.
5. User-generated copy (listing title, description, chat, review, store name)
   goes through `TGUserText`, not `context.t`.
6. Services must return `LocalizedMessage(key, args)` (or persist `titleKey` +
   `params`). Resolve in the UI with the **active locale**. Email/SMS use the
   **recipient** `TGUserLocales` / `User.preferredLocale`, not the sender.
7. Check `tool/i18n_glossary.csv` for agreed terms. Skip rows marked
   `TO CONFIRM`. Brand/technical tokens in `tool/i18n_allowlist.txt` stay the
   same in every language (BLIK, PLN, Twoja Gastromania, Spotlight, …).
8. `tool/check_hardcoded_strings.dart` plus `test/i18n2_*.dart` run in CI. New
   hardcoded chrome fails the ratchet until you move it into `tg_l10n` (or, to
   record a leftover, regenerate `tool/i18n_hardcoded_baseline.txt` with
   `dart run tool/check_hardcoded_strings.dart --write-baseline`).

Missing keys: debug/profile show `⚠ key_name` and log once; release falls back
to English and emits `i18n_missing_key` on `TGAnalytics` (hook Crashlytics via
`TGI18nAudit.onMissing` later). Silent English fallback is gone.

Dev only (off in Production Mode): long-press the header account control →
**Language audit** to red-frame non-key chrome and list ⚠ keys.
