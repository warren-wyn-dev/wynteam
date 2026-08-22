import 'package:flutter/material.dart';

/// Minimal full-screen image viewer for one appeal evidence image --
/// shared by MyModerationActionScreen (Screen 4) and AppealDetailScreen
/// (Screen 6). Deliberately no pinch-zoom/InteractiveViewer -- see
/// .wyn/docs/design/wyn-030-appeal-system.md, Screen 6 ("ไม่
/// over-engineer").
class EvidenceImageViewer extends StatelessWidget {
  const EvidenceImageViewer({super.key, required this.signedUrl});

  final String signedUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: Image.network(signedUrl)),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
