;=====================================================================
; title.i - the splash, the title, the high scores, the loop screen,
; the end of the demo
;=====================================================================
Splash:	bsr	SetTitleDisplay
	bsr	ClearScreen
	move.w	#96,d1
	bsr	DrawLogo
	lea	t_presents,a0
	moveq	#20,d1
	moveq	#3,d3
	bsr	DrawTextC
	move.w	#150,d7
	bra	WaitFrames

; Title: d0 = 0 start a game, 1 quit
Title:	tst.w	quitnow
	bne	.quit
	bsr	SetTitleDisplay
	bsr	ClearScreen
	bsr	StopMusic
	moveq	#0,d0
	bsr	PlayTune
	moveq	#4,d1
	bsr	DrawLogo
	lea	t_title1,a0
	moveq	#54,d1
	moveq	#2,d3
	bsr	DrawBigC
	lea	t_title2,a0
	moveq	#74,d1
	moveq	#10,d3
	bsr	DrawBigC
	ifne	DEMO
	lea	t_demo,a0
	moveq	#12,d1
	moveq	#12,d3
	bsr	DrawTextC
	endc
	lea	t_press,a0
	moveq	#27,d1
	moveq	#15,d3
	bsr	DrawTextC
	lea	t_credit,a0
	moveq	#29,d1
	moveq	#3,d3
	bsr	DrawTextC
	lea	t_ver,a0
	moveq	#30,d1
	moveq	#13,d3
	bsr	DrawTextC
	lea	t_keys1,a0
	moveq	#31,d1
	moveq	#13,d3
	bsr	DrawTextC
	clr.w	titlepage
	bsr	TitlePage
	bsr	TitleDev
	clr.w	lastkey
.l:	bsr	WaitFrame
	bsr	UpdateDisplay
	tst.w	quitnow
	bne	.quit
	tst.w	titlepage
	bne	.ns
	bsr	TitleSprites
.ns:	bsr	GetKey
	cmp.w	#K_ESC,d0
	beq	.quit
	cmp.w	#K_D,d0				; CTRL + ALT + D: developer mode
	bne	.nd
	lea	keys,a0
	tst.b	K_CTRL(a0)
	beq	.nd
	tst.b	K_LALT(a0)
	bne	.dv
	tst.b	K_RALT(a0)
	beq	.nd
.dv:	not.w	devmode
	bsr	TitleDev
.nd:	tst.w	devmode
	beq	.nj
	move.w	joyedge,d1			; dev: pick the level and the loop
	btst	#2,d1
	beq	.d1
	subq.w	#1,devlevel
	bpl	.d0
	move.w	#NLEVELS-1,devlevel
.d0:	bsr	TitleDev
.d1:	btst	#3,d1
	beq	.d2
	addq.w	#1,devlevel
	cmp.w	#NLEVELS,devlevel
	blo	.d3
	clr.w	devlevel
.d3:	bsr	TitleDev
.d2:	btst	#0,d1
	beq	.d4
	addq.w	#1,devloop
	and.w	#3,devloop
	bsr	TitleDev
.d4:	btst	#1,d1
	beq	.nj
	subq.w	#1,devloop
	and.w	#3,devloop
	bsr	TitleDev
.nj:	move.w	joyedge,d1
	btst	#4,d1
	bne	.start
	addq.w	#1,titletime
	cmp.w	#400,titletime
	blo	.l
	eor.w	#1,titlepage
	bsr	TitlePage
	bra	.l
.start:	bsr	ClearSprites
	moveq	#0,d0
	rts
.quit:	moveq	#1,d0
	rts

; TitlePage: rows 13-24: the story and the monsters, or the high scores
TitlePage:
	movem.l	d0-d7/a0-a2,-(sp)
	clr.w	titletime
	moveq	#13,d0
	moveq	#12,d1
	bsr	ClearRows
	tst.w	titlepage
	bne	.hi
	lea	t_s1,a0
	moveq	#2,d0
	moveq	#18,d1
	moveq	#2,d3
	bsr	DrawText
	lea	t_s2,a0
	moveq	#20,d1
	moveq	#1,d3
	bsr	DrawText
	lea	t_s3,a0
	moveq	#21,d1
	bsr	DrawText
	lea	t_s4,a0
	moveq	#22,d1
	bsr	DrawText
	lea	t_s5,a0
	moveq	#23,d1
	bsr	DrawText
	lea	monnames,a2
	moveq	#14,d1
	moveq	#2,d7
.m:	move.l	a2,a0
	moveq	#27,d0
	moveq	#10,d3
	bsr	DrawText
.m1:	tst.b	(a2)+
	bne	.m1
	move.l	a2,a0
	addq.w	#1,d1
	moveq	#13,d3
	bsr	DrawText
.m2:	tst.b	(a2)+
	bne	.m2
	addq.w	#3,d1
	dbf	d7,.m
	bra	.x
.hi:	bsr	ClearSprites
	lea	t_hst,a0
	moveq	#13,d1
	moveq	#2,d3
	bsr	DrawTextC
	lea	hitab,a2
	moveq	#0,d7
.e:	lea	linebuf,a1
	move.w	d7,d0
	addq.w	#1,d0
	cmp.w	#10,d0
	blo	.one
	move.b	#'1',(a1)+
	move.b	#'0',(a1)+
	bra	.r
.one:	move.b	#' ',(a1)+
	add.b	#'0',d0
	move.b	d0,(a1)+
.r:	move.b	#'.',(a1)+
	move.b	#' ',(a1)+
	move.b	(a2),(a1)+
	move.b	1(a2),(a1)+
	move.b	2(a2),(a1)+
	move.b	#' ',(a1)+
	move.l	4(a2),d0
	moveq	#6,d1
	bsr	NumText
	lea	numbuf,a0
.n:	move.b	(a0)+,(a1)+
	bne	.n
	lea	linebuf,a0
	moveq	#4,d0
	move.w	d7,d1
	cmp.w	#5,d7
	blo	.lc
	moveq	#22,d0
	subq.w	#5,d1
.lc:	add.w	d1,d1
	add.w	#15,d1
	moveq	#1,d3
	tst.w	d7
	bne	.c
	moveq	#15,d3
.c:	bsr	DrawText
	addq.l	#8,a2
	addq.w	#1,d7
	cmp.w	#HSN,d7
	bne	.e
.x:	movem.l	(sp)+,d0-d7/a0-a2
	rts

; TitleSprites: Stronkie and the three monsters on the story page
TitleSprites:
	movem.l	d0-d3,-(sp)
	moveq	#52,d0
	move.w	#108-PFTOP,d1
	moveq	#IMG_STAND,d2
	btst	#5,frame+3
	beq	.s
	moveq	#IMG_THROW,d2
.s:	moveq	#0,d3
	bsr	AddBig
	moveq	#1,d3
	move.l	frame,d2
	lsr.w	#4,d2
	and.w	#1,d2
	add.w	d2,d2
	move.w	d2,-(sp)
	add.w	#IMG_SCRUB1,d2
	move.w	#176,d0
	move.w	#104-PFTOP,d1
	bsr	AddBig
	move.w	(sp),d2
	add.w	#IMG_HOOT1,d2
	move.w	#136-PFTOP,d1
	bsr	AddBig
	move.w	(sp)+,d2
	add.w	#IMG_POG1,d2
	move.w	#168-PFTOP,d1
	bsr	AddBig
	movem.l	(sp)+,d0-d3
	rts

; TitleDev: row 25: the developer mode line
TitleDev:
	movem.l	d0-d3/a0-a1,-(sp)
	moveq	#25,d0
	moveq	#1,d1
	bsr	ClearRows
	tst.w	devmode
	beq	.x
	lea	linebuf,a1
	lea	t_devt,a0
.c:	move.b	(a0)+,(a1)+
	bne	.c
	subq.l	#1,a1
	move.w	devlevel,d0
	add.b	#'1',d0
	move.b	d0,(a1)+
	lea	t_devl,a0
.c2:	move.b	(a0)+,(a1)+
	bne	.c2
	subq.l	#1,a1
	move.w	devloop,d0
	lsl.w	#3,d0
	lea	t_views,a0
	add.w	d0,a0
.c3:	move.b	(a0)+,(a1)+
	bne	.c3
	lea	linebuf,a0
	moveq	#25,d1
	moveq	#12,d3
	bsr	DrawTextC
.x:	movem.l	(sp)+,d0-d3/a0-a1
	rts

;---------------------------------------------------------------------
; GameEnd: a new high score gets a name, then the file is saved
GameEnd:
	tst.w	devused
	bne	.x
	move.l	score,d0
	cmp.l	hitab+(HSN-1)*8+4,d0
	bls	.x
	bsr	NameEntry
	tst.w	quitnow
	bne	.x
	move.l	score,d0
	lea	namebuf,a0
	bsr	HiInsert
	tst.w	hichanged
	beq	.x
	lea	t_saving,a0
	moveq	#26,d1
	moveq	#15,d3
	bsr	DrawTextC
	bsr	WaitFrame
	bsr	SaveNow
	tst.l	d0
	beq	.x
	moveq	#26,d0
	moveq	#1,d1
	bsr	ClearRows
	lea	t_notsaved,a0
	moveq	#26,d1
	moveq	#12,d3
	bsr	DrawTextC
	move.w	#100,d7
	bsr	WaitFrames
.x:	rts

; NameEntry: three letters, typed or picked with the joystick
NameEntry:
	movem.l	d0-d7/a0-a3,-(sp)
	bsr	SetTitleDisplay
	bsr	ClearScreen
	moveq	#4,d0
	bsr	PlayTune
	lea	t_newhi,a0
	moveq	#40,d1
	moveq	#2,d3
	bsr	DrawBigC
	lea	t_yourscore,a0
	moveq	#13,d0
	moveq	#9,d1
	moveq	#3,d3
	bsr	DrawText
	move.l	score,d0
	moveq	#6,d4
	moveq	#24,d5
	moveq	#9,d6
	moveq	#15,d3
	bsr	DrawNum
	lea	t_entername,a0
	moveq	#11,d1
	moveq	#10,d3
	bsr	DrawTextC
	lea	t_ne1,a0
	moveq	#20,d1
	moveq	#13,d3
	bsr	DrawTextC
	lea	t_ne2,a0
	moveq	#21,d1
	bsr	DrawTextC
	lea	t_ne3,a0
	moveq	#22,d1
	bsr	DrawTextC
	move.l	#$41414100,namebuf		; "AAA"
	moveq	#0,d6				; position 0-2
	moveq	#0,d5				; frames up/down held
	clr.w	lastkey
	clr.w	joyedge
.loop:	bsr	WaitFrame
	bsr	UpdateDisplay
	tst.w	quitnow
	bne	.done
	bsr	NameDraw
	bsr	GetKey
	tst.w	d0
	beq	.joy
	cmp.w	#$44,d0				; Return
	beq	.done
	cmp.w	#$43,d0				; Enter
	beq	.done
	cmp.w	#$41,d0				; Backspace
	bne	.nb
	tst.w	d6
	beq	.joy
	subq.w	#1,d6
	lea	namebuf,a0
	move.b	#' ',(a0,d6.w)
	bra	.joy
.nb:	cmp.w	#$4f,d0
	beq	.joy
	cmp.w	#$4e,d0
	beq	.joy
	lea	rawkeys,a0
.rk:	move.b	(a0)+,d1
	beq	.joy
	move.b	(a0)+,d2
	cmp.b	d0,d1
	bne	.rk
	lea	namebuf,a0
	move.b	d2,(a0,d6.w)
	cmp.w	#2,d6
	beq	.joy
	addq.w	#1,d6
	clr.w	joyedge
	bra	.loop
.joy:	move.w	joy,d0
	move.w	joyedge,d1
	move.w	d0,d2
	and.w	#3,d2
	bne	.held
	moveq	#0,d5
	bra	.lr
.held:	addq.w	#1,d5
	btst	#0,d1
	bne	.up
	btst	#1,d1
	bne	.dn
	cmp.w	#18,d5
	blo	.lr
	move.w	d5,d3
	and.w	#3,d3
	bne	.lr
	btst	#0,d0
	bne	.up
.dn:	moveq	#-1,d3
	bra	.chg
.up:	moveq	#1,d3
.chg:	lea	namebuf,a0
	move.b	(a0,d6.w),d2
	lea	charset,a1
	moveq	#0,d4
.cf:	cmp.b	(a1,d4.w),d2
	beq	.cfo
	addq.w	#1,d4
	cmp.w	#CHARS,d4
	bne	.cf
	moveq	#0,d4
.cfo:	add.w	d3,d4
	bpl	.c1
	moveq	#CHARS-1,d4
.c1:	cmp.w	#CHARS,d4
	blo	.c2
	moveq	#0,d4
.c2:	move.b	(a1,d4.w),(a0,d6.w)
.lr:	btst	#2,d1
	beq	.nl
	tst.w	d6
	beq	.nl
	subq.w	#1,d6
.nl:	btst	#3,d1
	beq	.nr
	cmp.w	#2,d6
	beq	.nr
	addq.w	#1,d6
.nr:	btst	#4,d1
	beq	.loop
	cmp.w	#2,d6
	beq	.done
	addq.w	#1,d6
	bra	.loop
.done:	move.w	#-1,d6
	bsr	NameDraw
	move.w	#25,d7
.w:	bsr	WaitFrame
	bsr	UpdateDisplay
	dbf	d7,.w
	movem.l	(sp)+,d0-d7/a0-a3
	rts

; NameDraw: the three letters (big) with a blinking line under letter d6
NameDraw:
	movem.l	d0-d7/a0,-(sp)
	moveq	#0,d7
.l:	lea	namebuf,a0
	move.b	(a0,d7.w),chbuf
	clr.b	chbuf+1
	lea	chbuf,a0
	move.w	d7,d0
	mulu	#3,d0
	add.w	#16,d0				; columns 16, 19, 22
	moveq	#112,d1
	moveq	#15,d3
	bsr	DrawBig
	move.w	#$ff,d3
	moveq	#0,d4
	cmp.w	d6,d7
	bne	.nc
	btst	#4,frame+3
	bne	.nc
	moveq	#2,d4
.nc:	move.w	#130,d1
	bsr	PutByte
	addq.w	#1,d0
	bsr	PutByte
	addq.w	#1,d1
	bsr	PutByte
	subq.w	#1,d0
	bsr	PutByte
	addq.w	#1,d7
	cmp.w	#3,d7
	bne	.l
	movem.l	(sp)+,d0-d7/a0
	rts

;---------------------------------------------------------------------
; LoopScreen: all 8 levels done - the next loop has a twist
LoopScreen:
	bsr	StopMusic
	bsr	SetTitleDisplay
	bsr	ClearScreen
	moveq	#4,d0
	bsr	PlayTune
	lea	t_wd,a0
	moveq	#40,d1
	moveq	#2,d3
	bsr	DrawBigC
	lea	t_wd2,a0
	moveq	#9,d1
	moveq	#1,d3
	bsr	DrawTextC
	lea	t_wd3,a0
	moveq	#11,d1
	moveq	#15,d3
	bsr	DrawTextC
	move.w	loop,d0
	and.w	#3,d0
	lsl.w	#2,d0
	lea	twists,a0
	move.l	(a0,d0.w),a0
	moveq	#15,d1
	moveq	#10,d3
.t:	bsr	DrawTextC
.t1:	tst.b	(a0)+
	bne	.t1
	tst.b	(a0)
	beq	.go
	addq.w	#1,d1
	bra	.t
.go:	lea	t_press,a0
	moveq	#26,d1
	moveq	#13,d3
	bsr	DrawTextC
	move.w	#50,d7
.w:	bsr	WaitFrame
	bsr	UpdateDisplay
	dbf	d7,.w
	move.w	#500,d7
	bra	WaitFrames

	ifne	DEMO
; DemoEnd: what the full game has
DemoEnd:
	bsr	StopMusic
	bsr	SetTitleDisplay
	bsr	ClearScreen
	moveq	#4,d0
	bsr	PlayTune
	moveq	#6,d1
	bsr	DrawLogo
	lea	demotext,a0
	moveq	#8,d1
.l:	moveq	#1,d3
	cmp.w	#8,d1
	bne	.c
	moveq	#2,d3
.c:	bsr	DrawTextC
.n:	tst.b	(a0)+
	bne	.n
	addq.w	#1,d1
	tst.b	(a0)
	bne	.l
	move.w	#50,d7
.w:	bsr	WaitFrame
	bsr	UpdateDisplay
	dbf	d7,.w
	move.w	#3000,d7
	bra	WaitFrames
demotext:
	dc.b	'THANK YOU FOR PLAYING THE DEMO!',0
	dc.b	' ',0
	dc.b	'THE FULL GAME HAS:',0
	dc.b	' ',0
	dc.b	'8 LEVELS: BONES, ROPES AND CHAINS',0
	dc.b	'ENDLESS LOOPS WITH A TWIST:',0
	dc.b	'UPSIDE DOWN, TURNED 90 DEGREES,',0
	dc.b	'BLACK AND WHITE WITH FLASHES...',0
	dc.b	'FASTER MONSTERS EVERY LOOP',0
	dc.b	' ',0
	dc.b	'GET IT ON STRONKIE.ITCH.IO',0
	dc.b	' ',0
	dc.b	'PRESS FIRE',0
	dc.b	0
	even
	endc

;---------------------------------------------------------------------
twists:		dc.l	tw0,tw1,tw2,tw3
tw0:		dc.b	'BACK TO NORMAL...',0
		dc.b	'BUT THE MONSTERS ARE FASTER!',0,0
tw1:		dc.b	'THE STONE AGE IS NOW',0
		dc.b	'UPSIDE DOWN!',0,0
tw2:		dc.b	'THE STONE AGE HAS TIPPED OVER:',0
		dc.b	'IT IS TURNED 90 DEGREES!',0,0
tw3:		dc.b	'THE COLOURS ARE GONE:',0
		dc.b	'BLACK AND WHITE - AND IT FLASHES!',0,0
t_wd:		dc.b	'WELL DONE!',0
t_wd2:		dc.b	'ALL KEYS OF THE STONE AGE FOUND!',0
t_wd3:		dc.b	'BONUS 5000',0
t_presents:	dc.b	'PRESENTS',0
t_title1:	dc.b	"STRONKIE'S",0
t_title2:	dc.b	'STONEAGE',0
t_press:	dc.b	'PRESS FIRE TO START',0
t_credit:	dc.b	'CREATED BY MARK STRONKS, STRONKIE SOFT',0
t_ver:		include	'version.i'
t_keys1:	dc.b	'FIRE YO-YO  UP JUMP  M MUSIC  P PAUSE',0
	ifne	DEMO
t_demo:		dc.b	'DEMO VERSION - LEVELS 1 AND 2',0
	endc
t_s1:		dc.b	'STRONKIE',0
t_s2:		dc.b	'COLLECT ALL THE KEYS',0
t_s3:		dc.b	'BEFORE THE TIME RUNS',0
t_s4:		dc.b	'OUT - OR THE LIGHTS',0
t_s5:		dc.b	'GO OUT! YO-YO AWAY!',0
monnames:	dc.b	'SCRUBBLY',0,'200 POINTS',0
		dc.b	'HOOTER',0,'300 POINTS',0
		dc.b	'POGLET',0,'150 POINTS',0
t_hst:		dc.b	'THE BEST CAVEMEN',0
t_devt:		dc.b	'DEV MODE  LEVEL ',0
t_devl:		dc.b	'  VIEW ',0
t_views:	dc.b	'NORMAL ',0
		dc.b	'FLIPPED',0
		dc.b	'TURNED ',0
		dc.b	'B AND W',0
t_saving:	dc.b	'SAVING HIGH SCORES...',0
t_notsaved:	dc.b	'NOT SAVED - DISK WRITE PROTECTED?',0
t_newhi:	dc.b	'NEW HIGH SCORE!',0
t_yourscore:	dc.b	'YOUR SCORE',0
t_entername:	dc.b	'ENTER YOUR NAME',0
t_ne1:		dc.b	'TYPE YOUR NAME, OR WITH THE JOYSTICK:',0
t_ne2:		dc.b	'UP/DOWN LETTER, LEFT/RIGHT MOVE,',0
t_ne3:		dc.b	'FIRE NEXT.  RETURN OR LAST FIRE = OK',0
rawkeys:
	dc.b	$10,'Q',$11,'W',$12,'E',$13,'R',$14,'T',$15,'Y',$16,'U',$17,'I',$18,'O',$19,'P'
	dc.b	$20,'A',$21,'S',$22,'D',$23,'F',$24,'G',$25,'H',$26,'J',$27,'K',$28,'L'
	dc.b	$31,'Z',$32,'X',$33,'C',$34,'V',$35,'B',$36,'N',$37,'M'
	dc.b	$01,'1',$02,'2',$03,'3',$04,'4',$05,'5',$06,'6',$07,'7',$08,'8',$09,'9',$0a,'0'
	dc.b	$40,' ',$38,'.',$3a,'-'
	dc.b	0
charset:	dc.b	'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .-'
CHARS	equ	*-charset
	even
