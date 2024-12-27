; Utility code to process the font for the UMS
; Only included as a curiosity, the data file is the processed font
numspr	equ 13
lines	equ 16
width	equ 3	     (divided by 16)
bplanes	equ 1

	clr.l -(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp
	move.l d0,osp
	
	move.b $ff8260,ores
	clr.b $ff8260
	
	move.w pic+2,d0
	eori.w #$777,d0
	move.w d0,pic+32
	move.l #pic+2,1114
	lea pic+34,a0
	move.l $44e,a1
	lea (a1),a2
	move.l #7999,d0
lop	move.l (a0)+,(a1)+
	dbra d0,lop
	
	moveq #2-1,d5
	moveq #numspr/2-1,d7   * NO OF SPRITES
	move.l $44e,a0	   * SOURCE ADDR.
*	lea 16*160(a0),a0
	lea bufr,a1	   * DEST ADDR.
sprt	moveq #lines-1,d6   * NO OF LINES
	clr.l d0

line	move.b (a0,d0),(a1)+
	move.b 1(a0,d0),(a1)+
	move.b 8(a0,d0),(a1)+
	move.w #$f0f0,(a0,d0)
	add.w #160,d0
	dbra d6,line

	moveq #lines-1,d6   * NO OF LINES
	clr.l d0
line2	move.b 9(a0,d0),(a1)+
	move.b 16(a0,d0),(a1)+
	move.b 17(a0,d0),(a1)+
	move.w #$f0f0,8(a0,d0)
	move.w #$f0f0,16(a0,d0)
	add.w #160,d0
	dbra d6,line2
	
	add.l #width*8,a0	  * ADJUST ACCORDING TO WIDTH
	dbra d7,sprt

	moveq #lines-1,d6   * NO OF LINES
	clr.l d0
line3	move.b (a0,d0),(a1)+
	move.b 1(a0,d0),(a1)+
	move.b 8(a0,d0),(a1)+
	move.w #$f0f0,(a0,d0)
	move.w #$f0f0,8(a0,d0)
	add.w #160,d0
	dbra d6,line3

	lea 160*lines(a2),a2
	lea (a2),a0
	moveq #numspr/2-1,d7
	dbra d5,sprt

	lea bufr,a0
	sub.l a0,a1
	move.l a1,d7
	
	bsr fsel
	lea bufr,a1
	bsr save
	
	move.w #7,-(sp)
	trap #1
	addq.l #2,sp
	
	move.b ores,$ff8260
	
	move.l osp,-(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp
	
	clr.l -(sp)
	trap #1

*pass	none
*retn	a0=DTA Buffer addr.

fsel	movem.l d0-d1,-(sp)
	
	pea begstr
	move.w #10,-(sp)
	trap #1
	addq.l #6,sp
	
	clr.w -(sp)
	pea begnam
	move.w #$4e,-(sp)
	trap #1
	addq.l #8,sp
	tst.w d0
	bne noxst
	
	move.w #$2f,-(sp)
	trap #1
	addq.l #2,sp
	move.l d0,a0
	
noxst	movem.l (sp)+,d0-d1
	rts
	
*pass	a0=pointer to DTA
*	a1=Buffer
*	d7=Length
*retn	a0=-33 or DTA addr.

save	movem.l d0-d1,-(sp)
	lea begnam,a2

	move.l a2,-(sp)
	move.w #$41,-(sp)
	trap #1
	addq.l #6,sp

	clr.w -(sp)	
	move.l a2,-(sp)
	move.w #$3c,-(sp)
	trap #1
	addq.l #8,sp
	move.w d0,d1

	move.l a1,-(sp)
	move.l d7,-(sp)
	move.w d1,-(sp)
	move.w #$40,-(sp)
	trap #1
	add.l #12,sp

	move.w d1,-(sp)
	move.w #$3e,-(sp)
	trap #1
	addq.l #4,sp
	
	movem.l (sp)+,d0-d1
	rts

begstr	dc.b 128
retvar	ds.b 1
begnam	ds.b 128

pic	incbin "A:\umfont.pi1"
ores	ds.b 1
osp	ds.l 1
bufr