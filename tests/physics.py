#!/usr/bin/env python3
"""physics.py - checks that the game's physics (src/game.i) are the same as the
level checker's (tools/levels.py): jumps and slides from many places on real
levels, played in the 68000 harness, must land on the same pixel (or die).
  python3 tests/physics.py build/amiga build/test.game"""
import sys, os, subprocess, random
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'tools'))
import levels as LV
amiga, game = sys.argv[1], sys.argv[2]
rnd = random.Random(7)
cases = []
for li in (0, 2, 4, 7):
    L = LV.LEVELS[li]
    # standing places
    st = [(x, r * 16 - 24) for r in range(1, 12) for x in range(0, LV.XMAX + 1, 2) if L.supported(x, r * 16 - 24)]
    for _ in range(10):
        x, y = rnd.choice(st)
        d = rnd.choice((-1, 0, 1))
        e = L.fall(x, y, d * 2, LV.JUMP, set())
        cases.append((li, x, y, 'jump', d, e))
    # ledges: the last place before the edge
    edges = [(x, y, d) for (x, y) in st for d in (-1, 1)
             if 0 <= x + 2 * d <= LV.XMAX and not L.supported(x + 2 * d, y)]
    for _ in range(6):
        x, y, d = rnd.choice(edges)
        e = L.fall(x + 2 * d, y, d * 2, None, set())
        cases.append((li, x, y, 'slide', d, e))
lines = ['run 330']
for i, (li, x, y, kind, d, e) in enumerate(cases):
    lines += ['poke devmode w -1', 'poke devlevel w %d' % li, 'poke devloop w 0', 'fire 3', 'run 170',
              'poke nenemies w 0', 'poke mstimer w 30000', 'poke px w %d' % x, 'poke py w %d' % y, 'poke pst w 0', 'run 2']
    # start the jump / slide directly (as the game does on the frame of the press)
    if kind == 'jump':
        lines += ['poke jdx w %d' % (2 * d), 'poke jt w 0', 'poke ftop w %d' % y, 'poke pst w 2']
    else:
        lines += ['poke px w %d' % (x + 2 * d), 'poke jdx w %d' % (2 * d), 'poke ftop w %d' % y, 'poke pst w 3']
    keys = []
    lines += ['run %d' % (100 - 4 * (len(keys) * 2 - 1)), 'echo case %d' % i, 'peek px', 'peek py', 'peek pst', 'key ESC', 'run 120']
open('build/physics.txt', 'w').write('\n'.join(lines) + '\n')
out = subprocess.run([amiga, game, 'build/disk', 'build/physics.txt', 'build/t'], capture_output=True, text=True).stdout
res = {}
cur = None
for ln in out.splitlines():
    if ln.startswith('case'):
        cur = int(ln.split()[1]); res[cur] = {}
    elif ' = ' in ln and cur is not None:
        k, v = ln.split(' = ')
        res[cur][k.strip()] = int(v)
bad = 0
for i, (li, x, y, kind, d, e) in enumerate(cases):
    r = res.get(i, {})
    got = 'dead' if r.get('pst') == 4 or r.get('py', 0) > 200 else (r.get('px'), r.get('py'))
    want = 'dead' if e is None else e
    ok = got == want
    bad += not ok
    if not ok:
        print('level %d %s dir %d from (%d,%d): game %s, checker %s' % (li + 1, kind, d, x, y, got, want))
print('%d of %d cases the same' % (len(cases) - bad, len(cases)))
sys.exit(1 if bad else 0)
