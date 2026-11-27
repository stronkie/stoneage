;=====================================================================
; sys.i - the system, the high score file, input, sound and text
; (from Stronkie's Robot)
;=====================================================================
SysTakeover:
	move.l	4.w,a6
	sub.l	a1,a1
	jsr	-294(a6)			; FindTask(0)
	move.l	d0,a4
	tst.l	172(a4)				; pr_CLI
	bne	.cli
	lea	92(a4),a0			; started from Workbench
	jsr	-384(a6)			; WaitPort
	lea	92(a4),a0
	jsr	-372(a6)			; GetMsg
	move.l	d0,wbmsg
.cli:	lea	dosname,a1
	moveq	#0,d0
	jsr	-552(a6)
	move.l	d0,dosbase
	bsr	LoadHi
	move.l	4.w,a6
	lea	gfxname,a1
	moveq	#0,d0
	jsr	-552(a6)
	move.l	d0,gfxbase
	move.l	d0,a6
	move.l	34(a6),oldview			; gb_ActiView
	move.l	38(a6),oldcop			; gb_copinit
	sub.l	a1,a1
	jsr	-222(a6)			; LoadView(0)
	jsr	-270(a6)			; WaitTOF
	jsr	-270(a6)
	move.l	4.w,a6
	jsr	-132(a6)			; Forbid
	lea	CUSTOM,a5
	move.w	INTENAR(a5),oldint
	move.w	DMACONR(a5),olddma
	move.w	ADKCONR(a5),oldadk
	move.w	#$7fff,INTENA(a5)
	move.w	#$7fff,INTREQ(a5)
	move.w	#$7fff,DMACON(a5)
	move.w	#$00ff,ADKCON(a5)		; no audio modulation
	tst.b	CIAA_ICR			; clear the keyboard flag
	rts

SysRestore:
	lea	CUSTOM,a5
	move.w	#$7fff,DMACON(a5)
	move.w	#$7fff,INTENA(a5)
	move.l	oldcop,COP1LC(a5)
	move.w	d0,COPJMP1(a5)
	move.w	oldadk,d0
	or.w	#$8000,d0
	move.w	#$7fff,ADKCON(a5)
	move.w	d0,ADKCON(a5)
	move.w	olddma,d0
	or.w	#$8000,d0
	move.w	d0,DMACON(a5)
	move.w	#$7fff,INTREQ(a5)
	move.w	oldint,d0
	or.w	#$c000,d0
	move.w	d0,INTENA(a5)
	move.l	4.w,a6
	jsr	-138(a6)			; Permit
	move.l	gfxbase,a6
	move.l	oldview,a1
	jsr	-222(a6)			; LoadView
	jsr	-270(a6)
	jsr	-270(a6)
	move.l	4.w,a6
	move.l	gfxbase,a1
	jsr	-414(a6)			; CloseLibrary
	bsr	SaveHi
	move.l	4.w,a6
	move.l	dosbase,d0
	beq	.nd
	move.l	d0,a1
	jsr	-414(a6)
.nd:	move.l	wbmsg,d0
	beq	.x
	jsr	-132(a6)			; Forbid (the message goes back last)
	move.l	d0,a1
	jsr	-378(a6)			; ReplyMsg
.x:	rts

;=====================================================================
; high scores: the file StronkiesStoneAge.hi = 'SSA1', 10 x (name, score)
;=====================================================================
FILELEN	equ	4+HSN*8

LoadHi:	bsr	HiDefaults
	move.l	dosbase,d0
	beq	.x
	move.l	d0,a6
	move.l	#hiname,d1
	move.l	#1005,d2
	jsr	-30(a6)				; Open
	move.l	d0,d7
	beq	.x
	move.l	d7,d1
	move.l	#filebuf,d2
	move.l	#FILELEN,d3
	jsr	-42(a6)				; Read
	move.l	d0,d6
	move.l	d7,d1
	jsr	-36(a6)				; Close
	lea	filebuf,a0
	cmp.l	#'SSA1',(a0)
	bne	.x
	cmp.l	#FILELEN,d6
	bne	.x
	addq.l	#4,a0
	lea	hitab,a1
	moveq	#HSN*2-1,d0
.c:	move.l	(a0)+,(a1)+
	dbf	d0,.c
	lea	hitab,a1
	moveq	#HSN-1,d0
.s:	cmp.l	#999999,4(a1)
	bls	.ok
	bsr	HiDefaults
	bra	.x
.ok:	addq.l	#8,a1
	dbf	d0,.s
.x:	move.l	hitab+4,hiscore
	rts

HiDefaults:
	movem.l	d0/a0-a1,-(sp)
	lea	hidef,a0
	lea	hitab,a1
	moveq	#HSN*2-1,d0
.c:	move.l	(a0)+,(a1)+
	dbf	d0,.c
	move.l	hitab+4,hiscore
	movem.l	(sp)+,d0/a0-a1
	rts

; HiInsert: d0 = score, a0 = name (3 letters) -> d1 = place 0-9, or -1
HiInsert:
	movem.l	a1-a2,-(sp)
	lea	hitab,a1
	moveq	#0,d1
.f:	cmp.l	4(a1),d0
	bhi	.ins
	addq.l	#8,a1
	addq.w	#1,d1
	cmp.w	#HSN,d1
	bne	.f
	moveq	#-1,d1
	bra	.x
.ins:	lea	hitab+(HSN-1)*8,a2
.s:	cmp.l	a1,a2
	bls	.put
	move.l	-8(a2),(a2)
	move.l	-4(a2),4(a2)
	subq.l	#8,a2
	bra	.s
.put:	move.b	(a0),(a1)
	move.b	1(a0),1(a1)
	move.b	2(a0),2(a1)
	clr.b	3(a1)
	move.l	d0,4(a1)
	move.l	hitab+4,hiscore
	move.w	#1,hichanged
.x:	movem.l	(sp)+,a1-a2
	rts

; WriteHiFile: d0 = 0 when written (the system must be running)
WriteHiFile:
	movem.l	d1-d7/a0-a1/a6,-(sp)
	move.l	dosbase,d0
	beq	.fail
	move.l	d0,a6
	lea	filebuf,a0
	move.l	#'SSA1',(a0)+
	lea	hitab,a1
	moveq	#HSN*2-1,d0
.c:	move.l	(a1)+,(a0)+
	dbf	d0,.c
	move.l	#hiname,d1
	move.l	#1006,d2
	jsr	-30(a6)				; Open (new file)
	move.l	d0,d7
	beq	.fail
	move.l	d7,d1
	move.l	#filebuf,d2
	move.l	#FILELEN,d3
	jsr	-48(a6)				; Write
	move.l	d0,d6
	move.l	d7,d1
	jsr	-36(a6)				; Close
	cmp.l	#FILELEN,d6
	bne	.fail
	clr.w	hichanged
	moveq	#0,d0
	bra	.x
.fail:	moveq	#-1,d0
.x:	movem.l	(sp)+,d1-d7/a0-a1/a6
	rts

; at the very end, with the system back: write if anything changed
SaveHi:	tst.w	hichanged
	beq	.x
	move.l	4.w,a6
	sub.l	a1,a1
	jsr	-294(a6)			; FindTask: no requesters
	move.l	d0,a4
	move.l	184(a4),-(sp)
	move.l	#-1,184(a4)
	bsr	WriteHiFile
	move.l	(sp)+,184(a4)
.x:	rts

; SaveNow: writes the file while the game keeps its screen: the system
; gets the interrupts and DMA back for a moment (no requesters), then
; the game takes over again. d0 = 0 saved, -1 not (write protected...)
SaveNow:
	movem.l	d1-d7/a0-a6,-(sp)
	moveq	#-1,d7
	tst.l	dosbase
	beq	.x
	lea	CUSTOM,a5
	clr.w	AUD0+8(a5)			; quiet
	clr.w	AUD0+$18(a5)
	clr.w	AUD0+$28(a5)
	clr.w	AUD0+$38(a5)
	move.l	4.w,a6
	sub.l	a1,a1
	jsr	-294(a6)			; FindTask(0)
	move.l	d0,a4
	move.l	184(a4),-(sp)			; pr_WindowPtr
	move.l	#-1,184(a4)			; no "disk is write protected" requester
	move.w	#$7fff,INTREQ(a5)
	move.w	oldint,d0
	or.w	#$c000,d0
	move.w	d0,INTENA(a5)
	move.w	olddma,d0
	or.w	#$8000,d0
	move.w	d0,DMACON(a5)
	jsr	-138(a6)			; Permit
	bsr	WriteHiFile
	move.l	d0,d7
	bne	.nd
	move.l	dosbase,a6
	moveq	#100,d1
	jsr	-198(a6)			; Delay(2 s): the floppy finishes
.nd:	move.l	4.w,a6
	jsr	-132(a6)			; Forbid
	move.w	#$7fff,INTENA(a5)
	move.w	#$7fff,INTREQ(a5)
	move.w	#$7fff-$03af,DMACON(a5)		; only the game's DMA
	move.w	#$83af,DMACON(a5)
	move.l	(sp)+,184(a4)
	tst.b	CIAA_ICR
	lea	keys,a0
	moveq	#127,d0
.k:	clr.b	(a0)+
	dbf	d0,.k
	clr.w	lastkey
	clr.w	joy
	clr.w	joyedge
.x:	move.l	d7,d0
	movem.l	(sp)+,d1-d7/a0-a6
	rts

hidef:	dc.b	'MRK',0
	dc.l	20000
	dc.b	'STR',0
	dc.l	15000
	dc.b	'YOY',0
	dc.l	12000
	dc.b	'KEY',0
	dc.l	10000
	dc.b	'SCR',0
	dc.l	8000
	dc.b	'HOO',0
	dc.l	6000
	dc.b	'POG',0
	dc.l	4000
	dc.b	'ROK',0
	dc.l	3000
	dc.b	'UGH',0
	dc.l	2000
	dc.b	'CAV',0
	dc.l	1000

;=====================================================================
; the frame, the keyboard and the joystick
;=====================================================================
WaitFrame:
	movem.l	d0-d1,-(sp)
.w1:	move.l	CUSTOM+VPOSR,d0
	and.l	#$1ff00,d0
	cmp.l	#300<<8,d0
	beq	.w1
.w2:	move.l	CUSTOM+VPOSR,d0
	and.l	#$1ff00,d0
	cmp.l	#300<<8,d0
	bne	.w2
	addq.l	#1,frame
	movem.l	(sp)+,d0-d1
	bsr	PollKeys
	bsr	ReadJoy
	bsr	Audio
	cmp.w	#K_F10,lastkey			; F10 quits from anywhere
	bne	.x
	move.w	#1,quitnow
.x:	rts

PollKeys:
	movem.l	d0-d2/a0,-(sp)
	btst	#3,CIAA_ICR
	beq	.x
	move.b	CIAA_SDR,d0
	bset	#6,CIAA_CRA			; handshake
	not.b	d0
	ror.b	#1,d0
	moveq	#0,d1
	move.b	d0,d1
	and.w	#$7f,d1
	lea	keys,a0
	tst.b	d0
	bmi	.up
	move.b	#1,(a0,d1.w)
	move.w	d1,lastkey
	bra	.hs
.up:	clr.b	(a0,d1.w)
.hs:	moveq	#3,d2				; wait 3 lines (> 85 us)
.w:	move.b	CUSTOM+6,d0
.w2:	cmp.b	CUSTOM+6,d0
	beq	.w2
	dbf	d2,.w
	bclr	#6,CIAA_CRA
.x:	movem.l	(sp)+,d0-d2/a0
	rts

; joy: bit 0 up, 1 down, 2 left, 3 right, 4 fire; joyedge: new presses
ReadJoy:
	movem.l	d0-d2/a0,-(sp)
	moveq	#0,d2
	move.w	CUSTOM+JOY1DAT,d0
	btst	#1,d0
	beq	.nr
	bset	#3,d2
.nr:	btst	#9,d0
	beq	.nl
	bset	#2,d2
.nl:	move.w	d0,d1
	lsr.w	#1,d1
	eor.w	d0,d1
	btst	#0,d1
	beq	.nd
	bset	#1,d2
.nd:	btst	#8,d1
	beq	.nu
	bset	#0,d2
.nu:	btst	#7,CIAA_PRA
	bne	.nf
	bset	#4,d2
.nf:	lea	keys,a0
	tst.b	$4c(a0)
	beq	.k1
	bset	#0,d2
.k1:	tst.b	$4d(a0)
	beq	.k2
	bset	#1,d2
.k2:	tst.b	$4f(a0)
	beq	.k3
	bset	#2,d2
.k3:	tst.b	$4e(a0)
	beq	.k4
	bset	#3,d2
.k4:	tst.b	$40(a0)
	beq	.k5
	bset	#4,d2
.k5:	move.w	joy,d0
	move.w	d2,joy
	not.w	d0
	and.w	d2,d0
	move.w	d0,joyedge
	movem.l	(sp)+,d0-d2/a0
	rts

; GetKey: d0 = the last key pressed (0 = none), and forget it
GetKey:	move.w	lastkey,d0
	clr.w	lastkey
	rts

;=====================================================================
; sound: music on channels 0 and 1, effects on 2 and 3
;=====================================================================
InitSound:
	lea	CUSTOM,a5
	move.l	#wave_sq,AUD0(a5)
	move.w	#8,AUD0+4(a5)
	move.w	#400,AUD0+6(a5)
	clr.w	AUD0+8(a5)
	move.l	#wave_tri,AUD0+$10(a5)
	move.w	#16,AUD0+$14(a5)
	move.w	#400,AUD0+$16(a5)
	clr.w	AUD0+$18(a5)
	lea	AUD0(a5),a4
	moveq	#2,d0
.s:	move.w	d0,d1
	lsl.w	#4,d1
	move.l	#silence,(a4,d1.w)
	move.w	#1,4(a4,d1.w)
	move.w	#400,6(a4,d1.w)
	clr.w	8(a4,d1.w)
	addq.w	#1,d0
	cmp.w	#4,d0
	bne	.s
	move.w	#1,musicon
	rts

Audio:	movem.l	d0-d7/a0-a2/a5,-(sp)
	lea	CUSTOM,a5
	lea	sfxpend,a0
	moveq	#2,d0
.p:	tst.b	(a0,d0.w)
	beq	.np
	subq.b	#1,(a0,d0.w)
	bne	.np
	move.w	d0,d1
	lsl.w	#4,d1
	lea	AUD0(a5),a1
	move.l	#silence,(a1,d1.w)
	move.w	#1,4(a1,d1.w)
.np:	addq.w	#1,d0
	cmp.w	#4,d0
	bne	.p
	bsr	MusicTick
	movem.l	(sp)+,d0-d7/a0-a2/a5
	rts

; PlaySfx: d0 = effect. Ticks, landing and the yo-yo use channel 3,
; the rest channel 2.
PlaySfx:
	movem.l	d0-d3/a0-a1,-(sp)
	moveq	#2,d1
	cmp.w	#SFX_TICK,d0
	beq	.c3
	cmp.w	#SFX_LAND,d0
	beq	.c3
	cmp.w	#SFX_THROW,d0
	beq	.c3
	cmp.w	#SFX_POP,d0
	bne	.ch
.c3:	moveq	#3,d1
.ch:	lea	CUSTOM,a1
	moveq	#0,d2
	bset	d1,d2
	move.w	d2,DMACON(a1)			; channel off
	moveq	#4,d3
.w:	move.b	CUSTOM+6,d2
.w2:	cmp.b	CUSTOM+6,d2
	beq	.w2
	dbf	d3,.w
	mulu	#6,d0
	lea	sfxtab,a0
	add.w	d0,a0
	move.w	d1,d3
	lsl.w	#4,d3
	lea	AUD0(a1),a1
	add.w	d3,a1
	move.l	(a0)+,(a1)
	move.w	(a0),4(a1)
	move.w	#428,6(a1)
	move.w	#64,8(a1)
	moveq	#0,d2
	bset	d1,d2
	bset	#15,d2
	move.w	d2,CUSTOM+DMACON
	lea	sfxpend,a0
	move.b	#2,(a0,d1.w)
	movem.l	(sp)+,d0-d3/a0-a1
	rts

; PlayTune: d0 = tune (0 title, 1 game, 2 clear, 3 game over, 4 winner)
PlayTune:
	movem.l	d0/a0-a1,-(sp)
	lea	tunetab,a0
	add.w	d0,d0
	add.w	d0,d0
	move.l	(a0,d0.w),a0
	move.w	(a0)+,mvbase
	move.w	(a0)+,mvbase+2
	move.l	(a0),mvstart
	move.l	(a0)+,mvptr
	move.l	(a0),mvstart+4
	move.l	(a0),mvptr+4
	clr.l	mvcnt
	clr.w	musdone
	move.w	#1,musplay
	movem.l	(sp)+,d0/a0-a1
	rts

StopMusic:
	clr.w	musplay
	move.w	#1,musdone
	clr.w	CUSTOM+AUD0+8
	clr.w	CUSTOM+AUD0+$18
	rts

MusicTick:
	tst.w	musplay
	beq	.x
	moveq	#0,d7				; voice
.v:	move.w	d7,d6
	add.w	d6,d6				; word index
	move.w	d7,d5
	lsl.w	#2,d5				; long index
	lea	mvcnt,a0
	subq.w	#1,(a0,d6.w)
	bgt	.decay
	lea	mvptr,a2
	move.l	(a2,d5.w),a1
.rd:	move.w	(a1)+,d0
	cmp.w	#$ffff,d0
	bne	.n1
	lea	mvstart,a1
	move.l	(a1,d5.w),a1
	bra	.rd
.n1:	cmp.w	#$fffe,d0
	bne	.n2
	bsr	StopMusic
	rts
.n2:	move.w	(a1)+,(a0,d6.w)			; the length
	move.l	a1,(a2,d5.w)
	lea	mvvol,a2
	clr.w	(a2,d6.w)
	tst.w	d0
	beq	.out
	lea	mvbase,a1
	move.w	(a1,d6.w),(a2,d6.w)
	move.w	d7,d1
	lsl.w	#4,d1
	lea	CUSTOM+AUD0,a1
	move.w	d0,6(a1,d1.w)
	bra	.out
.decay:	lea	mvvol,a2
	move.w	frame+2,d0
	btst	#0,d0
	beq	.out
	move.w	(a2,d6.w),d0
	lea	mvbase,a1
	move.w	(a1,d6.w),d1
	lsr.w	#1,d1
	cmp.w	d1,d0
	ble	.out
	subq.w	#1,(a2,d6.w)
.out:	move.w	(a2,d6.w),d0
	tst.w	musicon
	beq	.mute
	tst.w	paused
	beq	.on
.mute:	moveq	#0,d0
.on:	move.w	d7,d1
	lsl.w	#4,d1
	lea	CUSTOM+AUD0,a1
	move.w	d0,8(a1,d1.w)
	addq.w	#1,d7
	cmp.w	#2,d7
	bne	.v
.x:	rts

;=====================================================================
; text on the screen (title, score panel)
;=====================================================================
ClearScreen:
	movem.l	d0-d1/a0,-(sp)
	lea	screen,a0
	move.w	#PLANE*4/16-1,d0
	moveq	#0,d1
.l:	move.l	d1,(a0)+
	move.l	d1,(a0)+
	move.l	d1,(a0)+
	move.l	d1,(a0)+
	dbf	d0,.l
	movem.l	(sp)+,d0-d1/a0
	rts

; ClearRows: d0 = first row, d1 = number of rows (8 lines each)
ClearRows:
	movem.l	d0-d3/a0-a1,-(sp)
	mulu	#320,d0
	lea	screen,a1
	add.l	d0,a1
	mulu	#80,d1				; longs per plane
	moveq	#3,d3
.p:	move.l	a1,a0
	move.w	d1,d2
	subq.w	#1,d2
.l:	clr.l	(a0)+
	dbf	d2,.l
	add.l	#PLANE,a1
	dbf	d3,.p
	movem.l	(sp)+,d0-d3/a0-a1
	rts

; DrawChar: d0 = column, d1 = row, d2 = character, d3 = colour
DrawChar:
	movem.l	d0-d4/a0-a1,-(sp)
	lea	screen,a0
	mulu	#320,d1
	add.w	d0,d1
	add.l	d1,a0
	lea	font,a1
	and.w	#$7f,d2
	lsl.w	#3,d2
	add.w	d2,a1
	moveq	#0,d4
.p:	btst	d4,d3
	beq	.z
	move.b	(a1),(a0)
	move.b	1(a1),40(a0)
	move.b	2(a1),80(a0)
	move.b	3(a1),120(a0)
	move.b	4(a1),160(a0)
	move.b	5(a1),200(a0)
	move.b	6(a1),240(a0)
	move.b	7(a1),280(a0)
	bra	.n
.z:	clr.b	(a0)
	clr.b	40(a0)
	clr.b	80(a0)
	clr.b	120(a0)
	clr.b	160(a0)
	clr.b	200(a0)
	clr.b	240(a0)
	clr.b	280(a0)
.n:	lea	PLANE(a0),a0
	addq.w	#1,d4
	cmp.w	#4,d4
	bne	.p
	movem.l	(sp)+,d0-d4/a0-a1
	rts

; DrawText: a0 = text (0 ends), d0 = column, d1 = row, d3 = colour
DrawText:
	movem.l	d0-d2/a0,-(sp)
.l:	moveq	#0,d2
	move.b	(a0)+,d2
	beq	.x
	bsr	DrawChar
	addq.w	#1,d0
	bra	.l
.x:	movem.l	(sp)+,d0-d2/a0
	rts

; DrawTextC: centred on the row
DrawTextC:
	movem.l	d0/a1,-(sp)
	move.l	a0,a1
	moveq	#40,d0
.l:	tst.b	(a1)+
	beq	.e
	subq.w	#1,d0
	bra	.l
.e:	asr.w	#1,d0
	bsr	DrawText
	movem.l	(sp)+,d0/a1
	rts

; DrawBig: a0 = text, d0 = byte column, d1 = pixel line, d3 = colour
; letters twice as wide and twice as high
DrawBig:
	movem.l	d0-d7/a0-a4,-(sp)
	lea	screen,a2
	mulu	#40,d1
	add.w	d0,d1
	add.l	d1,a2
.ch:	moveq	#0,d2
	move.b	(a0)+,d2
	beq	.x
	lea	font,a1
	lsl.w	#3,d2
	add.w	d2,a1
	moveq	#0,d4				; plane
	move.l	a2,a3
.p:	moveq	#7,d5
	move.l	a3,a2
	move.l	a1,-(sp)
.r:	moveq	#0,d6
	move.b	(a1)+,d6
	add.w	d6,d6
	lea	dbltab,a4
	move.w	(a4,d6.w),d6
	btst	d4,d3
	bne	.w
	moveq	#0,d6
.w:	move.b	d6,1(a2)
	move.b	d6,41(a2)
	lsr.w	#8,d6
	move.b	d6,(a2)
	move.b	d6,40(a2)
	lea	80(a2),a2
	dbf	d5,.r
	move.l	(sp)+,a1
	lea	PLANE(a3),a3
	addq.w	#1,d4
	cmp.w	#4,d4
	bne	.p
	move.l	a3,a2
	sub.l	#PLANE*4-2,a2
	bra	.ch
.x:	movem.l	(sp)+,d0-d7/a0-a4
	rts

; DrawBigC: centred big text, d1 = pixel line, d3 = colour
DrawBigC:
	movem.l	d0/a1,-(sp)
	move.l	a0,a1
	moveq	#20,d0
.l:	tst.b	(a1)+
	beq	.e
	subq.w	#1,d0
	bra	.l
.e:	bsr	DrawBig
	movem.l	(sp)+,d0/a1
	rts

; DrawLogo: d1 = pixel line (the logo is 160 wide, centred)
DrawLogo:
	movem.l	d0-d3/a0-a2,-(sp)
	lea	screen+10,a1
	mulu	#40,d1
	add.l	d1,a1
	lea	logo,a0
	moveq	#3,d3
.p:	move.l	a1,a2
	move.w	#LOGOH-1,d2
.r:	moveq	#19,d0
.b:	move.b	(a0)+,(a2)+
	dbf	d0,.b
	lea	20(a2),a2
	dbf	d2,.r
	add.l	#PLANE,a1
	dbf	d3,.p
	movem.l	(sp)+,d0-d3/a0-a2
	rts

; PutByte: d0 = byte column, d1 = pixel line, d3 = the bits, d4 = colour
PutByte:
	movem.l	d0-d2/a0,-(sp)
	lea	screen,a0
	mulu	#40,d1
	add.w	d0,d1
	add.l	d1,a0
	moveq	#0,d2
.p:	btst	d2,d4
	beq	.z
	move.b	d3,(a0)
	bra	.n
.z:	clr.b	(a0)
.n:	lea	PLANE(a0),a0
	addq.w	#1,d2
	cmp.w	#4,d2
	bne	.p
	movem.l	(sp)+,d0-d2/a0
	rts

; NumText: d0 = number, d1 = digits -> numbuf (text)
NumText:
	movem.l	d0-d3/a0-a1,-(sp)
	lea	numbuf,a0
	lea	pow10,a1
	moveq	#6,d2
	sub.w	d1,d2
	add.w	d2,d2
	add.w	d2,d2
	add.w	d2,a1
	subq.w	#1,d1
.d:	move.l	(a1)+,d2
	moveq	#'0',d3
.s:	cmp.l	d2,d0
	blo	.n
	sub.l	d2,d0
	addq.b	#1,d3
	bra	.s
.n:	move.b	d3,(a0)+
	dbf	d1,.d
	clr.b	(a0)
	movem.l	(sp)+,d0-d3/a0-a1
	rts

; DrawNum: d0 = number, d4 = digits, d5 = column, d6 = row, d3 = colour
DrawNum:
	movem.l	d0-d1/a0,-(sp)
	move.w	d4,d1
	bsr	NumText
	lea	numbuf,a0
	move.w	d5,d0
	move.w	d6,d1
	bsr	DrawText
	movem.l	(sp)+,d0-d1/a0
	rts

; Wait: d7 = frames (fire or Esc ends it early -> d0 = 1)
WaitFrames:
	subq.w	#1,d7
.l:	bsr	WaitFrame
	bsr	UpdateDisplay
	moveq	#1,d0
	tst.w	quitnow
	bne	.x
	move.w	joyedge,d1
	btst	#4,d1
	bne	.x
	dbf	d7,.l
	moveq	#0,d0
.x:	rts

pow10:		dc.l	100000,10000,1000,100,10,1
gfxname:	dc.b	'graphics.library',0
dosname:	dc.b	'dos.library',0
hiname:		dc.b	'StronkiesStoneAge.hi',0
	even
