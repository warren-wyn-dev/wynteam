/// Process-wide record of mounted conversation routes.
///
/// A conversation route stays mounted while another route is pushed on top,
/// so this keeps a small stack rather than one bare id. Popping the top chat
/// restores the previous conversation id automatically. The foreground DM
/// notifier uses this to avoid echoing a banner for the chat already open.
class ActiveConversationTracker {
  ActiveConversationTracker._();

  static final List<_ActiveConversationEntry> _entries =
      <_ActiveConversationEntry>[];

  static String? get currentConversationId =>
      _entries.isEmpty ? null : _entries.last.conversationId;

  static void enter(Object owner, String conversationId) {
    leave(owner);
    _entries.add(_ActiveConversationEntry(owner, conversationId));
  }

  static void leave(Object owner) {
    _entries.removeWhere((entry) => identical(entry.owner, owner));
  }

  static void resetForTesting() => _entries.clear();
}

class _ActiveConversationEntry {
  const _ActiveConversationEntry(this.owner, this.conversationId);

  final Object owner;
  final String conversationId;
}
