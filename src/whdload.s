;=====================================================================
; whdload.s : StronkiesStoneAge.slave - the WHDLoad slave of Stronkie's StoneAge
;
; WHDLoad gives the game the whole machine (512 KB chip; the game uses about 330 KB). The slave
; loads the game program (data/SStoneAge), relocates it and starts it.
; The game hardly uses the OS: the few calls it makes (open libraries,
; Forbid, LoadView, WaitTOF, and files for the high score) go to small stand-in libraries here; files go through
; WHDLoad (resload_LoadFile / resload_SaveFile), so no Kickstart image
; is needed. Esc on the title ends the game and quits WHDLoad, and on a
; 68010 or better F10 quits too.
; Everything is pc-relative.
;=====================================================================

; WHDLoad
WHDLF_NoError	equ	$0002
WHDLF_ClearMem	equ	$1000
WHDLF_NoKbd	equ	$0040
resload_Abort	equ	4
resload_LoadFile equ	8
resload_SaveFile equ	12
resload_GetFileSize equ	36
resload_Relocate equ	80
TDREASON_OK	equ	-1
TDREASON_DEBUG	equ	5

BASEMEM		equ	$80000
; the stand-ins in the base memory (chip)
COPINIT		equ	$400			; an empty copper list
PROCESS		equ	$500			; the "process" (pr_CLI = 1)
EXECBASE	equ	$1000			; library bases, the jump tables
GFXBASE		equ	$1800			; are in front of them
DOSBASE		equ	$1c00
INTBASE		equ	$2000
EXECVEC		equ	120			; vectors per library
GFXVEC		equ	120
DOSVEC		equ	40
INTVEC		equ	80
FILES		equ	$2100			; 2 file handles of 64 bytes
FILEBUF		equ	$3000			; and their buffers of 8 KB
FILEBUFSIZE	equ	$2000
PROGRAM		equ	$8000			; the game, relocated here

; a file handle
FH_MODE		equ	0			; 0 free, 1005 read, 1006 write
FH_POS		equ	4
FH_SIZE		equ	8
FH_BUF		equ	12
FH_NAME		equ	16			; 48 bytes

_base:	moveq	#-1,d0				; ws_Security
	rts
	dc.b	'WHDLOADS'			; ws_ID
	dc.w	10				; ws_Version
	dc.w	WHDLF_NoError|WHDLF_ClearMem|WHDLF_NoKbd ; ws_Flags (the game polls the keyboard)
	dc.l	BASEMEM				; ws_BaseMemSize
	dc.l	0				; ws_ExecInstall
	dc.w	_start-_base			; ws_GameLoader
	dc.w	_dir-_base			; ws_CurrentDir
	dc.w	0				; ws_DontCache
	dc.b	0				; ws_keydebug
	dc.b	$59				; ws_keyexit = F10
	dc.l	0				; ws_ExpMem
	dc.w	_name-_base			; ws_name
	dc.w	_copy-_base			; ws_copy
	dc.w	_info-_base			; ws_info

_dir:	dc.b	'data',0
_name:	dc.b	"Stronkie's StoneAge",0
_copy:	dc.b	'2026 Mark Stronks, Stronkie Soft',0
_info:	dc.b	'Installed by Stronkie Soft',10
	include	'whdver.i'
_prog:	dc.b	'SStoneAge',0
_gfxname:	dc.b	'graphics.library',0
	even
_resload:	dc.l	0

;---------------------------------------------------------------------
_start:	lea	_resload(pc),a1
	move.l	a0,(a1)
	lea	BASEMEM-16,a7			; (the stack: the end of the memory)
	; the stand-ins
	lea	COPINIT,a0
	move.l	#$fffffffe,(a0)
	lea	PROCESS,a0
	move.l	#1,172(a0)			; pr_CLI: started from a CLI
	lea	EXECBASE,a0
	moveq	#EXECVEC,d0
	lea	ExecTab(pc),a1
	bsr	MakeLib
	lea	GFXBASE,a0
	moveq	#GFXVEC,d0
	lea	GfxTab(pc),a1
	bsr	MakeLib
	move.l	#COPINIT,GFXBASE+38		; gb_copinit
	lea	DOSBASE,a0
	moveq	#DOSVEC,d0
	lea	DosTab(pc),a1
	bsr	MakeLib
	lea	INTBASE,a0
	moveq	#INTVEC,d0
	lea	IntTab(pc),a1
	bsr	MakeLib
	move.l	#EXECBASE,4.w
	; the game: load it, relocate it, start it
	lea	_prog(pc),a0
	lea	PROGRAM,a1
	move.l	_resload(pc),a2
	jsr	resload_LoadFile(a2)
	lea	PROGRAM,a0
	sub.l	a1,a1
	move.l	_resload(pc),a2
	jsr	resload_Relocate(a2)
	lea	CmdLine(pc),a0
	moveq	#1,d0
	jsr	PROGRAM
	; the game has ended: quit
	pea	TDREASON_OK
	move.l	_resload(pc),-(a7)
	addq.l	#resload_Abort,(a7)
	rts

CmdLine:	dc.b	10,0
	even

; MakeLib: a0 = the library base, d0 = the number of vectors,
; a1 = a table of (offset.w, routine-_base.w), ending in 0: every
; vector jumps to Nothing, those in the table to their routine
MakeLib:
	movem.l	d0-d3/a0-a3,-(sp)
	lea	_base(pc),a3
	move.l	a0,a2
	subq.w	#1,d0
.v:	subq.l	#6,a2
	move.w	#$4ef9,(a2)			; jmp Nothing
	lea	Nothing(pc),a0
	move.l	a0,2(a2)
	dbf	d0,.v
	move.l	16(sp),a2			; (the base again: saved a0)
.t:	move.w	(a1)+,d1			; the offset
	beq.s	.x
	move.w	(a1)+,d2
	lea	(a3,d2.w),a0
	move.l	a0,2(a2,d1.w)
	bra.s	.t
.x:	movem.l	(sp)+,d0-d3/a0-a3
	rts

; the routines of the stand-in libraries
ExecTab:	dc.w	-294,FindTask-_base
		dc.w	-408,OpenLib-_base
		dc.w	-552,OpenLib-_base
		dc.w	-330,AllocSignal-_base
		dc.w	-444,OpenDevice-_base
		dc.w	0
GfxTab:		dc.w	-270,WaitTOF-_base
		dc.w	0
DosTab:		dc.w	-30,DosOpen-_base
		dc.w	-36,DosClose-_base
		dc.w	-42,DosRead-_base
		dc.w	-48,DosWrite-_base
		dc.w	-198,DosDelay-_base
		dc.w	-132,Nothing-_base	; IoErr
		dc.w	0
IntTab:		dc.w	0

Nothing:
	moveq	#0,d0
	rts

FindTask:
	move.l	#PROCESS,d0
	rts

; OpenLib: a1 = the name: graphics, dos and intuition
OpenLib:
	moveq	#0,d0
	move.b	(a1),d1
	cmp.b	#'g',d1
	bne.s	.d
	move.l	#GFXBASE,d0
	rts
.d:	cmp.b	#'d',d1
	bne.s	.i
	move.l	#DOSBASE,d0
	rts
.i:	cmp.b	#'i',d1
	bne.s	.x
	move.l	#INTBASE,d0
.x:	rts

AllocSignal:					; no signals: no trackdisk
	moveq	#-1,d0
	rts

OpenDevice:					; trackdisk can't be opened
	moveq	#1,d0
	rts

; WaitTOF: wait for the next frame (line 303)
WaitTOF:
	move.l	d1,-(sp)
.w1:	move.l	$dff004,d1
	and.l	#$1ff00,d1
	cmp.l	#303<<8,d1
	beq.s	.w1
.w2:	move.l	$dff004,d1
	and.l	#$1ff00,d1
	cmp.l	#303<<8,d1
	bne.s	.w2
	move.l	(sp)+,d1
	moveq	#0,d0
	rts

; Delay: d1 = 50ths of a second
DosDelay:
	move.l	d1,-(sp)
.l:	subq.l	#1,(sp)
	bmi.s	.x
	bsr	WaitTOF
	bra.s	.l
.x:	addq.l	#4,sp
	moveq	#0,d0
	rts

; Open: d1 = the name, d2 = the mode -> d0 = a handle or 0
DosOpen:
	movem.l	d1-d3/a0-a3,-(sp)
	move.l	d1,a3
	lea	FILES,a2			; a free handle
	lea	FILEBUF,a1
	moveq	#1,d3
.f:	tst.l	FH_MODE(a2)
	beq.s	.got
	lea	64(a2),a2
	add.l	#FILEBUFSIZE,a1
	dbf	d3,.f
	bra.s	.fail
.got:	move.l	a1,FH_BUF(a2)
	clr.l	FH_POS(a2)
	clr.l	FH_SIZE(a2)
	lea	FH_NAME(a2),a0			; the name, without a "drawer:"
	move.l	a3,a1
	move.l	a3,d0
.c:	move.b	(a1)+,d1
	beq.s	.c2
	cmp.b	#':',d1
	bne.s	.c
	move.l	a1,d0
	bra.s	.c
.c2:	move.l	d0,a1
	moveq	#46,d1
.cp:	move.b	(a1)+,(a0)+
	dbeq	d1,.cp
	clr.b	(a0)
	cmp.l	#1006,d2
	beq.s	.new
	; read: the file must be there
	lea	FH_NAME(a2),a0
	move.l	_resload(pc),a1
	jsr	resload_GetFileSize(a1)
	tst.l	d0
	beq.s	.fail
	cmp.l	#FILEBUFSIZE,d0
	bhi.s	.fail
	move.l	d0,FH_SIZE(a2)
	lea	FH_NAME(a2),a0
	move.l	FH_BUF(a2),a1
	move.l	_resload(pc),a3
	jsr	resload_LoadFile(a3)
.new:	move.l	d2,FH_MODE(a2)
	move.l	a2,d0
	bra.s	.x
.fail:	moveq	#0,d0
.x:	movem.l	(sp)+,d1-d3/a0-a3
	rts

; Close: d1 = the handle; a written file is saved now
DosClose:
	movem.l	d0-d1/a0-a2,-(sp)
	move.l	d1,a2
	cmp.l	#1006,FH_MODE(a2)
	bne.s	.x
	move.l	FH_SIZE(a2),d0
	lea	FH_NAME(a2),a0
	move.l	FH_BUF(a2),a1
	move.l	_resload(pc),a2
	jsr	resload_SaveFile(a2)
	move.l	4(sp),a2			; (the handle again: saved d1)
.x:	clr.l	FH_MODE(a2)
	movem.l	(sp)+,d0-d1/a0-a2
	moveq	#-1,d0
	rts

; Read: d1 = handle, d2 = buffer, d3 = length -> d0 = bytes read
DosRead:
	movem.l	d1-d3/a0-a2,-(sp)
	move.l	d1,a2
	move.l	FH_SIZE(a2),d0
	sub.l	FH_POS(a2),d0			; what is left
	cmp.l	d3,d0
	bls.s	.n
	move.l	d3,d0
.n:	move.l	FH_BUF(a2),a0
	add.l	FH_POS(a2),a0
	add.l	d0,FH_POS(a2)
	move.l	d2,a1
	move.l	d0,d1
	bra.s	.e
.c:	move.b	(a0)+,(a1)+
.e:	subq.l	#1,d1
	bpl.s	.c
	movem.l	(sp)+,d1-d3/a0-a2
	rts

; Write: d1 = handle, d2 = data, d3 = length -> d0 = bytes written
DosWrite:
	movem.l	d1-d3/a0-a2,-(sp)
	move.l	d1,a2
	move.l	#FILEBUFSIZE,d0
	sub.l	FH_SIZE(a2),d0			; room left
	cmp.l	d3,d0
	bls.s	.n
	move.l	d3,d0
.n:	move.l	FH_BUF(a2),a1
	add.l	FH_SIZE(a2),a1
	add.l	d0,FH_SIZE(a2)
	move.l	d2,a0
	move.l	d0,d1
	bra.s	.e
.c:	move.b	(a0)+,(a1)+
.e:	subq.l	#1,d1
	bpl.s	.c
	movem.l	(sp)+,d1-d3/a0-a2
	rts
