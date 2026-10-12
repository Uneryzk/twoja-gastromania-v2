// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

/// Opens a browser file picker and returns a `data:image/...;base64,...` URL.
Future<String?> pickImageAsDataUrl() async {
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();
  await input.onChange.first;
  final file = input.files?.first;
  if (file == null) return null;
  final reader = html.FileReader();
  final done = Completer<String?>();
  reader.onLoad.listen((_) => done.complete(reader.result as String?));
  reader.onError.listen((_) => done.complete(null));
  reader.readAsDataUrl(file);
  return done.future;
}
