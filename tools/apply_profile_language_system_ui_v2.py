from pathlib import Path

# Apply the first-pass visual refresh exactly as validated up to analyze.
exec(
    compile(
        Path('tools/apply_profile_language_system_ui.py').read_text(),
        'tools/apply_profile_language_system_ui.py',
        'exec',
    ),
    {'__name__': '__main__'},
)

# dart format wraps this long guard onto two lines; the repo enables
# curly_braces_in_flow_control_structures, so keep the same behavior with
# an explicit block. This is intentionally logic-neutral.
path = Path('app/lib/features/notification/presentation/notification_list_screen.dart')
text = path.read_text()
old = """        if (newMessageConversationId == null || newMessageActorId == null) return;\n"""
new = """        if (newMessageConversationId == null || newMessageActorId == null) {\n          return;\n        }\n"""
if old not in text:
    raise RuntimeError('notification new-message guard anchor missing')
path.write_text(text.replace(old, new, 1))
