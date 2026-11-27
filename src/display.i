;=====================================================================
; display.i - the copper list, scrolling, the four views (normal,
; upside down, turned 90 degrees, black and white), the level bitmap,
; the sprite multiplexer and the yo-yo string
;
; Screen lines 0-27: the score panel (the screen bitmap). Lines 28-219:
; the playfield, the level bitmap (or, on the title, the rest of the
; screen bitmap). The level bitmap is interleaved (4 planes per line):
;   normal: 992 x 192 (16 pixels free on the left), scrolled with the
;           pointers and BPLCON1; upside down = the same bitmap shown
;           from the last line up (negative modulo)
;   turned: 320 x 960, the level turned 90 degrees clockwise in the
;           middle (x 64-255), scrolled down with the pointers
; Tiles use colours 0-7 (planes 0-2); plane 3 holds only the yo-yo
; string, so colours 8-15 are the string colour.
;=====================================================================
InitAll:
	lea	CUSTOM,a5
	bsr	BuildCopper
	bsr	ClearScreen
	bsr	InitSound
	move.w	#1,titlemode
	bsr	ClearSprites
	move.l	#$12345678,rnd
	bsr	WaitFrame
	move.l	#coplist,COP1LC(a5)
	move.w	d0,COPJMP1(a5)
	move.w	#$83af,DMACON(a5)		; bitplanes, copper, sprites, audio 0-3
	rts

CMOVE	macro
	move.l	#(\1<<16)|(\2&$ffff),(a0)+
	endm

BuildCopper:
	lea	coplist,a0
	CMOVE	$008e,$2c81			; DIWSTRT
	CMOVE	$0090,$2cc1			; DIWSTOP
	CMOVE	$0092,$0038			; DDFSTRT
	CMOVE	$0094,$00d0			; DDFSTOP
	CMOVE	$0106,$0c00			; BPLCON3 (ECS/AGA: as OCS)
	CMOVE	$01fc,$0000			; FMODE (AGA: as OCS)
	CMOVE	$0100,$4200			; 4 bitplanes
	CMOVE	$0102,$0000
	CMOVE	$0104,$0024			; sprites in front
	CMOVE	$0108,$0000
	CMOVE	$010a,$0000
	; the score panel: the screen bitmap
	move.l	#screen,d0
	move.w	#$00e0,d1
	moveq	#3,d2
.bp:	move.w	d1,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d1
	move.w	d1,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d1
	add.l	#PLANE,d0
	dbf	d2,.bp
	; the sprite lists
	lea	sprlists,a1
	move.w	#$0120,d1
	moveq	#7,d2
.sp:	move.l	a1,d0
	move.w	d1,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d1
	move.w	d1,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d1
	lea	SPRLEN(a1),a1
	dbf	d2,.sp
	; colours 0-15 (the panel) and 16-31 (sprites)
	move.l	a0,cp_hud
	lea	hudpal,a1
	move.w	#$0180,d1
	moveq	#15,d2
.c1:	move.w	d1,(a0)+
	move.w	(a1)+,(a0)+
	addq.w	#2,d1
	dbf	d2,.c1
	move.l	a0,cp_spr
	lea	sprpal,a1
	moveq	#15,d2
.c2:	move.w	d1,(a0)+
	move.w	(a1)+,(a0)+
	addq.w	#2,d1
	dbf	d2,.c2
	; line 26 of the panel (empty): the playfield colours 1-15
	move.l	#(($2c+PFTOP-2)<<24)|$07fffe,(a0)+
	move.l	a0,cp_pf
	move.w	#$0182,d1
	moveq	#14,d2
.c3:	move.w	d1,(a0)+
	clr.w	(a0)+
	addq.w	#2,d1
	dbf	d2,.c3
	; line 27: no bitplanes for a line, the playfield registers
	move.l	#(($2c+PFTOP-1)<<24)|$07fffe,(a0)+
	CMOVE	$0100,$0200
	move.w	#$0092,(a0)+
	move.l	a0,cp_ddf
	move.w	#$0038,(a0)+
	move.w	#$0108,(a0)+
	move.l	a0,cp_mod1
	clr.w	(a0)+
	move.w	#$010a,(a0)+
	move.l	a0,cp_mod2
	clr.w	(a0)+
	move.w	#$0102,(a0)+
	move.l	a0,cp_con1
	clr.w	(a0)+
	move.l	a0,cp_bpl
	move.w	#$00e0,d1
	moveq	#11,d2
.bp2:	move.w	d1,(a0)+
	clr.w	(a0)+
	addq.w	#2,d1
	dbf	d2,.bp2
	; lines 28-219: the playfield, colour 0 per line (the sky)
	lea	gradptr,a1
	moveq	#0,d2
.gl:	move.w	d2,d0
	add.w	#$2c+PFTOP,d0
	cmp.w	#$100,d0
	bne	.nw
	move.l	#$ffdffffe,(a0)+		; past line 255
.nw:	lsl.w	#8,d0
	or.w	#$07,d0
	move.w	d0,(a0)+
	move.w	#$fffe,(a0)+
	tst.w	d2
	bne	.nc
	move.w	#$0100,(a0)+			; the first line: the bitplanes on
	move.l	a0,cp_con0
	move.w	#$4200,(a0)+
.nc:	move.w	#$0180,(a0)+
	move.l	a0,(a1)+
	clr.w	(a0)+
	addq.w	#1,d2
	cmp.w	#PFH,d2
	bne	.gl
	move.l	gradptr,cp_col0
	; after the playfield (line 224): the message panel, the screen bitmap
	; again with the panel colours
	move.l	#((($2c+PFTOP+PFH)&$ff)<<24)|$07fffe,(a0)+
	CMOVE	$0100,$0200
	move.w	#$0180,(a0)+
	move.l	a0,cp_botcol
	clr.w	(a0)+
	CMOVE	$0092,$0038
	CMOVE	$0102,$0000
	CMOVE	$0108,$0000
	CMOVE	$010a,$0000
	move.l	#screen+(PFTOP+PFH)*40,d0
	move.w	#$00e0,d1
	moveq	#3,d2
.bb:	move.w	d1,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d1
	move.w	d1,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d1
	add.l	#PLANE,d0
	dbf	d2,.bb
	move.l	a0,cp_botpal
	lea	hudpal+2,a1
	move.w	#$0182,d1
	moveq	#14,d2
.bc:	move.w	d1,(a0)+
	move.w	(a1)+,(a0)+
	addq.w	#2,d1
	dbf	d2,.bc
	move.l	#((($2c+PFTOP+PFH+1)&$ff)<<24)|$07fffe,(a0)+
	move.w	#$0100,(a0)+
	move.l	a0,cp_botcon
	move.w	#$4200,(a0)+
	move.l	#$fffffffe,(a0)+
	rts

; SetPFPal: a0 = 16 colours for the playfield
SetPFPal:
	movem.l	d0-d1/a0-a2,-(sp)
	move.w	(a0)+,d1
	lea	gradptr,a2
	move.w	#PFH-1,d0
.g:	move.l	(a2)+,a1
	move.w	d1,(a1)
	dbf	d0,.g
	move.l	cp_pf,a1
	moveq	#14,d0
.l:	move.w	(a0)+,2(a1)
	addq.l	#4,a1
	dbf	d0,.l
	movem.l	(sp)+,d0-d1/a0-a2
	rts

; SetGrad: a0 = 192 colours for colour 0 (the sky), d0 <> 0 upside down
SetGrad:
	movem.l	d0-d1/a0-a2,-(sp)
	lea	gradptr,a2
	move.w	#PFH-1,d1
	tst.w	d0
	beq	.l
	lea	PFH*2(a0),a0
.u:	move.l	(a2)+,a1
	move.w	-(a0),(a1)
	dbf	d1,.u
	bra	.x
.l:	move.l	(a2)+,a1
	move.w	(a0)+,(a1)
	dbf	d1,.l
.x:	movem.l	(sp)+,d0-d1/a0-a2
	rts

; SetScreenPal: a0 = 16 colours for the screen bitmap parts (the panels,
; and the title / playfield part when the screen bitmap is shown there)
SetScreenPal:
	movem.l	d0/a0-a2,-(sp)
	move.l	a0,a2
	move.l	cp_hud,a1
	moveq	#15,d0
.h:	move.w	(a2)+,2(a1)
	addq.l	#4,a1
	dbf	d0,.h
	lea	2(a0),a2
	move.l	cp_botpal,a1
	moveq	#14,d0
.b:	move.w	(a2)+,2(a1)
	addq.l	#4,a1
	dbf	d0,.b
	move.l	cp_botcol,a1
	move.w	(a0),(a1)
	movem.l	(sp)+,d0/a0-a2
	rts

; SetSprPal: a0 = the 16 sprite colours
SetSprPal:
	movem.l	d0/a0-a1,-(sp)
	move.l	cp_spr,a1
	moveq	#15,d0
.l:	move.w	(a0)+,2(a1)
	addq.l	#4,a1
	dbf	d0,.l
	movem.l	(sp)+,d0/a0-a1
	rts

; SetTitleDisplay: the whole screen bitmap, panel colours everywhere
SetTitleDisplay:
	move.w	#1,titlemode
	move.w	#-PFTOP,cliptop
	lea	hudpal,a0
	bsr	SetScreenPal
	move.w	#256-PFTOP,clipbot
	move.w	#1,sprscr
	clr.w	camx
	clr.w	strdrawn
	move.l	#hudpal,pfpal
	lea	hudpal,a0
	bsr	SetPFPal
	move.l	cp_botcon,a0
	move.w	#$4200,(a0)
	move.l	cp_con0,a0
	move.w	#$4200,(a0)
	move.l	cp_botcol,a0
	clr.w	(a0)
	lea	sprpal,a0
	bsr	SetSprPal
	bsr	ClearSprites
	bra	PFRegs

; SetGameDisplay: the level bitmap below the panel
SetGameDisplay:
	clr.w	titlemode
	clr.w	cliptop
	clr.w	sprscr
	move.w	#PFH,clipbot
	move.l	cp_con0,a0
	move.w	#$6600,(a0)			; 6 planes, dual playfield
	bsr	ClearSprites
	bra	PFRegs

; ClearSprites: every sprite list empty
ClearSprites:
	movem.l	d0/a0,-(sp)
	lea	sprlists,a0
	moveq	#7,d0
.l:	clr.l	(a0)
	lea	SPRLEN(a0),a0
	dbf	d0,.l
	clr.w	nobj
	movem.l	(sp)+,d0/a0
	rts

;---------------------------------------------------------------------
; UpdateDisplay: once per frame, right after WaitFrame (the bottom of
; the screen): the scroll registers, the colours, the sprites, the string
PFRegs:
UpdateDisplay:
	movem.l	d0-d7/a0-a3,-(sp)
	tst.w	titlemode
	beq	.game
	; the title: the screen bitmap from line 28 on
	move.l	cp_ddf,a0
	move.w	#$0038,(a0)
	move.l	cp_mod1,a0
	clr.w	(a0)
	move.l	cp_mod2,a0
	clr.w	(a0)
	move.l	cp_con1,a0
	clr.w	(a0)
	move.l	#screen+PFTOP*40,d0		; planes 1, 3 (and 5)
	move.l	#PLANE*2,d1
	move.l	#screen+PFTOP*40+PLANE,d2	; planes 2, 4 (and 6)
	move.l	d1,d3
	bsr	.ptrs
	bra	.spr
.game:	move.w	dmode,d7
	move.w	camx,d4				; the jungle moves at half speed
	lsr.w	#1,d4
	cmp.w	#320,d4
	blo	.bx
	sub.w	#320,d4
.bx:	cmp.w	#DM_ROT,d7
	bne	.nrot
	move.l	cp_ddf,a0
	move.w	#$0038,(a0)
	move.l	cp_mod1,a0
	move.w	#RRB*2,(a0)
	move.l	cp_mod2,a0
	move.w	#RRB*2,(a0)
	move.l	cp_con1,a0
	clr.w	(a0)
	move.w	camx,d0
	mulu	#RSTR,d0
	add.l	#lvbm,d0
	moveq	#RRB,d1
	mulu	#BRSTR,d4
	move.l	#bgR,d2
	add.l	d4,d2
	moveq	#40,d3
	bsr	.ptrs
	bra	.col
.nrot:	; the level: pointer word q, delay d (fine scroll)
	move.w	camx,d0
	bsr	.fine
	move.w	d1,d6				; PF1 delay
	add.w	d0,d0
	ext.l	d0
	add.l	#lvbm,d0
	move.l	d0,a2
	move.w	d4,d0				; the jungle
	bsr	.fine
	lsl.w	#4,d1
	or.w	d1,d6				; PF2 delay
	move.l	cp_con1,a0
	move.w	d6,(a0)
	add.w	d0,d0
	ext.l	d0
	add.l	#bgN,d0
	move.l	d0,d2
	move.l	a2,d0
	move.l	cp_ddf,a0
	move.w	#$0030,(a0)
	move.w	#NSTR-42,d4
	move.w	#BNSTR-42,d5
	cmp.w	#DM_FLIP,d7
	bne	.nf
	add.l	#NSTR*(PFH-1),d0
	add.l	#BNSTR*(PFH-1),d2
	move.w	#-NSTR-42,d4
	move.w	#-BNSTR-42,d5
.nf:	move.l	cp_mod1,a0
	move.w	d4,(a0)
	move.l	cp_mod2,a0
	move.w	d5,(a0)
	moveq	#NRB,d1
	moveq	#BNRB,d3
	bsr	.ptrs
.col:	; the colours: black and white flashes now and then
	cmp.w	#DM_BW,dmode
	bne	.spr
	move.l	pfpal,a0
	move.l	frame,d0
	and.w	#127,d0
	cmp.w	#6,d0
	bhs	.nfl
	lea	linebuf,a1			; inverted for 6 frames
	moveq	#15,d1
.inv:	move.w	(a0)+,d2
	eor.w	#$fff,d2
	move.w	d2,(a1)+
	dbf	d1,.inv
	lea	linebuf,a0
.nfl:	bsr	SetPFPal
.spr:	bsr	BuildSprites
	tst.w	titlemode
	bne	.x
	bsr	DrawString
.x:	movem.l	(sp)+,d0-d7/a0-a3
	rts
; .fine: d0 = scroll x -> d0 = first word, d1 = delay
.fine:	move.w	d0,d1
	add.w	#15,d0
	lsr.w	#4,d0
	move.w	d0,d5
	lsl.w	#4,d5
	sub.w	d1,d5
	move.w	d5,d1
	rts
; .ptrs: playfield 1 (planes 1, 3, 5) from d0, d1 apart;
;        playfield 2 (planes 2, 4, 6) from d2, d3 apart -> the copper
.ptrs:	move.l	cp_bpl,a0
	moveq	#2,d5
.pl:	swap	d0
	move.w	d0,2(a0)
	swap	d0
	move.w	d0,6(a0)
	swap	d2
	move.w	d2,10(a0)
	swap	d2
	move.w	d2,14(a0)
	lea	16(a0),a0
	add.l	d1,d0
	add.l	d3,d2
	dbf	d5,.pl
	rts

;=====================================================================
; the level bitmap
;=====================================================================
; DrawLevelGfx: the whole level from gmap into the bitmap of the view
DrawLevelGfx:
	movem.l	d0-d7/a0-a1,-(sp)
	lea	lvbm,a0
	move.l	#LVBMSIZE/32-1,d0
	moveq	#0,d1
.cl:	move.l	d1,(a0)+
	move.l	d1,(a0)+
	move.l	d1,(a0)+
	move.l	d1,(a0)+
	move.l	d1,(a0)+
	move.l	d1,(a0)+
	move.l	d1,(a0)+
	move.l	d1,(a0)+
	subq.l	#1,d0
	bpl	.cl
	cmp.w	#DM_ROT,dmode
	bne	.tiles
	; turned: black on both sides of the level (colour 1)
	lea	lvbm,a0
	move.w	#960-1,d0
	moveq	#-1,d1
.side:	move.l	d1,(a0)
	move.l	d1,4(a0)
	move.l	d1,32(a0)
	move.l	d1,36(a0)
	lea	RSTR(a0),a0
	dbf	d0,.side
.tiles:	lea	gmap,a1
	moveq	#0,d1				; row
.r:	moveq	#0,d0				; column
.c:	moveq	#0,d2
	move.b	(a1)+,d2
	beq	.n
	bsr	DrawTile
.n:	addq.w	#1,d0
	cmp.w	#LVW,d0
	bne	.c
	addq.w	#1,d1
	cmp.w	#LVH,d1
	bne	.r
	movem.l	(sp)+,d0-d7/a0-a1
	rts

; DrawTile: d0 = column, d1 = row, d2 = tile
DrawTile:
	movem.l	d0-d4/a0-a3,-(sp)
	mulu	#96,d2
	cmp.w	#DM_ROT,dmode
	beq	.rot
	lea	tilesN,a1
	add.l	d2,a1
	lea	lvbm+2,a0
	add.w	d0,d0
	add.w	d0,a0
	mulu	#NSTR*16,d1
	add.l	d1,a0
	move.w	#NSTR,d3
	moveq	#NRB,d4
	bra	.draw
.rot:	lea	tilesR,a1
	add.l	d2,a1
	lea	lvbm+8,a0
	moveq	#LVH-1,d2
	sub.w	d1,d2
	add.w	d2,d2
	add.w	d2,a0
	mulu	#RSTR*16,d0
	add.l	d0,a0
	move.w	#RSTR,d3
	moveq	#RRB,d4
.draw:	lea	(a0,d4.w),a2
	lea	(a2,d4.w),a3
	moveq	#15,d0
.l:	move.w	(a1)+,(a0)
	move.w	(a1)+,(a2)
	move.w	(a1)+,(a3)
	add.w	d3,a0
	add.w	d3,a2
	add.w	d3,a3
	dbf	d0,.l
	movem.l	(sp)+,d0-d4/a0-a3
	rts

;=====================================================================
; the yo-yo string: XOR colour 6 (gold) into the level bitmap; the same
; XOR again takes it away and leaves the trunks as they were
;=====================================================================
DrawString:
	movem.l	d0-d6/a0,-(sp)
	tst.w	strdrawn			; take the old one away
	beq	.new
	clr.w	strdrawn
	move.w	strx0,d0
	move.w	strx1,d1
	move.w	stry,d2
	bsr	XorString
.new:	tst.w	ystate
	beq	.x
	cmp.w	#ST_DEAD,pst
	beq	.x
	; from the hand to the ball: x from d0 to d1 at y = d2 (world)
	move.w	ybx,d1
	bsr	HandX
	move.w	yby,d2
	cmp.w	d0,d1
	bge	.o
	exg	d0,d1
.o:	tst.w	d0
	bpl	.o1
	moveq	#0,d0
.o1:	cmp.w	#959,d1
	ble	.o2
	move.w	#959,d1
.o2:	cmp.w	d0,d1
	blt	.x
	move.w	d0,strx0
	move.w	d1,strx1
	move.w	d2,stry
	bsr	XorString
	move.w	#1,strdrawn
.x:	movem.l	(sp)+,d0-d6/a0
	rts

; XorString: world x d0 to d1 at world y d2
XorString:
	movem.l	d0-d5/a0,-(sp)
	cmp.w	#DM_ROT,dmode
	beq	.vert
	; a row: bitmap x = world x + 16, planes 1 and 2
	lea	lvbm+NRB,a0
	mulu	#NSTR,d2
	add.l	d2,a0
	add.w	#16,d0
	add.w	#16,d1
.hl:	move.w	d0,d3
	lsr.w	#3,d3
	move.w	d0,d4
	not.w	d4
	and.w	#7,d4
	bchg	d4,(a0,d3.w)
	bchg	d4,NRB(a0,d3.w)
	addq.w	#1,d0
	cmp.w	d1,d0
	ble	.hl
	bra	.x
.vert:	; a column: bitmap x = 64 + 191 - y, bitmap line = world x
	move.w	#64+191,d3
	sub.w	d2,d3
	move.w	d3,d4
	lsr.w	#3,d4
	not.w	d3
	and.w	#7,d3				; the bit
	lea	lvbm+RRB,a0
	add.w	d4,a0
	move.w	d0,d5
	mulu	#RSTR,d5
	add.l	d5,a0
	move.w	d1,d5
	sub.w	d0,d5
.vl:	bchg	d3,(a0)
	bchg	d3,RRB(a0)
	lea	RSTR(a0),a0
	dbf	d5,.vl
.x:	movem.l	(sp)+,d0-d5/a0
	rts

;=====================================================================
; sprites: every object is collected (AddBig / AddSmall), then sorted
; top to bottom and put in the sprite lists; a channel shows several
; objects one below the other (multiplexing).
;   channels 0+1: Stronkie   2: the yo-yo   3: balloons, daggers
;   4+5 and 6+7: the monsters (32 pixels wide, two channels each)
;=====================================================================
OB_SX	equ	0
OB_SY	equ	2
OB_H	equ	4
OB_PTR	equ	6
OB_STEP	equ	10
OB_W	equ	12			; 1 or 2 channels
OB_GRP	equ	14			; 0 Stronkie, 1 monster, 2 yo-yo, 3 balloon/dagger,
					; 4 decoration (big), 5 decoration (small)
OB_CH	equ	16			; the channel it got (-1 none)
OB_SIZE	equ	20
MAXOBJ	equ	24

; ToScreen: d0 = world x, d1 = world y, d4 = size (16 or 32)
;   -> d0 = screen x, d1 = screen y (playfield), d5 = 1 turned
ToScreen:
	moveq	#0,d5
	tst.w	sprscr
	bne	.x
	move.w	dmode,d5
	cmp.w	#DM_ROT,d5
	beq	.rot
	sub.w	camx,d0
	cmp.w	#DM_FLIP,d5
	bne	.n
	move.w	#PFH,d5
	sub.w	d4,d5
	sub.w	d1,d5
	move.w	d5,d1
.n:	moveq	#0,d5
.x:	rts
.rot:	move.w	#256,d5
	sub.w	d4,d5
	sub.w	d1,d5				; screen x = 256 - size - y
	sub.w	camx,d0				; screen y = x - camera
	exg	d0,d5
	move.w	d5,d1
	moveq	#1,d5
	rts

; AddBig: d0 = x, d1 = y, d2 = picture, d3 = group (0 Stronkie, 1 monster)
AddBig:
	movem.l	d0-d5/a0-a1,-(sp)
	moveq	#32,d4
	bsr	ToScreen
	lea	bigN,a1
	tst.w	d5
	beq	.n
	lea	bigR,a1
.n:	mulu	#256,d2
	add.l	d2,a1
	moveq	#2,d2
	bra	AddObj
; AddSmall: d0 = x, d1 = y, d2 = picture, d3 = group (2 yo-yo, 3 balloon/dagger)
AddSmall:
	movem.l	d0-d5/a0-a1,-(sp)
	moveq	#16,d4
	bsr	ToScreen
	lea	smallN,a1
	tst.w	d5
	beq	.n
	lea	smallR,a1
.n:	lsl.w	#6,d2
	add.w	d2,a1
	moveq	#1,d2
AddObj:	; d0/d1 screen, d2 width, d3 group, d4 size, a1 data
	move.w	cliptop,d5
	sub.w	d4,d5
	cmp.w	d5,d0
	ble	.x
	cmp.w	#320,d0
	bge	.x
	cmp.w	d5,d1
	ble	.x
	cmp.w	clipbot,d1
	bge	.x
	move.w	nobj,d5
	cmp.w	#MAXOBJ,d5
	bhs	.x
	addq.w	#1,nobj
	mulu	#OB_SIZE,d5
	lea	objs,a0
	add.w	d5,a0
	move.w	d0,OB_SX(a0)
	move.w	d1,OB_SY(a0)
	move.w	d4,OB_H(a0)
	move.w	d2,OB_W(a0)
	move.w	d3,OB_GRP(a0)
	move.w	#4,OB_STEP(a0)
	tst.w	sprscr
	bne	.p
	cmp.w	#DM_FLIP,dmode
	bne	.p
	move.w	#-4,OB_STEP(a0)			; upside down: the lines from the bottom
	move.w	d4,d5
	subq.w	#1,d5
	lsl.w	#2,d5
	add.w	d5,a1
.p:	move.l	a1,OB_PTR(a0)
.x:	movem.l	(sp)+,d0-d5/a0-a1
	rts

; BuildSprites: sort the objects top to bottom, give out the channels in
; order of importance, then fill the lists (top to bottom per channel)
BuildSprites:
	movem.l	d0-d7/a0-a4,-(sp)
	lea	sprlists,a0
	lea	sprwp,a1
	moveq	#7,d0
.i:	move.l	a0,(a1)+
	lea	SPRLEN(a0),a0
	dbf	d0,.i
	move.w	nobj,d7
	beq	.end
	; insertion sort on the screen y
	cmp.w	#2,d7
	blo	.sorted
	lea	objs,a0
	moveq	#1,d6
.s1:	move.w	d6,d5
.s2:	move.w	d5,d0
	mulu	#OB_SIZE,d0
	lea	(a0,d0.w),a1
	lea	-OB_SIZE(a1),a2
	move.w	OB_SY(a2),d1
	cmp.w	OB_SY(a1),d1
	ble	.s3
	moveq	#OB_SIZE/4-1,d2
.sw:	move.l	(a1),d3
	move.l	(a2),(a1)+
	move.l	d3,(a2)+
	dbf	d2,.sw
	subq.w	#1,d5
	bne	.s2
.s3:	addq.w	#1,d6
	cmp.w	d7,d6
	blo	.s1
.sorted:
	; no channel yet
	lea	objs,a3
	move.w	d7,d0
	subq.w	#1,d0
.nc:	move.w	#-1,OB_CH(a3)
	lea	OB_SIZE(a3),a3
	dbf	d0,.nc
	; the passes: Stronkie, yo-yo, balloons, monsters, birds, monkey
	lea	passes,a4
.pass:	move.w	(a4)+,d6			; the group
	bmi	.emit
	lea	objs,a3
	move.w	nobj,d5
	subq.w	#1,d5
.po:	cmp.w	OB_GRP(a3),d6
	bne	.pn
	lea	grpchans,a0			; 2 channels to try
	move.w	d6,d0
	add.w	d0,d0
	add.w	d0,d0
	add.w	d0,a0
	move.w	(a0)+,d1
	bsr	.free
	beq	.got
	move.w	(a0),d1
	bmi	.pn
	bsr	.free
	bne	.pn
.got:	move.w	d1,OB_CH(a3)
.pn:	lea	OB_SIZE(a3),a3
	dbf	d5,.po
	bra	.pass
.emit:	lea	objs,a3
	move.w	nobj,d7
	subq.w	#1,d7
.o:	move.w	OB_CH(a3),d1
	bmi	.next
	bsr	Emit
.next:	lea	OB_SIZE(a3),a3
	dbf	d7,.o
.end:	lea	sprwp,a1
	moveq	#7,d0
.t:	move.l	(a1)+,a0
	clr.l	(a0)
	dbf	d0,.t
	clr.w	nobj
	movem.l	(sp)+,d0-d7/a0-a4
	rts
; .free: can object a3 use channel d1 (and d1+1 when 32 wide)? Z = yes
.free:	movem.l	d0-d5/a1,-(sp)
	move.w	OB_SY(a3),d2			; top
	move.w	d2,d3
	add.w	OB_H(a3),d3			; bottom + 1
	move.w	d1,d4				; the channels it needs: d4..d5
	move.w	d1,d5
	cmp.w	#2,OB_W(a3)
	bne	.f0
	addq.w	#1,d5
.f0:	lea	objs,a1
	move.w	nobj,d0
	subq.w	#1,d0
.fl:	cmp.l	a1,a3
	beq	.fn
	move.w	OB_CH(a1),d1
	bmi	.fn
	; does it use one of our channels?
	cmp.w	d5,d1
	bgt	.fn
	cmp.w	#2,OB_W(a1)
	bne	.f1
	addq.w	#1,d1
.f1:	cmp.w	d4,d1
	blt	.fn
	; and do they overlap (with 2 lines between)?
	move.w	OB_SY(a1),d1
	sub.w	#2,d1
	cmp.w	d3,d1
	bge	.fn
	move.w	OB_SY(a1),d1
	add.w	OB_H(a1),d1
	addq.w	#2,d1
	cmp.w	d2,d1
	ble	.fn
	moveq	#1,d0				; busy
	bra	.fx
.fn:	lea	OB_SIZE(a1),a1
	dbf	d0,.fl
	moveq	#0,d0
.fx:	tst.w	d0
	movem.l	(sp)+,d0-d5/a1
	rts
passes:		dc.w	0,2,3,1,5,4,-1
grpchans:	dc.w	0,-1			; Stronkie
		dc.w	4,6			; monsters
		dc.w	2,-1			; the yo-yo
		dc.w	3,-1			; balloons, daggers
		dc.w	4,6			; the monkey
		dc.w	3,2			; birds

; Emit: object a3 into channel d1 (and d1+1 when 32 wide)
Emit:	movem.l	d0-d7/a0-a2,-(sp)
	move.w	OB_SY(a3),d2			; top
	move.w	OB_H(a3),d3			; lines
	move.l	OB_PTR(a3),a1
	move.w	OB_STEP(a3),d6
	cmp.w	cliptop,d2
	bge	.t
	move.w	cliptop,d4			; cut the lines above the playfield
	sub.w	d2,d4
	sub.w	d4,d3
	muls	d6,d4
	add.w	d4,a1
	move.w	cliptop,d2
.t:	move.w	d2,d4
	add.w	d3,d4
	sub.w	clipbot,d4
	ble	.b
	sub.w	d4,d3				; and below it
.b:	tst.w	d3
	ble	.x
	; the control words
	move.w	d2,d4
	add.w	#$2c+PFTOP,d4			; vstart
	move.w	d4,d5
	add.w	d3,d5				; vstop
	move.w	OB_SX(a3),d0
	add.w	#$80,d0				; hstart
	bsr	.one
	cmp.w	#2,OB_W(a3)
	bne	.done
	addq.w	#1,d1
	add.w	#16,d0
	move.l	OB_PTR(a3),a1			; the right half: 32 lines further
	lea	128(a1),a1
	move.w	cliptop,d4
	sub.w	OB_SY(a3),d4
	ble	.r
	muls	d6,d4
	add.w	d4,a1
.r:	move.w	d2,d4
	add.w	#$2c+PFTOP,d4
	bsr	.one
.done:	move.w	d2,d4				; the channel is busy until here
	add.w	d3,d4
	addq.w	#2,d4
	subq.w	#1,d1
	cmp.w	#2,OB_W(a3)
	beq	.nw
	addq.w	#1,d1
.nw:	lea	sprnext,a2
	move.w	d1,d0
	add.w	d0,d0
	move.w	d4,(a2,d0.w)
	cmp.w	#2,OB_W(a3)
	bne	.x
	move.w	d4,2(a2,d0.w)
.x:	movem.l	(sp)+,d0-d7/a0-a2
	rts
; .one: channel d1, hstart d0, vstart d4, vstop d5, d3 lines from a1 (step d6)
.one:	movem.l	d0-d7/a1,-(sp)
	lea	sprwp,a2
	move.w	d1,d7
	lsl.w	#2,d7
	move.l	(a2,d7.w),a0
	move.w	d4,d7
	lsl.w	#8,d7
	move.w	d0,d2
	lsr.w	#1,d2
	and.w	#$ff,d2
	or.w	d2,d7
	move.w	d7,(a0)+			; pos
	move.w	d5,d7
	lsl.w	#8,d7
	btst	#8,d4
	beq	.a
	bset	#2,d7
.a:	btst	#8,d5
	beq	.b2
	bset	#1,d7
.b2:	btst	#0,d0
	beq	.c
	bset	#0,d7
.c:	move.w	d7,(a0)+			; ctl
	subq.w	#1,d3
.l:	move.l	(a1),(a0)+
	add.w	d6,a1
	dbf	d3,.l
	lea	sprwp,a2
	move.w	d1,d7
	lsl.w	#2,d7
	move.l	a0,(a2,d7.w)
	movem.l	(sp)+,d0-d7/a1
	rts
