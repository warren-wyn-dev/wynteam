import 'package:flutter/material.dart';

import '../../pop/data/pop.dart';
import '../../pop/data/pop_mute_preference.dart';
import '../../pop/data/pop_repository.dart';
import '../../pop/presentation/widgets/pop_clip_view.dart';

/// Opened when a Pop card is tapped from Home. Shows just the one clip
/// full-screen (no swiping to other Pops) rather than jumping into the
/// middle of PopFeedScreen's paginated feed -- see
/// .wyn/docs/design/wyn-007-home.md, Design Rules, for why. Reuses
/// PopClipView (WYN-006/WYN-007) for the actual playback/interaction so
/// this is just a thin host around it.
class PopSingleClipScreen extends StatefulWidget {
  const PopSingleClipScreen({
    super.key,
    required this.pop,
    required this.popRepository,
  });

  final Pop pop;
  final PopRepository popRepository;

  @override
  State<PopSingleClipScreen> createState() => _PopSingleClipScreenState();
}

class _PopSingleClipScreenState extends State<PopSingleClipScreen> {
  bool _muted = false;
  bool _mutedPrefLoaded = false;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    _loadMutedPref();
  }

  Future<void> _loadMutedPref() async {
    final muted = await loadPopMutedPreference();
    if (!mounted) return;
    setState(() {
      _muted = muted;
      _mutedPrefLoaded = true;
    });
  }

  Future<void> _toggleMuted() async {
    setState(() => _muted = !_muted);
    await savePopMutedPreference(_muted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_mutedPrefLoaded
          ? const Center(child: CircularProgressIndicator())
          : _deleted
              // The clip was deleted from inside PopClipView -- nothing
              // left to show; pop back to Home automatically.
              ? const SizedBox.shrink()
              : PopClipView(
                  initialPop: widget.pop,
                  popRepository: widget.popRepository,
                  isActive: true,
                  muted: _muted,
                  onMutedToggle: _toggleMuted,
                  onDeleted: () {
                    setState(() => _deleted = true);
                    Navigator.of(context).pop();
                  },
                  topLeading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'ย้อนกลับ',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
    );
  }
}
