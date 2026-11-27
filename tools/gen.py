#!/usr/bin/env python3
"""gen.py - makes src/data_gen.i for Stronkie's StoneAge: levels, tiles
(normal and turned 90 degrees), sprites (normal and turned), font, logo,
palettes, music and sound effects.
Created By Mark Stronks, Stronkie Soft 2026"""
import os, sys, math, random
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import levels as LV
import art as A

TK = os.environ.get('AMIGA_TK', '/home/claude/amiga-toolkit')
out = []
def S(s=''):
    out.append(s)
def bytes_(data, per=16, kind='b'):
    if kind == 'b':
        for i in range(0, len(data), per):
            S('\tdc.b\t' + ','.join('$%02x' % (b & 255) for b in data[i:i + per]))
    else:
        for i in range(0, len(data), per):
            S('\tdc.w\t' + ','.join('$%04x' % (w & 0xffff) for w in data[i:i + per]))

def c12(r, g, b):
    return (r << 8) | (g << 4) | b
def split(c):
    return (c >> 8) & 15, (c >> 4) & 15, c & 15
def dim(c, f):
    r, g, b = split(c)
    return c12(int(r * f + .5), int(g * f + .5), int(b * f + .5))
def grey(c):
    r, g, b = split(c)
    v = int((r * 30 + g * 59 + b * 11) / 100 + .5)
    return c12(v, v, v)

# ------------------------------------------------------------------ palettes
# screen (score panel, title): 0 black, 1 white, 2 yellow, 3 cyan, 4-9 the logo,
# 10 magenta, 11 green, 12 red, 13 grey, 14 orange, 15 light yellow
HUDPAL = [0x000, 0xfff, 0xfe3, 0x5ef, 0x113, 0xfe2, 0x3cf, 0xe90,
          0x18b, 0xfac, 0xe3e, 0x4d4, 0xf33, 0x999, 0xf90, 0xffa]
S('hudpal\tdc.w\t' + ','.join('$%03x' % c for c in HUDPAL))
# sprites 16-31: 17-19 Stronkie, 21-23 yo-yo / balloons / daggers, 25-27 and 29-31 monsters
SPRPAL = [0x000, 0xfb8, 0xd71, 0x000,
          0x000, 0xe22, 0xfff, 0x000,
          0x000, 0xd2d, 0xfe2, 0x000,
          0x000, 0xd2d, 0xfe2, 0x000]
S('sprpal\tdc.w\t' + ','.join('$%03x' % c for c in SPRPAL))
# in the dark the monsters are hard to see; in the black and white loop everything is grey
S('sprpaldark\tdc.w\t' + ','.join('$%03x' % (dim(c, .45) if i >= 8 else c) for i, c in enumerate(SPRPAL)))
S('sprpalgrey\tdc.w\t' + ','.join('$%03x' % grey(c) for c in SPRPAL))
# the playfield: 0 sky, 1 platform top, 2 yellow (roots, bone ladders, keys), 3 black,
# 4 brown (ropes), 5 grey (chains, bulb base), 6 white, 7 gem; 8-15 the yo-yo string
SKIES = [  # sky, platform top, roots, gem
    (0x0dd, 0xd1d, 0xfe2, 0xf22),   # cyan, like the original
    (0x2b2, 0xd1d, 0xfe2, 0x22f),   # green
    (0xf95, 0xa2b, 0xfd4, 0x0c0),   # dusk
    (0x6ae, 0xd3a, 0xec3, 0xf22),   # pale blue
    (0x2a6, 0xe3c, 0xfe5, 0xf80),   # jungle
    (0xec8, 0xb2b, 0xd92, 0x22f),   # sand
    (0x448, 0xc4e, 0xdd4, 0x0ef),   # iron night
    (0xa20, 0xf4f, 0xfe0, 0x0ef),   # volcano
]
STRING = 0xfff
S('NSKIES\tequ\t%d' % len(SKIES))
for name, fn in (('skypal', lambda c: c), ('darkpal', lambda c: dim(c, .22)), ('greypal', grey)):
    S(name)
    for sky, top, roots, gem in SKIES:
        p = [sky, top, roots, 0x000, 0x962, 0xaab, 0xfff, gem] + [STRING] * 8
        if name == 'darkpal':
            p = [dim(c, .2) for c in p[:8]] + [dim(STRING, .35)] * 8
        else:
            p = [fn(c) for c in p]
        bytes_(p, 16, 'w')

# ------------------------------------------------------------------ tiles (16 x 16, colours 0-7, 3 planes)
def tile(rows):
    """16 strings of 16 -> per line: plane 0, 1, 2 words (96 bytes)"""
    assert len(rows) == 16, rows
    data = []
    for row in rows:
        assert len(row) == 16, row
        w = [0, 0, 0]
        for x, ch in enumerate(row):
            c = 0 if ch == '.' else (3 if ch == 'K' else int(ch))
            for p in range(3):
                if c >> p & 1:
                    w[p] |= 0x8000 >> x
        data += w
    return data
def rot(rows):
    """turn 90 degrees clockwise: screen (sx, sy) = picture (x = sy, y = n-1-sx)"""
    n = len(rows)
    return [''.join(rows[n - 1 - sx][sy] for sx in range(n)) for sy in range(n)]

TOPMID = [
    "KKKKKKKKKKKKKKKK",
    "1111111111111111",
    "11K11111111K1111",
    "1111111K11111111",
    "1111111111111111",
    "KKKKKKKKKKKKKKKK",
]
ROOTS = [
    "K222222KK222222K",
    "K222222KK222222K",
    ".K2222K..K2222K.",
    ".K2222K..K2222K.",
    "..K22K....K22K..",
    "...KK......KK...",
    "................",
    "................",
    "................",
    "................",
]
def ends(rows, left, right):
    rows = [list(r) for r in rows]
    if left:
        rows[0][0] = rows[0][1] = '.'
        rows[1][0] = 'K'
        rows[5][0] = '.'
        for y in (2, 3, 4):
            rows[y][0] = 'K'
    if right:
        rows[0][15] = rows[0][14] = '.'
        rows[1][15] = 'K'
        rows[5][15] = '.'
        for y in (2, 3, 4):
            rows[y][15] = 'K'
    return [''.join(r) for r in rows]
BONE = [  # a bone ladder
    "...K2K....K2K...",
    "...K2KKKKKK2K...",
    "..K2222222222K..",
    "...K2KKKKKK2K...",
] * 4
ROPE = [
    ".......K4K......",
    "......K44K......",
    "......K4K4K.....",
    ".....K4K44K.....",
    "......K44K......",
    "......K4K4K.....",
    ".....K4K44K.....",
    "......K44K......",
    ".....KK44KK.....",
    "....K444444K....",
    ".....KK44KK.....",
    "......K44K......",
    "......K4K4K.....",
    ".....K4K44K.....",
    "......K44K......",
    "......K4K4K.....",
]
CHAIN = [
    "......KKKK......",
    ".....K5665K.....",
    ".....K5KK5K.....",
    ".....K5KK5K.....",
    ".....K5555K.....",
    "......KKKK......",
    ".......K5K......",
    ".......K5K......",
] * 2
LADDERS = [BONE, ROPE, CHAIN]
KEY = [
    "................",
    "................",
    "....KKKK........",
    "...K2222K.......",
    "..K22KK22K......",
    "..K2K..K2KKKKKK.",
    "..K2K..K2222222K",
    "..K22KK22KK2KK2K",
    "...K2222K.K2KK2K",
    "....KKKK...K..K.",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]
GEM = [
    "................",
    "................",
    ".....KKKKKK.....",
    "....K766677K....",
    "...K77677777K...",
    "..KKKKKKKKKKKK..",
    "...K77777777K...",
    "....K777777K....",
    ".....K7777K.....",
    "......K77K......",
    ".......KK.......",
    "................",
    "................",
    "................",
    "................",
    "................",
]
BULB = [
    "......KKKK......",
    ".....K6666K.....",
    "....K662266K....",
    "....K626626K....",
    "....K626626K....",
    "....K662266K....",
    ".....K6666K.....",
    "......K66K......",
    "......K55K......",
    "......K55K......",
    ".......KK.......",
    "................",
    "................",
    "................",
    "................",
    "................",
]
EMPTYT = ['.' * 16] * 16
# tile numbers: 0 empty, 1-4 platform (single, left end, middle, right end),
# 5-7 ladder (bone, rope, chain), 8-10 platform with ladder (bone, rope, chain),
# 11 key, 12 gem, 13 bulb
tiles = [EMPTYT]
for l, r in ((1, 1), (1, 0), (0, 0), (0, 1)):
    tiles.append(ends(TOPMID, l, r) + ROOTS)
for L in LADDERS:
    tiles.append(L)
for L in LADDERS:
    tiles.append(TOPMID + L[6:])
tiles += [KEY, GEM, BULB]
S('NTILES\tequ\t%d' % len(tiles))
S('tilesN')
for t in tiles:
    bytes_(tile(t), 12, 'w')
S('tilesR')
for t in tiles:
    bytes_(tile(rot(t)), 12, 'w')

# ------------------------------------------------------------------ sprites
def pix(rows, w, h, align='bottom', dx=None):
    """text art -> w x h colour grid, centred horizontally"""
    g = [[0] * w for _ in range(h)]
    rw = max(len(r) for r in rows)
    ox = (w - rw) // 2 if dx is None else dx
    oy = h - len(rows) if align == 'bottom' else (h - len(rows)) // 2 if align == 'middle' else 0
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == '.':
                continue
            c = 3 if ch == 'K' else (1 if ch in 'SMR1' else 2)
            g[oy + y][ox + x] = c
    return g
def mirror(g):
    return [r[::-1] for r in g]
def rotg(g):
    n = len(g)
    return [[g[n - 1 - sx][sy] for sx in range(n)] for sy in range(n)]
def chan(g, x0):
    """16 columns from x0 -> per line plane A word, plane B word"""
    d = []
    for row in g:
        a = b = 0
        for x in range(16):
            c = row[x0 + x]
            if c & 1:
                a |= 0x8000 >> x
            if c & 2:
                b |= 0x8000 >> x
        d += [a, b]
    return d
big = []
for name, rows in A.BIG:
    g = pix(rows, 32, 32, 'middle' if name.startswith('poof') else 'bottom')
    big.append((name, g))
    big.append((name + 'L', mirror(g)))
for k, (name, g) in enumerate(big):
    S('IMG_%s\tequ\t%d' % (name.upper(), k))
for lab, f in (('bigN', lambda g: g), ('bigR', rotg)):
    S(lab)
    for name, g in big:
        g2 = f(g)
        bytes_(chan(g2, 0) + chan(g2, 16), 16, 'w')
small = []
for name, rows in A.SMALL:
    small.append((name, pix(rows, 16, 16, 'top')))
for k, (name, g) in enumerate(small):
    S('SM_%s\tequ\t%d' % (name.upper(), k))
for lab, f in (('smallN', lambda g: g), ('smallR', rotg)):
    S(lab)
    for name, g in small:
        bytes_(chan(f(g), 0), 16, 'w')
# a preview of all pictures
pal = [(0, 0xc0, 0xc0), (255, 187, 136), (221, 119, 17), (0, 0, 0)]
prev = Image.new('RGB', (34 * len(big) // 2 + 2, 70), (0, 160, 160))
for k, (name, g) in enumerate(big[::2]):
    for y in range(32):
        for x in range(32):
            if g[y][x]:
                prev.putpixel((2 + k * 34 + x, 2 + y), pal[g[y][x]])
    gr = rotg(g)
    for y in range(32):
        for x in range(32):
            if gr[y][x]:
                prev.putpixel((2 + k * 34 + x, 36 + y), pal[g[y][x] if False else gr[y][x]])
prev.resize((prev.size[0] * 3, prev.size[1] * 3), Image.NEAREST).save(os.path.join(ROOT, 'art', 'sprites_preview.png'))

# ------------------------------------------------------------------ font, logo
font = open(os.path.join(ROOT, 'art', 'font8x8.bin'), 'rb').read()
S('font')
bytes_(font)
S('dbltab')
dbl = []
for i in range(256):
    v = 0
    for b in range(8):
        if i >> b & 1:
            v |= 3 << (b * 2)
    dbl.append(v)
bytes_(dbl, 16, 'w')
im = Image.open(os.path.join(TK, 'art', 'stronkiesoft_logo.png')).convert('RGBA')
LH = im.size[1]
cmap = {(10, 10, 30): 4, (255, 226, 30): 5, (40, 200, 240): 6, (225, 150, 0): 7,
        (20, 130, 190): 8, (255, 160, 200): 9, (255, 255, 255): 1}
logo = bytearray(4 * LH * 20)
for y in range(LH):
    for x in range(im.size[0]):
        r, g, b, a = im.getpixel((x, y))
        if a < 128:
            continue
        c = cmap.get((r, g, b))
        if c is None:
            c = min(cmap.items(), key=lambda kv: sum((p - q) ** 2 for p, q in zip(kv[0], (r, g, b))))[1]
        xx = x + 1
        for p in range(4):
            if c >> p & 1:
                logo[p * LH * 20 + y * 20 + (xx >> 3)] |= 0x80 >> (xx & 7)
S('LOGOH\tequ\t%d' % LH)
S('logo')
bytes_(logo)

# ------------------------------------------------------------------ levels
levels = LV.build_all()
S('NLEVELS\tequ\t%d' % len(levels))
S('LVW\tequ\t%d' % LV.W)
S('LVH\tequ\t%d' % LV.H)
S('levtab')
for i in range(len(levels)):
    S('\tdc.l\tlev%d' % i)
def gfxmap(L):
    g = []
    for r in range(LV.H):
        for c in range(LV.W):
            t = L.m[r][c]
            if t == LV.PLAT or t == LV.PLAD:
                if t == LV.PLAD:
                    g.append(8 + L.style)
                    continue
                le = not L.solid(r, c - 1)
                ri = not L.solid(r, c + 1)
                g.append(1 if (le and ri) else 2 if le else 4 if ri else 3)
            elif t == LV.LAD:
                g.append(5 + L.style)
            elif t == LV.KEY:
                g.append(11)
            elif t == LV.GEM:
                g.append(12)
            elif t == LV.BULB:
                g.append(13)
            else:
                g.append(0)
    return g
for i, L in enumerate(levels):
    S('lev%d' % i)
    S('\tdc.w\t%d,%d,%d,%d,%d,%d' % (L.start[0], L.start[1], L.time, L.sky, len(L.items(LV.KEY)), L.style))
    S('\tdc.w\t%d' % len(L.enemies))
    for e in L.enemies:
        S('\tdc.w\t%d,%d,%d,%d,%d' % e)
    S("\tdc.b\t'%s',0" % L.name)
    S('\teven')
    data = []
    for r in range(LV.H):
        data += L.m[r]
    bytes_(data, 30)
    bytes_(gfxmap(L), 30)
with open(os.path.join(ROOT, 'levels.txt'), 'w') as f:
    for i, L in enumerate(levels):
        f.write('LEVEL %d  %s  (%d s, %d keys, %d enemies)\n%s\n\n' % (i + 1, L.name, L.time, len(L.items(LV.KEY)), len(L.enemies), L.ascii()))

# ------------------------------------------------------------------ music (the player of Stronkie's Robot)
CLOCK = 3546895
NOTES = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
def freq(n):
    name, octv = n[:-1], int(n[-1])
    semi = NOTES[name] + 12 * (octv + 1) - 69
    return 440.0 * 2 ** (semi / 12)
def voice(bars, step, wavelen):
    toks = ' '.join(bars).split()
    ev = []
    for t in toks:
        if t == '-':
            ev[-1][1] += step
        elif t == '.':
            if ev and ev[-1][0] == 0:
                ev[-1][1] += step
            else:
                ev.append([0, step])
        else:
            ev.append([int(round(CLOCK / (freq(t) * wavelen))), step])
    w = []
    for p, d in ev:
        w += [p, d]
    return w
TUNES = {}
# a bouncy "caveman stomp" in D minor
TUNES['title'] = (6, True, 32, 30, [
 'D5 - F5 - A5 - D6 - C6 - A5 - G5 - F5 -',
 'E5 - G5 - A5 - - - . . A4 - D5 - - -',
 'D5 - F5 - A5 - D6 - E6 - D6 - C6 - A5 -',
 'G5 - - - E5 - C5 - D5 - - - . . . .',
 'F5 - F5 - G5 - A5 - A#5 - A5 - G5 - F5 -',
 'E5 - C5 - E5 - G5 - F5 - E5 - D5 - C5 -',
 'D5 - F5 - A5 - D6 - C6 - A5 - G5 - E5 -',
 'D5 - - - - - - - . . . . . . . .'], [
 'D3 - . D3 A2 - . A2 D3 - . D3 A2 - C3 -',
 'C3 - . C3 G2 - . G2 A2 - . A2 E3 - C#3 -',
 'D3 - . D3 A2 - . A2 D3 - . D3 A2 - F2 -',
 'C3 - . C3 G2 - . G2 D3 - A2 - D2 - . .',
 'A#2 - . A#2 F2 - . F2 A#2 - . A#2 F2 - . F2',
 'C3 - . C3 G2 - . G2 C3 - . C3 A2 - . A2',
 'D3 - . D3 A2 - . A2 G2 - . G2 A2 - A2 -',
 'D3 - A2 - D3 - . . D2 - . . . . . .'])
TUNES['game'] = (5, True, 20, 22, [
 'A4 - . A4 C5 - D5 - E5 - . E5 D5 - C5 -',
 'D5 - - - A4 - - - G4 - A4 - C5 - A4 -',
 'A4 - . A4 C5 - D5 - E5 - G5 - E5 - D5 -',
 'C5 - D5 - C5 - A4 - A4 - - - . . . .',
 'G5 - . G5 E5 - D5 - E5 - . E5 C5 - A4 -',
 'C5 - - - D5 - - - E5 - D5 - C5 - D5 -',
 'A4 - . A4 C5 - D5 - E5 - G5 - E5 - D5 -',
 'C5 - A4 - G4 - E4 - A4 - - - . . . .'], [
 'A2 . A2 . E3 . A2 . A2 . A2 . E3 . A2 .',
 'D2 . D2 . A2 . D2 . E2 . E2 . B2 . E2 .',
 'A2 . A2 . E3 . A2 . A2 . A2 . E3 . A2 .',
 'F2 . F2 . C3 . F2 . A2 . A2 . E3 . A2 .',
 'C3 . C3 . G3 . C3 . A2 . A2 . E3 . A2 .',
 'F2 . F2 . C3 . F2 . G2 . G2 . D3 . G2 .',
 'A2 . A2 . E3 . A2 . F2 . F2 . C3 . F2 .',
 'G2 . G2 . D3 . G2 . A2 . A2 . E3 . A2 .'])
TUNES['clear'] = (5, False, 40, 34, [
 'D5 F5 A5 D6 - - A5 D6 - - - - . . . .'], [
 'D3 - - - A2 - - - D3 - - - . . . .'])
TUNES['over'] = (8, False, 36, 32, [
 'A4 - G4 - F4 - E4 - D4 - - - - - . .'], [
 'D3 - C3 - A#2 - A2 - D2 - - - - - . .'])
TUNES['win'] = (5, False, 40, 34, [
 'D5 F5 A5 D6 A5 D6 F6 - - - E6 - F6 - A6 - - - - - . . . .'], [
 'D3 - A2 - D3 - F3 - - - A2 - D3 - F3 - - - - - . . . .'])
S('tunetab')
for n in ('title', 'game', 'clear', 'over', 'win'):
    S('\tdc.l\ttune_%s' % n)
for n, (step, loop, v0, v1, mel, bass) in TUNES.items():
    S('tune_%s\tdc.w\t%d,%d' % (n, v0, v1))
    S('\tdc.l\ttune_%s_0,tune_%s_1' % (n, n))
    for vi, (bars, wl) in enumerate(((mel, 16), (bass, 32))):
        S('tune_%s_%d' % (n, vi))
        bytes_(voice(bars, step, wl) + [0xffff if loop else 0xfffe, 0], 16, 'w')

# ------------------------------------------------------------------ sound effects (8287 Hz)
RATE = CLOCK / 428
def env(n, a=0.002, d=1.0):
    return [min(1, i / (a * RATE + 1)) * max(0, 1 - i / n) ** d for i in range(n)]
def synth(dur, fn, vol=110, d=1.0):
    n = int(dur * RATE)
    e = env(n, d=d)
    s, ph = [], 0.0
    for i in range(n):
        t = i / RATE
        ph += fn(t) / RATE
        s.append(int(vol * e[i] * (1 if (ph % 1) < .5 else -1)))
    return s
rng = random.Random(3)
def noise(dur, vol=100, d=1.5, hold=1):
    n = int(dur * RATE)
    e = env(n, d=d)
    s, v = [], 0
    for i in range(n):
        if i % hold == 0:
            v = rng.uniform(-1, 1)
        s.append(int(vol * e[i] * v))
    return s
SFX = {}
SFX['jump'] = synth(0.16, lambda t: 260 + t * 2600, 90)
SFX['throw'] = synth(0.12, lambda t: 1400 - t * 6000, 70)
SFX['hit'] = [int(a * .6 + b * .5) for a, b in zip(noise(0.3, 120, 1.2, 3), synth(0.3, lambda t: 800 - 2000 * t, 90) + [0] * 9999)]
SFX['key'] = synth(0.05, lambda t: 1319, 110) + synth(0.05, lambda t: 1760, 110) + synth(0.08, lambda t: 2637, 100)
SFX['gem'] = [a for f in (1047, 1319, 1568, 2093) for a in synth(0.05, lambda t, f=f: f, 100)]
SFX['bulb'] = synth(0.35, lambda t: 400 + t * 3000, 90)
SFX['death'] = synth(0.9, lambda t: 900 * (1 - t) + 100 + 60 * math.sin(t * 60), 110, 0.7)
SFX['tick'] = synth(0.03, lambda t: 2000, 60)
SFX['life'] = [a for f in (587, 698, 880, 1175, 880, 1175) for a in synth(0.06, lambda t, f=f: f, 100)]
SFX['dark'] = synth(0.6, lambda t: 600 - t * 800, 100, 0.8)
SFX['land'] = noise(0.04, 60, 2, 4)
SFX['pop'] = noise(0.08, 110, 1.5, 1)
order = ['jump', 'throw', 'hit', 'key', 'gem', 'bulb', 'death', 'tick', 'life', 'dark', 'land', 'pop']
for i, n in enumerate(order):
    S('SFX_%s\tequ\t%d' % (n.upper(), i))
S('sfxtab')
for n in order:
    S('\tdc.l\tsfx_%s' % n)
    S('\tdc.w\t%d' % ((len(SFX[n]) + 1) // 2))
S('\tsection\tchipdata,data_c')
S('silence\tdc.w\t0,0')
S('wave_sq\tdc.b\t' + ','.join(['60'] * 8 + ['-60'] * 8))
tri = [int(100 * (1 - abs((i / 32) * 4 - 2))) for i in range(32)]
S('wave_tri')
bytes_(tri)
for n in order:
    d = SFX[n]
    if len(d) & 1:
        d = d + [0]
    S('sfx_%s' % n)
    bytes_([max(-127, min(127, v)) for v in d], 32)
S('\teven')
S('\tsection\tcode,code')

with open(os.path.join(ROOT, 'src', 'data_gen.i'), 'w') as f:
    f.write('; made by tools/gen.py - do not edit\n' + '\n'.join(out) + '\n')
print('data_gen.i written')
