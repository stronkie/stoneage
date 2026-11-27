;=====================================================================
; loader.s - Stronkie's StoneAge: shows the loading picture (32 colours)
; while the game (StoneAge.game) loads, then starts it.
; Created By Mark Stronks, Stronkie Soft (c) 2026
;
; The system keeps running while the game loads (the floppy needs it);
; only the copper list is ours. The game gets d0 = 'SSAL' so it knows
; the loader has the Workbench message. When the game ends it is
; unloaded and the Workbench display comes back.
;=====================================================================
CUSTOM	equ	$dff000
COP1LC	equ	$080
COPJMP1	equ	$088
PICW	equ	40			; bytes per line
PICH	equ	256

	section	code,code
start:	movem.l	d1-d7/a0-a6,-(sp)
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
.cli:	lea	dosname(pc),a1
	moveq	#0,d0
	jsr	-552(a6)			; OpenLibrary
	move.l	d0,dosbase
	beq	.end
	lea	gfxname(pc),a1
	moveq	#0,d0
	jsr	-552(a6)
	move.l	d0,gfxbase
	beq	.end
	; the picture
	bsr	BuildCopper
	move.l	gfxbase,a6
	move.l	34(a6),oldview			; gb_ActiView
	sub.l	a1,a1
	jsr	-222(a6)			; LoadView(0)
	jsr	-270(a6)			; WaitTOF
	jsr	-270(a6)
	; the system's vertical blank reloads COP1LC from gb_LOFlist every
	; frame while the disk loads, so the picture goes in there
	move.l	#coplist,50(a6)			; gb_LOFlist
	move.l	#coplist,54(a6)			; gb_SHFlist
	lea	CUSTOM,a5
	move.l	#coplist,COP1LC(a5)
	move.w	d0,COPJMP1(a5)
	; load the game: PROGDIR: first (Kickstart 2.0+), then the current directory
	move.l	dosbase,a6
	cmp.w	#36,20(a6)			; lib_Version: PROGDIR: needs 2.0+
	blo	.cur
	move.l	#name1,d1
	jsr	-150(a6)			; LoadSeg
	move.l	d0,seglist
	bne	.loaded
.cur:	move.l	#name2,d1
	jsr	-150(a6)
	move.l	d0,seglist
	beq	.back
.loaded:
	; show the picture for at least 1.5 seconds
	move.l	gfxbase,a6
	moveq	#74,d7
.w:	jsr	-270(a6)			; WaitTOF
	dbf	d7,.w
	; start the game
	move.l	seglist,d0
	lsl.l	#2,d0
	move.l	d0,a0
	lea	4(a0),a1
	lea	cmdline(pc),a0
	move.l	#'SSAL',d0
	jsr	(a1)
	move.l	dosbase,a6
	move.l	seglist,d1
	jsr	-156(a6)			; UnLoadSeg
.back:	; the system's display back
	move.l	gfxbase,a6
	move.l	38(a6),d0			; gb_copinit
	lea	CUSTOM,a5
	move.l	d0,COP1LC(a5)
	move.l	oldview,a1
	jsr	-222(a6)			; LoadView
	jsr	-270(a6)
	jsr	-270(a6)
.end:	move.l	4.w,a6
	move.l	gfxbase,d0
	beq	.nog
	move.l	d0,a1
	jsr	-414(a6)			; CloseLibrary
.nog:	move.l	dosbase,d0
	beq	.nod
	move.l	d0,a1
	jsr	-414(a6)
.nod:	move.l	wbmsg,d0
	beq	.x
	jsr	-132(a6)			; Forbid (the message goes back last)
	move.l	d0,a1
	jsr	-378(a6)			; ReplyMsg
.x:	movem.l	(sp)+,d1-d7/a0-a6
	moveq	#0,d0
	rts

; BuildCopper: 5 bitplanes, 32 colours, no sprites
BuildCopper:
	lea	coplist,a0
	move.l	#$008e2c81,(a0)+		; DIWSTRT
	move.l	#$00902cc1,(a0)+		; DIWSTOP
	move.l	#$00920038,(a0)+		; DDFSTRT
	move.l	#$009400d0,(a0)+		; DDFSTOP
	move.l	#$01060c00,(a0)+		; BPLCON3 (ECS/AGA: as OCS)
	move.l	#$01fc0000,(a0)+		; FMODE
	move.l	#$01005200,(a0)+		; 5 bitplanes
	move.l	#$01020000,(a0)+
	move.l	#$01040000,(a0)+
	move.l	#$01080000,(a0)+
	move.l	#$010a0000,(a0)+
	move.l	#loadpic,d0
	move.w	#$00e0,d1
	moveq	#4,d2
.bp:	move.w	d1,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d1
	move.w	d1,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d1
	add.l	#PICW*PICH,d0
	dbf	d2,.bp
	move.l	#nosprite,d0			; all 8 sprites: nothing
	move.w	#$0120,d1
	moveq	#7,d2
.sp:	move.w	d1,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d1
	move.w	d1,(a0)+
	swap	d0
	move.w	d0,(a0)+
	addq.w	#2,d1
	dbf	d2,.sp
	lea	loadpal(pc),a1
	move.w	#$0180,d1
	moveq	#31,d2
.c:	move.w	d1,(a0)+
	move.w	(a1)+,(a0)+
	addq.w	#2,d1
	dbf	d2,.c
	move.l	#$fffffffe,(a0)+
	rts

	include	'loadpal.i'
dosname:	dc.b	'dos.library',0
gfxname:	dc.b	'graphics.library',0
name1:		dc.b	'PROGDIR:StoneAge.game',0
name2:		dc.b	'StoneAge.game',0
cmdline:	dc.b	10,0
	even

	section	vars,bss
dosbase:	ds.l	1
gfxbase:	ds.l	1
oldview:	ds.l	1
wbmsg:		ds.l	1
seglist:	ds.l	1

	section	chip,data_c
loadpic:	incbin	'loadpic.bin'
nosprite:	dc.l	0,0

	section	chipbss,bss_c
coplist:	ds.l	80
	end
