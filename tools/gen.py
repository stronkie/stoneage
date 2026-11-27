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
# 10 magenta, 11 bamboo, 12 red, 13 grey, 14 light bamboo, 15 light yellow
# 11 and 14: the bamboo frames
HUDPAL = [0x000, 0xfff, 0xfe3, 0x5ef, 0x113, 0xfe2, 0x3cf, 0xe90,
          0x18b, 0xfac, 0xe3e, 0x592, 0xf33, 0x999, 0xad5, 0xffa]
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
# the playfield is a dual playfield:
#   front (playfield 1, colours 0-7): the level - 0 see-through, 1 black, 2 dark bark,
#     3 bark, 4 dark leaf, 5 light leaf, 6 gold (keys, bulbs, the yo-yo string), 7 red (gems)
#   back (playfield 2, colours 8-15): the jungle - 8 see-through (the sky gradient,
#     colour 0, per line), 9-15 the trees, leaves and vines, darker further away
FRONT = [0x000, 0x000, 0x521, 0x942, 0x261, 0x5b3, 0xfc2, 0xe22]
# per level: the sky gradient (top, middle, bottom) and the jungle colours 9-15
JUNGLES = [
    # name           sky gradient                  jungle base colours (dark .. light)
    ((0x9dc, 0x5b9, 0x264), [0x132, 0x153, 0x274, 0x386, 0x342, 0x564, 0x6a5]),   # morning
    ((0xbea, 0x7c7, 0x353), [0x231, 0x253, 0x374, 0x495, 0x432, 0x654, 0x8b6]),   # bright day
    ((0xcd9, 0x8a8, 0x354), [0x232, 0x243, 0x364, 0x575, 0x443, 0x665, 0x996]),   # misty
    ((0xfb6, 0xc75, 0x433), [0x221, 0x332, 0x453, 0x564, 0x432, 0x643, 0x985]),   # sunset
    ((0x7cb, 0x3a8, 0x143), [0x022, 0x143, 0x264, 0x385, 0x232, 0x354, 0x5a6]),   # deep green
    ((0xec7, 0xa94, 0x542), [0x231, 0x342, 0x463, 0x584, 0x543, 0x754, 0xa95]),   # hot
    ((0x67a, 0x356, 0x123), [0x112, 0x123, 0x234, 0x345, 0x223, 0x334, 0x566]),   # night
    ((0xf74, 0xa32, 0x311), [0x200, 0x311, 0x422, 0x533, 0x421, 0x632, 0x954]),   # volcano
]
S('NSKIES\tequ\t%d' % len(JUNGLES))
def lerp12(a, b, t):
    ca, cb = split(a), split(b)
    return c12(*[int(round(x + (y - x) * t)) for x, y in zip(ca, cb)])
def grad(stops, n):
    out = []
    for i in range(n):
        t = i / max(1, n - 1)
        for k in range(len(stops) - 1):
            if stops[k][0] <= t <= stops[k + 1][0]:
                u = (t - stops[k][0]) / max(1e-9, stops[k + 1][0] - stops[k][0])
                out.append(lerp12(stops[k][1], stops[k + 1][1], u))
                break
    return out
def grad3(t, m, b, n):
    return grad([(0, t), (.5, m), (1, b)], n)
def lvpal(k, fn, fr=None):
    sky, jung = JUNGLES[k]
    p = [fn(sky[1])] + [(fr or fn)(c) for c in FRONT[1:]] + [0x000] + [fn(c) for c in jung]
    return p
DARKF = lambda c: dim(c, .25)
for name, fn, fr in (('skypal', lambda c: c, None), ('darkpal', DARKF, lambda c: dim(c, .35)), ('greypal', grey, None)):
    S(name)
    for k in range(len(JUNGLES)):
        bytes_(lvpal(k, fn, fr), 16, 'w')
# the sky gradient: 192 lines per level (normal, dark, grey)
for name, fn in (('skygrad', lambda c: c), ('darkgrad', DARKF), ('greygrad', grey)):
    S(name)
    for sky, jung in JUNGLES:
        bytes_([fn(c) for c in grad3(*sky, 192)], 16, 'w')

# ------------------------------------------------------------------ tiles (16 x 16, colours 0-7, 3 planes)
def tile(rows):
    """16 strings of 16 -> per line: plane 0, 1, 2 words (96 bytes). K = black (1)"""
    assert len(rows) == 16, rows
    data = []
    for row in rows:
        assert len(row) == 16, row
        w = [0, 0, 0]
        for x, ch in enumerate(row):
            c = 0 if ch == '.' else (1 if ch == 'K' else int(ch))
            for p in range(3):
                if c >> p & 1:
                    w[p] |= 0x8000 >> x
        data += w
    return data
def rot(rows):
    """turn 90 degrees clockwise: screen (sx, sy) = picture (x = sy, y = n-1-sx)"""
    n = len(rows)
    return [''.join(rows[n - 1 - sx][sy] for sx in range(n)) for sy in range(n)]

# a tree trunk lying across: bark with dark grain, moss and leaves hanging below
TRUNK = [
    "KKKKKKKKKKKKKKKK",
    "3335333333353333",
    "3333233333333223",
    "2333333322333333",
    "3322333333333332",
    "3333333233333333",
    "2333223333332233",
    "3333333333333333",
    "2233333332223333",
    "2222222222222222",
    "KKKKKKKKKKKKKKKK",
    ".K45K...K5K..K4K",
    "..K4K....K...K5K",
    "...K..........K.",
    "................",
    "................",
]
LEND = [  # the cut end, on the left
    "...KKKKKKKKKKKKK",
    "..K3363333353333",
    ".K36632333333223",
    "K36336633322333K".replace('K', '3', 1) if False else "K363363333333333",
    "K363K63322333332",
    "K363K63333333333",
    "K366363333332233",
    ".K36632333333333",
    "..K3363332223333",
    "...K222222222222",
    "....KKKKKKKKKKKK",
    "......K5K..K4K..",
    ".......K....K5K.",
    "............K...",
    "................",
    "................",
]
REND = [r[::-1] for r in LEND]
def single():
    return [LEND[y][:8] + REND[y][8:] for y in range(16)]
# a vine to climb: a twisted green stem with leaves
VINE = [
    "......K45K......",
    ".....K454K......",
    "..KK.K545K......",
    ".K55KK454K......",
    "K5544K545K......",
    ".KK44K454K......",
    "...KKK545KKK....",
    "......K454K5K...",
    "......K545K55K..",
    "......K454K455K.",
    "......K545KK44K.",
    "......K454K.KK..",
    ".....KK545K.....",
    ".....K5454K.....",
    "......K545K.....",
    "......K454K.....",
]
ROPE = [
    ".......K3K......",
    "......K33K......",
    "......K3K3K.....",
    ".....K3K33K.....",
    "......K33K......",
    "......K3K3K.....",
    ".....K3K33K.....",
    "......K33K......",
    ".....KK33KK.....",
    "....K333333K....",
    ".....KK33KK.....",
    "......K33K......",
    "......K3K3K.....",
    ".....K3K33K.....",
    "......K33K......",
    "......K3K3K.....",
]
CHAIN = [
    "......KKKK......",
    ".....K6336K.....",
    ".....K6KK3K.....",
    ".....K6KK3K.....",
    ".....K6663K.....",
    "......KKKK......",
    ".......K6K......",
    ".......K3K......",
] * 2
LADDERS = [VINE, ROPE, CHAIN]
def trunk_with(lad):
    """a trunk the vine / rope / chain hangs from: wrapped round it, then down"""
    rows = [list(r) for r in TRUNK[:11]]
    for y in range(1, 10):
        for x in range(6, 10):
            ch = lad[y][x]
            if ch != '.':
                rows[y][x] = ch
    return [''.join(r) for r in rows] + lad[11:]
KEY = [
    "................",
    "................",
    "....KKKK........",
    "...K6666K.......",
    "..K66KK66K......",
    "..K6K..K6KKKKKK.",
    "..K6K..K6666666K",
    "..K66KK66KK6KK6K",
    "...K6666K.K6KK6K",
    "....KKKK...K..K.",
] + ['.' * 16] * 6
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
] + ['.' * 16] * 5
BULB = [
    "......KKKK......",
    ".....K6666K.....",
    "....K667766K....",
    "....K676676K....",
    "....K676676K....",
    "....K667766K....",
    ".....K6666K.....",
    "......K66K......",
    "......K22K......",
    "......K22K......",
    ".......KK.......",
] + ['.' * 16] * 5
EMPTYT = ['.' * 16] * 16
# tile numbers: 0 empty, 1-4 trunk (single, left end, middle, right end),
# 5-7 vine, rope, chain, 8-10 trunk with vine / rope / chain, 11 key, 12 gem, 13 bulb
tiles = [EMPTYT, single(), LEND, TRUNK, REND]
for L in LADDERS:
    tiles.append(L)
for L in LADDERS:
    tiles.append(trunk_with(L))
tiles += [KEY, GEM, BULB]
S('NTILES\tequ\t%d' % len(tiles))
S('tilesN')
for t in tiles:
    bytes_(tile(t), 12, 'w')
S('tilesR')
for t in tiles:
    bytes_(tile(rot(t)), 12, 'w')

# ------------------------------------------------------------------ the jungle background (playfield 2)
# 320 x 192, repeats every 320 pixels; colours 1-7 (= 9-15), 0 = the sky
from PIL import ImageDraw
BW, BH = 320, 192
jr = random.Random(11)
bgim = Image.new('P', (BW * 3, BH), 0)
d = ImageDraw.Draw(bgim)
def wrap(fn, x, *a):
    for o in (0, BW, 2 * BW):
        fn(x + o, *a)
def trunk_v(x, w, top, col, edge):
    d.rectangle([x, top, x + w, BH], fill=col)
    d.line([x + w, top, x + w, BH], fill=edge)
    for y in range(top + 6, BH, 11):
        d.line([x + 2, y, x + w - 3, y + 2], fill=edge)
def blob(x, y, rx, ry, col):
    d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=col)
# far trees (dark), then nearer trees
for k in range(7):
    x = jr.randrange(BW); w = jr.randrange(6, 12)
    wrap(trunk_v, x, w, 20, 1, 2)
for k in range(5):
    x = jr.randrange(BW); w = jr.randrange(12, 22)
    wrap(trunk_v, x, w, 30, 5, 6)
# the canopy: layers of leaves at the top
for col, n, ymax, r in ((1, 40, 26, 16), (2, 46, 30, 13), (3, 40, 22, 10), (4, 26, 14, 7)):
    for k in range(n):
        x = jr.randrange(BW); y = jr.randrange(-6, ymax)
        rx = jr.randrange(r // 2, r); ry = jr.randrange(r // 3, r // 2 + 2)
        wrap(blob, x, y, rx, ry, col)
# hanging vines with little leaves
for k in range(16):
    x = jr.randrange(BW); ln = jr.randrange(40, 130); col = jr.choice((2, 3))
    def vine(xx, ln=ln, col=col):
        y = 14
        while y < 14 + ln:
            xx2 = xx + int(2 * math.sin(y / 9.0))
            d.point([xx2, y], fill=col)
            d.point([xx2, y + 1], fill=col)
            if y % 12 == 0:
                d.ellipse([xx2 - 3, y, xx2, y + 2], fill=7 if col == 3 else 3)
            y += 2
    wrap(lambda xx: vine(xx), x)
# big leaves and ferns at the bottom
for col, n, ytop, r in ((1, 30, 150, 18), (2, 34, 160, 14), (3, 30, 170, 10), (7, 14, 178, 5)):
    for k in range(n):
        x = jr.randrange(BW); y = jr.randrange(ytop, BH + 4)
        rx = jr.randrange(r // 2, r); ry = jr.randrange(r // 3, r // 2 + 2)
        wrap(blob, x, y, rx, ry, col)
bgtile = bgim.crop((BW, 0, 2 * BW, BH))      # the middle copy: seamless
def bgplanes(get, w, h):
    """interleaved 3 planes: per line plane 0, 1, 2 (w/8 bytes each)"""
    rb = w // 8
    out = bytearray(rb * 3 * h)
    for y in range(h):
        for x in range(w):
            c = get(x, y)
            if not c:
                continue
            for p in range(3):
                if c >> p & 1:
                    out[(y * 3 + p) * rb + (x >> 3)] |= 0x80 >> (x & 7)
    return out
# normal: 672 x 192, bitmap x 16.. = picture x 0.. (repeating)
bgN = bgplanes(lambda x, y: bgtile.getpixel(((x - 16) % BW, y)), 672, BH)
# turned 90 degrees: 320 wide (the jungle at x 64-255) x 640 lines (two periods)
bgR = bgplanes(lambda x, y: bgtile.getpixel((y % BW, 64 + 191 - x)) if 64 <= x < 256 else 0, 320, 640)
open(os.path.join(ROOT, 'src', 'bg_n.bin'), 'wb').write(bgN)
open(os.path.join(ROOT, 'src', 'bg_r.bin'), 'wb').write(bgR)
# a preview of the jungle with the first palette
pv = bgtile.convert('RGB')
pal0 = lvpal(0, lambda c: c)
g0 = grad3(*JUNGLES[0][0], 192)
pv = Image.new('RGB', (BW, BH))
for y in range(BH):
    for x in range(BW):
        c = bgtile.getpixel((x, y))
        v = g0[y] if c == 0 else pal0[8 + c]
        pv.putpixel((x, y), (((v >> 8) & 15) * 17, ((v >> 4) & 15) * 17, (v & 15) * 17))
pv.resize((BW * 2, BH * 2), Image.NEAREST).save(os.path.join(ROOT, 'art', 'jungle_preview.png'))
pv.save(os.path.join(ROOT, 'art', 'jungle_tile.png'))
# the loading picture (for src/loader.s) and the title picture
import pics
loadpal, titlepal = pics.make(os.path.join(ROOT, 'src'))
with open(os.path.join(ROOT, 'src', 'loadpal.i'), 'w') as f:
    f.write('; made by tools/gen.py\nloadpal\tdc.w\t' + ','.join('$%03x' % c for c in loadpal) + '\n')
S('titlepal\tdc.w\t' + ','.join('$%03x' % c for c in titlepal))
S('titlepic\tincbin\t"titlepic.bin"')

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
# classical pieces (public domain), played on a soft flute-like wave
# title: J. S. Bach (attr.), Minuet in G
MIN_A = ['D5 - G4 A4 B4 C5', 'D5 - G4 - G4 -', 'E5 - C5 D5 E5 F#5', 'G5 - G4 - G4 -',
         'C5 - D5 C5 B4 A4', 'B4 - C5 B4 A4 G4']
TUNES['title'] = (8, True, 26, 22,
    MIN_A + ['F#4 - G4 A4 B4 G4', 'A4 - - - - -'] + MIN_A + ['A4 - B4 A4 G4 F#4', 'G4 - - - - -'],
    ['G3 - - - A3 -', 'B3 - - - G3 -', 'C4 - - - - -', 'B3 - - - - -', 'A3 - - - - -', 'G3 - - - - -',
     'D4 - - - B3 -', 'D3 - - - - -',
     'G3 - - - A3 -', 'B3 - - - G3 -', 'C4 - - - - -', 'B3 - - - - -', 'A3 - - - - -', 'G3 - - - - -',
     'C4 - D4 - D3 -', 'G3 - D3 - G2 -'])
# the game: E. Grieg, In the Hall of the Mountain King (a caveman's tune)
MK = ['B3 C#4 D4 E4 F#4 D4 F#4 -', 'F4 C#4 F4 - E4 C4 E4 -', 'B3 C#4 D4 E4 F#4 D4 F#4 B4', 'A4 F#4 D4 F#4 A4 - - -']
def transpose(bar, n):
    names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    out = []
    for t in bar.split():
        if t in ('-', '.'):
            out.append(t)
            continue
        k = names.index(t[:-1]) + 12 * int(t[-1]) + n
        out.append(names[k % 12] + str(k // 12))
    return ' '.join(out)
MKB = ['B2 . F#2 . B2 . F#2 .', 'C#3 . G#2 . C3 . G2 .', 'B2 . F#2 . B2 . F#2 .', 'D3 . A2 . D3 . F#2 .']
TUNES['game'] = (6, True, 18, 18, MK + MK + [transpose(b, 7) for b in MK] + MK,
                 MKB + MKB + [transpose(b, 7) for b in MKB] + MKB)
TUNES['clear'] = (6, False, 32, 26, ['G4 B4 D5 G5 - - D5 G5 - - - - . . . .'], ['G2 - - - D3 - - - G3 - - - . . . .'])
TUNES['over'] = (9, False, 30, 26, ['B4 - A4 - G4 - F#4 - E4 - - - - - . .'], ['E3 - D3 - C3 - B2 - E2 - - - - - . .'])
# all levels done: L. van Beethoven, Ode to Joy
TUNES['win'] = (7, False, 32, 26, ['E5 E5 F5 G5 G5 F5 E5 D5 C5 C5 D5 E5 E5 - D5 D5 - - . .'],
                ['C3 - G2 - C3 - G2 - A2 - E2 - G2 - G2 - - - . .'])
S('tunetab')
for n in ('title', 'game', 'clear', 'over', 'win'):
    S('\tdc.l\ttune_%s' % n)
for n, (step, loop, v0, v1, mel, bass) in TUNES.items():
    S('tune_%s\tdc.w\t%d,%d' % (n, v0, v1))
    S('\tdc.l\ttune_%s_0,tune_%s_1' % (n, n))
    for vi, (bars, wl) in enumerate(((mel, 32), (bass, 32))):
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
# the jungle: birds, a monkey, crickets (played now and then, quietly)
def sweep(dur, f0, f1, vol=90):
    n = int(dur * RATE)
    e = env(n, a=0.005, d=0.8)
    out, ph = [], 0.0
    for i in range(n):
        t = i / n
        ph += (f0 + (f1 - f0) * t) / RATE
        out.append(int(vol * e[i] * math.sin(2 * math.pi * ph)))
    return out
def gap(dur):
    return [0] * int(dur * RATE)
SFX['bird'] = sweep(.05, 2500, 3800) + gap(.03) + sweep(.05, 2600, 3900) + gap(.03) + sweep(.07, 2400, 3600)
SFX['bird2'] = sweep(.16, 1600, 2600) + sweep(.18, 2600, 1800)
def monkey():
    out = []
    for k, (f0, f1, dur, ah) in enumerate(((330, 420, .14, 0), (340, 440, .14, 0), (480, 600, .17, 1), (470, 590, .2, 1))):
        n = int(dur * RATE)
        e = env(n, a=0.01, d=0.6)
        ph, prev = 0.0, 0.0
        for i in range(n):
            f = f0 + (f1 - f0) * math.sin(math.pi * i / n)
            ph += f / RATE
            v = (ph % 1) * 2 - 1                    # a buzzy voice...
            v = v * .6 + (rng.uniform(-1, 1) * .5 if ah and i < n * .15 else 0)
            prev = prev * .55 + v * .45            # ...made softer
            out.append(int(110 * e[i] * prev))
        out += gap(.05)
    return out
SFX['monkey'] = monkey()
def cricket():
    out = []
    for k in range(3):
        n = int(.07 * RATE)
        for i in range(n):
            t = i / RATE
            out.append(int(55 * (1 if math.sin(2 * math.pi * 4400 * t) > 0 else -1) * (.5 + .5 * math.sin(2 * math.pi * 45 * t))))
        out += gap(.06)
    return out
SFX['cricket'] = cricket()
order = ['jump', 'throw', 'hit', 'key', 'gem', 'bulb', 'death', 'tick', 'life', 'dark', 'land', 'pop',
         'bird', 'bird2', 'monkey', 'cricket']
for i, n in enumerate(order):
    S('SFX_%s\tequ\t%d' % (n.upper(), i))
S('sfxtab')
for n in order:
    S('\tdc.l\tsfx_%s' % n)
    S('\tdc.w\t%d' % ((len(SFX[n]) + 1) // 2))
S('\tsection\tchipdata,data_c')
S('bgN\tincbin\t"bg_n.bin"')
S('bgR\tincbin\t"bg_r.bin"')
S('silence\tdc.w\t0,0')
S('wave_sq')
bytes_([int(70 * math.sin(2 * math.pi * i / 32) + 16 * math.sin(4 * math.pi * i / 32)) & 255 for i in range(32)])
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
