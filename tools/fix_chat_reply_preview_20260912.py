from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    assert count == 1, f"{path}: expected exactly one match, found {count}"
    p.write_text(text.replace(old, new, 1))


# 1) Model: make the UI decision explicit and testable.
replace_once(
    "app/lib/features/chat/data/chat_message.dart",
    "  bool get isDeleted => deletedAt != null;\n\n",
    "  bool get isDeleted => deletedAt != null;\n\n"
    "  /// True only when a reply has something meaningful to quote. Raw\n"
    "  /// postgres_changes payloads carry reply_to_message_id but no embedded\n"
    "  /// reply row, so this must stay false until the preview is hydrated.\n"
    "  bool get hasReplyPreview =>\n"
    "      replyPreviewDeletedAt != null ||\n"
    "      replyPreviewText?.isNotEmpty == true ||\n"
    "      replyPreviewImageUrl != null;\n\n",
)

# 2) Repository: if PostgREST's self-embed is missing/empty, hydrate the
# replied-to row directly. This covers initial history, optimistic sends,
# and realtime inserts without relying on the flaky self-join shape.
replace_once(
    "app/lib/features/chat/data/chat_repository.dart",
    "    final rows = await query.order('created_at', ascending: false).limit(messagePageSize);\n"
    "    return rows.map((row) => ChatMessage.fromMap(row)).toList();\n",
    "    final rows = await query.order('created_at', ascending: false).limit(messagePageSize);\n"
    "    final hydratedRows = await Future.wait(\n"
    "      rows.map((row) => _hydrateReplyPreviewRow(Map<String, dynamic>.from(row))),\n"
    "    );\n"
    "    return hydratedRows.map(ChatMessage.fromMap).toList();\n",
)

replace_once(
    "app/lib/features/chat/data/chat_repository.dart",
    "        .select(_messageColumns)\n"
    "        .single();\n"
    "    return ChatMessage.fromMap(row);\n"
    "  }\n\n"
    "  /// The recipient's one explicit \"I'm opening this now\" for a View\n",
    "        .select(_messageColumns)\n"
    "        .single();\n"
    "    final hydratedRow =\n"
    "        await _hydrateReplyPreviewRow(Map<String, dynamic>.from(row));\n"
    "    return ChatMessage.fromMap(hydratedRow);\n"
    "  }\n\n"
    "  /// The recipient's one explicit \"I'm opening this now\" for a View\n",
)

replace_once(
    "app/lib/features/chat/data/chat_repository.dart",
    "  Future<ChatMessage?> fetchMessage(String messageId) async {\n"
    "    final row = await _client\n"
    "        .from('messages')\n"
    "        .select(_messageColumns)\n"
    "        .eq('id', messageId)\n"
    "        .maybeSingle();\n"
    "    return row == null ? null : ChatMessage.fromMap(row);\n"
    "  }\n",
    "  Future<Map<String, dynamic>> _hydrateReplyPreviewRow(\n"
    "    Map<String, dynamic> row,\n"
    "  ) async {\n"
    "    final replyId = row['reply_to_message_id'] as String?;\n"
    "    if (replyId == null) return row;\n\n"
    "    final rawReply = row['reply_to'];\n"
    "    Map<String, dynamic>? embedded;\n"
    "    if (rawReply is Map<String, dynamic>) {\n"
    "      embedded = rawReply;\n"
    "    } else if (rawReply is List &&\n"
    "        rawReply.isNotEmpty &&\n"
    "        rawReply.first is Map<String, dynamic>) {\n"
    "      embedded = rawReply.first as Map<String, dynamic>;\n"
    "    }\n"
    "    final embeddedHasPreview = embedded != null &&\n"
    "        (embedded['deleted_at'] != null ||\n"
    "            (embedded['text'] as String?)?.isNotEmpty == true ||\n"
    "            embedded['image_url'] != null);\n"
    "    if (embeddedHasPreview) return row;\n\n"
    "    final reply = await _client\n"
    "        .from('messages')\n"
    "        .select('text, image_url, deleted_at')\n"
    "        .eq('id', replyId)\n"
    "        .maybeSingle();\n"
    "    if (reply == null) return row;\n"
    "    return <String, dynamic>{...row, 'reply_to': reply};\n"
    "  }\n\n"
    "  Future<ChatMessage?> fetchMessage(String messageId) async {\n"
    "    final row = await _client\n"
    "        .from('messages')\n"
    "        .select(_messageColumns)\n"
    "        .eq('id', messageId)\n"
    "        .maybeSingle();\n"
    "    if (row == null) return null;\n"
    "    final hydratedRow =\n"
    "        await _hydrateReplyPreviewRow(Map<String, dynamic>.from(row));\n"
    "    return ChatMessage.fromMap(hydratedRow);\n"
    "  }\n",
)

replace_once(
    "app/lib/features/chat/data/chat_repository.dart",
    "    final full = await fetchMessage(rawRow['id'] as String);\n"
    "    onInsert(full ?? ChatMessage.fromMap(rawRow));\n",
    "    final hydratedRow = await _hydrateReplyPreviewRow(\n"
    "      Map<String, dynamic>.from(rawRow),\n"
    "    );\n"
    "    onInsert(ChatMessage.fromMap(hydratedRow));\n",
)

# 3) UI safety net: never draw the empty quote shell seen in production.
replace_once(
    "app/lib/features/chat/presentation/conversation_screen.dart",
    "          if (message.replyToMessageId != null && !message.isDeleted)\n",
    "          if (message.replyToMessageId != null &&\n"
    "              !message.isDeleted &&\n"
    "              message.hasReplyPreview)\n",
)

# 4) Regression coverage for the render gate semantics.
replace_once(
    "app/test/chat_model_test.dart",
    "      expect(message.replyPreviewText, 'ข้อความต้นทาง');\n"
    "      expect(message.replyPreviewDeletedAt, isNull);\n",
    "      expect(message.replyPreviewText, 'ข้อความต้นทาง');\n"
    "      expect(message.replyPreviewDeletedAt, isNull);\n"
    "      expect(message.hasReplyPreview, isTrue);\n",
)

replace_once(
    "app/test/chat_model_test.dart",
    "      expect(message.replyPreviewText, isNull);\n"
    "      expect(message.replyPreviewDeletedAt, isNull);\n"
    "    });\n\n"
    "    test('parses shared_content_type/shared_content_id (WYN-033)', () {\n",
    "      expect(message.replyPreviewText, isNull);\n"
    "      expect(message.replyPreviewDeletedAt, isNull);\n"
    "      expect(message.hasReplyPreview, isFalse);\n"
    "    });\n\n"
    "    test('parses shared_content_type/shared_content_id (WYN-033)', () {\n",
)

# Existing scroll-to-original test intentionally exercises a real quote, so
# give its fixture the preview content the production repository now hydrates.
replace_once(
    "app/test/conversation_screen_test.dart",
    "        message(id: 'reply', text: 'ตอบกลับ', replyToMessageId: 'target'),\n",
    "        message(\n"
    "          id: 'reply',\n"
    "          text: 'ตอบกลับ',\n"
    "          replyToMessageId: 'target',\n"
    "          replyPreviewText: 'ข้อความต้นฉบับที่อยู่ไกลมาก',\n"
    "        ),\n",
)

# Directly guard the production symptom: a raw realtime-style reply with no
# preview must not draw the empty quote rectangle/left bar.
replace_once(
    "app/test/conversation_screen_test.dart",
    "    expect(find.text('ข้อความต้นฉบับที่อยู่ไกลมาก'), findsOneWidget);\n"
    "  });\n\n"
    "  testWidgets(\n"
    "      'deleting my own message calls deleteMessage and shows the deleted placeholder',\n",
    "    expect(find.text('ข้อความต้นฉบับที่อยู่ไกลมาก'), findsOneWidget);\n"
    "  });\n\n"
    "  testWidgets('reply with no hydrated preview does not render an empty quote shell',\n"
    "      (tester) async {\n"
    "    chatRepo.messagesByConversation = {\n"
    "      'c1': [\n"
    "        message(\n"
    "          id: 'reply-without-preview',\n"
    "          text: 'ตอบกลับ',\n"
    "          replyToMessageId: 'target',\n"
    "        ),\n"
    "      ],\n"
    "    };\n"
    "    await tester.pumpWidget(buildScreen());\n"
    "    await tester.pumpAndSettle();\n\n"
    "    expect(find.text('ตอบกลับ'), findsOneWidget);\n"
    "    expect(\n"
    "      find.byKey(const Key('reply_quote_reply-without-preview')),\n"
    "      findsNothing,\n"
    "    );\n"
    "  });\n\n"
    "  testWidgets(\n"
    "      'deleting my own message calls deleteMessage and shows the deleted placeholder',\n",
)

print("chat reply preview patch applied")
