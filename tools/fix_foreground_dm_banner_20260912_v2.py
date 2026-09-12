from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"missing anchor: {label}")
    return text.replace(old, new, 1)

tracker = ROOT / "app/lib/features/chat/presentation/active_conversation_tracker.dart"
tracker.write_text(
    """/// Process-wide record of mounted conversation routes.
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
""",
    encoding="utf-8",
)

conversation = ROOT / "app/lib/features/chat/presentation/conversation_screen.dart"
text = conversation.read_text(encoding="utf-8")
text = replace_once(
    text,
    "import '../../presence/data/presence_repository.dart';\n",
    "import '../../presence/data/presence_repository.dart';\n"
    "import 'active_conversation_tracker.dart';\n",
    "conversation tracker import",
)
text = replace_once(
    text,
    "class _ConversationScreenState extends State<ConversationScreen>\n"
    "    with WidgetsBindingObserver {\n"
    "  final _scrollController = ScrollController();\n",
    "class _ConversationScreenState extends State<ConversationScreen>\n"
    "    with WidgetsBindingObserver {\n"
    "  final Object _activeConversationOwner = Object();\n"
    "  final _scrollController = ScrollController();\n",
    "conversation tracker owner",
)
text = replace_once(
    text,
    "  void initState() {\n"
    "    super.initState();\n"
    "    WidgetsBinding.instance.addObserver(this);\n",
    "  void initState() {\n"
    "    super.initState();\n"
    "    ActiveConversationTracker.enter(\n"
    "      _activeConversationOwner,\n"
    "      widget.conversationId,\n"
    "    );\n"
    "    WidgetsBinding.instance.addObserver(this);\n",
    "conversation tracker enter",
)
text = replace_once(
    text,
    "  void dispose() {\n"
    "    WidgetsBinding.instance.removeObserver(this);\n",
    "  void dispose() {\n"
    "    ActiveConversationTracker.leave(_activeConversationOwner);\n"
    "    WidgetsBinding.instance.removeObserver(this);\n",
    "conversation tracker leave",
)
conversation.write_text(text, encoding="utf-8")

controller = ROOT / "app/lib/features/push/presentation/push_reliability_controller.dart"
text = controller.read_text(encoding="utf-8")
text = replace_once(
    text,
    "import '../../../core/text_utils.dart';\n"
    "import '../data/push_token_repository.dart';\n",
    "import '../../../core/text_utils.dart';\n"
    "import '../../chat/data/chat_repository.dart';\n"
    "import '../../chat/presentation/active_conversation_tracker.dart';\n"
    "import '../../chat/presentation/conversation_screen.dart';\n"
    "import '../data/push_token_repository.dart';\n",
    "foreground DM navigation imports",
)
text = replace_once(
    text,
    "  RealtimeChannel? _dmChannel;\n"
    "  String? _dmChannelUserId;\n",
    "  RealtimeChannel? _dmChannel;\n"
    "  String? _dmChannelUserId;\n"
    "  OverlayEntry? _foregroundOverlayEntry;\n"
    "  Timer? _foregroundOverlayTimer;\n",
    "foreground overlay fields",
)

handler_pattern = re.compile(
    r"  Future<void> _handleIncomingRealtimeDm\(\{.*?\n"
    r"  String _dmPreview\(Map<String, dynamic> record\) \{",
    re.S,
)
handler_replacement = """  Future<void> _handleIncomingRealtimeDm({
    required Map<String, dynamic> record,
    required String senderId,
    required String subscribedUserId,
  }) async {
    final client = _client;
    if (client == null) return;

    if (client.auth.currentUser?.id != subscribedUserId ||
        senderId == subscribedUserId) {
      return;
    }

    final conversationId = record['conversation_id'] as String?;
    if (conversationId != null &&
        ActiveConversationTracker.currentConversationId == conversationId) {
      return;
    }

    final preview = _dmPreview(record);
    final sender = await _senderPresentation(senderId);

    if (client.auth.currentUser?.id != subscribedUserId) return;
    if (conversationId != null &&
        ActiveConversationTracker.currentConversationId == conversationId) {
      return;
    }

    _showForegroundMessage(
      data: const {'type': 'new_message'},
      title: sender.name,
      body: preview,
      onTap: conversationId == null || sender.username.isEmpty
          ? null
          : () => _openRealtimeConversation(
                conversationId: conversationId,
                senderId: senderId,
                sender: sender,
              ),
    );
  }

  Future<_DmSenderPresentation> _senderPresentation(String senderId) async {
    final client = _client;
    if (client == null) {
      return const _DmSenderPresentation(name: 'ข้อความใหม่');
    }

    try {
      final profile = await client
          .from('profiles')
          .select('username, display_name, avatar_url')
          .eq('id', senderId)
          .maybeSingle();
      if (profile == null) {
        return const _DmSenderPresentation(name: 'ข้อความใหม่');
      }

      final username = (profile['username'] as String?)?.trim() ?? '';
      final displayName = (profile['display_name'] as String?)?.trim();
      final resolvedName = displayNameOrUsername(
        displayName: displayName,
        username: username,
      ).trim();
      return _DmSenderPresentation(
        name: resolvedName.isEmpty ? 'ข้อความใหม่' : resolvedName,
        username: username,
        displayName: displayName,
        avatarUrl: profile['avatar_url'] as String?,
      );
    } catch (_) {
      return const _DmSenderPresentation(name: 'ข้อความใหม่');
    }
  }

  void _openRealtimeConversation({
    required String conversationId,
    required String senderId,
    required _DmSenderPresentation sender,
  }) {
    final client = _client;
    final navigator = appNavigatorKey.currentState;
    if (client == null || navigator == null || sender.username.isEmpty) return;
    if (ActiveConversationTracker.currentConversationId == conversationId) {
      return;
    }

    _dismissForegroundMessage();
    unawaited(
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            chatRepository: ChatRepository(client),
            conversationId: conversationId,
            otherUserId: senderId,
            otherUsername: sender.username,
            otherDisplayName: sender.displayName,
            otherAvatarUrl: sender.avatarUrl,
          ),
        ),
      ),
    );
  }

  String _dmPreview(Map<String, dynamic> record) {"""
text, count = handler_pattern.subn(handler_replacement, text, count=1)
if count != 1:
    raise SystemExit(f"foreground DM handler replacement count={count}")

banner_pattern = re.compile(
    r"  void _showForegroundMessage\(\{.*?\n"
    r"  /// Test-only pure preview helper\.",
    re.S,
)
banner_replacement = """  void _showForegroundMessage({
    required Map<String, dynamic> data,
    String? title,
    String? body,
    VoidCallback? onTap,
  }) {
    if (data['type'] != 'new_message') return;

    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _dismissForegroundMessage();
    final safeTitle = title?.trim();
    final safeBody = body?.trim();
    final resolvedTitle =
        safeTitle == null || safeTitle.isEmpty ? 'ข้อความใหม่' : safeTitle;
    final resolvedBody = safeBody == null || safeBody.isEmpty
        ? 'ส่งข้อความถึงคุณ'
        : safeBody;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Material(
                key: const Key('foreground_dm_banner'),
                color: colors.surface,
                elevation: 8,
                shadowColor: colors.shadow.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap == null
                      ? null
                      : () {
                          _dismissForegroundMessage();
                          onTap();
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_rounded,
                            size: 20,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                resolvedTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                resolvedBody,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _foregroundOverlayEntry = entry;
    overlay.insert(entry);
    _foregroundOverlayTimer = Timer(
      _foregroundBannerDuration,
      _dismissForegroundMessage,
    );
  }

  void _dismissForegroundMessage() {
    _foregroundOverlayTimer?.cancel();
    _foregroundOverlayTimer = null;
    final entry = _foregroundOverlayEntry;
    _foregroundOverlayEntry = null;
    if (entry?.mounted ?? false) {
      entry!.remove();
    }
  }

  @visibleForTesting
  void debugShowForegroundMessage({
    required Map<String, dynamic> data,
    String? title,
    String? body,
    VoidCallback? onTap,
  }) {
    _showForegroundMessage(
      data: data,
      title: title,
      body: body,
      onTap: onTap,
    );
  }

  @visibleForTesting
  void debugPresentIncomingRealtimeDm({
    required String senderId,
    required String subscribedUserId,
    required String? activeUserId,
    required String senderName,
    String? conversationId,
    String? text,
    String? imageUrl,
    bool viewOnce = false,
    String? sharedContentType,
    VoidCallback? onTap,
  }) {
    if (activeUserId != subscribedUserId || senderId == subscribedUserId) {
      return;
    }
    if (conversationId != null &&
        ActiveConversationTracker.currentConversationId == conversationId) {
      return;
    }

    _showForegroundMessage(
      data: const {'type': 'new_message'},
      title: senderName,
      body: _dmPreview({
        'text': text,
        'image_url': imageUrl,
        'view_once': viewOnce,
        'shared_content_type': sharedContentType,
      }),
      onTap: onTap,
    );
  }

  @visibleForTesting
  void debugDismissForegroundMessage() => _dismissForegroundMessage();

  /// Test-only pure preview helper."""
text, count = banner_pattern.subn(banner_replacement, text, count=1)
if count != 1:
    raise SystemExit(f"foreground banner replacement count={count}")

if "class _DmSenderPresentation" not in text:
    text = text.rstrip() + """

class _DmSenderPresentation {
  const _DmSenderPresentation({
    required this.name,
    this.username = '',
    this.displayName,
    this.avatarUrl,
  });

  final String name;
  final String username;
  final String? displayName;
  final String? avatarUrl;
}
"""
controller.write_text(text + ("" if text.endswith("\n") else "\n"), encoding="utf-8")

test_file = ROOT / "app/test/push_reliability_controller_test.dart"
text = test_file.read_text(encoding="utf-8")
text = replace_once(
    text,
    "import 'package:wyn/core/navigation/app_navigator.dart';\n"
    "import 'package:wyn/features/push/presentation/push_reliability_controller.dart';\n",
    "import 'package:wyn/core/navigation/app_navigator.dart';\n"
    "import 'package:wyn/features/chat/presentation/active_conversation_tracker.dart';\n"
    "import 'package:wyn/features/push/presentation/push_reliability_controller.dart';\n",
    "test tracker import",
)
text = replace_once(
    text,
    "  Future<void> pumpApp(WidgetTester tester) async {\n"
    "    await tester.pumpWidget(\n",
    "  Future<void> pumpApp(WidgetTester tester) async {\n"
    "    PushReliabilityController.instance.debugDismissForegroundMessage();\n"
    "    ActiveConversationTracker.resetForTesting();\n"
    "    await tester.pumpWidget(\n",
    "test reset",
)
text = replace_once(
    text,
    "    expect(find.text('Alice'), findsOneWidget);\n"
    "    expect(find.text('ไปกินข้าวไหม'), findsOneWidget);\n"
    "  });\n\n"
    "  testWidgets('foreground image DM shows image preview',",
    "    expect(find.text('Alice'), findsOneWidget);\n"
    "    expect(find.text('ไปกินข้าวไหม'), findsOneWidget);\n"
    "    expect(find.byKey(const Key('foreground_dm_banner')), findsOneWidget);\n"
    "    expect(find.byType(SnackBar), findsNothing);\n"
    "    expect(\n"
    "      tester.getTopLeft(find.byKey(const Key('foreground_dm_banner'))).dy,\n"
    "      lessThan(80),\n"
    "    );\n"
    "  });\n\n"
    "  testWidgets('foreground image DM shows image preview',",
    "top banner test",
)
insert_anchor = "  testWidgets('foreground non-DM event shows no DM banner', (tester) async {\n"
extra_tests = """  testWidgets('foreground DM banner tap invokes the chat action', (tester) async {
    await pumpApp(tester);
    var tapped = false;
    PushReliabilityController.instance.debugShowForegroundMessage(
      data: const {'type': 'new_message'},
      title: 'Alice',
      body: 'แตะเพื่อเปิดแชท',
      onTap: () => tapped = true,
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('foreground_dm_banner')));
    await tester.pump();

    expect(tapped, isTrue);
    expect(find.byKey(const Key('foreground_dm_banner')), findsNothing);
  });

  testWidgets('DM for the mounted conversation does not echo a banner',
      (tester) async {
    await pumpApp(tester);
    final owner = Object();
    ActiveConversationTracker.enter(owner, 'conversation-1');
    addTearDown(() => ActiveConversationTracker.leave(owner));

    PushReliabilityController.instance.debugPresentIncomingRealtimeDm(
      senderId: 'sender-user',
      subscribedUserId: 'receiver-user',
      activeUserId: 'receiver-user',
      senderName: 'Alice',
      conversationId: 'conversation-1',
      text: 'ไม่ควรเด้งซ้ำ',
    );
    await tester.pump();

    expect(find.text('Alice'), findsNothing);
    expect(find.text('ไม่ควรเด้งซ้ำ'), findsNothing);
  });

"""
if extra_tests not in text:
    if insert_anchor not in text:
        raise SystemExit("missing test insertion anchor")
    text = text.replace(insert_anchor, extra_tests + insert_anchor, 1)
test_file.write_text(text, encoding="utf-8")

print("foreground DM banner patch applied")
