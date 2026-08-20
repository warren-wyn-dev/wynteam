import 'dart:typed_data';

import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// A fake ImagePickerPlatform so widget tests can exercise
/// CreateDropScreen's real _pickImage() -> centerCropToSquare() path
/// deterministically, instead of it hanging/throwing on a platform
/// channel with no handler in the test env -- same rationale as
/// FakeVideoPlayerPlatform (WYN-006). See .wyn/learning/PATTERNS.md.
///
/// Returns an XFile built via XFile.fromData(), which reads its bytes
/// straight out of memory (no real file I/O) -- see cross_file's
/// XFile.readAsBytes().
class FakeImagePickerPlatform extends ImagePickerPlatform {
  FakeImagePickerPlatform(this.bytes);

  final Uint8List bytes;

  int getImageFromSourceCalls = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    getImageFromSourceCalls++;
    return XFile.fromData(bytes, name: 'test.png', mimeType: 'image/png');
  }
}
