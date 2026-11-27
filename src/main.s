;=====================================================================
; Stronkie's StoneAge - a scrolling platform game for the Amiga 500
; Created By Mark Stronks, Stronkie Soft (c) 2026
;
; Stronkie the caveman, armed with a yo-yo, collects every key of a
; level before the time runs out. He jumps, climbs ladders (ropes and
; chains later on), slides down diagonally when he steps off a ledge,
; and a long drop is fatal. The yo-yo clears Scrubblies, Hooters and
; Poglets and pops the balloons and daggers - but not in the dark:
; when the timer hits zero the lights go out. Light bulbs give time
; and light back, gems give points. After the 8 levels the game loops
; with a twist: upside down, turned 90 degrees, black and white.
;
; Target: Amiga 500, 68000, Kickstart/Workbench 3.1, 1 MB chip RAM.
; Joystick in port 2 (or cursor keys + space). The game takes over
; the hardware (polled once per frame, no interrupts) and gives the
; system back when it quits (Esc on the title, or F10).
; Build: vasmm68k_mot -m68000 -Fhunkexe -kick1hunks [-DDEMO=1] main.s
;=====================================================================

	ifnd	DEMO
DEMO	equ	0
	endc

CUSTOM	equ	$dff000
DMACONR	equ	$002
VPOSR	equ	$004
JOY1DAT	equ	$00c
ADKCONR	equ	$010
INTENAR	equ	$01c
COP1LC	equ	$080
COPJMP1	equ	$088
DMACON	equ	$096
INTENA	equ	$09a
INTREQ	equ	$09c
ADKCON	equ	$09e
AUD0	equ	$0a0

CIAA_PRA	equ	$bfe001
CIAA_SDR	equ	$bfec01
CIAA_ICR	equ	$bfed01
CIAA_CRA	equ	$bfee01

PLANE	equ	40*256			; one bitplane of the screen (title, score panel)
PFTOP	equ	32			; the playfield starts at screen line 32
PFH	equ	192			; and is 192 lines high
NRB	equ	124			; level bitmap, normal: 992 pixels per line
NSTR	equ	NRB*3			; interleaved: one line of 3 planes
RRB	equ	40			; level bitmap, turned: 320 pixels per line
RSTR	equ	RRB*3
BNRB	equ	84			; the jungle, normal: 672 pixels per line
BNSTR	equ	BNRB*3
BRSTR	equ	40*3			; the jungle, turned
LVBMSIZE equ	RSTR*960		; (the bigger one)
SPRLEN	equ	1280			; one sprite channel's list
HSN	equ	10			; high score entries

; display modes (the loops)
DM_NORMAL equ	0
DM_FLIP	equ	1
DM_ROT	equ	2
DM_BW	equ	3

; Stronkie's states
ST_STAND equ	0
ST_LADDER equ	1
ST_JUMP	equ	2
ST_SLIDE equ	3
ST_DEAD	equ	4

PW	equ	16
PH	equ	24
XMAX	equ	960-PW
DEADLY	equ	100
LIVES	equ	5
INVTIME	equ	100

; tile types (the logic map)
T_EMPTY	equ	0
T_PLAT	equ	1
T_PLAD	equ	2
T_LAD	equ	3
T_KEY	equ	4
T_GEM	equ	5
T_BULB	equ	6

; an enemy
EN_TYPE	equ	0			; 0 Scrubbly, 1 Hooter, 2 Poglet
EN_X	equ	2
EN_Y	equ	4
EN_MIN	equ	6
EN_MAX	equ	8
EN_DIR	equ	10
EN_STATE equ	12			; 0 alive, 1 poof, 2 gone
EN_TIMER equ	14
EN_SPX	equ	16
EN_SPY	equ	18
EN_PHASE equ	20
EN_BASEY equ	22
EN_SIZE	equ	24
MAXEN	equ	10

; balloons and daggers
MS_KIND	equ	0			; 0 free, 1 balloon, 2 dagger, 3 pop
MS_X	equ	2
MS_Y	equ	4
MS_T	equ	6
MS_SIZE	equ	8
MAXMS	equ	4

; keys (raw codes)
K_ESC	equ	$45
K_P	equ	$19
K_M	equ	$37
K_D	equ	$22
K_N	equ	$36
K_I	equ	$17
K_T	equ	$14
K_F10	equ	$59
K_CTRL	equ	$63
K_LALT	equ	$64
K_RALT	equ	$65

	section	code,code

;---------------------------------------------------------------------
start:	movem.l	d1-d7/a0-a6,-(sp)
	bsr	SysTakeover
	bsr	InitAll
	bsr	Splash
.loop:	bsr	Title
	tst.w	d0
	bne	.quit
	bsr	Game
	tst.w	quitnow
	beq	.loop
.quit:	bsr	SysRestore
	movem.l	(sp)+,d1-d7/a0-a6
	moveq	#0,d0
	rts

	include	'sys.i'
	include	'display.i'
	include	'game.i'
	include	'title.i'
	include	'data_gen.i'

;=====================================================================
; variables
;=====================================================================
	section	vars,bss
frame:		ds.l	1
gfxbase:	ds.l	1
dosbase:	ds.l	1
oldview:	ds.l	1
oldcop:		ds.l	1
wbmsg:		ds.l	1
oldint:		ds.w	1
olddma:		ds.w	1
oldadk:		ds.w	1
quitnow:	ds.w	1
joy:		ds.w	1
joyedge:	ds.w	1
lastkey:	ds.w	1
keys:		ds.b	128
; copper patch points
cp_hud:		ds.l	1
cp_spr:		ds.l	1
cp_pf:		ds.l	1
cp_ddf:		ds.l	1
cp_mod1:	ds.l	1
cp_mod2:	ds.l	1
cp_con1:	ds.l	1
cp_bpl:		ds.l	1
cp_col0:	ds.l	1
cp_con0:	ds.l	1
gradptr:	ds.l	PFH
cp_botcon:	ds.l	1
cp_botcol:	ds.l	1
; display
titlemode:	ds.w	1
dmode:		ds.w	1
camx:		ds.w	1
clipbot:	ds.w	1
sprscr:		ds.w	1
pfpal:		ds.l	1			; the 16 playfield colours in use
; sprites
nobj:		ds.w	1
objs:		ds.b	16*24
sprwp:		ds.l	8
sprnext:	ds.w	8
; the yo-yo string on plane 3
strdrawn:	ds.w	1
strx0:		ds.w	1
strx1:		ds.w	1
stry:		ds.w	1
; sound
sfxpend:	ds.b	4
musicon:	ds.w	1
musplay:	ds.w	1
musdone:	ds.w	1
mvbase:		ds.w	2
mvptr:		ds.l	2
mvstart:	ds.l	2
mvcnt:		ds.w	2
mvvol:		ds.w	2
paused:		ds.w	1
; text
numbuf:		ds.b	12
linebuf:	ds.b	44
msgbuf:		ds.b	40
chbuf:		ds.w	1
namebuf:	ds.l	1
; high scores
hiscore:	ds.l	1
hichanged:	ds.w	1
hitab:		ds.b	HSN*8
filebuf:	ds.b	4+HSN*8+4
; title
titlepage:	ds.w	1
titletime:	ds.w	1
devmode:	ds.w	1
devused:	ds.w	1
devinv:		ds.w	1
devlevel:	ds.w	1
devloop:	ds.w	1
; the game
score:		ds.l	1
nextlife:	ds.l	1
lives:		ds.w	1
level:		ds.w	1
loop:		ds.w	1
levptr:		ds.l	1
lvstyle:	ds.w	1
lvsky:		ds.w	1
lvtime:		ds.w	1
keysleft:	ds.w	1
keystotal:	ds.w	1
tleft:		ds.w	1
dark:		ds.w	1
startx:		ds.w	1
starty:		ds.w	1
px:		ds.w	1
py:		ds.w	1
pst:		ds.w	1
pdir:		ds.w	1
jdx:		ds.w	1
jt:		ds.w	1
ftop:		ds.w	1
panim:		ds.w	1
pmoved:		ds.w	1
invul:		ds.w	1
deadt:		ds.w	1
ystate:		ds.w	1
ylen:		ds.w	1
ybx:		ds.w	1
yby:		ds.w	1
hudtime:	ds.w	1
levelclear:	ds.w	1
gameover:	ds.w	1
mstimer:	ds.w	1
msnext:		ds.w	1
rnd:		ds.l	1
nenemies:	ds.w	1
enemies:	ds.b	EN_SIZE*MAXEN
missiles:	ds.b	MS_SIZE*MAXMS
lmap:		ds.b	LVW*LVH
gmap:		ds.b	LVW*LVH
	even

	section	chipvars,bss_c
coplist:	ds.l	800
screen:		ds.b	PLANE*4
sprlists:	ds.b	SPRLEN*8
lvbm:		ds.b	LVBMSIZE
	end
