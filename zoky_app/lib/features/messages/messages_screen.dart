import 'package:flutter/material.dart';

import '../../core/adaptive/zoky_icons.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_bottom_nav.dart';
import '../../core/widgets/zoky_page_header.dart';
import '../../core/widgets/zoky_state_view.dart';

/// ข้อความ tab: placeholder only, exactly like the web (parity L01). Whether
/// the app shows this tab at all is still open (ZOKY-100 Q8).
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.only(bottom: ZokyBottomNav.reservedHeight(context)),
        children: const [
          ZokyPageHeader(title: ZokyStrings.navMessages),
          ZokyStateView.empty(
            icon: ZokyIcons.messages,
            title: ZokyStrings.noMessagesTitle,
            messages: [
              ZokyStrings.noMessagesBody1,
              ZokyStrings.noMessagesBody2,
            ],
          ),
        ],
      ),
    );
  }
}
