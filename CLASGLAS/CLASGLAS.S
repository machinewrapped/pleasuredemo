; Class In A Glass
;
; This screen was originally written in 1991 by Zax of The Cyberpunks.
;
; It was cleaned up and commented in 2024, with the addition of selectable colour palettes for the distorter.

screenbase	equ $76000
screensize	equ 32000
screentop	equ screenbase+screensize
stacktop  	equ (screenbase-screensize)-256
line_bytes	equ 160

disv		equ line_bytes*64	; Distorter vertical offset
dist_height	equ 48			; Distorter height

mid_lines	equ 77			; Number of lines between top and bottom HBL palette changes
scroller_line	equ 148			; Line where the scroller starts

numcolpatterns	equ 9
numcolpaths	equ 5
coldiswidth	equ 40
coldisheight	equ 48

font_height	equ 16
font_chars	equ 47
space_char	equ "A"+font_chars
total_chars	equ 48			; Includes the space character
scroller_chars	equ 11

ascii_space	equ $20
scancode_space	equ $39
scancode_f1	equ $3b
scancode_f10	equ $44


	; check for magic value indicating we were called from the bootstrap
	cmp.l #"PDOM",d0
	bne.s standalone

	move.l (sp)+,retadr
	bra.s standalone

retadr	dc.l 0

standalone
	clr.l -(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp
	move.l d0,osp

	lea bufr,a0
	move.l #screentop,a1
	moveq #0,d0
clmem	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	cmp.l a0,a1
	bgt.s clmem

	; move.l #stacktop,sp

	move.w #4,-(sp)
	trap #14
	addq.l #2,sp
	move.w d0,orez

	clr.w -(sp)
	move.l #screenbase,-(sp)
	move.l #screenbase,-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	move.l $44e.w,o44e

	movem.l $ffff8240.w,d0-d7
	movem.l d0-d7,opal

	movem.l frm(pc),d0-d7
	movem.l d0-d7,$ffff8240.w

	; moveq #1,d0
	; bsr starpaws

	bsr shftft
	bsr setmes
	bsr putlon
	bsr shiflog
	bsr presh
	bsr make_coldis
	bsr make_col_paths

	move.l dcolp(pc),start			; Colour distorter path start
	move.l dcolp(pc),dpoin			; Colour distorter path pointer
	move.l dcolp+4(pc),end			; Colour distorter path end

	bsr init_coldis

	movem.l pall1(pc),d0-d7
	movem.l d0-d7,$ffff8240.w

	bsr hblon

	clr.b key
waitkey	stop #$2300			; VSync
	move.b key(pc),d0
	beq.s waitkey

	clr.b key
	cmp.b #scancode_space,d0
	beq.s bad

	cmp.b #scancode_f10,d0
	bne.s .notf10

	bsr cycle_coldis_palette

	bra.s waitkey
	
.notf10	sub.b #scancode_f1,d0
	bmi.s waitkey
	cmp.b #numcolpatterns,d0
	bge.s waitkey

	bsr select_coldis_pattern

	bra.s waitkey

bad	move.b #7,$ffff8800.w
	move.b #%11111111,$ffff8802.w

	bsr hbloff

	; bsr starpaws+4			; Music off

	move.l o44e(pc),d0
	move.w orez(pc),d1
	move.w d1,-(sp)
	move.l d0,-(sp)
	move.l d0,-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	movem.l opal(pc),d0-d7
	movem.l d0-d7,$ffff8240.w

	move.l osp(pc),-(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp

	; check for return address
	move.l retadr(pc),d0
	tst.l d0
	beq.s exit

	; Return to the bootstrap
	move.l d0,a0
	jmp (a0)

exit	clr.w -(sp)
	trap #1

nul	rte

hblon	lea mfpstr(pc),a0
	move.b $fffffa07.w,(a0)+
	move.b $fffffa09.w,(a0)+
	move.b $fffffa13.w,(a0)+
	move.b $fffffa15.w,(a0)+
	move.l $70.w,(a0)+
	move.l $118.w,(a0)+
	move.l $120.w,(a0)+
	lea $8.w,a1
	move.l (a1)+,(a0)+
	move.l (a1)+,(a0)+
	move.l (a1)+,(a0)+
	clr.b $fffffa07.w
	clr.b $fffffa09.w
	bclr #3,$fffffa17.w
	move.l #nkey,$118.w
	move.l #vbl,$70.w
	move.l #nul,$120.w

	bset #6,$fffffa09.w		; enable keyboard interrupt
	bset #6,$fffffa15.w
	bset #0,$fffffa07.w		; enable timer B interrupt
	bset #0,$fffffa13.w

	lea bad(pc),a0			; enable crash handlers
	lea $8.w,a1
	move.l a0,(a1)+
	move.l a0,(a1)+
	move.l a0,(a1)+

	move.b #$12,$fffffc02.w		; keyboard ACIA data

	rts

nkey	move.w d0,-(sp)
	move.w d1,-(sp)
	move.b $fffffc02.w,d0
	cmp.b #$ff,d0
	beq.s joyst

	move.b d0,d1
	andi.b #$fc,d0
	cmp.b #$f8,d0
	beq.s mous

	move.b d1,key

	move.w (sp)+,d1
	move.w (sp)+,d0
	rte

joyst	move.l #gjoy,$118.w
	move.w (sp)+,d1
	move.w (sp)+,d0
	rte

gjoy	move.b $fffffc02.w,joycm
	move.l #nkey,$118.w
	rte

mous	move.l #gmous1,$118.w
	move.b d1,mousb
	move.w (sp)+,d1
	move.w (sp)+,d0
	rte

gmous1	move.b $fffffc02.w,mousx
	move.l #gmous2,$118.w
	rte

gmous2	move.b $fffffc02.w,mousy
	move.l #nkey,$118.w
	rte


hbloff
	clr.b $fffffa1b.w
	lea mfpstr(pc),a0
	move.b (a0)+,$fffffa07.w
	move.b (a0)+,$fffffa09.w
	move.b (a0)+,$fffffa13.w
	move.b (a0)+,$fffffa15.w
	bset #3,$fffffa17.w
	move.l (a0)+,$70.w
	move.l (a0)+,$118.w
	move.l (a0)+,$120.w
	lea $8.w,a1
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.b #8,$fffffc02.w
	rts


; First HBL handler
hblcol1	move.w scrlco,$ffff824a.w
colmd	move.w bars,$ffff8240.w
	bpl.s ehbl				; Repeat until the end of the bars

	move.l pall1(pc),$ffff8240.w		; Set up the main palette
	move.l pall1+4(pc),$ffff8240+4.w
	move.l pall1+8(pc),$ffff8240+8.w
	move.l pall1+12(pc),$ffff8240+12.w
	move.l pall1+16(pc),$ffff8240+16.w
	move.l #grbr,mccol+2
	move.b #mid_lines,$fffffa21.w	; Set the Timer B period (number of lines before the next interrupt)
	move.l #hblcol2,$120		; next handler
ehbl	addq.l #2,hblcol1+2		; advance the colour table pointers
	addq.l #2,colmd+2
	rte

hblcol2	move.b #1,$fffffa21.w		; Set the Timer B period (number of lines before the next interrupt)
mccol	move.w grbr,$ffff8240.w		; Grey bars
	bpl.s ecol2			; .. until we reach black 
	move.w #$333,$ffff8240.w	; .. which we'll pretend was a grey
	move.l #hblcol3,$120.w		; next handler
ecol2	addq.l #2,mccol+2		; advance the colour table pointer
	rte

hblcol3	clr.l $ffff8240.w		; Black background
	clr.b $fffffa1b.w		; Turn off Timer B
	movem.l d0-d7/a0-a2,-(a7)	; Save registers
	move.w sr,-(a7)			; Save status register
	move.w #$2700,sr		; Disable interrupts

	lea season+bufr,a1		; Colour distortion routine list
	movea.w #$8209,a2		; Video address pointer (low byte)
	movea.w #$8240,a0		; Background palette colour

sync	move.b (a2),d0			; Read the low byte of the video address
	bmi.s sync			; Wait until it is non-negative
	
	cmp.b #8,d0			; Wait until it is 8 or less
	bgt.s sync

	moveq #15,d1			; Subtract from 15
	sub.b d0,d1
	lsl.w d1,d0			; Variable shift to sync (4 cycles for every 2 steps)

	dcb.w 13,$4e71			; 52 cycles to get to the start of the next line (this depends which line we sync on)

collns	move.l (a1)+,a2
	jmp (a2)

abyss	clr.w (a0)
	move.l #grbr2,mccol2+2
	move.l #col4,$120.w
	move.b #1,$fffffa21.w
	move.b #8,$fffffa1b.w
	move.w (a7)+,sr
	movem.l (sp)+,d0-d7/a0-a2
	rte

col4	move.b #1,$fffffa21.w
mccol2	move.w grbr,$ffff8240.w
	bpl.s ecol4
	move.l #nul,$120.w
ecol4	addq.l #2,mccol2+2
	rte


vbl	movem.l d0-d7/a0-a6,-(sp)

	movem.l pall2(pc),d0-d7
	movem.l d0-d7,$ffff8240.w

	move.l screen1,d0
	move.l screen2,screen1
	move.l d0,screen2
	move.l d0,$44e.w
	lsr.w #8,d0
	move.l d0,$ffff8200.w

	move.l #bars,colmd+2
	move.l #scrlco,hblcol1+2
	move.l #hblcol1,$120.w
	clr.b $fffffa1b.w
	move.b #1,$fffffa21.w
	move.b #8,$fffffa1b.w
	clr.b colflg

	bsr scrlhbl
	bsr unball
	bsr distort
	bsr balls
	bsr scroller
	bsr coldis

	; bsr starpaws+8

timcol	move.w #$000,$ffff8240.w
*	move.w #$777,$ffff8240.w

	movem.l (sp)+,d0-d7/a0-a6
	rte

; Draw the logo at the top of the screen
putlon	lea toplog(pc),a0
	move.l screen1,a1
	move.l screen2,a2
	move.w #960-1,d7
plon	move.l (a0),(a1)+
	move.l (a0)+,(a2)+
	move.w (a0),(a1)+
	move.w (a0)+,(a2)+
	addq.l #2,a1
	addq.l #2,a2
	dbra d7,plon
	rts

; Scroll the rainbow colours in the logo
scrlhbl	addq.l #2,scrlpnt
	cmp.l #erain,scrlpnt
	blt.s nohbl
	move.l #rainbow,scrlpnt
nohbl	move.l scrlpnt(pc),a0
	lea scrlco(pc),a1
	movem.l (a0)+,d0-d7
	movem.l d0-d7,(a1)
	movem.l (a0)+,d0-d7
	movem.l d0-d7,32(a1)
	move.l (a0)+,64(a1)
	rts

; Preshift the distorter
shiflog	lea dislog(pc),a0
	lea logo+bufr,a1
	moveq #dist_height-1,d7
coptb	clr.l (a1)+
	clr.w (a1)+
	moveq #24-1,d6
coptbl	move.l (a0)+,(a1)+
	dbra d6,coptbl
	dbra d7,coptb

	lea logo+bufr,a0
	move.w #15*48-1,d7
shft	lea 96(a0),a3
	moveq #3-1,d6
bplns	moveq #17-1,d5
	move.w 6(a3),d0
	lsl.w #1,d0
	move.w d0,4902(a3)
colums	move.w (a3),d0
	roxl.w #1,d0
	move.w d0,4896(a3)
	subq.l #6,a3
	dbra d5,colums
	lea 104(a3),a3
	dbra d6,bplns
	lea 102(a0),a0
	dbra d7,shft

	lea dispth(pc),a0
	lea edisp(pc),a1
	moveq #dist_height*2-1,d7
copdisp	move.l (a0)+,(a1)+
	dbra d7,copdisp

	rts

; Draw the distorter
distort	lea logo+bufr,a0
	lea 0(a0),a3
	move.l $44e.w,a1
	lea disv(a1),a1
	lea 0(a1),a4
	move.l pdisp(pc),a2
	moveq #dist_height-1,d7
lines	add.w (a2)+,a1
	add.l (a2)+,a0
	move.w (a2)+,d6
cols	move.l (a0)+,(a1)+
	move.w (a0)+,(a1)
	addq.l #4,a1
	dbra d6,cols
	lea 102(a3),a3
	lea 0(a3),a0
	lea line_bytes(a4),a4
	lea (a4),a1
	dbra d7,lines
	addq.l #8,pdisp
	cmp.l #edisp,pdisp
	blt.s mock
	move.l #dispth,pdisp
mock
	rts

setmes	lea mess(pc),a0
	move.w #((emes-mess))-1,d0
suba	cmp.b #ascii_space,(a0)
	bne.s nospac
	move.b #space_char,(a0)
nospac	sub.b #"A",(a0)+
	dbra d0,suba

	moveq #10,d1
	lea mess(pc),a0
	lea frm(pc),a1
	moveq #11-1,d0
putbuf	clr.l d2
	move.b (a0)+,d2
	lsl.l d1,d2
	move.l d2,(a1)+
	dbra d0,putbuf

	rts

; Preshift the font
shftft	lea fnt,a0
	lea logo+bufr,a1
	move.l #47*4*font_height/4,d0
clop	move.l (a0)+,(a1)+
	dbra d0,clop

	lea logo+bufr,a0
	lea font+1024+bufr,a1
	moveq #48-1,d7    ; NO. OF LETTERS
loopa	lea font+bufr,a2
	moveq #font_height-1,d6    ; 16 lines
loopb	clr.l (a1)+
	clr.l (a2)+
	move.l (a0),(a1)+
	move.l (a0)+,(a2)+
	dbra d6,loopb

	moveq #7-1,d6     ; NO. OF SHIFTS
shlop	lea font+bufr,a2
	moveq #font_height-1,d4    ; NO. OF LINES
linlop	move.l (a2),d0
	lsl.l #4,d0
	move.l d0,(a2)+
ilop	move.b (a2),d0
	lsr.b #4,d0
	add.b d0,-1(a2)
	move.l (a2),d0
	lsl.l #4,d0
	move.l d0,(a2)+
	dbra d4,linlop

	lea font+bufr,a2
	moveq #32-1,d5    ; 64 pixels * 16 lines /8
stlop	move.l (a2)+,(a1)+
	dbra d5,stlop
	dbra d6,shlop
	dbra d7,loopa

	lea font+1024+bufr,a0    ; FONT TAKES UP BUFR TO BUFR+46000
	lea font+bufr,a1
	move.l #(font_chars*font_height*8),d0
backit	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	dbra d0,backit

	move.l #256-1,d0
clend	clr.l (a1)+
	dbra d0,clend

	lea logo+bufr,a0
	move.l #4000,d0
cls	clr.l (a0)+
	clr.l (a0)+
	dbra d0,cls

	rts

; Scroller
scroller	move.l $44e.w,a4
	lea scroller_line*line_bytes(a4),a4
	lea font+bufr,a3
	move.w pixl(pc),d0
	lsl.w #7,d0
	add.w d0,a3
	lea 4(a3),a0
	lea 0(a4),a1
	lea frm(pc),a2
	add.l (a2),a0
	moveq #font_height-1,d0	; height
yl1	move.w (a0)+,(a1)
	move.w (a0)+,8(a1)
	addq.w #4,a0
	lea line_bytes(a1),a1
	dbra d0,yl1

	lea 0(a3),a0
	lea 0(a4),a1
	adda.w #144,a1
	add.l 40(a2),a0
	moveq #font_height-1,d0	; height
yl2	move.w (a0)+,(a1)
	move.w (a0)+,8(a1)
	addq.w #4,a0
	lea line_bytes(a1),a1
	dbra d0,yl2

	lea 0(a4),a1
	lea 16(a1),a1
	moveq #4-1,d0
mloop	lea 0(a3),a0
	addq.l #8,a2
	add.l (a2),a0
	moveq #font_height-1,d1      ; height
yl3	move.w (a0)+,(a1)
	move.w (a0)+,8(a1)
	move.w (a0)+,16(a1)
	move.w (a0)+,24(a1)
	lea line_bytes(a1),a1
	dbra d1,yl3
	sub.l #line_bytes*font_height-32,a1
	dbra d0,mloop

	lea 0(a4),a1
*	lea 8(a1),a1
	lea frm(pc),a2
	subq.l #4,a2
	moveq #5-1,d0
mloop2	lea 0(a3),a0
	addq.l #8,a2
	add.l (a2),a0
	moveq #font_height-1,d1      ; height
yl4	movem.w (a0)+,d4-d7
	or.w d4,(a1)
	or.w d5,8(a1)
	or.w d6,16(a1)
	or.w d7,24(a1)
	lea line_bytes(a1),a1
	dbra d1,yl4
	sub.l #line_bytes*font_height-32,a1
	dbra d0,mloop2

	addq.w #1,pixl
	cmp.w #8,pixl
	bne nonlt

	clr.w pixl
	lea frm+4(pc),a0
	moveq #10-1,d0
lft	move.l (a0)+,-8(a0)
	dbra d0,lft

	clr.l d0
	addq.l #1,pmes
	cmp.l #emes,pmes
	bne.s nowrap

	move.l #mess,pmes

nowrap	move.l pmes(pc),a1
	move.b (a1)+,d0
	lsl.l #8,d0
	lsl.l #2,d0
	move.l d0,-4(a0)

nonlt	rts

******************************

presh	lea ballog,a5
	lea code+bufr,a2
	lea udraw+bufr,a4
	lea rlist+bufr,a6
	moveq #16-1,d6
shifs	move.l a2,(a6)+
	move.l a4,(a6)+
	lea (a5),a0
	bsr shif
	bsr maskmak
	bsr codegen
	dbra d6,shifs
	rts

shif	movem.l d0-d7/a0-a6,-(sp)
	lea ballz+bufr,a1
	moveq #16-1,d7
shif_l	clr.l d0
	move.w (a0)+,d0
	lsl.l d6,d0
	clr.l d1
	move.w (a0)+,d1
	lsl.l d6,d1
	clr.l d2
	move.w (a0)+,d2
	lsl.l d6,d2
	clr.l d3
	move.w (a0)+,d3
	lsl.l d6,d3
	move.w d0,8(a1)
	move.w d1,10(a1)
	move.w d2,12(a1)
	move.w d3,14(a1)
	swap d0
	swap d1
	swap d2
	swap d3
	move.w d0,(a1)
	move.w d1,2(a1)
	move.w d2,4(a1)
	move.w d3,6(a1)
	add.l #16,a1
	dbra d7,shif_l
	movem.l (sp)+,d0-d7/a0-a6
	rts


maskmak	movem.l d0-d7/a0-a6,-(sp)
	lea ballz+bufr,a0
	lea masp+bufr,a1
loopmsk	movem.w (a0)+,d0-d3
	or.w d1,d0
	or.w d2,d0
	or.w d3,d0
	not.w d0
	move.w d0,(a1)+
	move.w d0,(a1)+
	cmp.l #bufr+masp,a0
	ble.s loopmsk
	movem.l (sp)+,d0-d7/a0-a6
	rts

codegen	movem.l d0-d7/a0-a1/a3/a5-a6,-(sp)
	lea ballz+bufr,a0
	lea masp+bufr,a1
	moveq #8,d2
	move.l #line_bytes-8,d3
	move.l #line_bytes,d0

	move.l (a1)+,d1
	cmp.l #-1,d1
	beq.s nfwrd
 	move.w #$291,(a2)+
 	move.l d1,(a2)+
 	move.w #$2a9,(a2)+
 	move.l d1,(a2)+
 	move.w #4,(a2)+

 	move.w #$a9,(a2)+
 	move.l (a0),(a2)+
 	move.w #0,(a2)+

 	move.w #$a9,(a2)+
 	move.l 4(a0),(a2)+
 	move.w #4,(a2)+

	move.w #$2340,(a4)+
	move.w #0,(a4)+
	move.w #$2340,(a4)+
	move.w #4,(a4)+

nfwrd	move.l (a1)+,d1
	cmp.l #-1,d1
	beq.s nswrd
 	move.w #$2a9,(a2)+
 	move.l d1,(a2)+
 	move.w #8,(a2)+
 	move.w #$2a9,(a2)+
 	move.l d1,(a2)+
 	move.w #12,(a2)+

	move.w #$a9,(a2)+
 	move.l 8(a0),(a2)+
 	move.w #8,(a2)+
	move.w #$a9,(a2)+
 	move.l 12(a0),(a2)+
 	move.w #12,(a2)+

	move.w #$2340,(a4)+
	move.w #8,(a4)+
	move.w #$2340,(a4)+
	move.w #12,(a4)+

nswrd	add.l #16,a0
	moveq #14*2-1,d6
lincd	move.l (a1)+,d1
	beq.s solid
	cmp.l #-1,d1
	beq.s common

 	move.w #$2a9,(a2)+
 	move.l d1,(a2)+
 	move.w d0,(a2)+
 	move.w #$2a9,(a2)+
 	move.l d1,(a2)+
 	move.w d0,(a2)
 	addq.w #4,(a2)+

	move.w #$a9,(a2)+
 	move.l (a0),(a2)+
 	move.w d0,(a2)+
	move.w #$a9,(a2)+
 	move.l 4(a0),(a2)+
 	move.w d0,(a2)
 	addq.w #4,(a2)+

	move.w #$2340,(a4)+
	move.w d0,(a4)+
	move.w #$2340,(a4)+
	move.w d0,(a4)
	addq.w #4,(a4)+

common	addq.l #8,a0
	add.w d2,d0
	exg d2,d3
	dbra d6,lincd
	move.w #$4e75,(a2)+
	move.w #$4e75,(a4)+
	movem.l (sp)+,d0-d7/a0-a1/a3/a5-a6
	rts


solid	move.w #$237c,(a2)+
	move.l (a0),(a2)+
	move.w d0,(a2)+
	move.w #$237c,(a2)+
	move.l (a0),(a2)+
	move.w d0,(a2)
	addq.w #4,(a2)+

	move.w #$2340,(a4)+
	move.w d0,(a4)+
	move.w #$2340,(a4)+
	move.w d0,(a4)
	addq.w #4,(a4)+
	bra.s common

unball	moveq #11-1,d7
	move.l ubalp1(pc),a5
	move.l ubalp2(pc),a6
	move.l pbalp1(pc),ubalp1
	move.l pbalp2(pc),ubalp2
eachu	move.w (a5)+,d6
	beq.s nobl2
	add.w (a6)+,d6
	move.w (a6)+,d5

	move.l screen2(pc),a1
	add.w d6,a1
	lea rlist+bufr,a0
	move.l 4(a0,d5.w),a0
	clr.l d0
	jsr (a0)

nobl2	addq.l #6,a5
	add.l #12,a6
	dbra d7,eachu
	rts

balls	addq.l #2,pbalp1
	cmp.l #ebalp1,pbalp1
	blt.s nbalp1
	move.l #balpth1,pbalp1
nbalp1	addq.l #4,pbalp2
	cmp.l #ebalp2,pbalp2
	blt.s nbalp2
	move.l #balpth2,pbalp2

nbalp2	move.l pbalp1(pc),a5
	move.l pbalp2(pc),a6
	moveq #11-1,d7
eachb	move.w (a5)+,d6
	beq.s nobl
	add.w (a6)+,d6
	move.w (a6)+,d5
	move.l $44e.w,a1
	add.w d6,a1

	lea rlist+bufr,a0
	move.l (a0,d5.w),a0
	jsr (a0)

nobl	addq.l #6,a5
	adda.w #12,a6
	dbra d7,eachb
	rts


; Generate the routines for the colour distorter
; - uses immediate writes to (a0) for maximum speed (12 cycles per colour for palette registers)
; - generates 3 variations with different NOP patterns for 4 pixel offsets
make_coldis:
	move.l pdiscol(pc),a0		; a0: colour palette
	lea bufr+disrts,a1		; a1: colour distortion routines
	lea bufr+disrl,a2		; a2: colour distortion routine list

	moveq #coldiswidth-1,d7		; Loop over all palette entries
	move.w #$4e71,d5		; NOP
	move.w #$30bc,d4		; MOVE.W #XXX,(a0)
	move.l #$24594ed2,d3		; movea.l (a1)+,a2 ; jmp (a2)
makdr_1	lea (a0),a3			; Save the palette address in a3
	move.l a1,(a2)+
	move.w d5,(a1)+			; NOP
	move.w d5,(a1)+			; NOP
	move.w d5,(a1)+			; NOP
	moveq #coldiswidth/4-1,d6	; Loop over all palette entries (unrolled)
makdr_2	move.w d4,(a1)+			; MOVE.W #XXX,(a0)+
	move.w (a0)+,(a1)+		; Colour value
	move.w d4,(a1)+			; MOVE.W #XXX,(a0)+
	move.w (a0)+,(a1)+		; Colour value
	move.w d4,(a1)+			; MOVE.W #XXX,(a0)+
	move.w (a0)+,(a1)+		; Colour value
	move.w d4,(a1)+			; MOVE.W #XXX,(a0)+
	move.w (a0)+,(a1)+		; Colour value
	dbra d6,makdr_2
	move.l d3,(a1)+			; movea.l (a1)+,a2 ; jmp (a2)
	
	lea (a3),a0			; Reset the palette address
	move.l a1,(a2)+
	move.w d5,(a1)+			; NOP
	move.w d5,(a1)+			; NOP
	moveq #coldiswidth/4-1,d6	; Loop over all palette entries (unrolled)
makdr_3	move.w d4,(a1)+			; MOVE.W #XXX,(a0)+
	move.w (a0)+,(a1)+		; Colour value
	move.w d4,(a1)+			; MOVE.W #XXX,(a0)+
	move.w (a0)+,(a1)+		; Colour value
	move.w d4,(a1)+			; MOVE.W #XXX,(a0)+
	move.w (a0)+,(a1)+		; Colour value
	move.w d4,(a1)+			; MOVE.W #XXX,(a0)+
	move.w (a0)+,(a1)+		; Colour value
	dbra d6,makdr_3
	move.w d5,(a1)+			; NOP
	move.l d3,(a1)+			; movea.l (a1)+,a2 ; jmp (a2)

	lea (a3),a0			; Reset the palette address
	move.l a1,(a2)+
	move.w d5,(a1)+			; NOP
	moveq #coldiswidth/4-1,d6	; Loop over all palette entries (unrolled)
makdr_4	move.w d4,(a1)+			; MOVE.W #XXX,(a0)+
	move.w (a0)+,(a1)+		; Colour value
	move.w d4,(a1)+			; MOVE.W #XXX,(a0)+
	move.w (a0)+,(a1)+		; Colour value
	move.w d4,(a1)+			; MOVE.W #XXX,(a0)+
	move.w (a0)+,(a1)+		; Colour value
	move.w d4,(a1)+			; MOVE.W #XXX,(a0)+
	move.w (a0)+,(a1)+		; Colour value
	dbra d6,makdr_4
	move.w d5,(a1)+			; NOP
	move.w d5,(a1)+			; NOP
	move.l d3,(a1)+			; movea.l (a1)+,a2 ; jmp (a2)

	lea 2(a3),a0			; Advance to the next palette entry
	dbra d7,makdr_1
	rts

; Scroll the HBL colour distorter routine buffer
coldis	tst.w coldf			; Check if the colour distorter is enabled
	bmi.s serious

	move.l dpoin(pc),a2		; a2: current distorter path pointer
	add.w speed(pc),a2		; Advance the path pointer
	cmp.l end(pc),a2		; Check if we reached the end of the path
	blt.s carib
	move.l start(pc),a2		; Reset the path pointer
carib	move.l a2,dpoin			; Save the path pointer

	lea bufr+season,a1		; a1: colour distorter routine buffer
	moveq #coldisheight-1,d7	; Number of lines in the distorter
dance2	move.l (a2),(a1)+		; Copy the routine addresses to the buffer
	add.l incr,a2			; Path increment between lines
	dbra d7,dance2

	move.l #abyss,(a1)+		; Write the terminator HBL routine
serious	rts

; Initialise the HBL routine buffer for the colour distorter
init_coldis:
	move.l start,a2				; Colour distorter path start
	lea bufr+disrl,a0			; Colour distorter routine list
	lea bufr+season,a1			; Colour distorter routine buffer
	moveq #coldisheight-1,d7		; Number of lines

dance	clr.w d0				; Distorter offset
	move.b (a2)+,d0
	add.w d0,d0				; Multiply by 4
	add.w d0,d0
	move.l (a0,d0.w),(a1)+			; Copy the routine address to the buffer
	dbra d7,dance
	move.l #abyss,(a1)+			; Write the terminator routine
	rts

; Update the palette colours in the colour distorter routines
update_coldis:
	movem.l d0/d6-d7/a0-a5,-(sp)

	move.l pdiscol(pc),a0		; a0: colour palette
	lea bufr+disrl,a1		; a1: colour distortion routine list

	moveq #coldiswidth-1,d7		; Loop over all palette entries
.ucoldis_1
	move.l (a1)+,a2			; First routine address
	move.l (a1)+,a3			; Second routine address
	move.l (a1)+,a4			; Third routine address
	lea 8(a2),a2			; Skip 3 NOPs and the move.w
	lea 6(a3),a3			; Skip 2 NOPs and the move.w
	lea 4(a4),a4			; Skip 1 NOP and the move.w
	move.l a0,a5			; Copy the palette address

	moveq #coldiswidth/2-1,d6	; Loop over all palette entries
.ucoldis_2
	move.w (a5)+,d0			; Read RGB value
	move.w d0,(a2)			; Write the RGB value
	move.w d0,(a3)
	move.w d0,(a4)
	move.w (a5)+,d0			; Read RGB value
	move.w d0,4(a2)			; Write the RGB value
	move.w d0,4(a3)
	move.w d0,4(a4)
	lea 8(a2),a2			; Advance to the next instruction pair
	lea 8(a3),a3
	lea 8(a4),a4
	dbra d6,.ucoldis_2
	lea 2(a0),a0			; Advance to the next palette entry
	dbra d7,.ucoldis_1

	movem.l (sp)+,d0/d6-d7/a0-a5
	rts

; Select the pattern for the colour distorter
; d0: index of the pattern
select_coldis_pattern:
	move.w #-1,coldf		; Disable colour distorter
	ext.w d0
	add.w d0,d0
	add.w d0,d0
	lea coldist_settings(pc),a0	; List of colour distorter settings
	add.w d0,a0

	cmpa.l #e_coldist_settings,a0
	bge.s .invalid_selection

	lea dcolp(pc),a1		; List of colour distorter paths
	clr.w d1
	move.b (a0),d1			; Path number
	lsl.w #3,d1			; Path table entry
	adda.w d1,a1			; Path table entry address
	move.l (a1),start		; Set the start of the path
	move.l (a1),dpoin		; Set the path pointer to the start
	move.l 4(a1),end		; Set the end of the path
	clr.l d1
	move.b 1(a0),d1			; Speed
	move.w d1,speed
	move.b 2(a0),d1			; Increment (per-line step)
	move.l d1,incr

.invalid_selection
	clr.w coldf			; Enable colour distorter
	rts

; Cycle the palette for the colour distorter and regenerate the routines
cycle_coldis_palette:
	movem.l d0/a0-a1,-(sp)
	move.w #-1,coldf		; Disable colour distorter

	lea idiscol(pc),a0
	move.w (a0),d0		; Palette index
	add.w #1,d0

	lea coldis_palettes(pc),a1
	move.w d0,d1
	add.w d1,d1		; Convert to byte offset
	add.w d1,d1
	lea (a1,d1.w),a1

	cmp.l #e_coldis_palettes,a1
	blt.s .not_last

	clr.w d0
	lea coldis_palettes(pc),a1
 
.not_last
	move.w d0,(a0)		; Save the new palette index
	move.l (a1),pdiscol	; Set the new palette

	bsr update_coldis	; Update the palette colours in-place
	; bsr init_coldis	; Reinitialise the colour distorter (not safe, 16 bit bus means it can be interrupted mid-address)

	clr.w coldf		; Re-enable colour distorter
	movem.l (sp)+,d0/a0-a1
	rts


; Make paths for colour distorter
make_col_paths:
	lea dcolp(pc),a0
	lea bufr+cdpth,a1
	lea bufr+disrl,a2
	moveq #numcolpaths-1,d7
mpth_1	move.l (a0),a3
	move.l 4(a0),a4
	move.l a1,(a0)+
mpth_2	clr.w d0
	move.b (a3)+,d0
	lsl.w #2,d0
	move.l (a2,d0.w),(a1)+
	cmp.l a3,a4
	bgt.s mpth_2
	move.l a1,(a0)+
	move.l -8(a0),a3
	move.w #150-1,d6
mpth_3	move.l (a3)+,(a1)+
	dbra d6,mpth_3
	dbra d7,mpth_1
	rts

;***************

ortw	ds.w 16

screen1	dc.l screenbase-screensize
screen2	dc.l screenbase

pmes	dc.l mess+10
mess	dc.b "           ZAX OF THE CYBERPUNKS PRESENTSeeeee           CLASS IN A GLASSg            kBLOODY STUPID NAMEl               BORINGf ISNmT ITh"
	dc.b "           TRY THE FUNCTION KEYS TO LIVEN THINGS UP A BITeee"
	dc.b "            kNOf REALLYgl             "
	dc.b " I WANT TO NOW SLAG THIS SCREEN FOR NOT BEING GOODeeeee "
	dc.b "I HATE THAT DISTORTER PATH THAT LEAVES BITS BEHIND kAND IS BORINGlf "
	dc.b "I HATE THIS FONT WHERE THE LETTERS SOMETIMES TOUCH EACH OTHERf "
	dc.b "I HATE THE FACT THAT ULM AND THE REPLICANTS DID A HBL DISTORTER BEFORE ME kI HAD THE IDEA BEFORE I SAW nLIFEmS A BITCHnlf "
	dc.b "AND I HATE THE FACT THAT THIS SCROLLER DOES NOT GO INTO THE BORDERSeeeeeeeeee "
	dc.b "I WROTE A REALLY COOL PACKER THE OTHER WEEKf BUT THEN I GOT PACKjICE WHICH IS A MILLION TRILLION SQUILLION TIMES BETTEReeeeeeeeee "
	dc.b "TIMEf AS THEY SAYf TO WRAPeeeeeeeeee"
emes
pixl	dc.w 4
frm	ds.l 11
fnt	incbin "3216fnt3.dat"
	ds.l 16

pbalp1	dc.l pause
pbalp2	dc.l balpth2
ubalp1	dc.l pause
ubalp2	dc.l balpth2

grbr	dc.w $000,$333,$555,$777,$555,$8000
grbr2	dc.w $333,$555,$777,$555,$333,$8000

bars	dc.w $000,$000,$100,$200,$300,$400,$500,$600,$700,$600,$500,$400,$300,$200,$100,$000
	dc.w $000,$010,$020,$030,$040,$050,$060,$070,$060,$050,$040,$030,$020,$010,$000
	dc.w $000,$001,$002,$003,$004,$005,$006,$007,$006,$005,$004,$003,$002,$001,$000,$000,$000
	dc.w $8000
scrlpnt	dc.l colst
scrlco	ds.w 34
colst	ds.w 250
	dc.w $100,$200,$300,$400,$500,$600,$700
rainbow	dc.w $710,$720,$730,$740,$750,$760,$770
	dc.w $670,$570,$470,$370,$270,$170,$070
	dc.w $071,$072,$073,$074,$075,$076,$077
	dc.w $067,$057,$047,$037,$027,$017,$007
	dc.w $107,$207,$307,$407,$507,$607,$707
	dc.w $706,$705,$704,$703,$702,$702,$700
erain	dc.w $710,$720,$730,$740,$750,$760,$770
	dc.w $670,$570,$470,$370,$270,$170,$070
	dc.w $071,$072,$073,$074,$075,$076,$077
	dc.w $067,$057,$047,$037,$027,$017,$007
	dc.w $107,$207,$307,$407,$507,$607,$707

* PATH, SPEED, INCR, DUMMY
coldist_settings:
	dc.b 3,8,4,0			; Short, fast waves
	dc.b 4,12,4,0			; Long, fast waves
	dc.b 4,8,0,0			; Vertical bars on a sine path
	dc.b 0,4,0,0			; Vertical bars scrolling left then right
	dc.b 4,4,4,0			; Long, slow waves
	; dc.b 1,8,4,0			; Interlaced scrolling waves (alternate lines in phase)
	dc.b 1,16,4,0			; Interlaced waves (alternate lines in double interval phase)
	; dc.b 2,16,4,0			; Quadruple interlaced static waves (epilepsy inducer)
	dc.b 2,32,4,0			; Quadruple interlaced waves (slightly less epilepsy inducing)
	dc.b 0,0,4,0			; Static diagonal rainbow
	; dc.b 0,0,8,0			; Static diagonal rainbow with steeper angle
	dc.b 0,0,0,0			; Static vertical bars
e_coldist_settings:
	dc.w -1
	
coldis_palettes:
	dc.l discol1,discol4,discol9,discol6,discol7,discol3,discol8,discol5,discol2
e_coldis_palettes
idiscol dc.w 0
pdiscol	dc.l discol1			; Active colour distorter palette

dcolp	dc.l coldp,coldp2-1
	dc.l coldp2,coldp3-2
	dc.l coldp3,coldp4-4
	dc.l coldp4,coldp5-2
	dc.l coldp5,coldp6-2	

dpoin	ds.l 1
start	ds.l 1
end	ds.l 1
speed	dc.w 0
incr	dc.l 0
coldf	ds.w 1


pause	ds.w 100
balpth1	incbin "ballv4.dat"
ebalp1	incbin "ballv4.dat"
balpth2	incbin "ballh3.dat"
ebalp2	incbin "ballh3.dat"
ballog	incbin "redball.dat"

	EVEN
pall1	dc.w $000,$320,$431,$541,$652,$762,$300,$500,$700,$052,$062,$101,$202,$303,$404,$777
pall2	dc.w $000,$222,$333,$555,$777,$407,$000,$754,$700,$750,$670,$070,$056,$137,$607,$777

pdisp	dc.l dispth
dispth	incbin "dstrtr3.dax"
edisp	ds.l 100

readme	ds.w 1
mfpstr	ds.l 12
opal	ds.l 8
orez	ds.w 1
o44e	ds.l 1
blank	ds.l 4
colflg	ds.b 1
osp	ds.l 1
o120	ds.l 1
o118	ds.l 1
ovbl	ds.l 1
octr	ds.b 1
odat	ds.b 1
pntr	ds.l 1
omfp	ds.l 1	
oh	ds.l 1

key	dc.b $ff
joycm	ds.b 1
mousx	ds.b 1
mousy	ds.b 1
mousb	ds.b 1

; 	EVEN
; starpaws	incbin "starpaws.snd"
; epaws		ds.w 1

	EVEN
dislog	incbin "cyberpnk.dat"

	EVEN
toplog	incbin "toplogo.dat"

discol1 dc.w $070,$070,$070				; Green			(3)
	dc.w $170,$270,$370,$470,$570,$670,$770		; Green to yellow	(10)
	dc.w $760,$750,$740,$730,$720,$710,$700		; Yellow to red		(17)
	dc.w $701,$702,$703,$704,$705,$706,$707		; Red to magenta	(24)
	dc.w $607,$507,$407,$307,$207,$107,$007		; Magenta to blue	(31)
	dc.w $017,$027,$037,$047,$057,$067,$077		; Blue to cyan		(38)
	dc.w $176,$275,$374,$473,$572,$671,$770		; Cyan to yellow	(45)
	dc.w $761,$752,$743,$734,$725,$716,$707 	; Yellow to magenta	(52)
	dc.w $717,$727,$737,$747,$757,$767,$777		; Magenta to white	(59)
	dc.w $766,$755,$744,$733,$722,$711,$700		; White to red		(66)
	dc.w $710,$720,$730,$740,$750,$760,$770		; Red to yellow		(73)
	dc.w $670,$570,$470,$370,$270,$170,$070		; Yellow to green	(80)

discol2	dc.w $777,$766,$755,$744,$733	; White to red
	dc.w $722,$711,$700,$701,$702	; Red to magenta
	dc.w $703,$704,$705,$706,$707	; Red to magenta
	dc.w $716,$725,$734,$743,$752	; Magenta to yellow
	dc.w $761,$770,$670,$570,$470	; Yellow to green
	dc.w $370,$270,$170,$070,$071	; Green to cyan
	dc.w $072,$073,$074,$075,$076	; Green to cyan
	dc.w $077,$067,$057,$047,$037	; Cyan to blue			(40)

	dc.w $027,$017,$007,$107,$207	; Blue to magenta
	dc.w $307,$407,$507,$607,$707	; Blue to magenta
	dc.w $706,$705,$704,$702,$701	; Magenta to red
	dc.w $700,$610,$520,$430,$340	; Red to green
	dc.w $250,$160,$070,$170,$270	; Green to yellow
	dc.w $370,$470,$570,$670,$770	; Green to yellow
	dc.w $771,$772,$773,$774,$775	; Yellow to white
	dc.w $776,$777,$777,$777,$777	; White				(80)

discol3	dc.w $000,$000,$000    ; 3
	dc.w $100,$200,$300,$400,$500,$600,$700    ; 10
	dc.w $600,$500,$400,$300,$200,$100,$000    ; 17
	dc.w $101,$202,$303,$404,$505,$606,$707    ; 24
	dc.w $606,$505,$404,$303,$202,$101,$000    ; 31
	dc.w $001,$002,$003,$004,$005,$006,$007    ; 38
	dc.w $006,$005,$004,$003,$002,$001,$000    ; 45
	dc.w $011,$022,$033,$044,$055,$066,$077    ; 52
	dc.w $066,$055,$044,$033,$022,$011,$000    ; 59
	dc.w $010,$020,$030,$040,$050,$060,$070    ; 66
	dc.w $060,$050,$040,$030,$020,$010,$000    ; 73
	dc.w $110,$220,$330,$440,$550,$660,$770    ; 80

discol4	dc.w $777,$777,$777    ; 3
	dc.w $766,$755,$744,$733,$722,$711,$700    ; 10
	dc.w $711,$722,$733,$744,$755,$766,$777    ; 17
	dc.w $676,$575,$474,$373,$272,$171,$070    ; 24
	dc.w $171,$272,$373,$474,$575,$676,$777    ; 31
	dc.w $667,$557,$447,$337,$227,$117,$007    ; 38
	dc.w $117,$227,$337,$447,$557,$667,$777    ; 45
	dc.w $767,$757,$747,$737,$727,$717,$707    ; 52
	dc.w $717,$727,$737,$747,$757,$767,$777    ; 59
	dc.w $677,$577,$477,$377,$277,$177,$077    ; 66
	dc.w $177,$277,$377,$477,$577,$677,$777    ; 73
	dc.w $776,$775,$774,$773,$772,$771,$770    ; 80

; $737:3,$773,$730,$305,$057,$254,$351,$472,$623,$525,$325,$013,$255,$043:4,$370,$531,$504,$547,$275,$473,$020,$003,$000,$000
discol5	dc.w $737,$737,$737    ; 3
	dc.w $746,$755,$764,$773    ; 7
	dc.w $762,$752,$741,$730    ; 11
	dc.w $621,$522,$513,$414,$305    ; 16
	dc.w $215,$226,$136,$147,$057    ; 21
	dc.w $156,$155,$254    ; 24
	dc.w $253,$352,$351    ; 27
	dc.w $462,$472    ; 29
	dc.w $462,$552,$543,$633,$623    ; 34
	dc.w $624,$525    ; 36
	dc.w $425,$325    ; 38
	dc.w $224,$114,$013    ; 41
	dc.w $124,$134,$245,$255    ; 45
	dc.w $255,$154,$144,$043    ; 49
	dc.w $152,$261,$370    ; 52
	dc.w $460,$451,$541,$531    ; 56
	dc.w $522,$513,$504    ; 59
	dc.w $515,$526,$536,$547    ; 63
	dc.w $456,$366,$275    ; 66
	dc.w $374,$473    ; 68
	dc.w $362,$252,$241,$131,$020    ; 73
	dc.w $011,$012,$003    ; 76
	dc.w $002,$001,$000    ; 79
	dc.w $000    ; 80

discol6	rept 20
	dc.w $707,$707,$770,$770
	endr

discol7	rept 10
	dc.w $111,$111,$111,$111,$777,$777,$777,$777
	endr

discol8 rept 7
	dc.w $700,$700,$707,$707,$007,$007,$070,$070,$077,$077,$770,$770
	endr

discol9:
	dc.w $770,$770,$770    ; 3
	dc.w $760,$750,$740,$730,$720,$710,$700    ; 10
	dc.w $710,$720,$730,$740,$750,$760,$770    ; 17
	dc.w $760,$750,$740,$730,$720,$710,$700    ; 24
	dc.w $710,$720,$730,$740,$750,$760,$770    ; 31
	dc.w $760,$750,$740,$730,$720,$710,$700    ; 38
	dc.w $710,$720,$730,$740,$750,$760,$770    ; 45
	dc.w $760,$750,$740,$730,$720,$710,$700    ; 52
	dc.w $710,$720,$730,$740,$750,$760,$770    ; 59
	dc.w $760,$750,$740,$730,$720,$710,$700    ; 66
	dc.w $710,$720,$730,$740,$750,$760,$770    ; 73
	dc.w $760,$750,$740,$730,$720,$710,$700    ; 80

	EVEN
coldp	incbin "coldis4.pth"
	EVEN
coldp2	incbin "coldis7.pth"
	EVEN
coldp3	incbin "coldis3.pth"
	EVEN
coldp4	incbin "coldis.pth"
	EVEN
coldp5	incbin "coldis5.pth"
coldp6

	EVEN

bufr	ds.l 1

	rsreset
logo	rs.b 80000
font	rs.b 50000
rout	rs.w 6000/2
rlist	rs.l 8*2*16
ballz	rs.w 64*2
masp	rs.w 64*2
code	rs.w 15000/2
udraw	rs.w 5000/2
season	rs.l 100
disrl	rs.l coldiswidth*3
disrts	rs.w 22000/2
cdpth	rs.w 10000/2
