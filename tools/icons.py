#!/usr/bin/env python3
"""icons.py - the Workbench 1.3 icons of Stronkie's StoneAge.
  build/SStoneAge.info   the game (a white robot on a platform)
  build/Install.info  the hard disk installer
  build/drawer.info   the drawer (hard drive zip and WHDLoad)
  build/whd.info      the WHDLoad project icon (default tool WHDLoad)
Workbench 1.3 colours: 0 blue, 1 white, 2 black, 3 orange."""
import os, sys, struct
from PIL import Image, ImageDraw
TK = os.environ.get('AMIGA_TK', '/home/claude/amiga-toolkit')
sys.path.insert(0, os.path.join(TK, 'tools'))
from make_disk import diskobject, install_image, drawer_image, planes
B = sys.argv[1] if len(sys.argv) > 1 else 'build'

def robot_image():
    """Stronkie the caveman with his yo-yo on a stone platform"""
    W, H = 52, 30
    im = Image.new('P', (W, H), 0)
    d = ImageDraw.Draw(im)
    d.ellipse([14, 1, 25, 11], fill=2)                  # hair
    d.rectangle([18, 4, 25, 10], fill=1)                # face
    d.point([23, 6], fill=2)
    d.rectangle([14, 12, 25, 20], fill=3, outline=2)    # fur tunic
    d.line([26, 14, 31, 14], fill=1)                    # arm
    d.line([31, 14, 40, 14], fill=1)                    # string
    d.ellipse([40, 11, 46, 17], fill=3, outline=2)      # yo-yo
    d.line([16, 21, 16, 24], fill=1); d.line([23, 21, 23, 24], fill=1)
    d.rectangle([2, 25, 49, 28], fill=3, outline=2)     # stone platform
    for x in range(5, 48, 6):
        d.point([x, 27], fill=1)
    return im

def bstr(s):
    b = s.encode('latin-1') + b'\0'
    return struct.pack('>I', len(b)) + b

def project(im, tool, tooltypes=()):
    W, H = im.size
    o = struct.pack('>HH', 0xe310, 1)
    o += struct.pack('>IhhhhHHHIIIiIHI', 0, 0, 0, W, H, 5, 3, 1, 1, 0, 0, 0, 0, 0, 0)
    o += struct.pack('>BB', 4, 0)
    o += struct.pack('>IIiiIIi', 1, 1 if tooltypes else 0, -0x80000000, -0x80000000, 0, 0, 8192)
    o += struct.pack('>hhhhhIBBI', 0, 0, W, H, 2, 1, 3, 0, 0)
    o += planes(im)
    o += bstr(tool)
    if tooltypes:
        o += struct.pack('>I', (len(tooltypes) + 1) * 4)
        for t in tooltypes:
            o += bstr(t)
    return o

open(os.path.join(B, 'SStoneAge.info'), 'wb').write(diskobject(3, robot_image()))
open(os.path.join(B, 'Install.info'), 'wb').write(diskobject(3, install_image()))
open(os.path.join(B, 'drawer.info'), 'wb').write(diskobject(2, drawer_image()))
open(os.path.join(B, 'whd.info'), 'wb').write(project(robot_image(), 'WHDLoad', ['PRELOAD']))
# for the installer (incbin)
open(os.path.join(os.path.dirname(B.rstrip('/')) or '.', 'src', 'drawer.info'), 'wb').write(diskobject(2, drawer_image()))
pal = robot_image(); pal.putpalette([0, 0x55, 0xaa, 255, 255, 255, 0, 0, 0, 255, 0x88, 0] + [0] * 756)
pal.convert('RGB').resize((208, 120), Image.NEAREST).save(os.path.join(B, 'icon_preview.png'))
