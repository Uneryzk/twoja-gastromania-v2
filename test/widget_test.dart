import 'package:flutter_test/flutter_test.dart';

import 'helpers/tg_test_app.dart';

void main() {
  testWidgets('app boots on the home page', (tester) async {
    final app = await pumpTgApp(tester, location: '/');
    expect(find.text('Twoja Gastromania'), findsWidgets);
    expect(find.text('Buy'), findsWidgets);
    app.errors.stop();
    expect(app.errors.distinct, isEmpty, reason: app.errors.distinct.join('\n'));
  });
}
