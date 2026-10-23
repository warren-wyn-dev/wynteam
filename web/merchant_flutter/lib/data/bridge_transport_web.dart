import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'bridge_transport.dart';

@JS('zokyMerchant')
external _HostBridge get _hostBridge;
@JS()
extension type _HostBridge(JSObject _) implements JSObject {
  external JSPromise<JSString> request(JSString method, JSString payload);
}

class WebBridgeTransport implements BridgeTransport {
  WebBridgeTransport() : _capturedBridge = _hostBridge {
    listener = ((web.Event _) {
      if (!changes.isClosed) changes.add(null);
    }).toJS;
    web.window.addEventListener('zoky-merchant-order-change', listener);
  }
  final _HostBridge _capturedBridge;
  bool disposed = false;
  final changes = StreamController<void>.broadcast();
  late final JSFunction listener;
  @override
  Stream<void> get orderChanges => changes.stream;
  @override
  Future<String> request(String method, String payload) async {
    if (disposed) throw StateError('Merchant view has been closed');
    final response = await _capturedBridge
        .request(method.toJS, payload.toJS)
        .toDart;
    if (disposed) throw StateError('Merchant view has been closed');
    return response.toDart;
  }

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    web.window.removeEventListener('zoky-merchant-order-change', listener);
    unawaited(changes.close());
  }
}

BridgeTransport createBridgeTransport() => WebBridgeTransport();
