import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'adaptive.dart';

/// Single place that maps ZOKY's icon vocabulary to glyphs.
///
/// Design section 7 specifies Lucide (as on the web). The Lucide package for
/// Flutter is not chosen yet (architecture doc section 3), so shared icons
/// use the closest Material icon for now; swapping the set later means
/// editing only this file.
abstract final class ZokyIcons {
  // Shared (same on every platform).
  static const IconData home = Icons.home_outlined; // Lucide House
  static const IconData homeActive = Icons.home_rounded; // House, filled
  static const IconData orders = Icons.receipt_long_outlined; // ReceiptText
  static const IconData messages =
      Icons.chat_bubble_outline_rounded; // MessageCircle
  static const IconData account = Icons.person_outline_rounded; // UserRound
  static const IconData search = Icons.search_rounded;
  static const IconData store = Icons.storefront_outlined;
  static const IconData food = Icons.restaurant_rounded; // UtensilsCrossed
  static const IconData star = Icons.star_rounded;
  static const IconData clock = Icons.schedule_rounded; // Clock3
  static const IconData add = Icons.add_rounded;
  static const IconData remove = Icons.remove_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData error = Icons.error_outline_rounded; // CircleAlert
  static const IconData wifiOff = Icons.wifi_off_rounded;
  static const IconData location = Icons.location_on_outlined; // MapPin
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData cart = Icons.shopping_bag_outlined;
  static const IconData favorite = Icons.favorite_border_rounded; // Heart
  static const IconData info = Icons.info_outline_rounded; // Info
  static const IconData coupon = Icons.confirmation_number_outlined; // Ticket
  static const IconData bike = Icons.pedal_bike_rounded; // Bike
  static const IconData trolley = Icons.shopping_cart_outlined; // ShoppingCart
  static const IconData filter = Icons.tune_rounded; // SlidersHorizontal
  static const IconData arrowForward =
      Icons.arrow_forward_rounded; // ArrowRight
  static const IconData chevronDown =
      Icons.keyboard_arrow_down_rounded; // ChevronDown
  static const IconData check = Icons.check_rounded; // Check

  // Adaptive (design 11.2): back, share, more.
  static IconData back(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.back : Icons.arrow_back;

  static IconData share(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.share : Icons.share;

  static IconData more(BuildContext context) =>
      isCupertino(context) ? CupertinoIcons.ellipsis : Icons.more_vert;
}
