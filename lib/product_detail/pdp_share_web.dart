import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Future<bool> tryNavigatorShare({
  required String title,
  required String text,
  required String url,
}) async {
  final nav = globalContext.getProperty('navigator'.toJS);
  if (nav.isUndefinedOrNull) return false;
  final navigator = nav as JSObject;
  if (!navigator.has('share')) return false;
  try {
    final data = JSObject()
      ..['title'] = title.toJS
      ..['text'] = text.toJS
      ..['url'] = url.toJS;
    final promise = navigator.callMethod('share'.toJS, data);
    if (promise == null) return false;
    await (promise as JSPromise).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
