#!/usr/bin/env python3
"""make_print.py - the print kit of Stronkie's StoneAge:
  print/StronkiesStoneAge_Manual.pdf      A5 pages (print as a booklet)
  print/StronkiesStoneAge_Box.pdf         A3: a fold-up box (cut, fold, glue)
  print/StronkiesStoneAge_DiskLabels.pdf  A4: six 3.5" disk labels (game + demo)
Uses the game's 8x8 font for headings and screenshots from screenshots/.
Usage: make_print.py <version>"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art as ART
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A5, A3, A4, landscape
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, white, black
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.utils import ImageReader

VER = sys.argv[1] if len(sys.argv) > 1 else '0.1'
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
FONT = open(os.path.join(ROOT, 'art', 'font8x8.bin'), 'rb').read()
SH = os.path.join(ROOT, 'screenshots')
LOGO = os.path.join(os.environ.get('AMIGA_TK', '/home/claude/amiga-toolkit'), 'art', 'stronkiesoft_logo.png')
OUT = os.path.join(ROOT, 'print')
os.makedirs(OUT, exist_ok=True)
GF = os.path.join(ROOT, 'art', 'fonts') + os.sep          # Poppins (SIL OFL), in the repo
pdfmetrics.registerFont(TTFont('Pop', GF + 'Poppins-Regular.ttf'))
pdfmetrics.registerFont(TTFont('PopB', GF + 'Poppins-Bold.ttf'))
from reportlab.lib.fonts import addMapping
addMapping('Pop', 0, 0, 'Pop'); addMapping('Pop', 1, 0, 'PopB')
addMapping('Pop', 0, 1, 'Pop'); addMapping('Pop', 1, 1, 'PopB')

NIGHT = HexColor('#0b0d1e')
NIGHT2 = HexColor('#1a1f45')
PAPER = HexColor('#f4efe2')
INK = HexColor('#1b1b24')
PINK = HexColor('#ff88cc')
CYAN = HexColor('#55ccee')
YELLOW = HexColor('#ffee33')
GREEN = HexColor('#55dd55')
ORANGE = HexColor('#ff9933')
RAIN = ['#ff4040', '#ff9a30', '#ffe633', '#55dd55', '#33ccee', '#5577ff', '#aa55dd', '#ff55aa']
PLAT = ['#ccaa55', '#ee7766', '#aa55dd', '#7777ff', '#55ccee', '#55dd55', '#ff9933', '#ee55aa']


def pix(c, text, x, y, px, color=white, center=False, rainbow=False, shadow=None):
    w = len(text) * 8 * px
    if center:
        x -= w / 2
    passes = ([(px, -px, shadow)] if shadow is not None else []) + [(0, 0, color)]
    for dx, dy, col in passes:
        for i, ch in enumerate(text):
            o = ord(ch) & 127
            for r in range(8):
                bits = FONT[o * 8 + r]
                if not bits:
                    continue
                if rainbow and col is color:
                    c.setFillColor(HexColor(RAIN[(r + i) % 8]))
                else:
                    c.setFillColor(col)
                b = 0
                while b < 8:
                    if bits & (0x80 >> b):
                        e = b
                        while e < 8 and bits & (0x80 >> e):
                            e += 1
                        c.rect(x + dx + (i * 8 + b) * px, y + dy + (7 - r) * px, (e - b) * px + .02, px + .02, stroke=0, fill=1)
                        b = e
                    else:
                        b += 1
    return w


def para(c, text, x, ytop, w, size=8.5, color=INK, align=0, font='Pop'):
    st = ParagraphStyle('p', fontName=font, fontSize=size, leading=size * 1.4, textColor=color, alignment=align)
    p = Paragraph(text, st)
    _, h = p.wrapOn(c, w, 3000)
    p.drawOn(c, x, ytop - h)
    return ytop - h


def shot(c, name, x, y, w):
    path = os.path.join(SH, name)
    im = ImageReader(path)
    iw, ih = im.getSize()
    h = w * ih / iw
    c.setFillColor(black)
    c.rect(x - 2, y - 2, w + 4, h + 4, stroke=0, fill=1)
    c.drawImage(im, x, y, w, h)
    return h



SKY = HexColor('#00dddd')
MAG = HexColor('#dd11dd')
YEL = HexColor('#ffee22')
COLS = {'player': {'1': HexColor('#ffbb88'), '2': HexColor('#dd7711'), '3': black},
        'monster': {'1': MAG, '2': YEL, '3': black}}

def sprite(c, rows, x, y, s, kind='player', flip=False):
    """text art from tools/art.py, s = pixel size; (x, y) = bottom left"""
    col = COLS[kind]
    n = len(rows)
    for r, row in enumerate(rows):
        if flip:
            row = row[::-1]
        for i, ch in enumerate(row):
            if ch == '.':
                continue
            k = '3' if ch == 'K' else ('1' if ch in 'SMR1' else '2')
            c.setFillColor(col[k])
            c.rect(x + i * s, y + (n - 1 - r) * s, s + .02, s + .02, stroke=0, fill=1)

def platform(c, x, y, n, s):
    """a stone age platform: magenta top, yellow roots; n tiles of 16 pixels"""
    w = n * 16 * s
    c.setFillColor(black); c.rect(x, y - 6 * s, w, 6 * s, stroke=0, fill=1)
    c.setFillColor(MAG); c.rect(x, y - 5 * s, w, 4 * s, stroke=0, fill=1)
    for k in range(n * 2):
        p = c.beginPath()
        x0 = x + k * 8 * s
        p.moveTo(x0, y - 6 * s); p.lineTo(x0 + 8 * s, y - 6 * s); p.lineTo(x0 + 4 * s, y - 12 * s); p.close()
        c.setFillColor(black); c.drawPath(p, stroke=0, fill=1)
        p = c.beginPath()
        p.moveTo(x0 + s, y - 6 * s); p.lineTo(x0 + 7 * s, y - 6 * s); p.lineTo(x0 + 4 * s, y - 11 * s); p.close()
        c.setFillColor(YEL); c.drawPath(p, stroke=0, fill=1)

def ladder(c, x, y, h, s):
    """a bone ladder from y up to y + h"""
    c.setFillColor(YEL)
    c.rect(x + 4 * s, y, 1.6 * s, h, stroke=0, fill=1)
    c.rect(x + 10.4 * s, y, 1.6 * s, h, stroke=0, fill=1)
    k = 0
    while k * 4 * s < h:
        c.rect(x + 3 * s, y + k * 4 * s, 10 * s, 1.4 * s, stroke=0, fill=1)
        k += 1

def keyicon(c, x, y, s):
    c.setFillColor(YEL); c.setStrokeColor(black); c.setLineWidth(.6 * s)
    c.circle(x + 3 * s, y + 3 * s, 2.6 * s, stroke=1, fill=1)
    c.rect(x + 5 * s, y + 2.3 * s, 8 * s, 1.6 * s, stroke=1, fill=1)
    c.rect(x + 10 * s, y + .4 * s, 1.4 * s, 2 * s, stroke=1, fill=1)

def scene(c, x, y, w, h):
    """a little stone age picture for the covers"""
    c.setFillColor(SKY); c.rect(x, y, w, h, stroke=0, fill=1)
    s = w / 200
    c.saveState()
    p = c.beginPath(); p.rect(x, y, w, h); c.clipPath(p, stroke=0)
    platform(c, x, y + 14 * s, 13, s)
    platform(c, x + 8 * s, y + 62 * s, 6, s)
    platform(c, x + 120 * s, y + 62 * s, 6, s)
    platform(c, x + 60 * s, y + 104 * s, 5, s)
    ladder(c, x + 40 * s, y + 14 * s, 42 * s, s)
    ladder(c, x + 150 * s, y + 14 * s, 42 * s, s)
    sprite(c, ART.THROW, x + 70 * s, y + 14 * s, 1.5 * s)
    c.setStrokeColor(white); c.setLineWidth(.8 * s)
    c.line(x + 94 * s, y + 35 * s, x + 112 * s, y + 35 * s)
    c.setFillColor(HexColor('#ee2222')); c.circle(x + 114 * s, y + 35 * s, 3 * s, stroke=0, fill=1)
    sprite(c, ART.SCRUB1, x + 122 * s, y + 14 * s, 1.3 * s, 'monster')
    sprite(c, ART.HOOT1, x + 128 * s, y + 62 * s, 1.1 * s, 'monster')
    sprite(c, ART.POG1, x + 14 * s, y + 62 * s, 1.1 * s, 'monster')
    keyicon(c, x + 80 * s, y + 112 * s, 1.5 * s)
    keyicon(c, x + 20 * s, y + 92 * s, 1.5 * s)
    keyicon(c, x + 170 * s, y + 80 * s, 1.5 * s)
    c.restoreState()


# ====================================================================== manual
def manual():
    W, H = A5
    c = canvas.Canvas(os.path.join(OUT, 'StronkiesStoneAge_Manual.pdf'), pagesize=A5)
    c.setTitle("Stronkie's StoneAge - Manual")
    c.setAuthor('Mark Stronks, Stronkie Soft')
    M = 14 * mm
    pageno = [0]

    def newpage(title=None):
        if pageno[0]:
            c.showPage()
        pageno[0] += 1
        c.setFillColor(PAPER)
        c.rect(0, 0, W, H, stroke=0, fill=1)
        if title:
            c.setFillColor(NIGHT)
            c.rect(0, H - 22 * mm, W, 22 * mm, stroke=0, fill=1)
            pix(c, title, W / 2, H - 14 * mm, 2.0, YELLOW, center=True, shadow=HexColor('#aa5500'))
        c.setFillColor(INK)
        c.setFont('Pop', 7)
        if pageno[0] > 1:
            c.drawCentredString(W / 2, 7 * mm, "Stronkie's StoneAge  -  %d" % pageno[0])
        return H - 30 * mm

    # cover
    newpage()
    c.setFillColor(NIGHT)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    c.drawImage(ImageReader(LOGO), W / 2 - 40 * mm, H - 33 * mm, 80 * mm, 80 * mm * 44 / 158, mask='auto')
    pix(c, "STRONKIE'S", W / 2, H - 55 * mm, 3.6, YELLOW, center=True, shadow=HexColor('#aa5500'))
    pix(c, 'STONEAGE', W / 2, H - 76 * mm, 4.6, MAG, center=True, shadow=HexColor('#440044'))
    scene(c, M, 42 * mm, W - 2 * M, (W - 2 * M) * 0.62)
    pix(c, 'INSTRUCTION MANUAL', W / 2, 30 * mm, 1.6, CYAN, center=True)
    c.setFillColor(white); c.setFont('Pop', 8)
    c.drawCentredString(W / 2, 20 * mm, 'Amiga 500 (68000)  -  Kickstart / Workbench 3.1  -  1 MB chip  -  Version %s' % VER)
    c.drawCentredString(W / 2, 14 * mm, 'Created By Mark Stronks, Stronkie Soft  (c) 2026')

    # story
    y = newpage('THE STORY')
    y = para(c, "Long, long ago, when the mountains were still young, the caveman <b>Stronkie</b> kept the "
             "keys of the stone age: the keys to every cave, every bone gate and every rock door. One stormy "
             "night the keys were scattered all over the land - over the bone valleys, the rope bridges and "
             "the iron caves.", M, y, W - 2 * M, 9.5)
    y = para(c, "Stronkie has to get them all back before the sun goes down. When the time runs out the "
             "<b>lights go out</b>, and in the dark nothing is safe. Luckily the cavemen left <b>light bulbs</b> "
             "(don't ask how) here and there: they bring the light back and give him more time.", M, y - 8, W - 2 * M, 9.5)
    y = para(c, "The land is full of strange creatures. The big furry <b>Scrubblies</b> block the platforms, "
             "the goggle-eyed <b>Hooters</b> flap through the air and the <b>Poglets</b> hop around with their "
             "curly tails. Balloons rise up from below and daggers fall from the sky.", M, y - 8, W - 2 * M, 9.5)
    y = para(c, "But Stronkie has his trusty <b>yo-yo</b>. One good throw and a monster goes poof!", M, y - 8, W - 2 * M, 9.5)
    sprite(c, ART.THROW, W / 2 - 50, 24 * mm, 3)
    sprite(c, ART.SCRUB1, W / 2 + 10, 24 * mm, 2.2, 'monster')

    # how to play
    y = newpage('HOW TO PLAY')
    items = [
        ('KEYS', "Collect every key of a level to finish it. The score panel shows how many you have. "
         "Time left at the end is worth 10 points a second."),
        ('THE TIME', "The bar in the score panel. When it is empty the lights go out: the level turns dark, "
         "and the yo-yo goes right through the balloons and daggers. A light bulb gives 15 seconds and the light back."),
        ('JUMPING AND SLIDING', "Push up to jump (up and left/right to jump sideways). Step off a ledge and "
         "Stronkie slides down diagonally. One floor down is fine - two floors is a drop he does not survive, "
         "and neither is a pit in the ground."),
        ('LADDERS, ROPES, CHAINS', "Bone ladders in the first levels, then ropes, then chains. Up and down to "
         "climb; at a floor, left or right steps off."),
        ('THE YO-YO', "Fire throws it. A Scrubbly, Hooter or Poglet that is hit goes poof (and comes back "
         "later, when Stronkie is far away). Balloons and daggers pop - but only while it is light."),
        ('GEMS', "250 points each. They are often in hard places..."),
    ]
    for t, d in items:
        pix(c, t, M, y - 8, 1.3, HexColor('#c0306a'))
        y = para(c, d, M, y - 12, W - 2 * M, 8.6) - 6

    # monsters
    y = newpage('THE MONSTERS')
    for k, (rows, name, txt) in enumerate(((ART.SCRUB1, 'SCRUBBLY', "Big, furry and in the way. Shuffles to and fro on its platform. 200 points."),
                                         (ART.HOOT1, 'HOOTER', "Flaps through the air, up and down, back and forth. 300 points."),
                                         (ART.POG1, 'POGLET', "Hops along its platform with its curly tail. 150 points."))):
        yy = y - 10 - k * 44 * mm
        sprite(c, rows, M, yy - 32 * 2.6, 2.6, 'monster')
        pix(c, name, M + 34 * mm, yy - 12, 1.6, MAG)
        para(c, txt, M + 34 * mm, yy - 20, W - 2 * M - 34 * mm, 8.8)
    para(c, "Balloons (rising) and daggers (falling) are worth 50 points when the yo-yo pops them.", M, 30 * mm, W - 2 * M, 8.6)

    # controls + scores
    y = newpage('CONTROLS')
    rows = [('Joystick left / right', 'Walk'), ('Joystick up', 'Jump (with left/right: jump sideways)'),
            ('Up / down at a ladder', 'Climb (left / right: step off at a floor)'),
            ('Fire button', 'Throw the yo-yo'), ('Cursor keys + Space', 'The same on the keyboard'),
            ('M', 'Music on / off'), ('P', 'Pause'), ('Esc', 'End the game / on the title: quit'),
            ('F10', 'Quit the game (also in WHDLoad)')]
    for a, b in rows:
        c.setFillColor(INK); c.setFont('PopB', 8.6); c.drawString(M, y, a)
        c.setFont('Pop', 8.6); c.drawString(M + 48 * mm, y, b)
        y -= 14
    y -= 10
    pix(c, 'POINTS', M, y, 1.6, HexColor('#c0306a'))
    y -= 18
    for a, b in (('Key', '100'), ('Gem', '250'), ('Light bulb', '100'), ('Balloon / dagger', '50'),
                 ('Scrubbly / Hooter / Poglet', '200 / 300 / 150'), ('Time left at the end', '10 per second'),
                 ('All 8 levels (a loop)', '5000 bonus'), ('Extra life', 'at 20000, then every 30000')):
        c.setFont('Pop', 8.6); c.drawString(M, y, a); c.setFont('PopB', 8.6); c.drawRightString(W - M, y, b)
        y -= 13
    y -= 10
    para(c, "You start with 5 lives. After level 8 the stone age starts again - with a twist: upside down, "
         "turned 90 degrees, black and white with flashes, and faster monsters every loop.", M, y, W - 2 * M, 8.6)

    # screens
    y = newpage('THE STONE AGE')
    shots_ = (('level1.png', 'Level 1, Bone Valley: keys, gems and the first Scrubbly.'),
              ('dark.png', 'Lights out! Find a light bulb.'),
              ('flip.png', 'Loop 2: upside down.'),
              ('rot.png', 'Loop 3: turned 90 degrees.'))
    w = W / 2 - M - 4
    for i, (n, cap) in enumerate(shots_):
        x = M if i % 2 == 0 else W / 2 + 4
        yy = y - (i // 2) * (w * .8 + 34)
        shot(c, n, x, yy - w * 0.8, w)
        para(c, cap, x, yy - w * 0.8 - 4, w, 7.6)
    # tips + loading
    y = newpage('LOADING & TIPS')
    y = para(c, "<b>Floppy:</b> switch on the Amiga and insert the disk. "
             "<b>Hard disk / CF card:</b> double-click <i>Install</i> on the game disk, or unpack the hard drive zip. "
             "<b>WHDLoad:</b> unpack the WHDLoad zip and start <i>StronkiesStoneAge</i> (F10 quits). "
             "Made for an Amiga 500 (68000) with Kickstart / Workbench 3.1 and 1 MB chip memory (8372A Agnus); "
             "also runs on an ACA500, in WinUAE and on later Amigas.", M, y, W - 2 * M, 8.6)
    pix(c, 'HIGH SCORES', M, y - 18, 1.5, HexColor('#c0306a'))
    y = para(c, "The ten best scores are kept with a three-letter name: type it on the keyboard, or pick the "
             "letters with the joystick (up/down = letter, fire = next). They are saved on the disk when a game ends.",
             M, y - 26, W - 2 * M, 8.6)
    pix(c, "TIPS FROM STRONKIE", M, y - 18, 1.5, HexColor('#c0306a'))
    y = para(c, "- Count the floors before you step off a ledge: one down is fine, two is not.<br/>"
             "- Keep a light bulb for later: when the lights go out, it is a long way to find one.<br/>"
             "- Throw the yo-yo early: it flies 64 pixels, then comes back.<br/>"
             "- Balloons rise, daggers fall: step aside or pop them while it is light.<br/>"
             "- Every key can be reached - every level is checked by computer.", M, y - 26, W - 2 * M, 8.6)
    pix(c, 'CREDITS', M, y - 20, 1.5, HexColor('#c0306a'))
    para(c, "Game, graphics, music and sound: <b>Mark Stronks, Stronkie Soft</b> (c) 2026.<br/>"
         "Font: font8x8 (public domain).<br/>More games: stronkie.itch.io", M, y - 28, W - 2 * M, 8.6)
    c.save()


# ====================================================================== box
def box():
    PW, PH = landscape(A3)
    c = canvas.Canvas(os.path.join(OUT, 'StronkiesStoneAge_Box.pdf'), pagesize=(PW, PH))
    c.setTitle("Stronkie's StoneAge - Box")
    Wf, Hf, D = 135 * mm, 190 * mm, 32 * mm          # front width, height, depth
    G = 12 * mm                                      # glue tab
    ox = (PW - (2 * Wf + 2 * D + G)) / 2
    oy = (PH - (Hf + 2 * D + 2 * 12 * mm)) / 2 + 12 * mm + D
    xs = [ox + G, ox + G + D, ox + G + D + Wf, ox + G + 2 * D + Wf]   # side, front, side, back
    c.setFillColor(white); c.rect(0, 0, PW, PH, stroke=0, fill=1)
    # panels
    def face_front(x, y):
        c.setFillColor(NIGHT); c.rect(x, y, Wf, Hf, stroke=0, fill=1)
        c.drawImage(ImageReader(LOGO), x + Wf / 2 - 30 * mm, y + Hf - 24 * mm, 60 * mm, 60 * mm * 44 / 158, mask='auto')
        pix(c, "STRONKIE'S", x + Wf / 2, y + Hf - 44 * mm, 3.4, YELLOW, center=True, shadow=HexColor('#aa5500'))
        pix(c, 'STONEAGE', x + Wf / 2, y + Hf - 66 * mm, 4.4, MAG, center=True, shadow=HexColor('#440044'))
        scene(c, x + 6 * mm, y + 30 * mm, Wf - 12 * mm, (Wf - 12 * mm) * .55)
        pix(c, '8 LEVELS - ENDLESS LOOPS!', x + Wf / 2, y + 19 * mm, 1.7, YELLOW, center=True)
        c.setFillColor(HexColor('#c8102e')); c.rect(x, y, Wf, 10 * mm, stroke=0, fill=1)
        pix(c, 'AMIGA 500', x + Wf / 2, y + 3.4 * mm, 1.5, white, center=True)
    def face_back(x, y):
        c.setFillColor(NIGHT2); c.rect(x, y, Wf, Hf, stroke=0, fill=1)
        pix(c, 'FIND THE KEYS!', x + Wf / 2, y + Hf - 14 * mm, 1.6, YELLOW, center=True)
        para(c, "Stronkie the caveman has lost the keys of the stone age! Jump, climb and slide through "
             "8 scrolling levels and collect every key before the light runs out. His trusty yo-yo makes "
             "short work of the Scrubblies, Hooters and Poglets - and pops the balloons and daggers.",
             x + 8 * mm, y + Hf - 20 * mm, Wf - 16 * mm, 9, white)
        w = (Wf - 22 * mm) / 2
        for i, n in enumerate(('title.png', 'level1.png', 'flip.png', 'rot.png')):
            shot(c, n, x + 8 * mm + (i % 2) * (w + 6 * mm), y + Hf - 87 * mm - (i // 2) * (w * .8 + 6 * mm), w)
        para(c, "- 8 smooth scrolling levels: bone ladders, ropes and chains<br/>- the yo-yo, light bulbs, gems, the darkness<br/>"
             "- endless loops: upside down, turned 90 degrees, black and white<br/>- music, sound effects, high scores<br/>- floppy, hard disk installer and WHDLoad",
             x + 8 * mm, y + 47 * mm, Wf - 16 * mm, 8.4, white)
        c.setFillColor(HexColor('#c8102e')); c.rect(x, y, Wf, 10 * mm, stroke=0, fill=1)
        c.setFillColor(white); c.setFont('Pop', 7)
        c.drawCentredString(x + Wf / 2, y + 3.6 * mm, 'Created By Mark Stronks, Stronkie Soft (c) 2026  -  Version %s' % VER)
    def face_side(x, y, specs):
        c.setFillColor(NIGHT); c.rect(x, y, D, Hf, stroke=0, fill=1)
        c.saveState(); c.translate(x + D / 2 + 4, y + Hf / 2); c.rotate(90)
        pix(c, "STRONKIE'S STONEAGE", 0, 0, 1.9, YELLOW, center=True)
        c.restoreState()
        if specs:
            c.setFillColor(white); c.setFont('PopB', 6.2)
            for k, t in enumerate(('SYSTEM', 'Amiga 500', '68000', 'Kickstart 3.1', '1 MB chip', 'joystick')):
                c.drawCentredString(x + D / 2, y + 40 * mm - k * 8, t)
        sprite(c, ART.STAND, x + D / 2 - 12, y + 6 * mm, 1.5)
    def face_flap(x, y, w, h, text):
        c.setFillColor(NIGHT2); c.rect(x, y, w, h, stroke=0, fill=1)
        if text:
            pix(c, text, x + w / 2, y + h / 2 - 4, 1.4, YELLOW, center=True)
    face_side(xs[0], oy, True)
    face_front(xs[1], oy)
    face_side(xs[2], oy, False)
    face_back(xs[3], oy)
    face_flap(xs[1], oy + Hf, Wf, D, "STRONKIE'S STONEAGE")
    face_flap(xs[1], oy - D, Wf, D, 'STRONKIE SOFT')
    # tucks and dust flaps (white)
    c.setStrokeColor(black); c.setLineWidth(.5)
    T = 12 * mm
    def outline(pts):
        p = c.beginPath(); p.moveTo(*pts[0])
        for q in pts[1:]:
            p.lineTo(*q)
        p.close(); c.drawPath(p, stroke=1, fill=0)
    outline([(xs[1], oy + Hf + D), (xs[1] + 4 * mm, oy + Hf + D + T), (xs[2] - 4 * mm, oy + Hf + D + T), (xs[2], oy + Hf + D)])
    outline([(xs[1], oy - D), (xs[1] + 4 * mm, oy - D - T), (xs[2] - 4 * mm, oy - D - T), (xs[2], oy - D)])
    for sx in (xs[0], xs[2]):
        outline([(sx, oy + Hf), (sx + 3 * mm, oy + Hf + D - 4 * mm), (sx + D - 3 * mm, oy + Hf + D - 4 * mm), (sx + D, oy + Hf)])
        outline([(sx, oy), (sx + 3 * mm, oy - D + 4 * mm), (sx + D - 3 * mm, oy - D + 4 * mm), (sx + D, oy)])
    outline([(ox + G, oy), (ox, oy + 6 * mm), (ox, oy + Hf - 6 * mm), (ox + G, oy + Hf)])
    c.setFont('Pop', 6); c.setFillColor(HexColor('#888888'))
    c.drawString(ox + 1 * mm, oy + Hf / 2, 'glue')
    # cut + fold lines
    c.setStrokeColor(black); c.setLineWidth(.6)
    c.rect(xs[0], oy, 2 * D + 2 * Wf, Hf, stroke=1, fill=0)
    c.rect(xs[1], oy + Hf, Wf, D, stroke=1, fill=0)
    c.rect(xs[1], oy - D, Wf, D, stroke=1, fill=0)
    c.setDash(3, 3); c.setStrokeColor(HexColor('#777777'))
    for x in xs[1:]:
        c.line(x, oy, x, oy + Hf)
    c.setDash()
    c.setFont('Pop', 8); c.setFillColor(INK)
    c.drawString(12 * mm, 10 * mm, "Stronkie's StoneAge - fold-up box. Print on A3 (100%), cut along the solid lines, "
                 "fold along the dashed lines and the panel edges, glue the tab inside the back.")
    c.save()


# ====================================================================== labels
def labels():
    PW, PH = A4
    c = canvas.Canvas(os.path.join(OUT, 'StronkiesStoneAge_DiskLabels.pdf'), pagesize=A4)
    c.setTitle("Stronkie's StoneAge - Disk labels")
    LW, LH = 70 * mm, 60 * mm
    for k in range(6):
        demo = k >= 4
        x = 25 * mm + (k % 2) * (LW + 10 * mm)
        y = PH - 25 * mm - (k // 2 + 1) * (LH + 14 * mm)
        c.setFillColor(NIGHT); c.rect(x, y, LW, LH, stroke=0, fill=1)
        c.setFillColor(HexColor('#c8102e')); c.rect(x, y + LH - 9 * mm, LW, 9 * mm, stroke=0, fill=1)
        pix(c, "STRONKIE'S STONEAGE", x + LW / 2, y + LH - 6 * mm, 1.2, white, center=True)
        scene(c, x + 4 * mm, y + 14 * mm, LW - 8 * mm, (LW - 8 * mm) * .5)
        pix(c, 'FREE DEMO' if demo else 'GAME DISK  V%s' % VER, x + LW / 2, y + 7.5 * mm, 1.2, YELLOW, center=True)
        c.setFillColor(white); c.setFont('Pop', 5.5)
        c.drawCentredString(x + LW / 2, y + 3 * mm, 'A500 68000  -  KS 3.1  -  1 MB chip  -  (c) 2026 Mark Stronks, Stronkie Soft')
        c.setStrokeColor(HexColor('#999999')); c.setLineWidth(.3); c.rect(x, y, LW, LH, stroke=1, fill=0)
    c.setFont('Pop', 8); c.setFillColor(INK)
    c.drawString(25 * mm, 12 * mm, "Stronkie's StoneAge - 3.5\" disk labels (print at 100%, cut along the grey lines).")
    c.save()


manual()
box()
labels()
print('print kit written to', OUT)
