import 'dart:convert';
import 'dart:html' as html;

void applyStoreAggregateRating({required String name, required double rating, required int count}) {
  html.ScriptElement? node = html.document.querySelector('script[data-tg-jsonld="store"]') as html.ScriptElement?;
  if (count < 3) {
    node?.remove();
    return;
  }
  node ??= html.ScriptElement()
    ..type = 'application/ld+json'
    ..dataset['tg-jsonld'] = 'store';
  node.text = jsonEncode({
    '@context': 'https://schema.org',
    '@type': 'LocalBusiness',
    'name': name,
    'aggregateRating': {
      '@type': 'AggregateRating',
      'ratingValue': rating.toStringAsFixed(1),
      'reviewCount': count,
      'bestRating': 5,
      'worstRating': 1,
    },
  });
  html.document.head?.append(node);
}

void clearStoreAggregateRating() {
  html.document.querySelector('script[data-tg-jsonld="store"]')?.remove();
}

void applyFaqPage(List<({String q, String a})> items) {
  html.ScriptElement? node = html.document.querySelector('script[data-tg-jsonld="faq"]') as html.ScriptElement?;
  if (items.isEmpty) {
    node?.remove();
    return;
  }
  node ??= html.ScriptElement()
    ..type = 'application/ld+json'
    ..dataset['tg-jsonld'] = 'faq';
  node.text = jsonEncode({
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    'mainEntity': [
      for (final item in items)
        {
          '@type': 'Question',
          'name': item.q,
          'acceptedAnswer': {'@type': 'Answer', 'text': item.a},
        },
    ],
  });
  html.document.head?.append(node);
}

void clearFaqPage() {
  html.document.querySelector('script[data-tg-jsonld="faq"]')?.remove();
}
