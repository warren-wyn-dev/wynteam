import 'package:flutter/foundation.dart';

import 'data/address_repository.dart';
import 'domain/address_models.dart';

/// App-wide "จัดส่งที่" state: the saved addresses and the one the customer
/// picked. A plain [ChangeNotifier] handed down by AppDependencies (no
/// state-management package, architecture doc section 5).
///
/// The selection lives in memory only; it falls back to the default
/// address (else the first) after every load.
class DeliveryAddressController extends ChangeNotifier {
  DeliveryAddressController(this.repository);

  final AddressRepository repository;

  List<ZokyDeliveryAddress>? _addresses;
  ZokyDeliveryAddress? _selected;
  Object? _error;
  bool _loading = false;

  /// null until the first load finishes.
  List<ZokyDeliveryAddress>? get addresses => _addresses;
  ZokyDeliveryAddress? get selected => _selected;
  Object? get error => _error;
  bool get isLoading => _loading;

  /// Loads once; later calls are no-ops unless [force] (retry).
  Future<void> load({bool force = false}) async {
    if (_loading || (_addresses != null && !force)) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await repository.fetchSavedAddresses();
      _addresses = List.unmodifiable(list);
      final keep = list.where((a) => a.id == _selected?.id);
      _selected = keep.isNotEmpty
          ? keep.first
          : list.where((a) => a.isDefault).firstOrNull ?? list.firstOrNull;
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Picks one of the loaded [addresses]; anything else is ignored.
  void select(ZokyDeliveryAddress address) {
    final match = _addresses?.where((a) => a.id == address.id).firstOrNull;
    if (match == null || match.id == _selected?.id) return;
    _selected = match;
    notifyListeners();
  }
}
