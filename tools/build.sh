#!/bin/sh
# build.sh - Stronkie's StoneAge: game, demo, floppies, hard drive zip, WHDLoad.
#   VER=0.1 tools/build.sh
# Needs the Stronkie Soft amiga-toolkit (AMIGA_TK, default /home/claude/amiga-toolkit).
set -e
cd "$(dirname "$0")/.."
TK=${AMIGA_TK:-/home/claude/amiga-toolkit}
export AMIGA_TK=$TK
export PATH="$TK/bin:$PATH"
NAME=StronkiesStoneAge
EXE=SStoneAge
VOL="Stronkies StoneAge"
VER=${VER:-0.1}
mkdir -p build
python3 tools/levels.py >/dev/null || { python3 tools/levels.py; exit 1; }
python3 tools/gen.py >/dev/null
printf "\tdc.b\t'VERSION %s  (C) 2026',0\n" "$VER" > src/version.i
printf "\tdc.b\t'Version %s',0\n" "$VER" > src/whdver.i
# 1. icons, then assemble (68000 only): the game, the demo, the installer, the slave
python3 tools/icons.py build
(cd src && vasmm68k_mot -quiet -m68000 -Fhunkexe -kick1hunks -nosym -o ../build/$EXE main.s)
(cd src && vasmm68k_mot -quiet -m68000 -Fhunkexe -kick1hunks -nosym -DDEMO=1 -o ../build/${EXE}Demo main.s)
(cd src && vasmm68k_mot -quiet -m68000 -Fhunkexe -kick1hunks -nosym -o ../build/Install install.s)
(cd src && vasmm68k_mot -quiet -m68000 -Fhunkexe -kick1hunks -nosym -o ../build/Loader loader.s)
(cd src && vasmm68k_mot -quiet -m68000 -Fhunkexe -nosym -o ../build/$NAME.slave whdload.s)
# a test build with symbols for the harness
(cd src && vasmm68k_mot -quiet -m68000 -Fhunkexe -kick1hunks -o ../build/test.game main.s)
# 2. the floppies (packed program)
for kind in full demo; do
  rm -rf build/disk && mkdir -p build/disk/s
  if [ $kind = full ]; then
    python3 $TK/tools/pack/crunch.py build/$EXE build/disk/StoneAge.game >/dev/null
    cp build/Install build/disk/Install; cp build/Install.info build/disk/Install.info
    ADF=build/${NAME}_V$VER.adf; V="$VOL"
  else
    python3 $TK/tools/pack/crunch.py build/${EXE}Demo build/disk/StoneAge.game >/dev/null
    ADF=build/${NAME}_Demo.adf; V="$VOL Demo"
  fi
  python3 $TK/tools/pack/crunch.py build/Loader build/disk/$EXE >/dev/null
  cp build/$EXE.info build/disk/$EXE.info
  cp ReadMe.txt build/disk/ReadMe
  printf '%s\n' "$EXE" > build/disk/s/startup-sequence
  python3 $TK/tools/adf.py build $ADF "$V" build/disk $TK/tools/bootblock.bin >/dev/null
  echo "built $ADF"
done
# the Stronkie Soft boot intro before the game on the floppy (toolkit intro/, build it first)
python3 $TK/tools/add_intro.py build/${NAME}_V$VER.adf build/${NAME}_V$VER.adf
# 3. hard drive / CF card zip (unpacked program)
rm -rf build/hd && mkdir -p build/hd/$NAME
cp build/Loader build/hd/$NAME/$EXE; cp build/$EXE build/hd/$NAME/StoneAge.game
cp build/$EXE.info build/hd/$NAME/; cp ReadMe.txt build/hd/$NAME/ReadMe
cp build/drawer.info build/hd/$NAME.info
(cd build/hd && rm -f ../${NAME}_V${VER}_harddrive.zip && zip -qr ../${NAME}_V${VER}_harddrive.zip $NAME $NAME.info)
echo "built build/${NAME}_V${VER}_harddrive.zip"
# 4. WHDLoad (own slave, no Kickstart image; the game file unpacked)
rm -rf build/whd && mkdir -p build/whd/$NAME/data
cp build/$NAME.slave build/whd/$NAME/
cp build/$EXE build/whd/$NAME/data/$EXE
cp build/whd.info build/whd/$NAME/$NAME.info
cp build/drawer.info build/whd/$NAME.info
cp ReadMe.txt build/whd/$NAME/ReadMe
(cd build/whd && rm -f ../${NAME}_V${VER}_WHDLoad.zip && zip -qr ../${NAME}_V${VER}_WHDLoad.zip $NAME $NAME.info)
echo "built build/${NAME}_V${VER}_WHDLoad.zip"
# 5. WHDLoad for the free demo (same slave, the demo program)
D=${NAME}Demo
rm -rf build/whdd && mkdir -p build/whdd/$D/data
cp build/$NAME.slave build/whdd/$D/$D.slave
cp build/${EXE}Demo build/whdd/$D/data/$EXE
cp build/whd.info build/whdd/$D/$D.info
cp build/drawer.info build/whdd/$D.info
cp ReadMe.txt build/whdd/$D/ReadMe
(cd build/whdd && rm -f ../${NAME}_Demo_WHDLoad.zip && zip -qr ../${NAME}_Demo_WHDLoad.zip $D $D.info)
echo "built build/${NAME}_Demo_WHDLoad.zip"
