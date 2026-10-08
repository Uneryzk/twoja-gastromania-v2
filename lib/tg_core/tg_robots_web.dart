import 'dart:html' as html;

void applyListingRobots(bool noIndex) {
  html.MetaElement? meta = html.document.querySelector('meta[name="robots"]') as html.MetaElement?;
  if (meta == null) {
    meta = html.MetaElement()..name = 'robots';
    html.document.head?.append(meta);
  }
  meta.content = noIndex ? 'noindex, nofollow' : 'index, follow';
}
