"""pics.py - the loading picture (320 x 256, 32 colours) and the title picture
(320 x 256, 16 colours) of Stronkie's StoneAge, drawn from the game's own
jungle, sprites and font, plus a big Stronkie throwing his yo-yo.
Called by gen.py (needs art/jungle_tile.png that gen.py writes first).
Created By Mark Stronks, Stronkie Soft 2026"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter
import art as A

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TK = os.environ.get('AMIGA_TK', '/home/claude/amiga-toolkit')
FONT = open(os.path.join(ROOT, 'art', 'font8x8.bin'), 'rb').read()
BLACK = (0, 0, 0)
SKIN = (255, 187, 136)
SKIND = (200, 120, 80)
FUR = (215, 120, 25)
FURD = (140, 70, 15)
BARK = (150, 75, 35)
BARKD = (85, 40, 20)
LEAF = (85, 185, 55)
LEAFD = (35, 105, 25)
GOLD = (255, 200, 40)
MAG = (221, 34, 221)
YEL = (255, 238, 34)
RED = (230, 35, 35)
WHITE = (255, 255, 255)

def text(img, s, x, y, px, cols, outline=2, center=False):
    """the game font, px pixels per dot, a colour per font row, black outline"""
    d = ImageDraw.Draw(img)
    w = len(s) * 8 * px
    if center:
        x = x - w // 2
    for pas in (0, 1):
        for i, ch in enumerate(s):
            o = ord(ch) & 127
            for r in range(8):
                bits = FONT[o * 8 + r]
                for b in range(8):
                    if bits & (0x80 >> b):
                        X = x + (i * 8 + b) * px
                        Y = y + r * px
                        if pas == 0:
                            d.rectangle([X - outline, Y - outline, X + px - 1 + outline, Y + px - 1 + outline], fill=BLACK)
                        else:
                            d.rectangle([X, Y, X + px - 1, Y + px - 1], fill=cols[r % len(cols)])
    return w

def sprite(img, rows, x, y, s, cols):
    d = ImageDraw.Draw(img)
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch == '.':
                continue
            k = 'K' if ch == 'K' else ('1' if ch in 'SMR1' else '2')
            d.rectangle([x + c * s, y + r * s, x + c * s + s - 1, y + r * s + s - 1], fill=cols[k])

def log(img, x0, x1, y, h=16):
    """a fallen tree trunk lying across, top at y"""
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x0, y, x1, y + h], radius=h // 2, fill=BARK, outline=BLACK, width=2)
    rnd = random.Random(x0 * 7 + y)
    for k in range((x1 - x0) // 9):
        xx = x0 + 6 + k * 9 + rnd.randrange(4)
        yy = y + 3 + rnd.randrange(h - 6)
        d.line([xx, yy, xx + 5, yy], fill=BARKD, width=1)
    d.line([x0 + h // 2, y + 2, x1 - h // 2, y + 2], fill=(190, 110, 60))
    # the cut ends with rings
    for ex in (x0 + h // 2 - 2, x1 - h // 2 + 2):
        d.ellipse([ex - h // 2 + 2, y + 1, ex + h // 2 - 2, y + h - 1], fill=(225, 165, 80), outline=BLACK, width=2)
        d.ellipse([ex - h // 4, y + h // 4 + 1, ex + h // 4, y + h - h // 4 - 1], outline=BARKD)
    for k in range((x1 - x0) // 7):   # moss and little leaves hanging below
        xx = x0 + 4 + k * 7 + rnd.randrange(3)
        ln = rnd.randrange(2, 7)
        d.line([xx, y + h, xx, y + h + ln], fill=LEAFD if k % 2 else LEAF, width=2)

def vine(img, x, y0, y1, seed):
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    prev = None
    for y in range(y0, y1, 2):
        xx = x + int(4 * math.sin(y / 14.0 + seed))
        if prev:
            d.line([prev, (xx, y)], fill=LEAFD, width=4)
            d.line([prev, (xx, y)], fill=LEAF, width=2)
        prev = (xx, y)
        if y % 14 == 0:
            side = 1 if (y // 14) % 2 else -1
            d.ellipse([xx + side * 3 - 5, y - 3, xx + side * 3 + 5, y + 3], fill=LEAF, outline=LEAFD)

def caveman(img, fx, fy, s=1.0):
    """big Stronkie throwing his yo-yo to the right; (fx, fy) = between his feet on the ground"""
    d = ImageDraw.Draw(img)
    P = lambda x, y: (fx + x * s, fy + y * s)
    def ell(x0, y0, x1, y1, fill, w=2):
        d.ellipse([*P(x0, y0), *P(x1, y1)], fill=fill, outline=BLACK, width=w)
    def poly(pts, fill, w=2):
        d.polygon([P(*p) for p in pts], fill=fill, outline=BLACK, width=w)
    # back arm
    poly([(-30, -92), (-20, -90), (-24, -52), (-34, -52)], SKIN)
    ell(-38, -60, -22, -44, SKIN)
    # legs and feet
    poly([(-22, -42), (-8, -42), (-9, -8), (-21, -8)], SKIN)
    poly([(4, -42), (18, -42), (20, -8), (8, -8)], SKIN)
    ell(-30, -14, -4, 0, FURD)
    ell(4, -14, 30, 0, FURD)
    # the fur tunic with a ragged hem
    hem = []
    for k in range(9):
        hem.append((26 - k * 7, -38 if k % 2 else -30))
    poly([(-30, -96), (-8, -100), (22, -96), (30, -70), (28, -38)] + hem + [(-34, -40), (-36, -70)], FUR)
    for (x, y, r) in ((-18, -80, 5), (6, -70, 6), (14, -88, 4), (-10, -56, 5), (16, -50, 4)):
        d.ellipse([*P(x - r, y - r), *P(x + r, y + r)], fill=FURD)
    # the throwing arm, stretched out
    poly([(10, -98), (22, -100), (66, -96), (66, -84), (20, -84)], SKIN)
    ell(60, -100, 76, -82, SKIN)
    # head: hair, face, eye, nose, smile
    ell(-34, -160, 20, -110, BLACK)
    for (x, y) in ((-32, -140), (-28, -152), (-18, -158)):
        poly([(x + 4, y + 6), (x - 4, y - 6), (x + 12, y + 2)], BLACK, 1)
    ell(-12, -146, 30, -104, SKIN)
    d.ellipse([*P(-14, -150), *P(18, -136)], fill=BLACK)            # fringe
    ell(8, -136, 22, -122, WHITE, 1)
    d.ellipse([*P(14, -132), *P(21, -124)], fill=BLACK)
    d.line([*P(6, -140), *P(24, -138)], fill=BLACK, width=max(2, int(3 * s)))
    ell(22, -128, 38, -114, SKIN)                                     # nose
    d.arc([*P(6, -118), *P(26, -104)], 10, 160, fill=BLACK, width=2)
    # the string and the yo-yo
    hx, hy = P(74, -92)
    yx, yy = P(150, -78)
    d.line([hx, hy, yx, yy], fill=WHITE, width=1)
    r = 10 * s
    d.ellipse([yx - r, yy - r, yx + r, yy + r], fill=RED, outline=BLACK, width=2)
    d.line([yx - r + 2, yy, yx + r - 2, yy], fill=BLACK, width=2)
    d.ellipse([yx - r * .6, yy - r * .7, yx - r * .1, yy - r * .25], fill=WHITE)
    for k in range(3):                                                # motion lines
        d.line([yx + r + 4, yy - 6 + k * 6, yx + r + 12 + k * 2, yy - 6 + k * 6], fill=WHITE)

def background(w=320, h=256, dark=1.0):
    jt = Image.open(os.path.join(ROOT, 'art', 'jungle_tile.png')).convert('RGB')
    bg = jt.resize((w, h), Image.BICUBIC)
    if dark != 1.0:
        bg = Image.eval(bg, lambda v: int(v * dark))
    return bg

MONC = {'1': MAG, '2': YEL, 'K': BLACK}
PLC = {'1': SKIN, '2': FUR, 'K': BLACK}
BIRDC = {'1': RED, '2': WHITE, 'K': BLACK}

def logo(img, x, y):
    lg = Image.open(os.path.join(TK, 'art', 'stronkiesoft_logo.png')).convert('RGBA')
    img.paste(lg, (x, y), lg)

def amiga12(img):
    """round to the Amiga's 4 bits per colour"""
    return Image.eval(img, lambda v: (v >> 4) * 17)

def loading_picture():
    im = background(dark=.85)
    vine(im, 18, 0, 150, 1)
    vine(im, 302, 0, 120, 2)
    vine(im, 250, 0, 60, 3)
    log(im, -10, 330, 214, 18)
    logo(im, 81, 4)
    text(im, "STRONKIE'S", 160, 50, 3, [(255, 250, 150), (255, 235, 90), (255, 215, 50), (255, 190, 30), (250, 160, 20), (235, 130, 10), (215, 100, 0), (190, 80, 0)], 2, True)
    text(im, 'STONEAGE', 160, 76, 3, [(255, 150, 255), (245, 110, 245), (230, 70, 230), (221, 34, 221), (200, 20, 200), (175, 10, 175), (150, 0, 150), (120, 0, 120)], 2, True)
    sprite(im, A.SCRUB1, 236, 214 - 30 * 2 - 6, 2, MONC)               # the Scrubbly on the log
    sprite(im, [r[::-1] for r in A.HOOT1], 262, 108, 1, MONC)
    sprite(im, A.MONKEY_SWING, 262, 0, 2, MONC)
    sprite(im, A.BIRD1, 20, 118, 2, BIRDC)
    sprite(im, [r[::-1] for r in A.BIRD2], 200, 120, 1, BIRDC)
    caveman(im, 78, 214, 0.64)
    text(im, 'LOADING...', 160, 242, 1, [WHITE, WHITE, (255, 238, 51)], 1, True)
    return im

def title_picture():
    im = background(dark=.75)
    vine(im, 14, 0, 140, 4)
    vine(im, 306, 0, 110, 5)
    log(im, -10, 330, 196, 16)
    logo(im, 81, 2)
    text(im, "STRONKIE'S", 160, 52, 3, [(255, 250, 150), (255, 235, 90), (255, 215, 50), (255, 190, 30), (250, 160, 20), (235, 130, 10), (215, 100, 0), (190, 80, 0)], 2, True)
    text(im, 'STONEAGE', 160, 80, 3, [(255, 150, 255), (245, 110, 245), (230, 70, 230), (221, 34, 221), (200, 20, 200), (175, 10, 175), (150, 0, 150), (120, 0, 120)], 2, True)
    return im

# the title palette: 8 fixed colours (text, logo) + 8 from the jungle
TITLEFIX = [(0, 0, 0), (255, 255, 255), (255, 238, 51), (85, 238, 255), (17, 17, 51), (221, 34, 221), (238, 51, 51), (255, 153, 0)]

def quant(im, ncol, fixed=()):
    im = amiga12(im.convert('RGB'))
    if fixed:
        rest = ncol - len(fixed)
        q = im.quantize(colors=rest, method=Image.MEDIANCUT, dither=Image.NONE)
        pal = list(fixed) + [tuple(q.getpalette()[i * 3:i * 3 + 3]) for i in range(rest)]
    else:
        q = im.quantize(colors=ncol, method=Image.MEDIANCUT, dither=Image.NONE)
        pal = [tuple(q.getpalette()[i * 3:i * 3 + 3]) for i in range(ncol)]
    pal = [tuple((c >> 4) * 17 for c in p) for p in pal]
    pimg = Image.new('P', (1, 1))
    flat = []
    for p in pal:
        flat += p
    pimg.putpalette(flat + [0] * (768 - len(flat)))
    out = im.quantize(palette=pimg, dither=Image.NONE)
    return out, pal

def planes(pim, n, w=320, h=256):
    """separate bitplanes (plane after plane)"""
    rb = w // 8
    data = bytearray(rb * h * n)
    px = pim.load()
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            for p in range(n):
                if c >> p & 1:
                    data[p * rb * h + y * rb + (x >> 3)] |= 0x80 >> (x & 7)
    return data

def c12(p):
    return ((p[0] >> 4) << 8) | ((p[1] >> 4) << 4) | (p[2] >> 4)

def make(outdir):
    lp, lpal = quant(loading_picture(), 32, [BLACK, WHITE, SKIN, SKIND, FUR, FURD, MAG, YEL, RED, (255, 160, 20), (255, 210, 60), BARK, (225, 165, 80)])
    # black first: the screen around the picture
    open(os.path.join(outdir, 'loadpic.bin'), 'wb').write(planes(lp, 5))
    tp, tpal = quant(title_picture(), 16, TITLEFIX)
    open(os.path.join(outdir, 'titlepic.bin'), 'wb').write(planes(tp, 4))
    # previews
    lp.convert('RGB').resize((640, 512), Image.NEAREST).save(os.path.join(ROOT, 'art', 'loading_preview.png'))
    tp.convert('RGB').resize((640, 512), Image.NEAREST).save(os.path.join(ROOT, 'art', 'title_preview.png'))
    return [c12(p) for p in lpal], [c12(p) for p in tpal]
