import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../data/location_repository.dart';
import '../data/location_result.dart';

/// Thrown by [resolveCurrentDevicePosition] when the user has no
/// granted (or has permanently denied) location permission -- see
/// that function's own doc comment.
class LocationPermissionDeniedException implements Exception {}

/// Wraps `package:geolocator`'s permission-check-then-request dance
/// (WYN-098's "ใช้ตำแหน่งปัจจุบันของฉัน") into one call: throws
/// [LocationPermissionDeniedException] rather than returning a
/// sentinel, so the screen's own try/catch stays a single flat
/// structure alongside its other 2 failure modes (search/reverse-
/// geocode errors from [LocationRepository], which throw their own
/// distinct exception types the exact same way).
Future<(double lat, double lon)> resolveCurrentDevicePosition() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw LocationPermissionDeniedException();
  }
  final position = await Geolocator.getCurrentPosition();
  return (position.latitude, position.longitude);
}

/// Screen 2 -- ค้นหา/เลือกสถานที่ (WYN-098). Pushed by
/// `CreateDropScreen`'s ปักหมุด toolbar button; pops with the selected
/// [LocationResult], or `null` on ยกเลิก/back. Implemented as a
/// full-screen push rather than a `DraggableScrollableSheet` (Design
/// spec explicitly left this choice to AI Coding) -- the search field
/// opening the keyboard on a modal sheet is fiddlier to get right than
/// on an ordinary pushed screen, and every other list+search screen in
/// this codebase (FollowListScreen, ExcludeFriendsScreen) already uses
/// a full push for the same reason.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.locationRepository,
    @visibleForTesting this.debugResolveCurrentPosition,
  });

  final LocationRepository locationRepository;

  /// Test-only seam: replaces the real `resolveCurrentDevicePosition()`
  /// (which calls `package:geolocator`'s platform channel -- no
  /// handler registered in this sandbox's widget tests, same class of
  /// problem as `image_picker`'s own MethodChannel, see
  /// create_drop_screen.dart's `debugInitialImagesBytes` doc comment
  /// and .wyn/company/DECISIONS.md 2026-09-02) with a canned function.
  @visibleForTesting
  final Future<(double, double)> Function()? debugResolveCurrentPosition;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Bumped on every new search kicked off -- a response is only
  // applied if it's still the most recent one in flight, guarding the
  // exact race condition Product spec's Edge Cases table calls out
  // ("ผู้ใช้พิมพ์แล้วลบอย่างรวดเร็ว... request เก่าที่ยังไม่ตอบกลับ
  // ควรถูกยกเลิก/ignore").
  int _searchRequestId = 0;

  List<LocationResult> _results = [];
  bool _isSearching = false;
  bool _hasSearchedOnce = false;
  bool _isLocatingCurrent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _hasSearchedOnce = false;
        _errorMessage = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(trimmed));
  }

  Future<void> _search(String query) async {
    final requestId = ++_searchRequestId;
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    try {
      final results = await widget.locationRepository.search(query);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _results = results;
        _hasSearchedOnce = true;
      });
    } on LocationSearchRateLimitedException {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _errorMessage = 'ค้นหาบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่');
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _errorMessage = 'ค้นหาสถานที่ไม่สำเร็จตอนนี้ ลองอีกครั้งในอีกสักครู่');
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocatingCurrent) return;
    setState(() {
      _isLocatingCurrent = true;
      _errorMessage = null;
    });
    try {
      final resolvePosition =
          widget.debugResolveCurrentPosition ?? resolveCurrentDevicePosition;
      final (lat, lon) = await resolvePosition();
      final results =
          await widget.locationRepository.reverseGeocode(lat: lat, lon: lon);
      if (!mounted) return;
      setState(() {
        // Prepended, not selected automatically -- Design spec: "ไม่
        // auto-select ทันที แสดงผลลัพธ์แรก (ใกล้ที่สุด) เป็นแถวบนสุด
        // ของ list ให้ผู้ใช้กดยืนยันเอง".
        _results = [...results, ..._results];
        _hasSearchedOnce = true;
      });
    } on LocationPermissionDeniedException {
      if (!mounted) return;
      setState(() => _errorMessage =
          'WYN ไม่มีสิทธิ์เข้าถึงตำแหน่งของคุณ กรุณาเปิดสิทธิ์ในการตั้งค่าเครื่อง');
    } on LocationSearchRateLimitedException {
      if (!mounted) return;
      setState(() => _errorMessage = 'ค้นหาบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่');
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'ค้นหาสถานที่ไม่สำเร็จตอนนี้ ลองอีกครั้งในอีกสักครู่');
    } finally {
      if (mounted) setState(() => _isLocatingCurrent = false);
    }
  }

  void _select(LocationResult result) => Navigator.of(context).pop(result);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('เพิ่มสถานที่'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_isSearching)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space6, WynSpacing.space3, WynSpacing.space6, WynSpacing.space2,
      ),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
        decoration: BoxDecoration(
          color: WynColors.surfaceTint,
          borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
          border: Border.all(color: WynColors.hairline),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 14, color: WynColors.mutedNeutral),
            const SizedBox(width: WynSpacing.space2),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                decoration: const InputDecoration(
                  hintText: 'ค้นหาสถานที่...',
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      children: [
        Semantics(
          label: 'ใช้ตำแหน่งปัจจุบันของฉันเป็นสถานที่เช็คอิน',
          button: true,
          excludeSemantics: true,
          child: ListTile(
            leading: _isLocatingCurrent
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, color: WynColors.sapphire),
            title: Text(
              _isLocatingCurrent
                  ? 'กำลังค้นหาตำแหน่งของคุณ...'
                  : 'ใช้ตำแหน่งปัจจุบันของฉัน',
              style: const TextStyle(
                  color: WynColors.sapphire, fontWeight: FontWeight.w600),
            ),
            enabled: !_isLocatingCurrent,
            onTap: _useCurrentLocation,
          ),
        ),
        const Divider(height: 1, color: WynColors.hairline),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(WynSpacing.space4),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: WynColors.errorLight),
            ),
          )
        else if (_hasSearchedOnce && _results.isEmpty && !_isSearching)
          const Padding(
            padding: EdgeInsets.all(WynSpacing.space6),
            child: Center(
              child: Text('ไม่พบสถานที่ที่ค้นหา ลองพิมพ์คำอื่นดูนะ'),
            ),
          )
        else
          for (final result in _results) _buildResultRow(result),
      ],
    );
  }

  Widget _buildResultRow(LocationResult result) {
    return Semantics(
      label: result.address != null ? '${result.name}, ${result.address}' : result.name,
      excludeSemantics: true,
      child: ListTile(
        leading: const Icon(Icons.place_outlined, color: WynColors.mutedNeutral),
        title: Text(result.name),
        subtitle: result.address != null
            ? Text(
                result.address!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: WynColors.graphite, fontSize: 13),
              )
            : null,
        onTap: () => _select(result),
      ),
    );
  }
}
