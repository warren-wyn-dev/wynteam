/// The one place that decides how a post's photo is *shaped* and
/// *decoded*, for every surface that shows a post as a post -- Home
/// feed (single image and peek carousel) and Drop Detail (single image
/// and swipeable gallery).
///
/// Beta3 exists because those surfaces had each grown their own answer:
/// HomeDropCard clamped a Drop's true aspect ratio to 4:5..1.91:1
/// (WYN-093), HomeFeedImagePeekCarousel duplicated that same clamp in a
/// private copy of the function "rather than exporting it just for this
/// one reuse", and DropImageGallery ignored dimensions entirely and
/// rendered every photo into a hard `AspectRatio(1)` with
/// `BoxFit.cover`. The visible result was the Founder's own Beta3
/// report: a portrait photo that reads correctly in the feed is cropped
/// top-and-bottom the moment you open the post -- the same picture,
/// half of it gone, on the one screen dedicated to looking at it.
///
/// Profile's grid is deliberately NOT a caller here: a grid is a
/// content *overview* and square tiles are the right shape for it (see
/// [NetworkThumbnail], which grid tiles already use). This file is
/// about the post-shaped surfaces only.
library;

import 'package:flutter/material.dart';

import 'network_thumbnail.dart';

/// The most-portrait shape a post photo is shown at without cropping
/// (4:5) and the most-landscape (1.91:1). Outside that range the photo
/// still renders, cropped at whichever edge it overshoots -- the same
/// bounds WYN-093 established for the feed, now applied everywhere a
/// post is shown post-shaped.
const double minPostImageAspectRatio = 0.8;
const double maxPostImageAspectRatio = 1.91;

/// The aspect ratio to render a post photo at, given its true pixel
/// dimensions. Falls back to a 1:1 square when the dimensions aren't
/// known -- every Drop uploaded before WYN-093 added the columns, and
/// any row with a non-positive height.
double postImageAspectRatio(int? width, int? height) {
  if (width == null || height == null || height <= 0 || width <= 0) return 1;
  return (width / height)
      .clamp(minPostImageAspectRatio, maxPostImageAspectRatio);
}

/// A post's photo: decoded at the size it is actually painted at, with
/// the neutral placeholder/broken-image pair every surface was
/// repeating by hand.
///
/// The decode bound is the reason this is a widget rather than a bare
/// `Image.network` call. Wynos compresses uploads to 1600x1600
/// (WYN-103); a plain `Image.network` decodes all of that regardless of
/// the box it lands in -- ~10MB of bitmap per photo. A feed row on a
/// 390pt-wide phone paints roughly 1170 physical pixels of width at
/// DPR 3, and only 780 at DPR 2, so the same photo costs ~5.5MB and
/// ~2.4MB respectively once decoded to fit. With images from several
/// rows alive at once that difference is the difference between a feed
/// that scrolls and one the OS starts evicting.
///
/// Deliberately still `Image.network` under the hood, not
/// `CachedNetworkImage`: WYN-074 tried that and every image failed to
/// render on this project's Flutter Web build. That constraint has not
/// changed, so neither has this.
class PostImage extends StatelessWidget {
  const PostImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  final String imageUrl;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Image.network(
          imageUrl,
          fit: fit,
          semanticLabel: semanticLabel,
          cacheWidth: decodeWidthFor(
            constraints.maxWidth,
            devicePixelRatio: devicePixelRatio,
          ),
          // A neutral block, never a spinner: a post photo resolves in
          // well under a second on any usable connection, and a
          // spinner appearing and vanishing on every row of a scroll
          // is more visual noise than the wait it reports. Matches the
          // placeholder NetworkThumbnail already uses for grid tiles,
          // so a photo looks the same while loading wherever it is.
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
          errorBuilder: networkImageErrorBuilder,
        );
      },
    );
  }
}

/// A post's photo laid out the way every post-shaped surface lays one
/// out: the clamped aspect ratio from [postImageAspectRatio], capped so
/// a tall photo can never eat a whole viewport, decoded to fit.
///
/// The height cap (WYN-093) is a second, independent ceiling on top of
/// the ratio clamp -- without it a photo right at the 4:5 bound fills
/// almost the entire screen on a tall viewport (a tablet held upright),
/// leaving no visible sign that a caption, an action bar, or a next
/// post exists below it.
class PostImageFrame extends StatelessWidget {
  const PostImageFrame({
    super.key,
    required this.imageUrl,
    required this.imageWidth,
    required this.imageHeight,
    this.maxHeightFraction = 0.75,
    this.semanticLabel,
  });

  final String imageUrl;
  final int? imageWidth;
  final int? imageHeight;

  /// Share of the viewport height this photo may occupy at most.
  final double maxHeightFraction;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeightFraction * MediaQuery.sizeOf(context).height,
      ),
      child: AspectRatio(
        aspectRatio: postImageAspectRatio(imageWidth, imageHeight),
        child: PostImage(imageUrl: imageUrl, semanticLabel: semanticLabel),
      ),
    );
  }
}
