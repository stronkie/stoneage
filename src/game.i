;=====================================================================
; game.i - the game: levels, Stronkie, the yo-yo, the monsters, the
; balloons and daggers, the timer and the darkness, the score panel
; The player physics are the same as in tools/levels.py (the level
; checker): keep both the same.
;=====================================================================
Game:	clr.l	score
	move.l	#20000,nextlife
	move.w	#LIVES,lives
	clr.w	level
	clr.w	loop
	move.w	devmode,devused
	clr.w	devinv
	tst.w	devmode
	beq	.lv
	move.w	devlevel,level
	move.w	devloop,loop
.lv:	clr.w	gameover
	bsr	StartLevel
.fr:	bsr	WaitFrame
	bsr	UpdateDisplay
	tst.w	quitnow
	bne	.x
	bsr	GameFrame
	tst.w	gameover
	bne	.over
	tst.w	levelclear
	beq	.fr
	bsr	LevelDone
	tst.w	quitnow
	bne	.x
	addq.w	#1,level
	ifne	DEMO
	cmp.w	#2,level
	blo	.lv
	bsr	DemoEnd
	bra	.end
	endc
	cmp.w	#NLEVELS,level
	blo	.lv
	clr.w	level
	addq.w	#1,loop
	moveq	#0,d0
	move.l	#5000,d0
	bsr	AddScore
	bsr	LoopScreen
	tst.w	quitnow
	bne	.x
	bra	.lv
.over:	bsr	GameOver
.end:	bsr	GameEnd
.x:	bsr	StopMusic
	rts

;---------------------------------------------------------------------
; StartLevel: load the level, draw it, show it, get ready
StartLevel:
	move.w	loop,d0
	and.w	#3,d0
	move.w	d0,dmode
	lea	levtab,a0
	move.w	level,d0
	lsl.w	#2,d0
	move.l	(a0,d0.w),a0
	move.l	a0,levptr
	move.w	(a0)+,startx
	move.w	(a0)+,starty
	move.w	(a0)+,lvtime
	move.w	(a0)+,lvsky
	move.w	(a0)+,keysleft
	move.w	keysleft,keystotal
	move.w	(a0)+,lvstyle
	move.w	(a0)+,d7			; the monsters
	move.w	d7,nenemies
	lea	enemies,a1
	subq.w	#1,d7
	bmi	.ne
.en:	move.w	(a0)+,EN_TYPE(a1)
	move.w	(a0),EN_X(a1)
	move.w	(a0)+,EN_SPX(a1)
	move.w	(a0),EN_Y(a1)
	move.w	(a0),EN_BASEY(a1)
	move.w	(a0)+,EN_SPY(a1)
	move.w	(a0)+,EN_MIN(a1)
	move.w	(a0)+,EN_MAX(a1)
	move.w	#1,EN_DIR(a1)
	clr.w	EN_STATE(a1)
	clr.w	EN_TIMER(a1)
	clr.w	EN_PHASE(a1)
	lea	EN_SIZE(a1),a1
	dbf	d7,.en
.ne:	tst.b	(a0)+				; the name
	bne	.ne
	move.l	a0,d0
	addq.l	#1,d0
	and.w	#$fffe,d0
	move.l	d0,a0
	lea	lmap,a1
	move.w	#LVW*LVH*2-1,d0			; lmap and gmap follow each other
.cp:	move.b	(a0)+,(a1)+
	dbf	d0,.cp
	; time, light
	move.w	lvtime,d0
	mulu	#50,d0
	move.w	d0,tleft
	clr.w	dark
	clr.w	levelclear
	move.w	#300,mstimer
	move.w	#1,msnext
	lea	missiles,a0
	moveq	#MAXMS*MS_SIZE/2-1,d0
.cm:	clr.w	(a0)+
	dbf	d0,.cm
	bsr	PlaceStronkie
	clr.w	invul
	bsr	StopMusic
	; the picture
	move.w	#1,titlemode			; nothing on screen while drawing
	bsr	SetTitleDisplay
	bsr	ClearScreen
	bsr	WaitFrame
	bsr	DrawLevelGfx
	bsr	SetLevelPal
	bsr	Camera
	bsr	SetGameDisplay
	bsr	MsgBox
	bsr	HudAll
	; level n: name
	lea	linebuf,a1
	lea	t_level,a0
.c1:	move.b	(a0)+,(a1)+
	bne	.c1
	subq.l	#1,a1
	bsr	LevelNumber
	move.w	d0,d1
	divu	#10,d1
	add.b	#'0',d1
	move.b	d1,(a1)+
	swap	d1
	add.b	#'0',d1
	move.b	d1,(a1)+
	move.b	#':',(a1)+
	move.b	#' ',(a1)+
	move.l	levptr,a0
	move.w	12(a0),d0			; skip the header and the monsters
	mulu	#10,d0
	lea	14(a0,d0.w),a0
.c2:	move.b	(a0)+,(a1)+
	bne	.c2
	lea	linebuf,a0
	bsr	Message
	moveq	#100,d7
.gr:	bsr	WaitFrame
	bsr	UpdateDisplay
	tst.w	quitnow
	bne	.go
	bsr	DrawActors
	dbf	d7,.gr
	lea	t_ready,a0
	bsr	Message
	moveq	#50,d7
.gr2:	bsr	WaitFrame
	bsr	UpdateDisplay
	bsr	DrawActors
	dbf	d7,.gr2
.go:	bsr	ClearMessage
	moveq	#1,d0
	bsr	PlayTune
	rts

; LevelNumber: d0 = 1, 2, 3 ... (8 per loop)
LevelNumber:
	move.w	loop,d0
	mulu	#NLEVELS,d0
	add.w	level,d0
	addq.w	#1,d0
	rts

PlaceStronkie:
	move.w	startx,px
	move.w	starty,py
	clr.w	pst
	move.w	#1,pdir
	clr.w	ystate
	clr.w	ylen
	clr.w	panim
	clr.w	pmoved
	rts

; SetLevelPal: the colours of the level (light / dark / black and white)
SetLevelPal:
	movem.l	d0/a0,-(sp)
	move.w	lvsky,d0
	lsl.w	#5,d0
	lea	skypal,a0
	tst.w	dark
	beq	.l
	lea	darkpal,a0
	bra	.s
.l:	cmp.w	#DM_BW,dmode
	bne	.s
	lea	greypal,a0
.s:	add.w	d0,a0
	move.l	a0,pfpal
	bsr	SetPFPal
	; the sky gradient (not when turned or black and white: one colour)
	move.w	dmode,d0
	cmp.w	#DM_ROT,d0
	bhs	.flat
	lea	skygrad,a0
	tst.w	dark
	beq	.g
	lea	darkgrad,a0
.g:	move.w	lvsky,d0
	mulu	#PFH*2,d0
	add.l	d0,a0
	moveq	#0,d0
	cmp.w	#DM_FLIP,dmode
	bne	.g2
	moveq	#1,d0
.g2:	bsr	SetGrad
.flat:	lea	sprpal,a0			; the sprites
	tst.w	dark
	beq	.sl
	lea	sprpaldark,a0
.sl:	cmp.w	#DM_BW,dmode
	bne	.sp
	lea	sprpalgrey,a0
.sp:	bsr	SetSprPal
	movem.l	(sp)+,d0/a0
	rts

;---------------------------------------------------------------------
; GameFrame: one frame of the game
GameFrame:
	bsr	GetKey
	cmp.w	#K_P,d0
	bne	.np
	not.w	paused
.np:	tst.w	paused
	beq	.run
	lea	t_paused,a0
	bsr	Message
	bra	DrawActors
.run:	cmp.w	#K_M,d0
	bne	.nm
	not.w	musicon
.nm:	cmp.w	#K_ESC,d0
	bne	.ne
	move.w	#1,gameover
	rts
.ne:	tst.w	devused
	beq	.nd
	cmp.w	#K_N,d0				; dev: the level is done
	bne	.d1
	clr.w	keysleft
	move.w	#1,levelclear
.d1:	cmp.w	#K_I,d0				; dev: invulnerable
	bne	.d2
	not.w	devinv
	bsr	HudAll
.d2:	cmp.w	#K_T,d0				; dev: 3 seconds left
	bne	.nd
	move.w	#150,tleft
.nd:	bsr	Player
	bsr	YoYo
	bsr	Enemies
	bsr	Missiles
	bsr	Timer
	bsr	Camera
	bsr	DrawActors
	bsr	HudUpdate
	rts

;=====================================================================
; the map
;=====================================================================
; CellAddr: d0 = column, d1 = row -> a0 = the logic map cell
CellAddr:
	move.w	d1,a0
	move.l	d2,-(sp)
	move.w	d1,d2
	mulu	#LVW,d2
	add.w	d0,d2
	lea	lmap,a0
	add.w	d2,a0
	move.l	(sp)+,d2
	rts

; Cell: d0 = column, d1 = row -> d2 = type (0 outside the level)
Cell:	moveq	#0,d2
	cmp.w	#LVW,d0
	bhs	.x
	cmp.w	#LVH,d1
	bhs	.x
	move.l	a0,-(sp)
	bsr	CellAddr
	move.b	(a0),d2
	move.l	(sp)+,a0
.x:	rts

; Solid: d0 = column, d1 = row -> d2 <> 0 when you can stand on it
Solid:	bsr	Cell
	cmp.b	#T_PLAT,d2
	beq	.y
	cmp.b	#T_PLAD,d2
	beq	.y
	moveq	#0,d2
	rts
.y:	moveq	#1,d2
	rts

; Ladder: d0 = column, d1 = row -> d2 <> 0 for a ladder / rope / chain
Ladder:	bsr	Cell
	cmp.b	#T_LAD,d2
	beq	.y
	cmp.b	#T_PLAD,d2
	beq	.y
	moveq	#0,d2
	rts
.y:	moveq	#1,d2
	rts

; Supported: d0 = x, d1 = y -> d2 <> 0 when standing on a floor
Supported:
	movem.l	d0-d1/d3,-(sp)
	moveq	#0,d2
	add.w	#PH,d1
	move.w	d1,d3
	and.w	#15,d3
	bne	.x
	cmp.w	#LVH*16+16,d1
	bge	.x
	asr.w	#4,d1
	move.w	d0,d3
	addq.w	#4,d0
	asr.w	#4,d0
	bsr	Solid
	tst.w	d2
	bne	.x
	move.w	d3,d0
	add.w	#11,d0
	asr.w	#4,d0
	bsr	Solid
.x:	movem.l	(sp)+,d0-d1/d3
	tst.w	d2
	rts

;=====================================================================
; Stronkie
;=====================================================================
Player:	move.w	pst,d0
	tst.w	invul
	beq	.ni
	subq.w	#1,invul
.ni:	clr.w	pmoved
	cmp.w	#ST_STAND,d0
	beq	PStand
	cmp.w	#ST_LADDER,d0
	beq	PLadder
	cmp.w	#ST_DEAD,d0
	beq	PDead
	bra	PFall

PStand:	move.w	joy,d7
	tst.w	ystate				; throwing: stand still
	bne	.x
	move.w	joyedge,d0
	btst	#4,d0
	beq	.nf
	move.w	#1,ystate			; throw the yo-yo
	clr.w	ylen
	moveq	#SFX_THROW,d0
	bsr	PlaySfx
	rts
.nf:	btst	#0,d7
	beq	.nup
	; up: a ladder here? (within 6 pixels of its middle)
	bsr	NearLadder
	bmi	.jump
	move.w	py,d1
	add.w	#PH-1,d1
	asr.w	#4,d1
	bsr	Ladder
	beq	.jump
	lsl.w	#4,d0
	move.w	d0,px
	move.w	#ST_LADDER,pst
	subq.w	#1,py
	rts
.jump:	moveq	#0,d0
	btst	#2,d7
	beq	.j1
	moveq	#-2,d0
	move.w	#-1,pdir
.j1:	btst	#3,d7
	beq	.j2
	moveq	#2,d0
	move.w	#1,pdir
.j2:	move.w	d0,jdx
	move.w	#ST_JUMP,pst
	clr.w	jt
	move.w	py,ftop
	moveq	#SFX_JUMP,d0
	bsr	PlaySfx
	rts
.nup:	btst	#1,d7
	beq	.ndn
	bsr	NearLadder
	bmi	.ndn
	move.w	py,d1
	add.w	#PH,d1
	asr.w	#4,d1
	bsr	Cell
	cmp.b	#T_PLAD,d2
	bne	.ndn
	lsl.w	#4,d0
	move.w	d0,px
	move.w	#ST_LADDER,pst
	addq.w	#1,py
	rts
.ndn:	moveq	#0,d1
	btst	#2,d7
	beq	.w1
	moveq	#-1,d1
.w1:	btst	#3,d7
	beq	.w2
	moveq	#1,d1
.w2:	tst.w	d1
	beq	.x
	move.w	d1,pdir
	move.w	#1,pmoved
	addq.w	#1,panim
	add.w	d1,d1
	move.w	px,d0
	add.w	d1,d0
	bsr	ClampX
	move.w	d0,px
	move.w	py,d1
	bsr	Supported
	bne	.col
	move.w	#ST_SLIDE,pst			; off the edge: slide down
	move.w	pdir,d0
	add.w	d0,d0
	move.w	d0,jdx
	move.w	py,ftop
.col:	bsr	Collect
.x:	rts

; NearLadder: d0 = the column under Stronkie's middle; N set when he
; is more than 6 pixels away from it
NearLadder:
	move.w	px,d0
	addq.w	#8,d0
	asr.w	#4,d0
	move.w	d0,d1
	lsl.w	#4,d1
	sub.w	px,d1
	bpl	.p
	neg.w	d1
.p:	cmp.w	#6,d1
	bgt	.no
	moveq	#0,d1
	rts
.no:	moveq	#-1,d1
	rts

ClampX:	tst.w	d0
	bpl	.a
	moveq	#0,d0
.a:	cmp.w	#XMAX,d0
	ble	.b
	move.w	#XMAX,d0
.b:	rts

PLadder:
	move.w	joy,d7
	move.w	px,d0
	asr.w	#4,d0
	btst	#0,d7
	beq	.nu
	move.w	py,d1
	add.w	#PH-1,d1
	asr.w	#4,d1
	bsr	Ladder
	beq	.lr
	subq.w	#1,py
	move.w	#1,pmoved
	bra	.lr
.nu:	btst	#1,d7
	beq	.lr
	move.w	py,d1
	add.w	#PH,d1
	asr.w	#4,d1
	bsr	Ladder
	beq	.lr
	addq.w	#1,py
	move.w	#1,pmoved
.lr:	moveq	#0,d1
	btst	#2,d7
	beq	.l1
	moveq	#-1,d1
.l1:	btst	#3,d7
	beq	.l2
	moveq	#1,d1
.l2:	tst.w	d1
	beq	.x
	move.w	px,d0
	move.w	d1,-(sp)
	move.w	py,d1
	bsr	Supported
	move.w	(sp)+,d1
	tst.w	d2
	beq	.x
	move.w	d1,pdir				; off the ladder, onto the floor
	move.w	#ST_STAND,pst
.x:	bra	Collect

; PFall: jumping (the jump table) or sliding (2 down, 2 across a frame)
PFall:	moveq	#2,d3
	cmp.w	#ST_JUMP,pst
	bne	.dy
	move.w	jt,d1
	addq.w	#1,jt
	moveq	#4,d3
	cmp.w	#JLEN,d1
	bhs	.dy
	lea	jumptab,a0
	move.b	(a0,d1.w),d3
	ext.w	d3
.dy:	move.w	px,d0
	add.w	jdx,d0
	bsr	ClampX
	move.w	d0,px
	tst.w	d3
	bpl	.down
	add.w	d3,py
	move.w	py,d1
	cmp.w	ftop,d1
	bge	.chk
	move.w	d1,ftop
	bra	.chk
.down:	subq.w	#1,d3
	bmi	.chk
.st:	addq.w	#1,py
	move.w	px,d0
	move.w	py,d1
	bsr	Supported
	bne	.land
	dbf	d3,.st
.chk:	move.w	py,d1
	add.w	#PH,d1
	cmp.w	#LVH*16+8,d1
	ble	Collect
	tst.w	devinv				; dev: back to the start
	beq	Die
	bra	PlaceStronkie
.land:	move.w	py,d1
	sub.w	ftop,d1
	cmp.w	#DEADLY,d1
	bgt	Die
	move.w	#ST_STAND,pst
	moveq	#SFX_LAND,d0
	bsr	PlaySfx
	bra	Collect

; Die: Stronkie is caught (not while invulnerable in dev mode)
Die:	tst.w	devinv
	bne	.x
	cmp.w	#ST_DEAD,pst
	beq	.x
	move.w	#ST_DEAD,pst
	move.w	#110,deadt
	clr.w	ystate
	moveq	#SFX_DEATH,d0
	bsr	PlaySfx
.x:	rts

PDead:	subq.w	#1,deadt
	bne	.x
	tst.w	devused
	bne	.again
	subq.w	#1,lives
	bsr	HudAll
	tst.w	lives
	bne	.again
	move.w	#1,gameover
	rts
.again:	bsr	PlaceStronkie
	move.w	#INVTIME,invul
	lea	missiles,a0
	moveq	#MAXMS*MS_SIZE/2-1,d0
.cm:	clr.w	(a0)+
	dbf	d0,.cm
	tst.w	dark				; it was dark: 30 seconds of light
	beq	.x
	clr.w	dark
	move.w	#30*50,tleft
	bsr	SetLevelPal
.x:	rts

; Collect: the keys, gems and bulbs Stronkie touches
Collect:
	movem.l	d0-d7/a0,-(sp)
	cmp.w	#ST_DEAD,pst
	beq	.x
	move.w	py,d5
	asr.w	#4,d5				; first row
	bpl	.r0
	moveq	#0,d5
.r0:	move.w	py,d6
	add.w	#PH-1,d6
	asr.w	#4,d6
	cmp.w	#LVH-1,d6
	ble	.r
	moveq	#LVH-1,d6
.r:	move.w	px,d4
	asr.w	#4,d4
	move.w	px,d7
	add.w	#PW-1,d7
	asr.w	#4,d7
	cmp.w	#LVW-1,d7
	ble	.c
	moveq	#LVW-1,d7
.c:	move.w	d4,d0
	move.w	d5,d1
	bsr	Cell
	cmp.b	#T_KEY,d2
	blo	.n
	; the middle 8 x 8 of the cell
	move.w	d0,d3
	lsl.w	#4,d3
	addq.w	#4,d3				; ix
	move.w	d3,d1
	addq.w	#8,d1
	cmp.w	px,d1				; px < ix + 8
	ble	.n
	move.w	px,d1
	add.w	#PW,d1
	cmp.w	d3,d1				; px + 16 > ix
	ble	.n
	move.w	d5,d3
	lsl.w	#4,d3
	addq.w	#4,d3				; iy
	move.w	d3,d1
	addq.w	#8,d1
	cmp.w	py,d1
	ble	.n
	move.w	py,d1
	add.w	#PH,d1
	cmp.w	d3,d1
	ble	.n
	move.w	d5,d1
	bsr	Take
.n:	addq.w	#1,d4
	cmp.w	d7,d4
	ble	.c
	move.w	px,d4
	asr.w	#4,d4
	addq.w	#1,d5
	cmp.w	d6,d5
	ble	.c
.x:	movem.l	(sp)+,d0-d7/a0
	rts

; Take: d0 = column, d1 = row, d2 = what
Take:	movem.l	d0-d2/a0,-(sp)
	bsr	CellAddr
	clr.b	(a0)
	lea	LVW*LVH(a0),a0
	clr.b	(a0)
	move.w	d2,-(sp)
	moveq	#0,d2
	bsr	DrawTile
	move.w	(sp)+,d2
	cmp.b	#T_KEY,d2
	bne	.ng
	moveq	#100,d0
	bsr	AddScore
	moveq	#SFX_KEY,d0
	bsr	PlaySfx
	subq.w	#1,keysleft
	bne	.x
	move.w	#1,levelclear
	bra	.x
.ng:	cmp.b	#T_GEM,d2
	bne	.nb
	move.l	#250,d0
	bsr	AddScore
	moveq	#SFX_GEM,d0
	bsr	PlaySfx
	bra	.x
.nb:	moveq	#100,d0				; a light bulb: 15 seconds and light
	bsr	AddScore
	moveq	#SFX_BULB,d0
	bsr	PlaySfx
	move.w	tleft,d0
	add.w	#15*50,d0
	move.w	lvtime,d1
	mulu	#50,d1
	cmp.w	d1,d0
	bls	.t
	move.w	d1,d0
.t:	move.w	d0,tleft
	tst.w	dark
	beq	.x
	clr.w	dark
	bsr	SetLevelPal
	bsr	ClearMessage
.x:	bsr	HudAll
	movem.l	(sp)+,d0-d2/a0
	rts

; AddScore: d0.l = points (an extra Stronkie at 20000, then every 30000)
AddScore:
	movem.l	d0-d1,-(sp)
	tst.w	devused
	bne	.x
	add.l	d0,score
	move.l	score,d0
	cmp.l	#999999,d0
	bls	.a
	move.l	#999999,score
.a:	cmp.l	nextlife,d0
	blo	.h
	add.l	#30000,nextlife
	addq.w	#1,lives
	moveq	#SFX_LIFE,d0
	bsr	PlaySfx
	bsr	HudAll
.h:	move.l	score,d0
	cmp.l	hiscore,d0
	bls	.x
	move.l	d0,hiscore
.x:	movem.l	(sp)+,d0-d1
	rts

;=====================================================================
; the yo-yo: 16 frames out (4 pixels a frame), 16 frames back
;=====================================================================
; HandX: d0 = x of Stronkie's hand
HandX:	move.w	px,d0
	tst.w	pdir
	bmi	.x
	add.w	#PW-1,d0
.x:	rts

YoYo:	tst.w	ystate
	beq	.x
	cmp.w	#ST_STAND,pst
	beq	.ok
	clr.w	ystate
	rts
.ok:	cmp.w	#1,ystate
	bne	.back
	addq.w	#4,ylen
	cmp.w	#64,ylen
	blt	.pos
	move.w	#2,ystate
	bra	.pos
.back:	subq.w	#4,ylen
	bgt	.pos
	clr.w	ystate
	rts
.pos:	bsr	HandX
	move.w	ylen,d1
	tst.w	pdir
	bpl	.r
	neg.w	d1
.r:	add.w	d1,d0
	move.w	d0,ybx
	move.w	py,d0
	add.w	#9,d0
	move.w	d0,yby
	cmp.w	#8,ylen
	blt	.x
	; hit a monster?
	lea	enemies,a2
	move.w	nenemies,d7
	subq.w	#1,d7
	bmi	.ms
.e:	tst.w	EN_STATE(a2)
	bne	.en
	bsr	EnemyBox
	bsr	BallHits
	beq	.en
	move.w	#1,EN_STATE(a2)			; poof!
	move.w	#24,EN_TIMER(a2)
	move.w	EN_TYPE(a2),d0
	add.w	d0,d0
	lea	enpoints,a0
	move.w	(a0,d0.w),d0
	ext.l	d0
	bsr	AddScore
	moveq	#SFX_HIT,d0
	bsr	PlaySfx
	move.w	#2,ystate
	bra	.x
.en:	lea	EN_SIZE(a2),a2
	dbf	d7,.e
.ms:	tst.w	dark				; in the dark it goes right through
	bne	.x
	lea	missiles,a2
	moveq	#MAXMS-1,d7
.m:	move.w	MS_KIND(a2),d0
	beq	.mn
	cmp.w	#3,d0
	beq	.mn
	bsr	MissileBox
	bsr	BallHits
	beq	.mn
	move.w	#3,MS_KIND(a2)
	move.w	#12,MS_T(a2)
	moveq	#50,d0
	bsr	AddScore
	moveq	#SFX_POP,d0
	bsr	PlaySfx
	move.w	#2,ystate
	bra	.x
.mn:	addq.l	#MS_SIZE,a2
	dbf	d7,.m
.x:	rts

; BallHits: the box d0-d3 (x0, y0, x1, y1) touches the ball? (Z = no)
BallHits:
	move.w	ybx,d4
	addq.w	#4,d4
	cmp.w	d0,d4				; ball x1 > x0
	ble	.no
	move.w	ybx,d4
	subq.w	#4,d4
	cmp.w	d2,d4				; ball x0 < x1
	bge	.no
	move.w	yby,d4
	addq.w	#4,d4
	cmp.w	d1,d4
	ble	.no
	move.w	yby,d4
	subq.w	#4,d4
	cmp.w	d3,d4
	bge	.no
	moveq	#1,d4
	rts
.no:	moveq	#0,d4
	rts

; PlayerHits: the box d0-d3 touches Stronkie? (Z = no)
PlayerHits:
	tst.w	invul
	bne	.no
	cmp.w	#ST_DEAD,pst
	beq	.no
	move.w	px,d4
	add.w	#PW-3,d4
	cmp.w	d0,d4
	ble	.no
	move.w	px,d4
	addq.w	#3,d4
	cmp.w	d2,d4
	bge	.no
	move.w	py,d4
	add.w	#PH,d4
	cmp.w	d1,d4
	ble	.no
	move.w	py,d4
	addq.w	#4,d4
	cmp.w	d3,d4
	bge	.no
	moveq	#1,d4
	rts
.no:	moveq	#0,d4
	rts

; EnemyBox: a2 = monster -> d0-d3 its box
EnemyBox:
	move.w	EN_TYPE(a2),d0
	lsl.w	#3,d0
	lea	enboxes,a0
	add.w	d0,a0
	move.w	EN_X(a2),d0
	add.w	(a0)+,d0
	move.w	EN_Y(a2),d1
	add.w	(a0)+,d1
	move.w	d0,d2
	add.w	(a0)+,d2
	move.w	d1,d3
	add.w	(a0)+,d3
	rts

; MissileBox: a2 = balloon / dagger -> d0-d3
MissileBox:
	move.w	MS_X(a2),d0
	move.w	MS_Y(a2),d1
	cmp.w	#1,MS_KIND(a2)
	bne	.d
	addq.w	#3,d0
	move.w	d0,d2
	add.w	#10,d2
	move.w	d1,d3
	add.w	#10,d3
	rts
.d:	addq.w	#4,d0
	move.w	d0,d2
	addq.w	#8,d2
	move.w	d1,d3
	add.w	#15,d3
	rts

;=====================================================================
; the monsters
;=====================================================================
Enemies:
	lea	enemies,a2
	move.w	nenemies,d7
	subq.w	#1,d7
	bmi	.x
.e:	move.w	EN_STATE(a2),d0
	beq	.alive
	subq.w	#1,EN_TIMER(a2)
	bne	.n
	cmp.w	#1,d0
	bne	.back
	move.w	#2,EN_STATE(a2)			; gone for 8 seconds
	move.w	#400,EN_TIMER(a2)
	bra	.n
.back:	move.w	px,d0				; back when Stronkie is not near
	sub.w	EN_SPX(a2),d0
	bpl	.ab
	neg.w	d0
.ab:	cmp.w	#120,d0
	bgt	.ret
	move.w	#50,EN_TIMER(a2)
	bra	.n
.ret:	clr.w	EN_STATE(a2)
	move.w	EN_SPX(a2),EN_X(a2)
	move.w	EN_SPY(a2),EN_Y(a2)
	clr.w	EN_PHASE(a2)
	bra	.n
.alive:	move.w	EN_TYPE(a2),d0
	beq	.scrub
	addq.w	#1,EN_PHASE(a2)
	bsr	.walk
	move.w	EN_PHASE(a2),d1
	cmp.w	#1,d0
	bne	.pog
	lsr.w	#1,d1				; a Hooter flies up and down
	and.w	#31,d1
	lea	hoottab,a0
	move.b	(a0,d1.w),d1
	ext.w	d1
	add.w	EN_BASEY(a2),d1
	move.w	d1,EN_Y(a2)
	bra	.touch
.pog:	and.w	#31,d1				; a Poglet hops
	lea	hoptab,a0
	move.b	(a0,d1.w),d1
	ext.w	d1
	move.w	EN_BASEY(a2),d2
	sub.w	d1,d2
	move.w	d2,EN_Y(a2)
	bra	.touch
.scrub:	tst.w	loop				; a Scrubbly shuffles (faster later)
	bne	.sw
	btst	#0,frame+3
	bne	.touch
.sw:	bsr	.walk
.touch:	bsr	EnemyBox
	bsr	PlayerHits
	beq	.n
	bsr	Die
.n:	lea	EN_SIZE(a2),a2
	dbf	d7,.e
.x:	rts
.walk:	move.w	EN_X(a2),d1
	add.w	EN_DIR(a2),d1
	cmp.w	EN_MIN(a2),d1
	bgt	.w1
	move.w	EN_MIN(a2),d1
	move.w	#1,EN_DIR(a2)
.w1:	cmp.w	EN_MAX(a2),d1
	blt	.w2
	move.w	EN_MAX(a2),d1
	move.w	#-1,EN_DIR(a2)
.w2:	move.w	d1,EN_X(a2)
	rts

;=====================================================================
; balloons rise, daggers fall
;=====================================================================
Missiles:
	cmp.w	#ST_DEAD,pst
	beq	.upd
	subq.w	#1,mstimer
	bgt	.upd
	; how often: faster in later levels and loops
	move.w	#300,d0
	move.w	level,d1
	mulu	#15,d1
	sub.w	d1,d0
	move.w	loop,d1
	mulu	#30,d1
	sub.w	d1,d0
	cmp.w	#80,d0
	bge	.t
	moveq	#80,d0
.t:	move.w	d0,mstimer
	lea	missiles,a2
	moveq	#MAXMS-1,d7
.f:	tst.w	MS_KIND(a2)
	beq	.new
	addq.l	#MS_SIZE,a2
	dbf	d7,.f
	bra	.upd
.new:	move.w	msnext,MS_KIND(a2)
	eor.w	#3,msnext			; 1 <-> 2
	bsr	Random			; 32-95 pixels to the left or right
	move.w	d0,d1
	and.w	#63,d0
	add.w	#32,d0
	btst	#8,d1
	beq	.rs
	neg.w	d0
.rs:	add.w	px,d0
	bsr	ClampX
	move.w	d0,MS_X(a2)
	move.w	#PFH,MS_Y(a2)
	cmp.w	#1,MS_KIND(a2)
	beq	.upd
	move.w	#-16,MS_Y(a2)
.upd:	lea	missiles,a2
	moveq	#MAXMS-1,d7
.m:	move.w	MS_KIND(a2),d0
	beq	.n
	cmp.w	#3,d0
	bne	.mv
	subq.w	#1,MS_T(a2)
	bne	.n
	clr.w	MS_KIND(a2)
	bra	.n
.mv:	cmp.w	#1,d0
	bne	.dag
	subq.w	#1,MS_Y(a2)			; a balloon: up, swaying
	move.l	frame,d1
	and.w	#15,d1
	bne	.b1
	btst	#4,frame+3
	beq	.bl
	addq.w	#1,MS_X(a2)
	bra	.b1
.bl:	subq.w	#1,MS_X(a2)
.b1:	cmp.w	#-16,MS_Y(a2)
	bgt	.hit
	clr.w	MS_KIND(a2)
	bra	.n
.dag:	addq.w	#2,MS_Y(a2)			; a dagger: down
	cmp.w	#PFH,MS_Y(a2)
	blt	.hit
	clr.w	MS_KIND(a2)
	bra	.n
.hit:	bsr	MissileBox
	bsr	PlayerHits
	beq	.n
	bsr	Die
.n:	addq.l	#MS_SIZE,a2
	dbf	d7,.m
	rts

; Random: d0 = random word
Random:	move.l	d1,-(sp)
	move.l	rnd,d0
	move.l	d0,d1
	lsl.l	#8,d1
	lsl.l	#5,d1
	eor.l	d1,d0
	move.l	d0,d1
	lsr.l	#8,d1
	lsr.l	#8,d1
	lsr.l	#1,d1
	eor.l	d1,d0
	move.l	d0,d1
	lsl.l	#5,d1
	eor.l	d1,d0
	move.l	d0,rnd
	move.l	(sp)+,d1
	rts

;=====================================================================
; the timer: at zero the lights go out
;=====================================================================
Timer:	cmp.w	#ST_DEAD,pst
	beq	.x
	tst.w	dark
	bne	.x
	subq.w	#1,tleft
	bgt	.tick
	clr.w	tleft
	move.w	#1,dark
	bsr	SetLevelPal
	moveq	#SFX_DARK,d0
	bsr	PlaySfx
	lea	t_dark,a0
	bra	Message
.tick:	cmp.w	#10*50,tleft
	bhs	.x
	moveq	#0,d0
	move.w	tleft,d0
	divu	#50,d0
	swap	d0
	tst.w	d0
	bne	.x
	moveq	#SFX_TICK,d0
	bsr	PlaySfx
.x:	rts

;=====================================================================
; Camera: follow Stronkie
;=====================================================================
Camera:	move.w	px,d0
	cmp.w	#DM_ROT,dmode
	beq	.rot
	sub.w	#160-8,d0
	bpl	.a
	moveq	#0,d0
.a:	cmp.w	#960-320,d0
	ble	.s
	move.w	#960-320,d0
	bra	.s
.rot:	sub.w	#96-8,d0
	bpl	.b
	moveq	#0,d0
.b:	cmp.w	#960-PFH,d0
	ble	.s
	move.w	#960-PFH,d0
.s:	move.w	d0,camx
	rts

;=====================================================================
; DrawActors: every sprite of this frame
;=====================================================================
DrawActors:
	movem.l	d0-d7/a0-a2,-(sp)
	; Stronkie
	move.w	pst,d4
	cmp.w	#ST_DEAD,d4
	bne	.alive
	moveq	#IMG_DEAD,d2
	btst	#2,deadt+1
	bne	.pdraw
	bra	.yo
.alive:	tst.w	invul
	beq	.vis
	btst	#2,frame+3
	bne	.yo
.vis:	moveq	#IMG_STAND,d2
	cmp.w	#ST_STAND,d4
	bne	.nst
	tst.w	ystate
	beq	.nth
	moveq	#IMG_THROW,d2
	bra	.dir
.nth:	tst.w	pmoved
	beq	.dir
	move.w	panim,d0
	lsr.w	#2,d0
	and.w	#3,d0
	lea	walkseq,a0
	move.b	(a0,d0.w),d2
	bra	.dir
.nst:	cmp.w	#ST_LADDER,d4
	bne	.njp
	moveq	#IMG_CLIMB1,d2
	btst	#3,py+1
	beq	.dir
	moveq	#IMG_CLIMB2,d2
	bra	.dir
.njp:	moveq	#IMG_JUMP,d2
	cmp.w	#ST_JUMP,d4
	beq	.dir
	moveq	#IMG_SLIDE,d2
.dir:	tst.w	pdir
	bpl	.pdraw
	addq.w	#1,d2				; facing left
.pdraw:	move.w	px,d0
	subq.w	#8,d0
	move.w	py,d1
	subq.w	#8,d1
	moveq	#0,d3
	bsr	AddBig
.yo:	; the yo-yo
	tst.w	ystate
	beq	.en
	move.w	ybx,d0
	subq.w	#8,d0
	move.w	yby,d1
	subq.w	#8,d1
	moveq	#SM_YOYO,d2
	moveq	#2,d3
	bsr	AddSmall
.en:	; the monsters
	lea	enemies,a2
	move.w	nenemies,d7
	subq.w	#1,d7
	bmi	.ms
.e:	move.w	EN_STATE(a2),d0
	cmp.w	#2,d0
	beq	.enx
	tst.w	d0
	beq	.ealive
	moveq	#IMG_POOF1,d2
	btst	#2,EN_TIMER+1(a2)
	beq	.edraw
	moveq	#IMG_POOF2,d2
	bra	.edraw
.ealive:
	move.w	EN_TYPE(a2),d0
	move.l	frame,d1
	lsr.w	#3,d1
	and.w	#1,d1				; animation
	moveq	#IMG_SCRUB1,d2
	tst.w	d0
	bne	.e1
	move.l	frame,d1
	lsr.w	#4,d1
	and.w	#1,d1
	bra	.ef
.e1:	moveq	#IMG_HOOT1,d2
	cmp.w	#1,d0
	beq	.ef
	moveq	#IMG_POG1,d2
	move.w	EN_PHASE(a2),d1
	lsr.w	#4,d1
	and.w	#1,d1
	tst.w	EN_DIR(a2)
	bmi	.ef
	addq.w	#1,d2				; facing the other way
.ef:	add.w	d1,d1				; frame 2 (pictures come in R, L pairs)
	add.w	d1,d2
.edraw:	move.w	EN_X(a2),d0
	move.w	EN_Y(a2),d1
	moveq	#1,d3
	bsr	AddBig
.enx:	lea	EN_SIZE(a2),a2
	dbf	d7,.e
.ms:	; balloons, daggers
	lea	missiles,a2
	moveq	#MAXMS-1,d7
.m:	move.w	MS_KIND(a2),d0
	beq	.mn
	moveq	#SM_POP,d2
	cmp.w	#3,d0
	beq	.md
	moveq	#SM_DAGGER,d2
	cmp.w	#2,d0
	beq	.md
	moveq	#SM_BALLOON1,d2
	btst	#4,frame+3
	beq	.md
	moveq	#SM_BALLOON2,d2
.md:	move.w	MS_X(a2),d0
	move.w	MS_Y(a2),d1
	moveq	#3,d3
	bsr	AddSmall
.mn:	addq.l	#MS_SIZE,a2
	dbf	d7,.m
	bsr	Ambient
	movem.l	(sp)+,d0-d7/a0-a2
	rts


;=====================================================================
; the jungle's other animals (only decoration, they do no harm) and
; the jungle sounds: a parrot flies by now and then, a monkey swings
; from vine to vine across the top (on the title it also walks along
; the log). Coordinates: the world (game) or the screen (title).
;=====================================================================
Ambient:
	movem.l	d0-d7/a0,-(sp)
	; jungle sounds
	subq.w	#1,ambsnd
	bgt	.b
	bsr	Random
	and.w	#255,d0
	add.w	#150,d0
	move.w	d0,ambsnd
	bsr	Random
	and.w	#3,d0
	lea	ambsounds,a0
	move.b	(a0,d0.w),d0
	ext.w	d0
	bsr	PlayAmbient
.b:	; the width of the view
	move.w	#320,d6
	tst.w	titlemode
	bne	.vw
	cmp.w	#DM_ROT,dmode
	bne	.vw
	move.w	#PFH,d6
.vw:	move.w	camx,d5
	; the parrot
	tst.w	birdon
	bne	.bm
	subq.w	#1,birdt
	bgt	.m
	bsr	Random
	and.w	#511,d0
	add.w	#300,d0
	move.w	d0,birdt
	bsr	Random
	move.w	#1,birddir
	move.w	d5,d1
	sub.w	#16,d1
	btst	#4,d0
	beq	.bd
	move.w	#-1,birddir
	move.w	d5,d1
	add.w	d6,d1
.bd:	move.w	d1,birdx
	and.w	#63,d0
	add.w	#4,d0
	tst.w	titlemode
	beq	.by
	sub.w	#PFTOP,d0
.by:	move.w	d0,birdy
	move.w	#1,birdon
	moveq	#SFX_BIRD2,d0
	bsr	PlayAmbient
	bra	.m
.bm:	move.w	birddir,d0
	add.w	d0,d0
	add.w	d0,birdx
	move.l	frame,d0			; a little up and down
	and.w	#31,d0
	bne	.bo
	addq.w	#2,birdy
	btst	#5,frame+3
	beq	.bo
	subq.w	#4,birdy
.bo:	move.w	birdx,d0			; gone?
	move.w	d5,d1
	sub.w	#20,d1
	cmp.w	d1,d0
	blt	.boff
	move.w	d5,d1
	add.w	d6,d1
	addq.w	#4,d1
	cmp.w	d1,d0
	ble	.m
.boff:	clr.w	birdon
.m:	; the monkey
	tst.w	monkon
	bne	.mm
	subq.w	#1,monkt
	bgt	.draw
	bsr	Random
	and.w	#1023,d0
	add.w	#600,d0
	move.w	d0,monkt
	clr.w	monkph
	move.w	#1,monkon			; swinging
	move.w	#-8,monky
	tst.w	titlemode
	beq	.ms
	move.w	#-PFTOP,monky
	tst.w	titlepage			; the high scores: walking on the log
	beq	.ms
	move.w	#2,monkon
	move.w	#164-PFTOP,monky
.ms:	bsr	Random
	move.w	#1,monkdir
	move.w	d5,d1
	sub.w	#32,d1
	btst	#3,d0
	beq	.md
	move.w	#-1,monkdir
	move.w	d5,d1
	add.w	d6,d1
.md:	move.w	d1,monkx
	moveq	#SFX_MONKEY,d0
	bsr	PlayAmbient
	bra	.draw
.mm:	addq.w	#1,monkph
	move.w	monkdir,d0
	cmp.w	#2,monkon
	beq	.mw
	btst	#0,monkph+1			; swinging: 1.5 pixels a frame
	beq	.m1
	add.w	d0,d0
.m1:	add.w	d0,monkx
	bra	.mo
.mw:	btst	#0,monkph+1			; walking: half a pixel a frame
	beq	.mo
	add.w	d0,monkx
.mo:	move.w	monkx,d0
	move.w	d5,d1
	sub.w	#36,d1
	cmp.w	d1,d0
	blt	.moff
	move.w	d5,d1
	add.w	d6,d1
	addq.w	#4,d1
	cmp.w	d1,d0
	ble	.draw
.moff:	clr.w	monkon
.draw:	tst.w	birdon
	beq	.dm
	moveq	#SM_BIRD1,d2
	tst.w	birddir
	bpl	.d1
	moveq	#SM_BIRD1L,d2
.d1:	btst	#2,frame+3
	beq	.d2
	addq.w	#1,d2
.d2:	move.w	birdx,d0
	move.w	birdy,d1
	moveq	#5,d3
	bsr	AddSmall
.dm:	move.w	monkon,d4
	beq	.x
	cmp.w	#2,d4
	beq	.dw
	move.w	monkph,d0			; a swing every 40 frames
	ext.l	d0
	divu	#40,d0
	moveq	#IMG_MSWING1,d2
	btst	#0,d0
	beq	.d3
	moveq	#IMG_MSWING2,d2
.d3:	swap	d0
	lea	swingtab,a0
	moveq	#0,d1
	move.b	(a0,d0.w),d1
	add.w	monky,d1
	bra	.d5
.dw:	moveq	#IMG_MWALK1,d2
	btst	#3,frame+3
	beq	.d4
	moveq	#IMG_MWALK2,d2
.d4:	tst.w	monkdir
	bpl	.d6
	addq.w	#1,d2				; facing left
.d6:	move.w	monky,d1
.d5:	move.w	monkx,d0
	moveq	#4,d3
	bsr	AddBig
.x:	movem.l	(sp)+,d0-d7/a0
	rts

swingtab:	dc.b	0,1,2,3,4,5,6,7,8,9,10,11,11,12,12,13,13,14,14,14,14,14,14,14,13,13,12,12,11,11,10,9,8,7,6,5,4,3,2,1
ambsounds:	dc.b	SFX_BIRD,SFX_BIRD2,SFX_CRICKET,SFX_BIRD
	even

;=====================================================================
; the score panel (screen rows 0-2)
;=====================================================================
HudAll:	movem.l	d0-d7/a0,-(sp)
	moveq	#0,d0
	moveq	#4,d1
	bsr	ClearRows
	moveq	#1,d0				; the frame of the panel
	moveq	#30,d1
	bsr	DrawBox
	lea	t_score,a0
	moveq	#1,d0
	moveq	#1,d1
	moveq	#3,d3
	bsr	DrawText
	lea	t_hi,a0
	moveq	#15,d0
	bsr	DrawText
	lea	t_lev,a0
	moveq	#26,d0
	bsr	DrawText
	bsr	LevelNumber
	moveq	#2,d4
	moveq	#32,d5
	moveq	#1,d6
	moveq	#2,d3
	bsr	DrawNum
	ifne	DEMO
	lea	t_demo2,a0
	moveq	#35,d0
	moveq	#1,d1
	moveq	#12,d3
	bsr	DrawText
	endc
	tst.w	devused
	beq	.nd
	lea	t_dev,a0
	tst.w	devinv
	beq	.dv
	lea	t_devinv,a0
.dv:	moveq	#35,d0
	moveq	#1,d1
	moveq	#12,d3
	bsr	DrawText
.nd:	lea	t_lives,a0
	moveq	#1,d0
	moveq	#2,d1
	moveq	#3,d3
	bsr	DrawText
	moveq	#0,d0
	move.w	lives,d0
	cmp.w	#9,d0
	bls	.lv
	moveq	#9,d0
.lv:	moveq	#1,d4
	moveq	#7,d5
	moveq	#2,d6
	moveq	#2,d3
	bsr	DrawNum
	lea	t_keys,a0
	moveq	#10,d0
	moveq	#2,d1
	moveq	#3,d3
	bsr	DrawText
	moveq	#0,d0
	move.w	keystotal,d0
	sub.w	keysleft,d0
	moveq	#1,d4
	moveq	#15,d5
	moveq	#2,d3
	bsr	DrawNum
	move.w	#'/',d2
	moveq	#16,d0
	moveq	#2,d1
	bsr	DrawChar
	moveq	#0,d0
	move.w	keystotal,d0
	moveq	#1,d4
	moveq	#17,d5
	bsr	DrawNum
	lea	t_time,a0
	moveq	#20,d0
	moveq	#2,d1
	moveq	#3,d3
	bsr	DrawText
	move.w	#-1,hudtime
	bsr	HudUpdate
	movem.l	(sp)+,d0-d7/a0
	rts

; HudUpdate: the score, the high score and the time bar
HudUpdate:
	movem.l	d0-d7/a0,-(sp)
	move.l	score,d0
	moveq	#6,d4
	moveq	#7,d5
	moveq	#1,d6
	moveq	#2,d3
	bsr	DrawNum
	move.l	hiscore,d0
	moveq	#18,d5
	moveq	#15,d3
	bsr	DrawNum
	; the time bar: 112 pixels (columns 25-38, lines 17-22)
	moveq	#0,d0
	move.w	tleft,d0
	mulu	#112,d0
	move.w	lvtime,d1
	mulu	#50,d1
	divu	d1,d0				; 0-112
	cmp.w	hudtime,d0
	beq	.x
	move.w	d0,hudtime
	move.w	d0,d6
	moveq	#2,d4				; yellow
	cmp.w	#10*50,tleft
	bhs	.c
	moveq	#12,d4				; red: hurry
.c:	moveq	#25,d0
.b:	move.w	d6,d3
	cmp.w	#8,d3
	blo	.part
	move.w	#$ff,d3
	subq.w	#8,d6
	bra	.put
.part:	move.w	#$ff00,d5
	lsr.w	d3,d5
	move.w	d5,d3
	and.w	#$ff,d3
	moveq	#0,d6
.put:	moveq	#17,d1
	moveq	#5,d5
.ln:	bsr	PutByte
	addq.w	#1,d1
	dbf	d5,.ln
	addq.w	#1,d0
	cmp.w	#39,d0
	bne	.b
.x:	movem.l	(sp)+,d0-d7/a0
	rts

; DrawBox: a bamboo frame on the screen bitmap from line d0 to line d1
DrawBox:
	movem.l	d0-d7,-(sp)
	move.w	d0,d6
	move.w	d1,d7
	lea	boxcols,a0
	moveq	#2,d5				; three lines at the top and the bottom
.h:	move.w	(a0)+,d4
	move.w	#$ff,d3
	moveq	#0,d0
.hl:	move.w	d6,d1
	bsr	PutByte
	move.w	d7,d1
	bsr	PutByte
	addq.w	#1,d0
	cmp.w	#40,d0
	bne	.hl
	addq.w	#1,d6
	subq.w	#1,d7
	dbf	d5,.h
	; the sides: 3 pixels in column 0 and column 39
.v:	moveq	#0,d0
	move.w	d6,d1
	move.w	#$80,d3
	move.w	boxcols,d4
	bsr	PutBits
	lsr.w	#1,d3
	move.w	boxcols+2,d4
	bsr	PutBits
	lsr.w	#1,d3
	move.w	boxcols+4,d4
	bsr	PutBits
	moveq	#39,d0
	moveq	#1,d3
	move.w	boxcols,d4
	bsr	PutBits
	add.w	d3,d3
	move.w	boxcols+2,d4
	bsr	PutBits
	add.w	d3,d3
	move.w	boxcols+4,d4
	bsr	PutBits
	addq.w	#1,d6
	cmp.w	d7,d6
	ble	.v
	movem.l	(sp)+,d0-d7
	rts
boxcols:	dc.w	14,11,4			; light bamboo, bamboo, dark edge

; PutBits: d0 = byte column, d1 = line, d3 = the bits, d4 = colour (other bits stay)
PutBits:
	movem.l	d0-d2/d5/a0,-(sp)
	lea	screen,a0
	mulu	#40,d1
	add.w	d0,d1
	add.l	d1,a0
	move.b	d3,d5
	not.b	d5
	moveq	#0,d2
.p:	btst	d2,d4
	beq	.z
	or.b	d3,(a0)
	bra	.n
.z:	and.b	d5,(a0)
.n:	lea	PLANE(a0),a0
	addq.w	#1,d2
	cmp.w	#4,d2
	bne	.p
	movem.l	(sp)+,d0-d2/d5/a0
	rts

; MsgBox: the frame of the message panel under the playfield
MsgBox:	movem.l	d0-d1,-(sp)
	moveq	#28,d0
	moveq	#4,d1
	bsr	ClearRows
	move.w	#PFTOP+PFH+2,d0
	move.w	#PFTOP+PFH+26,d1
	bsr	DrawBox
	movem.l	(sp)+,d0-d1
	rts

; Message: a0 = text in the message panel (row 29), centred
Message:
	movem.l	d0-d3/a0-a1,-(sp)
	lea	msgbuf,a1
	moveq	#37,d0
.f:	move.b	#' ',(a1)+
	dbf	d0,.f
	clr.b	(a1)
	move.l	a0,a1
	moveq	#38,d0
.l:	tst.b	(a1)+
	beq	.e
	subq.w	#1,d0
	bra	.l
.e:	asr.w	#1,d0
	lea	msgbuf,a1
	add.w	d0,a1
.c:	move.b	(a0)+,d1
	beq	.d
	move.b	d1,(a1)+
	bra	.c
.d:	lea	msgbuf,a0
	moveq	#1,d0
	moveq	#29,d1
	moveq	#15,d3
	bsr	DrawText
	movem.l	(sp)+,d0-d3/a0-a1
	rts
ClearMessage:
	move.l	a0,-(sp)
	lea	t_empty,a0
	bsr	Message
	move.l	(sp)+,a0
	rts

;=====================================================================
; the end of a level, the game
;=====================================================================
LevelDone:
	bsr	StopMusic
	moveq	#2,d0
	bsr	PlayTune
	clr.w	ystate
	lea	t_clear,a0
	bsr	Message
	moveq	#40,d7
.w:	bsr	WaitFrame
	bsr	UpdateDisplay
	bsr	DrawActors
	dbf	d7,.w
.tb:	; the time bonus: 10 points a second
	tst.w	tleft
	beq	.done
	sub.w	#50,tleft
	bpl	.t
	clr.w	tleft
.t:	moveq	#10,d0
	bsr	AddScore
	move.l	frame,d0
	btst	#0,d0
	bne	.nt
	moveq	#SFX_TICK,d0
	bsr	PlaySfx
.nt:	bsr	WaitFrame
	bsr	UpdateDisplay
	bsr	DrawActors
	bsr	HudUpdate
	tst.w	quitnow
	bne	.x
	bra	.tb
.done:	moveq	#75,d7
.w2:	bsr	WaitFrame
	bsr	UpdateDisplay
	bsr	DrawActors
	dbf	d7,.w2
.x:	rts

GameOver:
	bsr	StopMusic
	moveq	#3,d0
	bsr	PlayTune
	lea	t_over,a0
	bsr	Message
	move.w	#150,d7
.w:	bsr	WaitFrame
	bsr	UpdateDisplay
	bsr	DrawActors
	tst.w	quitnow
	bne	.x
	dbf	d7,.w
.x:	rts

;---------------------------------------------------------------------
jumptab:	dc.b	-4,-4,-3,-3,-3,-3,-2,-2,-2,-2,-2,-1,-1,-1,-1,0,0
		dc.b	0,1,1,1,1,2,2,2,2,3,3,3,3
JLEN	equ	*-jumptab
	even
hoptab:		dc.b	0,2,4,6,8,9,10,11,12,12,11,10,9,8,6,4,2,0
		dc.b	0,0,0,0,0,0,0,0,0,0,0,0,0,0
hoottab:	dc.b	0,2,3,5,6,7,7,8,8,8,7,7,6,5,3,2
		dc.b	0,-2,-3,-5,-6,-7,-7,-8,-8,-8,-7,-7,-6,-5,-3,-2
walkseq:	dc.b	IMG_WALK1,IMG_STAND,IMG_WALK2,IMG_STAND
	even
; the monsters' boxes in their 32 x 32 picture: x, y, x end, y end
enboxes:	dc.w	4,4,28,32			; Scrubbly
		dc.w	6,10,26,32			; Hooter
		dc.w	8,10,26,32			; Poglet
enpoints:	dc.w	200,300,150
t_score:	dc.b	'SCORE',0
t_hi:		dc.b	'HI',0
t_lev:		dc.b	'LEVEL',0
t_lives:	dc.b	'LIVES',0
t_keys:		dc.b	'KEYS',0
t_time:		dc.b	'TIME',0
t_dev:		dc.b	'DEV',0
t_devinv:	dc.b	'INV',0
t_demo2:	dc.b	'DEMO',0
t_level:	dc.b	'LEVEL ',0
t_ready:	dc.b	'GET READY!',0
t_paused:	dc.b	'PAUSED - PRESS P',0
t_dark:		dc.b	'LIGHTS OUT! FIND A LIGHT BULB!',0
t_clear:	dc.b	'ALL KEYS! LEVEL CLEAR - TIME BONUS',0
t_over:		dc.b	'GAME OVER',0
t_empty:	dc.b	0
	even
