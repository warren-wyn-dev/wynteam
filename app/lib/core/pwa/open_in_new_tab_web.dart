import 'package:web/web.dart' as web;

void openInNewTab(String path) {
  web.window.open(path, '_blank');
}
