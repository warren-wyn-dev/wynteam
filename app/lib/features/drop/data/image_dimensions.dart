import 'dart:typed_data';
import 'dart:ui' as ui;

/// WYN-093 (Wynos V1.0.0 Beta2, item 19): the real pixel dimensions of
/// an about-to-be-uploaded image, decoded once client-side so
/// DropRepository.createDrop can store them on `drops`/`drop_images`
/// (`image_width`/`image_height`) at insert time -- letting
/// HomeDropCard render the feed at the image's true aspect ratio
/// without ever waiting on a network image to finish loading first
/// (see .wyn/docs/design/wyn-093-dynamic-height-images.md's
/// "performance" section). Same "dart:ui only, no extra
/// image-processing package" posture as [centerCropToSquare]'s
/// identical doc comment -- sibling helper, not merged into that file,
/// since cropping and measuring are two independent concerns callers
/// may want separately.
Future<(int width, int height)> decodeImageDimensions(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return (frame.image.width, frame.image.height);
}
