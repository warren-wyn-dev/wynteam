from pathlib import Path

path = Path('tools/wyn141_founder_ui_patch.py')
text = path.read_text()
old = '''replace_once(\n    root_path,\n    "        clubPostRepository: _clubPostRepository,\\n      ),\\n",\n    "        clubPostRepository: _clubPostRepository,\\n"\n    "        onRootBack: () => _onDestinationSelected(_homeDestinationIndex),\\n"\n    "      ),\\n",\n)'''
new = '''replace_once(\n    root_path,\n    "        userId: userId,\\n        clubRepository: _clubRepository,\\n        clubPostRepository: _clubPostRepository,\\n      ),\\n",\n    "        userId: userId,\\n        clubRepository: _clubRepository,\\n        clubPostRepository: _clubPostRepository,\\n"\n    "        onRootBack: () => _onDestinationSelected(_homeDestinationIndex),\\n"\n    "      ),\\n",\n)'''
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one patcher block, got {count}')
path.write_text(text.replace(old, new, 1))
print('fixed patcher root target')
