; The Summer Demo
; Written in 1990/1991/1992 by Zax and Vilm of The Cyberpunks
; Updated in 2024 to work with the new bootstrap or as a standalone TOS program.
;
; I think the comment in the scroller about my ST starting to smell was written just before it died from overheating,
; leading to an 8 month pause in the development of the demo (or anything else).

	; check for magic value indicating we were called from the bootstrap
	cmp.l #"PDOM",d0
	bne.s standalone

	move.l a0,retadr
	bra.s standalone

retadr	ds.l 1

standalone
 	clr.l -(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp
	move.l d0,osp

	move.l $44e,oscr
	move.b $ffff8260.w,d0
	andi.w #%11,d0
	move.w d0,orez

	clr.b $ffff8260.w		; low resolution

	lea bufr,a0
	lea $7ffff,a1
	clr.l d0
clmem	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	cmp.l a1,a0
	blt.s clmem

	movem.l $ffff8240.w,d0-d7
	movem.l d0-d7,opal

	movem.l bufr,d0-d7
	movem.l d0-d7,$ffff8240.w

	; moveq #1,d0
	; bsr music

	bsr shift2
	
	lea bufr+chars,a0
	lea bufr+chars+25000,a1
	clr.l d0
clchar	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	cmp.l a1,a0
	blt.s clchar
	
	lea bufr+font,a1
	lea bufr+chars,a2
	bsr prescr
	move.l a1,esh1
	bsr shfnt
	move.l esh1,a1
	lea bufr+chars2,a2
	bsr prescr
	bsr inibuf
	bsr pretw

	move.l curadr(pc),a0
	move.l altadr(pc),a1
	move.l #8000-1,d0
clrsc2	clr.l (a0)+
	clr.l (a1)+
	dbra d0,clrsc2

	lea bufr+stk,a7

	movem.l pallete,d0-d7
	movem.l d0-d7,$ffff8240.w

	bsr hblon
	
x	move.b key,d0
	cmp.b #$39,d0
	beq xit
	
	cmp.b #$3b,d0
	blt.s nmc
	cmp.b #$44,d0
	bgt.s nmc
	
	sub.b #$3a,d0
	cmp.b select,d0
	beq.s x
	andi.l #$ff,d0
	move.b d0,select

	; move.l #norple,lemon+2
	; bsr music
	; move.l #music+4,lemon+2
	bra.s x

nmc	tst.b left
	beq.s right

	tst.b rite
	beq.s acshl

	tst.b mrec
	bpl.s right
	
acshl	cmp.w #256*16,speed
	bge.s xp
	add.w #256,speed
	bra.s xp

right	tst.b rite
	beq.s x
	cmp.w #-256*16,speed
	ble.s xp
	sub.w #256,speed

xp	move.l $466.w,d0
	addq.l #4,d0
del	cmp.l $466.w,d0
	bgt.s del
	bra x

xit	bsr hbloff

	movem.l opal,d0-d7
	movem.l d0-d7,$ffff8240.w

	move.w orez,-(sp)
	move.l oscr,-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	move.l osp,-(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp
	
	; check for return address
	move.l retadr(pc),d0
	tst.l d0
	beq.s byebye

	move.l d0,a0
	jmp (a0)

byebye	clr.w -(sp)
	trap #1

vbl	movem.l d0-d7/a0-a6,-(sp)

	clr.b $fffffa1b.w
	move.l #hbl3,$120.w
	move.b #8,$fffffa21.w
	move.b #8,$fffffa1b.w

	clr.w $ffff8240.w
	move.l shds2,$ffff8252.w
	move.l shds2,$ffff8256.w
	move.w shds2+2,$ffff8250.w
	move.w shds2+2,$ffff825e.w
	move.l shds2+2,$ffff825a.w
	move.l shds2+6,$ffff824a.w
	move.w shds2+10,$ffff824e.w
	
	move.l #shds,pointer

	move.l curadr,d0
	move.l altadr,curadr
	move.l d0,$44e
	move.l d0,altadr
	lsr.w #8,d0
	move.l d0,$ffff8200.w
	
	bsr putbg

	move.l $44e.w,a0
	movem.l blnk,d0-d7
	movem.l d0-d7,160*(8*12)(a0)
	movem.l d0-d7,160*(8*12)+32(a0)
	movem.l d0-d7,160*(8*12)+64(a0)
	movem.l d0-d7,160*(8*12)+96(a0)
	movem.l d0-d7,160*(8*12)+128(a0)

*	move.w #$330,$ffff8240.w
	bsr bscrl
	bsr doolit
	bsr twist
*	clr.w $ffff8240.w

; lemon	jsr music+4

*	move.w #$777,$ffff8240.w

	addq.l #1,$466.w

	movem.l (sp)+,d0-d7/a0-a6
	rte

putbg	move.l $44e.w,a1

	lea linoff(pc),a0
	moveq #11-1,d7
scrit	move.w 2(a0),(a0)+
	dbra d7,scrit
	
	move.w speed,d0
	add.w d0,linoff+22
	cmp.w #256*64,linoff+22
	blt.s poik
	sub.w #256*64,linoff+22
poik	tst.w linoff+22
	bpl.s poik2
	add.w #256*64,linoff+22
	
poik2	clr.w oset
	clr.w cntln
	lea (a1),a2
	lea bufr+backr,a0
	add.l oser,a0
	move.w #32000-(8*160)+32,d2

	moveq #8-1,d0
lines	lea linoff(pc),a3
	moveq #12-1,d1
linet	lea bufr+backr,a0
	add.w cntln,a0
	add.w (a3)+,a0
	movem.l (a0)+,d3-d7/a4-a6
	movem.l d3-d7/a4-a6,(a1)
	movem.l d3-d7/a4-a6,32(a1)
	movem.l d3-d7/a4-a6,64(a1)
	movem.l d3-d7/a4-a6,96(a1)
	movem.l d3-d7/a4-a6,128(a1)

	movem.l d3-d7/a4-a6,-32(a1,d2.w)
	movem.l d3-d7/a4-a6,(a1,d2.w)
	movem.l d3-d7/a4-a6,32(a1,d2.w)
	movem.l d3-d7/a4-a6,64(a1,d2.w)
	movem.l d3-d7/a4-a6,96(a1,d2.w)
	
	lea 8*160(a1),a1
	sub.w #16*160,d2
	dbra d1,linet
	
	move.w #32000-(8*160)+32,d2
	add.w #32,cntln
	add.w #320,oset
	sub.w oset(pc),d2
	lea 160(a2),a2
	lea (a2),a1
	dbra d0,lines
	add.l #256,oser
	cmp.l #64*256,oser
	blt.s norple
	clr.l oser
norple	rts

shift2	lea bufr+backr,a1
	lea bgr+256(pc),a0
	moveq #(256/4)-1,d6
bgtl2	move.l (a0),256(a1)
	move.l (a0)+,(a1)+
	dbra d6,bgtl2

	lea bufr+backr+256(pc),a0
	moveq #32-1,d5
bgtl	moveq #8-1,d7
scrt	move.w (a0),d0
	roxl.w d0
	move.w 24(a0),d0
	roxl.w #1,d0
	move.w d0,256+24(a0)
	move.w 16(a0),d0
	roxl.w #1,d0
	move.w d0,256+16(a0)
	move.w 8(a0),d0
	roxl.w #1,d0
	move.w d0,256+8(a0)
	move.w (a0),d0
	roxl.w #1,d0
	move.w d0,256(a0)

	move.w 2(a0),d0
	roxl.w d0
	move.w 26(a0),d0
	roxl.w #1,d0
	move.w d0,256+26(a0)
	move.w 18(a0),d0
	roxl.w #1,d0
	move.w d0,256+18(a0)
	move.w 10(a0),d0
	roxl.w #1,d0
	move.w d0,256+10(a0)
	move.w 2(a0),d0
	roxl.w #1,d0
	move.w d0,256+2(a0)

	move.w 4(a0),d0
	roxl.w d0
	move.w 28(a0),d0
	roxl.w #1,d0
	move.w d0,256+28(a0)
	move.w 20(a0),d0
	roxl.w #1,d0
	move.w d0,256+20(a0)
	move.w 12(a0),d0
	roxl.w #1,d0
	move.w d0,256+12(a0)
	move.w 4(a0),d0
	roxl.w #1,d0
	move.w d0,256+4(a0)

	move.w 6(a0),d0
	roxl.w d0
	move.w 30(a0),d0
	roxl.w #1,d0
	move.w d0,256+30(a0)
	move.w 22(a0),d0
	roxl.w #1,d0
	move.w d0,256+22(a0)
	move.w 14(a0),d0
	roxl.w #1,d0
	move.w d0,256+14(a0)
	move.w 6(a0),d0
	roxl.w #1,d0
	move.w d0,256+6(a0)

	lea 32(a0),a0
	dbra d7,scrt

	moveq #8*8-1,d6
copyx	move.l (a0)+,252(a0)
	dbra d6,copyx
	dbra d5,bgtl
	
	bsr shift

	lea bufr+chars,a0
	lea bufr+backr,a1
	move.w #(64*256)/4-1,d7
xray	movem.w (a0)+,d0-d3
	move.w d0,d4
	or.w d1,d4
	or.w d2,d4
	or.w d3,d4
	not.w d4
	and.w d4,(a1)
	and.w d4,2(a1)
	and.w d4,4(a1)
	and.w d4,6(a1)
	add.w d0,(a1)
	add.w d1,2(a1)
	add.w d2,4(a1)
	add.w d3,6(a1)
	addq.l #8,a1
	dbra d7,xray
	rts


shift	lea bgr,a0
	move.l $44e,a1
	move.l #64-1,d0
s1	move.l (a0)+,(a1)+
	dbra d0,s1
	lea bufr+chars,a1
	move.l $44e,a0
	move.l #64-1,d0
s2	move.l (a0)+,(a1)+
	dbra d0,s2
	lea bufr+chars,a0
	sub.l #256,a0
	sub.l #256,a1
	move.l #64-1,d0
s3	move.l #8-1,d1
	add.l #512,a0
	add.l #512,a1
	lea sav,a2
	clr.l d3
s4	move.w -(a0),d2
	lsl.w #1,d2
	scs d3
	andi.w #1,d3
	move.w d3,8(a2)
	move.w d2,-(a1)
	move.w -(a0),d2
	lsl.w #1,d2
	scs d3
	andi.w #1,d3
	move.w d3,6(a2)
	move.w d2,-(a1)
	move.w -(a0),d2
	lsl.w #1,d2
	scs d3
	andi.w #1,d3
	move.w d3,4(a2)
	move.w d2,-(a1)
	move.w -(a0),d2
	lsl.w #1,d2
	scs d3
	andi.w #1,d3
	move.w d3,2(a2)
	move.w d2,-(a1)
	moveq #3-1,d4
	
s5	move.w -(a0),d2
	lsl.w #1,d2
	scs d3
	add.w 8(a2),d2
	andi.w #1,d3
	move.w d3,8(a2)
	move.w d2,-(a1)
	move.w -(a0),d2
	lsl.w #1,d2
	scs d3
	add.w 6(a2),d2 
	andi.w #1,d3
	move.w d3,6(a2)
	move.w d2,-(a1)
	move.w -(a0),d2
	lsl.w #1,d2
	scs d3
	add.w 4(a2),d2
	andi.w #1,d3
	move.w d3,4(a2)
	move.w d2,-(a1)
	move.w -(a0),d2
	lsl.w #1,d2
	scs d3
	add.w 2(a2),d2
	andi.w #1,d3
	move.w d3,2(a2)
	move.w d2,-(a1)
	dbra d4,s5
	
	move.w 8(a2),d2
	add.w d2,30(a1)
	move.w 6(a2),d2
	add.w d2,28(a1)
	move.w 4(a2),d2
	add.w d2,26(a1)
	move.w 2(a2),d2
	add.w d2,24(a1)
	dbra d1,s4
	dbra d0,s3
	rts

bscrl	move.l scrptr,a0
	move.l $44e,a1
	addq.l #6,a1
	lea 160*30(a1),a1
	move.w #$ffff,d0
	moveq #20-1,d7
bscrl_1	move.l (a0),a3
	jsr (a3)
	addq.l #8,a0
	addq.l #8,a1
	dbra d7,bscrl_1

	lea bufr+chars2,a1
	not.b shtog
	bne.s sstrp
	
	lea bufr+chars,a1
	subq.w #1,strp
	bgt.s slet
	addq.l #1,pmes
	cmp.l #emes,pmes
	blt.s mover
	move.l #mesg,pmes
mover	move.w #8,strp
	move.l pmes,a0
	clr.l d0
	move.b (a0),d0
	sub.b #"A"-1,d0
	bpl.s alpha
	clr.l valu
	bra.s sstrp
alpha	lsl.l #5,d0
	move.l d0,valu
	bra.s sstrp
slet	addq.l #4,valu
sstrp	move.l valu,d0
	move.l (a1,d0),d0
	move.l scrptr,a0
	move.l d0,(a0)+
	move.l d0,40*4-4(a0)
	cmp.l #bufr+scrbf+40*4,a0
	blt.s seamonk
	lea bufr+scrbf,a0
seamonk	move.l a0,scrptr

	rts

prescr	lea bfont,a3
	moveq #47-1,d7
letrs	moveq #15,d6
	moveq #8-1,d5
stripz	lea (a3),a0
	move.l a1,(a2)+
	moveq #16-1,d4
	clr.w d2
linez	move.w (a0)+,d0
	clr.l d1
	btst d6,d0
	beq.s blank
	move.l #$13400000,d1
blank	subq.w #1,d6
	btst d6,d0
	beq.s blnk2
	tst.l d1
	beq.s npix1
	move.l #$33400000,d1
	bra.s blnk2
npix1	move.l #$13400001,d1
blnk2	tst.l d1
	beq.s blnk3
	add.w d2,d1
	moveq #8-1,d3
strtc	move.l d1,(a1)+
	add.w #160,d1
	dbra d3,strtc
blnk3	add.w #160*8,d2
	addq.w #1,d6
	dbra d4,linez
	subq.w #2,d6
	move.w #$4e75,(a1)+
	dbra d5,stripz
	adda.w #32,a3
	dbra d7,letrs
	rts

shfnt	lea bfont(pc),a0
shl1	move.w (a0),d0
	lsl.w #1,d0
	move.w d0,(a0)+
	cmp.l #ebfnt,a0
	blt.s shl1
	rts


inibuf	lea bufr+chars,a0
	lea bufr+scrbf,a1
	move.w #80-1,d7
inibf_1	move.l (a0),(a1)+
	dbra d7,inibf_1
	rts


doolit	lea llets(pc),a0
	move.l $44e.w,a1
	lea 160*160+8+6(a1),a1
	move.l plpth(pc),a2
	lea offsets,a3
	lea offs2,a4
	moveq #22-1,d7
doolop	move.w (a4)+,d0
	lea (a0,d0.w),a5
	move.w (a2)+,d0
	add.w (a3)+,d0
	lea (a1,d0.w),a6
	clr.b -160(a6)
	move.b (a5)+,(a6)
	move.b (a5)+,160(a6)
	move.b (a5)+,320(a6)
	move.b (a5)+,480(a6)
	move.b (a5)+,640(a6)
	move.b (a5)+,800(a6)
	move.b (a5)+,960(a6)
	move.b (a5)+,1120(a6)
	dbra d7,doolop

	addq.l #2,plpth
	cmp.l #elpth,plpth
	blt.s endoo
	move.l #lpth2,plpth
endoo	rts

hbl	move.l a2,-(sp)
	move.l pointer,a2
	move.w (a2)+,$ffff8252.w
	move.w (a2),$ffff8250.w
	move.w (a2),$ffff825e.w
	move.l (a2)+,$ffff825a.w
	move.l (a2)+,$ffff824a.w
	move.w (a2)+,$ffff824e.w
	bpl.s skol2
	move.l #hbl3,$120.w
skol2	move.l a2,pointer
	move.l (sp)+,a2
	rte

hbl3	move.l a2,-(sp)
	move.l pointer,a2
	move.l (a2),$ffff8252.w
	move.l (a2),$ffff8256.w
	move.w (a2)+,$ffff8250.w
	move.w (a2),$ffff825e.w
	move.l (a2)+,$ffff825a.w
	move.l (a2)+,$ffff824a.w
	move.w (a2)+,$ffff824e.w
	bpl.s skol
	move.l #hbl4,$120.w
skol	move.l a2,pointer
	move.l (sp)+,a2
	rte

hbl4	move.l a2,-(sp)
	move.l pointer,a2
	move.l pallete+$12,$ffff8252.w
	move.l pallete+$16,$ffff8256.w
	move.w (a2)+,$ffff8252.w
	move.w (a2),$ffff8250.w
	move.w (a2),$ffff825e.w
	move.l (a2)+,$ffff825a.w
	move.l (a2)+,$ffff824a.w
	move.w (a2)+,$ffff824e.w
	move.l #hbl,$120.w
	move.l a2,pointer
	move.l (sp)+,a2
	rte


hblon	lea mfpstr,a0
	move.b $fffffa07.w,(a0)+
	move.b $fffffa09.w,(a0)+
	move.b $fffffa13.w,(a0)+
	move.b $fffffa15.w,(a0)+
	move.l $70.w,(a0)+
	move.l $118.w,(a0)+
	move.l $120.w,(a0)+
	clr.b $fffffa07.w
	clr.b $fffffa09.w
	bclr #3,$fffffa17.w
	move.l #nkey,$118.w
	move.l #vbl,$70.w
	move.l #nul2,$120.w
	bset #6,$fffffa09.w
	bset #6,$fffffa15.w
	bset #0,$fffffa07.w
	bset #0,$fffffa13.w
	move.b #$12,$fffffc02.w
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
	
	cmp.b #$4d,d1
	bne.s n_rite
	move.b #1,rite
	move.b #1,mrec
n_rite	cmp.b #$4d+$80,d1
	bne.s nrite_2
	clr.b rite
nrite_2	cmp.b #$4b,d1
	bne.s nleft
	move.b #-1,left
	move.b #-1,mrec
nleft	cmp.b #$4b+$80,d1
	bne.s nleft_2
	clr.b left
	
nleft_2	move.b d1,key

	move.w (sp)+,d1
	move.w (sp)+,d0
	rte

joyst	move.l #gjoy,$118.w
	move.w (sp)+,d1
	move.w (sp)+,d0
	rte

gjoy	move.b $fffffc02.w,joycm
	move.l #nkey,$118.w
nul2	rte

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


key	dc.b $ff
joycm	ds.b 1
mousx	ds.b 1
mousy	ds.b 1
mousb	ds.b 1
mfpstr	ds.l 10
left	ds.b 1
rite	ds.b 1
mrec	ds.b 1


hbloff	clr.b $fffffa1b.w
	lea mfpstr,a0
	move.b (a0)+,$fffffa07.w
	move.b (a0)+,$fffffa09.w
	move.b (a0)+,$fffffa13.w
	move.b (a0)+,$fffffa15.w
	bset #3,$fffffa17.w
	move.l (a0)+,$70.w
	move.l (a0)+,$118.w
	move.l (a0)+,$120.w
	move.b #8,$fffffc02.w
	move.b #7,$ffff8800.w
	move.b #%11111111,$ffff8802.w
	rts


pretw	lea twdat,a0
	lea bufr+twisrt,a1
	lea bufr+twadr,a2
	moveq #28-1,d7
numrt	move.l a1,(a2)+
	clr.w d0
	moveq #28-1,d6
twlin	clr.w d1
	move.b (a0)+,d1
	bne.s strange
	move.w #$1340,(a1)+
	move.w d0,(a1)+
	bra.s ndata
strange	subq.w #1,d1
	move.w #$1368,(a1)+
	move.w d1,(a1)+
	move.w d0,(a1)+
ndata	add.w #160,d0
	dbra d6,twlin
	move.w #$4e75,(a1)+
	dbra d7,numrt

	lea bufr+twpath,a0
	move.l bufr+twadr,d0
	move.l d0,twvl
	moveq #32-1,d7
filbuf	move.l d0,(a0)+
	dbra d7,filbuf

	rts

twist	lea grphic(pc),a0
	move.l $44e.w,a3
	lea 2*160+16+6(a3),a3
	lea twoff,a4
	move.l twptr,a2
	clr.l d0
	moveq #32-1,d7
tw_1	move.w (a4)+,d1
	lea (a3,d1.w),a1
	move.l (a2)+,a5
	jsr (a5)
	lea 28(a0),a0
	dbra d7,tw_1
	
	move.l twptr,a0
	subq.b #1,ctwvl
	bne.s stwvl
	move.l twptr2,a1
	clr.w d0
	move.b (a1)+,ctwvl
	move.b (a1)+,d0
	move.l a1,twptr2
	lsl.w #2,d0
	lea bufr+twadr,a1
	move.l (a1,d0.w),twvl
stwvl	move.l twvl,d0
	move.l d0,(a0)+
	move.l a0,twptr
	move.l d0,31*4(a0)

	cmp.l #etwst,twptr2
	blt.s nrtw_1
	move.l #twpth2,twptr2
nrtw_1	cmp.l #bufr+twpath+31*4,twptr
	ble.s nrtw_2
	move.l #bufr+twpath,twptr

nrtw_2	rts

twvl	ds.l 1
ctwvl	dc.b 250

twptr2	dc.l twpth2
twpth2	dc.b 1,14,1,13,1,12,1,11,1,10,1,9,2,8,2,7,3,6,3,5,4,4,5,3,6,2,50,1
	dc.b 5,2,4,3,3,4,3,5,2,6,2,7,2,8,1,9,1,10,1,11,1,12,1,13,1,14,1,0
	dc.b 1,15,1,16,1,17,1,18,1,19,1,20,2,21,2,22,2,23,3,24,3,25,4,26,5,27
	dc.b 5,27,4,26,3,25,3,24,2,23,2,22,2,21,1,20,1,19,1,18,1,17,1,16,1,15,5,0
	dc.b 1,14,1,13,1,12,1,11,1,10,1,9,2,8,2,7,3,6,3,5,4,4,5,3,6,2,5,1
	dc.b 5,2,4,3,3,4,3,5,2,6,2,7,2,8,1,9,1,10,1,11,1,12,1,13,1,14,1,0
	dc.b 1,15,1,16,1,17,1,18,1,19,1,20,2,21,2,22,2,23,3,24,3,25,4,26,5,27
	dc.b 5,27,4,26,3,25,3,24,2,23,2,22,2,21,1,20,1,19,1,18,1,17,1,16,1,15,5,0
	dc.b 1,14,1,13,1,12,1,11,1,10,1,9,2,8,2,7,3,6,3,5,4,4,5,3,6,2,50,1
	dc.b 5,2,4,3,3,4,3,5,2,6,2,7,2,8,1,9,1,10,1,11,1,12,1,13,1,14,1,0
	dc.b 1,15,1,16,1,17,1,18,1,19,1,20,2,21,2,22,2,21,1,20,1,19,1,18,1,17,1,16,1,15,5,0
	dc.b 1,14,1,13,1,12,1,11,1,10,1,9,2,8,2,7,2,6,3,5,2,6,2,7,2,8,1,9,1,10,1,11,1,12,1,13,1,14,1,0
etwst

twoff	dc.w 0,1,8,9,16,17,24,25,32,33,40,41,48,49,56,57
	dc.w 64,65,72,73,80,81,88,89,96,97,104,105,112,113,120,121

twdat	ds.b 28
	incbin "twist.dat"
grphic	incbin "twistme.dat"
twptr	dc.l bufr+twpath	
	

shds2	dc.w $705,$705,$705,$000,$000,$100
shds	dc.w $604,$604,$604,$000,$000,$200
	dc.w $503,$503,$503,$000,$100,$300
	dc.w $402,$402,$402,$000,$200,$8400

	dc.w $000,$040,$050,$100,$300,$500
	dc.w $000,$050,$060,$200,$400,$600
	dc.w $010,$060,$070,$300,$500,$700
	dc.w $020,$070,$171,$400,$600,$710
	dc.w $030,$071,$272,$500,$700,$620
	dc.w $040,$072,$373,$600,$710,$530
	dc.w $041,$073,$374,$700,$620,$440
	dc.w $042,$064,$265,$710,$530,$350
	dc.w $043,$055,$156,$620,$440,$260

	dc.w $034,$055,$065,$530,$350,$170
	dc.w $024,$046,$056,$440,$260,$070
	dc.w $014,$037,$047,$350,$170,$060
	dc.w $004,$027,$037,$260,$070,$050
	dc.w $003,$017,$027,$170,$060,$040
	dc.w $002,$007,$017,$070,$050,$030
	dc.w $001,$006,$007,$060,$040,$8020

	dc.w $777,$777,$777,$050,$030,$010
	dc.w $666,$666,$666,$040,$020,$000
	dc.w $555,$555,$555,$030,$010,$000
	dc.w $444,$444,$444,$020,$000,$000
	dc.w $000,$000,$000,$010,$000,$000

plpth	dc.l lpth1

offsets	dc.w 16,17,24,32,33,40,41,48,56,57,64,65,73,80,81,89,96,104,105,113,120,121  *** SCREEN
offs2	dc.w 0,8,16,0024,8,8,40,48,0056,64,16,72,0024,80,88,0096,104,0000,40,96,0104,112	    *** DATA

llets	incbin "8x8lets.dat"
lpth1	incbin "litlet2.pth"
lpth2	incbin "litlet.pth"
elpth	incbin "litlet.pth"	


valu	ds.l 1
shtog	ds.b 1
strp	dc.w 8

pmes	dc.l mesg
pbit	ds.w 1

scrptr	dc.l bufr+scrbf
esh1	ds.l 1
bfont	ds.w 16
	incbin "bigfnt2.dat"
ebfnt

mesg	dc.b "           WHAT A STUPID IDEA PUTTING A BIG SCROLLER BETWEEN THE LAYERS OF A FULL SCREEN PARALLAX DISTORTEReeeeee     "
	dc.b "THIS SCREEN WAS CODED IN ONE WEEKEND IN SUMMER \dd[f ONE AFTERNOON IN SUMMER \dd\f AND ONE WEEKEND IN SUMMER \dd]g     ITmS CALLED nTHE SUMMER DEMOneeeeee         MOST CODE BY ZAXe          "
	dc.b "BY THE WAY j WE HAVENmT CHANGED OUR NAMEf  nTHE SAD PUNKSn IS A REFERENCE TO A PIXIES SONGf BUT YOU CAN TAKE IT THE OTHER WAY IF YOU WISHeeeee       "
	dc.b "THIS SCREEN CONTAINS SOME OF OUR OLDEST CODE kINCLUDING OUR VERY FIRST XjRAY ROUTINEl AND SOME OF OUR NEWEST CODE kLIKE THIS VERY FAST BIG SCROLL CODE j IT NEVER EXCEEDS _[ SCANLINESg   "
	dc.b "IF ANYBODY CAN DO A BIG SCROLL FASTER I WILL BE VERY IMPRESSEDl            "
	dc.b "THE SCREEN ISNmT VERY ORIGINALf BUT IT IS QUITE ABSORBING PLAYING WITH THE DISTORTEReeeeee     "
	dc.b "THE MUSIC IS BY MAD MAX kWHAT A SURPRISEgle    I AM CURRENTLY MELLOWING OUT TO THE JOHN PEEL SHOW ON RADIO \f AND MY ST IS BEGINNING TO SMELL AS ITmS BEEN ON FOR MOST OF THE PAST ^ DAYS"
	dc.b "e          "
	dc.b "I HATE THE RAGGA TWINSggg          TIME FOR A CIGARETTE AND SOME SLEEPeee        "
	dc.b "DID YOU KNOW THAT ALL THE SCREENS WERE PACKED WITH PACKjICEf WHICH IS A VERY GOOD PACKERh          BYEjDEjBYEjBYESg           "
emes
	
opal	ds.l 8

curadr	dc.l $78000
altadr	dc.l $70000
pointer	dc.l shds
select	dc.b 1
o120	ds.l 1
sav	ds.l 5
blnk	ds.l 8
ovbl	ds.l 1
osp	ds.l 1
speed	ds.w 1
cntln	ds.w 1
orez	ds.w 1
oscr	ds.l 1
oser	ds.l 1
oset	ds.w 1
pallete	dc.w $000,$000,$330,$550,$770,$300,$500,$700
	dc.w $000,$000,$330,$550,$770,$300,$500,$700
	
linoff	ds.w 12

; music	incbin "jambala2.msx"

bgr	incbin "grphics.dat"

bufr	RSRESET
backr	rs.w 25000/2
stack	rs.w 1000/2
stk	rs.w 1
twadr	rs.l 40*4
twpath	rs.l 32*2+10
twisrt	rs.w 5000/2
chars	rs.l 46*8+10
chars2	rs.l 46*8+10
scrbf	rs.l 40*2*2+20
font	rs.w 1
