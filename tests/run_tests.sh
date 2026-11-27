#!/bin/sh
# run_tests.sh - after tools/build.sh: the level checker, the physics check
# (the game's jumps and slides = the checker's, played in the toolkit's 68000
# harness) and the screenshots (screenshots/, used by the README, print kit, itch).
set -e
cd "$(dirname "$0")/.."
TK=${AMIGA_TK:-/home/claude/amiga-toolkit}
mkdir -p build/t screenshots
python3 tools/levels.py
gcc -O2 -w -I"$TK/tools" -o build/amiga "$TK/tools/amiga.c" "$TK/tools/m68k.c" -lm
python3 tests/physics.py build/amiga build/test.game
./build/amiga build/test.game build/disk tests/shots.txt build/t > build/shots.log 2>&1
grep -q "errors: 0" build/shots.log || { tail build/shots.log; exit 1; }
python3 - <<'PY'
from PIL import Image
import os
for n in ('title', 'level1', 'yoyo', 'dark', 'flip', 'rot', 'bw', 'ropes'):
    Image.open('build/t/' + n).save('screenshots/%s.png' % n)
ims = [Image.open('screenshots/%s.png' % n) for n in ('title', 'level1', 'yoyo', 'ropes', 'dark', 'flip', 'rot', 'bw')]
W = Image.new('RGB', (4 * 328 - 8, 2 * 264 - 8), (40, 40, 40))
for i, im in enumerate(ims):
    W.paste(im, ((i % 4) * 328, (i // 4) * 264))
W.save('screenshots/all_screens.png')
print('screenshots written')
PY
