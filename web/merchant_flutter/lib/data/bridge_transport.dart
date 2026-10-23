import 'bridge_transport_stub.dart'
    if (dart.library.js_interop) 'bridge_transport_web.dart'
    as platform;

abstract class BridgeTransport {
  Future<String> request(String method, String payload);
  Stream<void> get orderChanges;
  void dispose();
}

BridgeTransport createBridgeTransport() => platform.createBridgeTransport();
