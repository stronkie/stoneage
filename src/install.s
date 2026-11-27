;------------------------------------------------------------------------------
;  install.s - Stronkie's StoneAge hard disk installer
;
;  Runs from Workbench (double-click "Install" on the game disk) or from the
;  CLI (StronkiesStoneAge:Install).  Opens a console window, asks where to install
;  (default DH0:), makes the drawer StronkiesStoneAge there with its icon and
;  copies the game, its icon, the ReadMe and any saved records into it.
;  Needs only Kickstart/Workbench 1.3: no C: commands, no Installer utility.
;  Created By Mark Stronks, Stronkie Soft 2026
;------------------------------------------------------------------------------

_LVOFindTask	equ	-294
_LVOGetMsg	equ	-372
_LVOReplyMsg	equ	-378
_LVOWaitPort	equ	-384
_LVOForbid	equ	-132
_LVOCloseLibrary equ	-414
_LVOOpenLibrary	equ	-552
_LVOOpen	equ	-30
_LVOClose	equ	-36
_LVORead	equ	-42
_LVOWrite	equ	-48
_LVOLock	equ	-84
_LVOUnLock	equ	-90
_LVOCreateDir	equ	-120
_LVOCurrentDir	equ	-126
_LVOIoErr	equ	-132

BUFSIZE		equ	32768

	section	code,code
start:
	move.l	4.w,a6
	sub.l	a1,a1
	jsr	_LVOFindTask(a6)
	move.l	d0,a4
	tst.l	172(a4)			; pr_CLI: started from the CLI?
	bne.s	.cli
	lea	92(a4),a0		; from Workbench: take the startup message
	jsr	_LVOWaitPort(a6)
	lea	92(a4),a0
	jsr	_LVOGetMsg(a6)
	move.l	d0,wbmsg
.cli	lea	dosname,a1
	moveq	#0,d0
	jsr	_LVOOpenLibrary(a6)
	move.l	d0,dosbase
	beq	exit
	move.l	d0,a6
	move.l	#conname,d1		; our own window (Workbench gives us none)
	move.l	#1006,d2
	jsr	_LVOOpen(a6)
	move.l	d0,con
	beq	closedos
	bsr	find_source
	lea	t_hello,a0
	bsr	print

ask:	lea	t_where,a0
	bsr	print
	bsr	read_line		; -> inbuf, d0 = length
	tst.w	d0
	bne.s	.got
	lea	inbuf,a0		; just RETURN: DH0:
	lea	t_dh0,a1
.cp	move.b	(a1)+,(a0)+
	bne.s	.cp
.got	lea	inbuf,a0
	bsr	strlen
	cmp.b	#'Q',inbuf		; Q = quit
	beq.s	.q
	cmp.b	#'q',inbuf
	bne.s	.nq
.q	cmp.w	#1,d0
	beq	quit
.nq	; the place must exist
	move.l	#inbuf,d1
	moveq	#-2,d2
	jsr	_LVOLock(a6)
	tst.l	d0
	bne.s	.ok
	lea	t_nowhere,a0
	bsr	print
	bra.s	ask
.ok	move.l	d0,d1
	jsr	_LVOUnLock(a6)
	; dest = place + '/' + drawer
	lea	inbuf,a0
	lea	dest,a1
.c1	move.b	(a0)+,(a1)+
	bne.s	.c1
	subq.l	#1,a1
	move.b	-1(a1),d0
	cmp.b	#':',d0
	beq.s	.nos
	cmp.b	#'/',d0
	beq.s	.nos
	move.b	#'/',(a1)+
.nos	lea	drawername,a0
.c2	move.b	(a0)+,(a1)+
	bne.s	.c2
	; already there?
	move.l	#dest,d1
	moveq	#-2,d2
	jsr	_LVOLock(a6)
	tst.l	d0
	beq.s	.make
	move.l	d0,d1
	jsr	_LVOUnLock(a6)
	lea	t_exists,a0
	bsr	print
	bsr	read_line
	move.b	inbuf,d0
	or.b	#$20,d0
	cmp.b	#'y',d0
	bne	ask
	bra.s	.copy
.make	move.l	#dest,d1
	jsr	_LVOCreateDir(a6)
	tst.l	d0
	bne.s	.made
	lea	t_nodir,a0		; (write protected, full...)
	bsr	print
	bra	ask
.made	move.l	d0,d1
	jsr	_LVOUnLock(a6)

.copy	lea	t_installing,a0
	bsr	print
	lea	dest,a0
	bsr	print
	lea	t_nl,a0
	bsr	print
	clr.w	errors
	lea	f_game,a0
	moveq	#1,d7			; must be there
	bsr	copy_file
	lea	f_icon,a0
	bsr	copy_file
	lea	f_readme,a0
	bsr	copy_file
	lea	f_rec,a0
	moveq	#0,d7			; records: only if there are any
	bsr	copy_file
	bsr	write_drawer_icon
	tst.w	errors
	bne.s	.bad
	lea	t_done,a0
	bsr	print
	lea	dest,a0
	bsr	print
	lea	t_done2,a0
	bsr	print
	bra.s	wait_close
.bad	lea	t_failed,a0
	bsr	print
	bra	ask

quit:	lea	t_bye,a0
	bsr	print
wait_close:
	lea	t_close,a0
	bsr	print
	bsr	read_line
	move.l	con,d1
	jsr	_LVOClose(a6)
	move.l	olddir,d1		; back to where we were
	beq.s	closedos
	jsr	_LVOCurrentDir(a6)
	move.l	d0,d1			; (our lock on the disk)
	tst.b	ownlock
	beq.s	closedos
	jsr	_LVOUnLock(a6)
closedos:
	move.l	a6,a1
	move.l	4.w,a6
	jsr	_LVOCloseLibrary(a6)
exit:	move.l	4.w,a6
	move.l	wbmsg,d0
	beq.s	.x
	jsr	_LVOForbid(a6)		; (Workbench unloads us after the reply)
	move.l	d0,a1
	jsr	_LVOReplyMsg(a6)
.x	moveq	#0,d0
	rts

; find_source: the current directory becomes the folder with the game files
find_source:
	move.l	wbmsg,d0		; Workbench: the drawer of this tool
	beq.s	.cli
	move.l	d0,a0
	move.l	36(a0),a0		; sm_ArgList
	move.l	(a0),d1			; wa_Lock
	jsr	_LVOCurrentDir(a6)
	move.l	d0,olddir
	rts
.cli	move.l	#f_game,d1		; CLI: here, or on the game disk
	moveq	#-2,d2
	jsr	_LVOLock(a6)
	tst.l	d0
	beq.s	.disk
	move.l	d0,d1
	jmp	_LVOUnLock(a6)
.disk	move.l	#volname,d1
	moveq	#-2,d2
	jsr	_LVOLock(a6)
	tst.l	d0
	beq.s	.x
	st	ownlock
	move.l	d0,d1
	jsr	_LVOCurrentDir(a6)
	move.l	d0,olddir
.x	rts

; copy_file: a0 = name (in the current directory) -> dest/name; d7 = 1 must exist
copy_file:
	movem.l	d2-d6/a2,-(sp)
	move.l	a0,a2
	moveq	#0,d5			; (no input yet)
	move.l	a2,d1
	move.l	#1005,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	bne.s	.in
	tst.w	d7
	beq	.x			; optional and not there: fine
	lea	t_copy,a0
	bsr	print
	move.l	a2,a0
	bsr	print
	lea	t_missing,a0
	bsr	print
	addq.w	#1,errors
	bra	.x
.in	lea	t_copy,a0
	bsr	print
	move.l	a2,a0
	bsr	print
	lea	t_dots,a0
	bsr	print
	move.l	a2,a0			; dest/name
	bsr	dest_name
	move.l	#path,d1
	move.l	#1006,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d5
	beq.s	.werr
.l	move.l	d4,d1
	move.l	#buffer,d2
	move.l	#BUFSIZE,d3
	jsr	_LVORead(a6)
	tst.l	d0
	bmi.s	.rerr
	beq.s	.ok
	move.l	d0,d6
	move.l	d5,d1
	move.l	#buffer,d2
	move.l	d6,d3
	jsr	_LVOWrite(a6)
	cmp.l	d6,d0
	bne.s	.werr
	lea	t_dot,a0
	bsr	print
	bra.s	.l
.ok	lea	t_ok,a0
	bsr	print
	bra.s	.cl
.rerr	lea	t_readerr,a0
	bra.s	.err
.werr	lea	t_writeerr,a0
.err	bsr	print
	addq.w	#1,errors
.cl	tst.l	d5
	beq.s	.c2
	move.l	d5,d1
	jsr	_LVOClose(a6)
.c2	move.l	d4,d1
	jsr	_LVOClose(a6)
.x	movem.l	(sp)+,d2-d6/a2
	rts

; the drawer's icon, next to the drawer: dest.info
write_drawer_icon:
	movem.l	d2-d4,-(sp)
	lea	dest,a0
	lea	path,a1
.c	move.b	(a0)+,(a1)+
	bne.s	.c
	subq.l	#1,a1
	lea	t_info,a0
.c2	move.b	(a0)+,(a1)+
	bne.s	.c2
	move.l	#path,d1
	move.l	#1006,d2
	jsr	_LVOOpen(a6)
	move.l	d0,d4
	beq.s	.x
	move.l	d4,d1
	move.l	#drawer_icon,d2
	move.l	#drawer_icon_end-drawer_icon,d3
	jsr	_LVOWrite(a6)
	move.l	d4,d1
	jsr	_LVOClose(a6)
.x	movem.l	(sp)+,d2-d4
	rts

; dest_name: a0 = name -> path = dest/name
dest_name:
	lea	dest,a1
	lea	path,a2
.c	move.b	(a1)+,(a2)+
	bne.s	.c
	move.b	#'/',-1(a2)
.n	move.b	(a0)+,(a2)+
	bne.s	.n
	rts

; print: a0 = text (0 ends it)
print:
	movem.l	d1-d3/a0-a1,-(sp)
	bsr	strlen
	move.l	d0,d3
	beq.s	.x
	move.l	a0,d2
	move.l	con,d1
	jsr	_LVOWrite(a6)
.x	movem.l	(sp)+,d1-d3/a0-a1
	rts

strlen:					; a0 -> d0
	move.l	a0,a1
	moveq	#0,d0
.l	tst.b	(a1)+
	beq.s	.x
	addq.l	#1,d0
	bra.s	.l
.x	rts

; read_line -> inbuf (without the RETURN and spaces around it), d0 = length
read_line:
	movem.l	d1-d3/a0-a1,-(sp)
	move.l	con,d1
	move.l	#inbuf,d2
	moveq	#100,d3
	jsr	_LVORead(a6)
	tst.l	d0
	bpl.s	.ok
	moveq	#0,d0
.ok	lea	inbuf,a0
	clr.b	(a0,d0.w)
.t	tst.w	d0			; cut RETURN and spaces at the end
	beq.s	.f
	move.b	-1(a0,d0.w),d1
	cmp.b	#' ',d1
	bhi.s	.f
	subq.w	#1,d0
	clr.b	(a0,d0.w)
	bra.s	.t
.f	lea	inbuf,a0		; and at the start
	move.l	a0,a1
.s	cmp.b	#' ',(a1)
	bne.s	.m
	addq.l	#1,a1
	bra.s	.s
.m	moveq	#0,d0
.mv	move.b	(a1)+,(a0)+
	beq.s	.x
	addq.w	#1,d0
	bra.s	.mv
.x	movem.l	(sp)+,d1-d3/a0-a1
	rts

;------------------------------------------------------------------ data
	section	data,data
dosname		dc.b	'dos.library',0
conname		dc.b	'CON:20/12/600/180/Stronkie',39,'s StoneAge - Hard Disk Installer',0
volname		dc.b	'Stronkies StoneAge:',0
drawername	dc.b	'StronkiesStoneAge',0
f_game		dc.b	'SStoneAge',0
f_icon		dc.b	'SStoneAge.info',0
f_readme	dc.b	'ReadMe',0
f_rec		dc.b	'StronkiesStoneAge.hi',0
t_info		dc.b	'.info',0
t_dh0		dc.b	'DH0:',0
t_hello		dc.b	10,$9b,'1m','  STRONKIE',39,'S STONEAGE - HARD DISK INSTALLER',$9b,'0m',10
		dc.b	'  Created By Mark Stronks, Stronkie Soft',10,10
		dc.b	'  This puts the full game on your hard disk (or CF card)',10
		dc.b	'  in a new drawer called StronkiesStoneAge.',10
		dc.b	'  It needs about 150 KB of free space.',10,0
t_where		dc.b	10,'  Install where? Type a disk or drawer, like DH0: or',10
		dc.b	'  Work:Games, then press RETURN.',10
		dc.b	'  (Just RETURN = DH0:   Q = quit)',10,'  > ',0
t_nowhere	dc.b	'  That disk or drawer was not found. Try again.',10,0
t_exists	dc.b	'  The drawer is already there. Install over it (Y/N)? ',0
t_nodir		dc.b	'  Could not make the drawer there (write protected or full?)',10,0
t_installing	dc.b	10,'  Installing to ',0
t_copy		dc.b	'    ',0
t_dots		dc.b	' ',0
t_dot		dc.b	'.',0
t_ok		dc.b	' OK',10,0
t_missing	dc.b	' NOT FOUND ON THE GAME DISK!',10,0
t_readerr	dc.b	' READ ERROR!',10,0
t_writeerr	dc.b	' WRITE ERROR (disk full?)',10,0
t_failed	dc.b	10,'  Something went wrong, the game is not installed.',10,0
t_done		dc.b	10,'  Done! Open the drawer ',0
t_done2		dc.b	10,'  and double-click SStoneAge to play.',10
		dc.b	'  (On Workbench 1.3, close and open the disk window to see it.)',10,0
t_bye		dc.b	10,'  Nothing was installed.',10,0
t_close		dc.b	10,'  Press RETURN to close this window.',0
t_nl		dc.b	10,0
	even
drawer_icon	incbin	"drawer.info"
drawer_icon_end
	even

	section	bss,bss
wbmsg		ds.l	1
dosbase		ds.l	1
con		ds.l	1
olddir		ds.l	1
errors		ds.w	1
ownlock		ds.b	1
	even
inbuf		ds.b	128
dest		ds.b	256
path		ds.b	300
buffer		ds.b	BUFSIZE
