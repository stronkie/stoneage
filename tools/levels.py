#!/usr/bin/env python3
"""levels.py - the levels of Stronkie's StoneAge and a copy of the player
physics of src/main.s, used to check every level:
  - every key can be reached from the start (walking, ladders/ropes/chains,
    jumps, slides) without a deadly drop,
  - from every place Stronkie can reach he can get back (no traps),
  - gems and bulbs are reachable too.
Run it to print a report:  python3 tools/levels.py
Created By Mark Stronks, Stronkie Soft 2026"""
import sys
from collections import deque

W, H = 60, 12          # tiles (16 x 16 pixels): a level is 960 x 192 pixels
LW = W * 16
PW, PH = 16, 24        # Stronkie's hitbox
XMAX = LW - PW
DEADLY = 100           # a drop of more pixels kills
WALK = 2               # pixels per frame
CLIMB = 1
# jump: dy per frame (the rest of the fall: 4 per frame)
JUMP = [-4, -4, -3, -3, -3, -3, -2, -2, -2, -2, -2, -1, -1, -1, -1, 0, 0,
        0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3]
FALLMAX = 4

EMPTY, PLAT, PLAD, LAD, KEY, GEM, BULB = 0, 1, 2, 3, 4, 5, 6
CH = {'.': EMPTY, '=': PLAT, '#': PLAD, 'H': LAD, 'K': KEY, '*': GEM, 'B': BULB}
# enemies
SCRUB, HOOT, POG = 0, 1, 2

class Level:
    def __init__(self, name, style, time, rows, sky):
        self.name, self.style, self.time, self.sky = name, style, time, sky
        assert len(rows) == H, (name, len(rows))
        self.m = [[EMPTY] * W for _ in range(H)]
        self.enemies = []          # (type, x, y, minx, maxx)
        self.start = None
        for r, row in enumerate(rows):
            if len(row) > W and set(row[W:]) == {'.'}:
                row = row[:W]
            assert len(row) <= W, (name, r, len(row))
            row = row.ljust(W, '.')
            for c, ch in enumerate(row):
                if ch in CH:
                    self.m[r][c] = CH[ch]
                elif ch == 'S':
                    self.start = (c, r)
                elif ch in 'cpo':
                    self.enemies.append((ch, c, r))
                else:
                    raise ValueError('%s: bad char %r' % (name, ch))
        assert self.start, name
        c, r = self.start
        fr = r + 1
        while fr < H - 1 and not self.solid(fr, c):
            fr += 1
        self.start = (c * 16, fr * 16 - PH)
        ens = []
        self.problems = []
        for ch, c, r in self.enemies:
            if ch in 'cp' and not any(self.solid(k, c) for k in range(r + 1, H)):
                self.problems.append('enemy %s at col %d row %d has no floor' % (ch, c, r))
                continue
            if ch in 'cp':
                fr = r + 1                       # stands on the first floor below
                while fr < H and not self.solid(fr, c):
                    fr += 1
                assert self.solid(fr, c), (name, ch, c, r)
                a = c
                while a > 0 and self.solid(fr, a - 1):
                    a -= 1
                b = c
                while b < W - 1 and self.solid(fr, b + 1):
                    b += 1
                if ch == 'c':     # 32 x 32, feet on the floor
                    ens.append((SCRUB, c * 16 - 8, fr * 16 - 32, a * 16 - 8, b * 16 - 8))
                else:             # poglet: 32 x 32 box, hops
                    ens.append((POG, c * 16 - 8, fr * 16 - 32, a * 16 - 8, b * 16 - 8))
            else:                 # hooter flies at this row, 9 tiles each way
                a, b = max(0, c - 9), min(W - 2, c + 9)
                ens.append((HOOT, c * 16 - 8, r * 16 - 8, a * 16 - 8, b * 16 - 8))
        self.enemies = ens

    def solid(self, r, c):
        return 0 <= r < H and 0 <= c < W and self.m[r][c] in (PLAT, PLAD)

    def lad(self, r, c):
        return 0 <= r < H and 0 <= c < W and self.m[r][c] in (LAD, PLAD)

    def items(self, kind):
        return [(r, c) for r in range(H) for c in range(W) if self.m[r][c] == kind]

    # ---------------------------------------------------------- physics (as main.s)
    def supported(self, x, y):
        f = y + PH
        if f & 15 or f >= H * 16 + 16:
            return False
        r = f >> 4
        return self.solid(r, (x + 4) >> 4) or self.solid(r, (x + 11) >> 4)

    def touched(self, x, y, out):
        """items the hitbox touches (the item's middle 8 x 8)"""
        for r in range(max(0, y >> 4), min(H, ((y + PH - 1) >> 4) + 1)):
            for c in range(max(0, x >> 4), min(W, ((x + PW - 1) >> 4) + 1)):
                if self.m[r][c] in (KEY, GEM, BULB):
                    ix, iy = c * 16 + 4, r * 16 + 4
                    if x < ix + 8 and x + PW > ix and y < iy + 8 and y + PH > iy:
                        out.add((r, c))

    def fall(self, x, y, dx, table, out):
        """jump (table = JUMP) or slide (table = None): -> (x, y) landed or None (dead)"""
        top = y
        i = 0
        while True:
            if table is None:
                dy = 2
            else:
                dy = table[i] if i < len(table) else FALLMAX
                i += 1
            x = max(0, min(XMAX, x + dx))
            if dy < 0:
                y += dy
                top = min(top, y)
            else:
                for _ in range(dy):
                    y += 1
                    if self.supported(x, y):
                        self.touched(x, y, out)
                        return (x, y) if y - top <= DEADLY else None
            self.touched(x, y, out)
            if y + PH > H * 16 + 8:
                return None

    def moves(self, s):
        """standing / ladder state -> [(state, items touched)]"""
        kind, x, y = s
        res = []
        if kind == 'S':
            for d in (-1, 1):
                nx = max(0, min(XMAX, x + d * WALK))
                out = set()
                self.touched(nx, y, out)
                if self.supported(nx, y):
                    res.append((('S', nx, y), out))
                else:
                    e = self.fall(nx, y, d * 2, None, out)
                    if e:
                        res.append((('S',) + e, out))
            for d in (-1, 0, 1):
                out = set()
                e = self.fall(x, y, d * 2, JUMP, out)
                if e:
                    res.append((('S',) + e, out))
            # ladders (snap when within 6 pixels of the ladder)
            c = (x + 8) >> 4
            if abs(x - c * 16) <= 6:
                f = y + PH
                if self.lad((f - 1) >> 4, c):
                    res.append((('L', c * 16, y - CLIMB), set()))
                if self.lad(f >> 4, c) and self.m[f >> 4][c] == PLAD:
                    res.append((('L', c * 16, y + CLIMB), set()))
        else:
            f = y + PH
            c = x >> 4
            if self.lad((f - 1) >> 4, c):
                res.append((('L', x, y - CLIMB), set()))
            if self.lad(f >> 4, c):
                res.append((('L', x, y + CLIMB), set()))
            if self.supported(x, y):
                res.append((('S', x, y), set()))
        return res

    def check(self):
        s0 = ('S',) + self.start
        if not self.supported(*self.start):
            return ['start not on a floor'], 0
        seen = {s0: set()}
        q = deque([s0])
        edges = {}
        got = set()
        while q:
            s = q.popleft()
            ms = self.moves(s)
            edges[s] = [m[0] for m in ms]
            for t, out in ms:
                got |= out
                if t not in seen:
                    seen[t] = 1
                    q.append(t)
        # back to the start from everywhere?
        rev = {}
        for s, ts in edges.items():
            for t in ts:
                rev.setdefault(t, []).append(s)
        back = {s0}
        q = deque([s0])
        while q:
            s = q.popleft()
            for p in rev.get(s, []):
                if p not in back:
                    back.add(p)
                    q.append(p)
        traps = [s for s in seen if s not in back]
        problems = list(self.problems)
        for kind, nm in ((KEY, 'key'), (GEM, 'gem'), (BULB, 'bulb')):
            for it in self.items(kind):
                if it not in got:
                    problems.append('%s at row %d col %d not reachable' % (nm, it[0], it[1]))
        if traps:
            xs = sorted(set((s[1] // 16, (s[2] + PH) // 16) for s in traps))
            problems.append('%d trap states, e.g. %s' % (len(traps), xs[:6]))
        return problems, len(seen)

    def ascii(self):
        t = '.=#HK*B'
        rows = [''.join(t[v] for v in row) for row in self.m]
        rows = [list(r) for r in rows]
        sx, sy = self.start
        rows[(sy + PH) // 16 - 1][sx // 16] = 'S'
        for e in self.enemies:
            k, x, y = e[0], e[1], e[2]
            rows[min(H - 1, (y + 16) // 16)][(x + 8) // 16] = 'cop'[k] if k != HOOT else 'o'
        return '\n'.join(''.join(r) for r in rows)

# ------------------------------------------------------------------ the levels
class B:
    """level builder: floors on rows 3, 7 and 11, stepping stones on 5 and 9"""
    def __init__(self):
        self.g = [['.'] * W for _ in range(H)]
    def plat(self, r, a, b):
        for c in range(a, b + 1):
            self.g[r][c] = '#' if self.g[r][c] == '#' else '='
        return self
    def lad(self, c, top, bot):
        self.g[top][c] = '#'
        for r in range(top + 1, bot):
            self.g[r][c] = 'H'
        return self
    def put(self, r, c, s):
        for k, ch in enumerate(s):
            self.g[r][c + k] = ch
        return self
    def rows(self):
        return [''.join(r) for r in self.g]

def L1():   # JUNGLE EDGE: easy, few gaps
    b = B()
    b.plat(11, 0, 22).plat(11, 27, 59)
    b.plat(7, 0, 10).plat(7, 13, 23).plat(7, 26, 39).plat(7, 43, 59)
    b.plat(3, 2, 11).plat(3, 16, 25).plat(3, 30, 39).plat(3, 44, 57)
    b.lad(5, 3, 7).lad(18, 7, 11).lad(33, 3, 7).lad(48, 3, 7).lad(55, 7, 11)
    b.put(10, 1, 'S').put(9, 8, '*').put(9, 30, 'K').put(10, 37, 'p').put(9, 57, 'K')
    b.put(5, 16, '*').put(5, 28, 'K').put(5, 40, 'B').put(5, 54, '*').put(6, 20, 'c')
    b.put(1, 3, 'K').put(1, 28, '*').put(1, 55, 'K').put(1, 44, 'o')
    return b.rows()

def L2():   # MONKEY TREES: stairs of stepping stones
    b = B()
    b.plat(11, 0, 16).plat(11, 21, 26).plat(11, 33, 59)
    b.plat(9, 18, 19).plat(9, 29, 30)
    b.plat(7, 0, 6).plat(7, 11, 13).plat(7, 36, 47).plat(7, 52, 59)
    b.plat(5, 8, 9).plat(5, 15, 17).plat(5, 22, 24).plat(5, 49, 50)
    b.plat(3, 1, 8).plat(3, 19, 33).plat(3, 43, 52).plat(3, 55, 59)
    b.lad(3, 3, 11).lad(30, 3, 7).lad(47, 3, 7).lad(56, 7, 11)
    b.put(10, 1, 'S').put(9, 9, '*').put(10, 14, 'c').put(9, 23, 'K').put(10, 39, 'p').put(9, 44, 'K').put(9, 52, '*')
    b.put(6, 41, 'c').put(5, 26, '*').put(5, 57, 'B')
    b.put(1, 4, 'K').put(1, 15, '*').put(1, 37, 'K').put(1, 52, '*').put(1, 58, 'K').put(0, 25, 'o')
    return b.rows()

def L3():   # SNAKE RIVER GAP: pits to jump
    b = B()
    b.plat(11, 0, 7).plat(11, 11, 32).plat(11, 35, 38).plat(11, 41, 46).plat(11, 49, 59)
    b.plat(7, 2, 9).plat(7, 14, 25).plat(7, 30, 44).plat(7, 48, 55)
    b.plat(3, 0, 9).plat(3, 12, 14).plat(3, 16, 18).plat(3, 21, 31).plat(3, 37, 43).plat(3, 48, 59)
    b.lad(5, 3, 7).lad(19, 7, 11).lad(34, 7, 11).lad(40, 3, 7).lad(51, 3, 7).lad(52, 7, 11)
    b.put(10, 1, 'S').put(10, 15, 'p').put(9, 25, '*').put(9, 57, 'K').put(10, 44, 'c')
    b.put(5, 12, '*').put(6, 27, 'c').put(5, 35, 'K').put(5, 46, '*')
    b.put(1, 1, 'K').put(1, 11, 'B').put(1, 20, 'K').put(1, 30, '*').put(1, 58, 'K').put(0, 46, 'o')
    return b.rows()

def L4():   # ROPE BRIDGE
    b = B()
    b.plat(11, 0, 8).plat(11, 13, 21).plat(11, 26, 32).plat(11, 38, 43).plat(11, 48, 59)
    b.plat(7, 0, 8).plat(7, 13, 23).plat(7, 29, 39).plat(7, 43, 57)
    b.plat(3, 2, 10).plat(3, 15, 24).plat(3, 29, 36).plat(3, 40, 47).plat(3, 51, 59)
    b.lad(5, 3, 7).lad(19, 3, 7).lad(18, 7, 11).lad(33, 3, 7).lad(30, 7, 11).lad(44, 3, 7).lad(49, 7, 11).lad(55, 3, 7)
    b.put(10, 1, 'S').put(9, 7, 'K').put(10, 15, 'c').put(9, 41, '*').put(9, 57, 'K')
    b.put(6, 11 - 9 + 9, '.').put(6, 15, 'p').put(5, 26, '*').put(5, 37, 'K').put(6, 48, 'c')
    b.put(1, 3, 'K').put(1, 14, '*').put(1, 25, 'K').put(1, 43, 'B').put(1, 54, '*').put(1, 58, 'K')
    b.put(0, 9, 'o').put(0, 51, 'o')
    return b.rows()

def L5():   # HANGING ROPES
    b = B()
    b.plat(11, 0, 4).plat(11, 9, 18).plat(11, 26, 32).plat(11, 38, 44).plat(11, 49, 59)
    b.plat(9, 5, 6).plat(9, 21, 23).plat(9, 34, 35).plat(9, 46, 47)
    b.plat(7, 1, 13).plat(7, 19, 26).plat(7, 30, 41).plat(7, 44, 49).plat(7, 54, 58)
    b.plat(5, 15, 16)
    b.plat(3, 1, 4).plat(3, 9, 15).plat(3, 20, 24).plat(3, 30, 38).plat(3, 43, 46).plat(3, 51, 58)
    b.lad(2, 3, 7).lad(11, 3, 7).lad(12, 7, 11).lad(22, 3, 7).lad(24, 7, 11).lad(35, 3, 7).lad(36, 7, 11)
    b.lad(45, 3, 7).lad(46, 7, 9).lad(57, 3, 7).lad(56, 7, 11)
    b.put(10, 1, 'S').put(9, 3, 'K').put(9, 17, '*').put(10, 28, 'c').put(9, 40, 'K').put(9, 51, '*')
    b.put(6, 6, 'c').put(5, 25, '*').put(5, 40, 'B').put(6, 47, 'p')
    b.put(1, 2, '*').put(1, 10, 'K').put(1, 32, 'K').put(1, 47, '*').put(1, 57, 'K').put(0, 27, 'o')
    return b.rows()

def L6():   # DINO NEST
    b = B()
    b.plat(11, 0, 5).plat(11, 10, 18).plat(11, 23, 31).plat(11, 37, 46).plat(11, 51, 59)
    b.plat(7, 2, 9).plat(7, 13, 21).plat(7, 27, 37).plat(7, 41, 49).plat(7, 52, 58)
    b.plat(3, 0, 8).plat(3, 14, 20).plat(3, 25, 36).plat(3, 40, 49).plat(3, 54, 59)
    b.lad(4, 3, 7).lad(4, 7, 11).lad(16, 3, 7).lad(16, 7, 11).lad(32, 3, 7).lad(32, 7, 11)
    b.lad(45, 3, 7).lad(45, 7, 11).lad(53, 7, 11).lad(57, 3, 7)
    b.put(10, 1, 'S').put(9, 9, '*').put(10, 25, 'c').put(9, 28, 'K').put(9, 49, '*').put(9, 58, 'K')
    b.put(6, 7, 'c').put(5, 23, '.').put(5, 20, 'B').put(6, 35, 'p').put(5, 51, 'K')
    b.put(1, 1, 'K').put(1, 7, '*').put(1, 25, 'K').put(1, 48, '*').put(1, 56, 'K')
    b.put(0, 14, 'o').put(0, 39, 'o')
    return b.rows()

def L7():   # TEMPLE CHAINS
    b = B()
    b.plat(11, 0, 9).plat(11, 13, 22).plat(11, 26, 35).plat(11, 39, 47).plat(11, 51, 59)
    b.plat(7, 0, 9).plat(7, 14, 22).plat(7, 25, 34).plat(7, 38, 48).plat(7, 51, 59)
    b.plat(3, 2, 9).plat(3, 13, 21).plat(3, 25, 33).plat(3, 38, 46).plat(3, 50, 58)
    b.lad(4, 3, 7).lad(5, 7, 11).lad(17, 3, 7).lad(18, 7, 11).lad(28, 3, 7).lad(31, 7, 11)
    b.lad(41, 3, 7).lad(44, 7, 11).lad(54, 3, 7).lad(56, 7, 11)
    b.put(10, 1, 'S').put(9, 10, '*').put(9, 23, 'K').put(10, 37 - 3, 'c').put(9, 50 - 1, '*').put(9, 58, 'K')
    b.put(6, 10 - 2, 'p').put(5, 23, '*').put(6, 31, 'c').put(5, 46, 'K')
    b.put(1, 2, 'K').put(1, 13, '*').put(1, 22, 'K').put(1, 36, 'B').put(1, 50, '*').put(1, 57, 'K')
    b.put(0, 10, 'o').put(0, 44, 'o')
    return b.rows()

def L8():   # VOLCANO: the hardest
    b = B()
    b.plat(11, 0, 8).plat(11, 12, 20).plat(11, 24, 32).plat(11, 36, 44).plat(11, 48, 59)
    b.plat(7, 2, 8).plat(7, 12, 20).plat(7, 24, 32).plat(7, 36, 44).plat(7, 48, 56).plat(7, 58, 59)
    b.plat(3, 1, 7).plat(3, 12, 19).plat(3, 24, 30).plat(3, 36, 42).plat(3, 48, 56)
    b.lad(4, 3, 7).lad(4, 7, 11).lad(15, 3, 7).lad(15, 7, 11).lad(26, 3, 7).lad(26, 7, 11)
    b.lad(39, 3, 7).lad(39, 7, 11).lad(51, 3, 7).lad(51, 7, 11)
    b.put(10, 1, 'S').put(9, 8, '*').put(10, 19, 'p').put(9, 32, 'K').put(10, 42, 'c').put(9, 56, 'K')
    b.put(6, 7, 'c').put(5, 20, 'K').put(6, 30, 'p').put(6, 41, 'c').put(5, 57, '*')
    b.put(1, 1, 'K').put(1, 11, '*').put(1, 22, 'K').put(1, 34, 'B').put(1, 44, '*').put(1, 55, 'K')
    b.put(0, 15, 'o').put(0, 35, 'o').put(0, 55, 'o')
    return b.rows()

# name, style (0 vines, 1 ropes, 2 chains), seconds, map, sky colour set
LEVELS = [
    Level('JUNGLE EDGE', 0, 120, L1(), 0),
    Level('MONKEY TREES', 0, 120, L2(), 1),
    Level('SNAKE RIVER GAP', 0, 110, L3(), 2),
    Level('ROPE BRIDGE', 1, 110, L4(), 3),
    Level('HANGING ROPES', 1, 105, L5(), 4),
    Level('DINO NEST', 1, 100, L6(), 5),
    Level('TEMPLE CHAINS', 2, 100, L7(), 6),
    Level('VOLCANO JUNGLE', 2, 95, L8(), 7),
]

def build_all(verbose=False):
    for L in LEVELS:
        pass
    return LEVELS

if __name__ == '__main__':
    bad = 0
    for i, L in enumerate(LEVELS):
        p, n = L.check()
        print('LEVEL %d %-20s %d states, %d keys, %d gems, %d bulbs, %d enemies%s' % (
            i + 1, L.name, n, len(L.items(KEY)), len(L.items(GEM)), len(L.items(BULB)), len(L.enemies),
            '' if not p else ''))
        for x in p:
            print('   !! ' + x)
        bad += len(p)
    sys.exit(1 if bad else 0)
