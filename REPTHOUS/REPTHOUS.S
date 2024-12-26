; The Reptile House
; Originally written in 1989 by Zax and Vilm
; Updated in 1991 for inclusion in The Pleasuredemo
; Updated in 2024 to work with the new boostrap or to run as a standalone screen.
;
; Music has been replaced by dummy data for the Github version.
; Apologies for the lack of comments and cryptic labels - this is how we rolled in those days. 
; I'll try to add some later to make it more comprehensible (if I can make sense of it myself!).

first_music	equ $3b		; F1
last_music	equ $3b+4	; F5
music_vbl_offs	equ 8		; SNDH header has the VBL playback routine at offset 8, MSX header has it at offset 4

	; check for magic value indicating we were called from the bootstrap
	cmp.l #"PDOM",d0
	bne.s standalone

	move.l (sp)+,retadr
	bra.s standalone

retadr	dc.l 0

standalone
	clr.l -(sp)
	move.w #$20,-(sp)
	trap #1
	addq.l #6,sp
	move.l d0,osp

	lea bufr,a6
	lea staktop(a6),sp

	; Save the palette, screen address and resolution
	movem.l $ffff8240.w,d0-d7
	movem.l d0-d7,opal(a6)
	move.l $44e.w,o44e(a6)
	move.b $ffff8260.w,d0
	andi.w #%11,d0
	move.w d0,orez(a6)

	clr.w -(sp)			; Low resolution
	move.l #-1,-(sp)
	move.l #-1,-(sp)
	move.w #5,-(sp)
	trap #14
	add.l #12,sp

	bsr setmes
	bsr shftft

	jsr presh
	jsr rotshif

	moveq #32-1,d7
	move.l #bufr+data+59000,a1
lp	bsr dis

	moveq #64,d4
	move.l #bufr+data+48000,a0
cpy	add.l #16,a0
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	add.l #160-32,a0
	dbra d4,cpy
	dbra d7,lp

	move.l #bufr+data+59000,pfr

	move.l #cols,a6
	move.l $44e.w,a0
	move.l a0,addr
	sub.l #$14000,a0

	clr.w -(sp)
	move.l a0,-(sp)
	move.l a0,-(sp)
	move.w #5,-(sp)
	trap #14
	add.l #12,sp

	move.w #37,-(sp)
	trap #14
	addq.l #2,sp

	move.l $44e.w,a1
	move.l #20*232-1,d0
yloop	clr.l (a1)+
	clr.l (a1)+
	clr.l (a1)+
	clr.l (a1)+
	dbra d0,yloop

	lea pasc2,a0
	move.l $44e.w,a1
	lea 128*160(a1),a1
	move.w #40*34-1,d7
ltile	move.l (a0)+,(a1)+
	dbra d7,ltile

	lea pic,a0
	move.l $44e.w,a1
 	add.l #32*160,a1
	move.l #20*96-1,d0
yloop2	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	dbra d0,yloop2

	lea bufr+data+discol,a0
	clr.l d0
	move.w #4*35,d7
duck	move.l d0,(a0)+
	dbra d7,duck

	moveq #4,d0
	bsr changemusic

	move.l #pal,1114.w

	move.l #cols,a6

	move.b #$12,$fffffc02.w

	bsr hblon

rd	move.b $fffffc02.w,d0
	bmi.s rd

	cmp.b #$39,d0		; Space
	beq.s exit

	cmp.b #first_music,d0
	blt.s rd
	cmp.b #last_music,d0
	bgt.s nother

	andi.l #$ff,d0
	sub.w #$3b,d0
	bsr changemusic
	bra.s rd

nother	cmp.b #$3b+5,d0		; F6
	beq ngrphx

	bra.s rd

exit	bsr hbloff

	move.b #7,$ffff8800.w
	move.b #%11111111,$ffff8802.w
	move.b #8,$fffffc02.w

	; Restore the original screen address and resolution
	lea bufr,a6

	move.w orez(a6),-(sp)
	move.l o44e(a6),-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	movem.l opal(a6),d0-d7
	movem.l d0-d7,$ffff8240.w

	move.l osp,-(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp
	
	; check for return address
	move.l retadr(pc),d0
	tst.l d0
	beq.s byebye

	; Return to the bootstrap
	move.l d0,a0
	jmp (a0)

byebye	clr.w -(sp)
	trap #1

changemusic:
	cmp.b musnm,d0
	beq.s .nochg

	move.b #-1,musflg
	move.b d0,musnm

	lsl.w #3,d0
	lea musiclist(pc),a0
	move.l (a0,d0.w),a1			; Get the music data address
	move.l 4(a0,d0.w),d0			; Get the tune number
	lea music_vbl_offs(a1),a0		; Get the VBL routine address
	move.l a0,what+2			; Set the VBL routine address
	jsr (a1)				; Call the music player
	
.nochg	clr.b musflg
	rts

nomusic	rts					; Dummy music player

sync	subq.b #1,hbc
	rte

vbl	movem.l d0-d7/a0-a6,-(sp)
	move.l $68.w,-(sp)
	move.w sr,-(sp)
	move.l #sync,$68.w
	move.w #$2700,sr
	move.b #32,hbc

	movem.l pal(pc),d0-d7
	movem.l d0-d7,$ffff8240.w

	clr.l $ffff8240.w
	clr.l $ffff8244.w
*	clr.l rollercoaster
	addq.l #1,$466.w

	clr.b   $fffffa1b.w
	move.l #col,$120.w
	move.b  #1,$fffffa21.w
	move.b  #8,$fffffa1b.w

	move.l #cols,rollercoaster


	clr.b $ffff8260.w
	move.b #2,$ffff820a.w

	stop #$2100
	tst.b scron
	bne.s wchb
	bsr pallfc

wchb	stop #$2100
	tst.b hbc
	bpl.s wchb
	moveq #23,d7
delay	dbra d7,delay
	clr.b $ffff820a.w
	dcb.w 16,$4e71
	move.b #2,$ffff820a.w
	move.w (sp)+,sr
	move.l (sp)+,$68.w

	move.l $44e,a1
	add.l #165*160,a1
	addq.l #1,fc
	moveq #64-1,d7
	move.l pfr,a0
oop	movem.l (a0)+,d0-d3
	movem.l d0-d3,(a1)
	movem.l d0-d3,16(a1)
	movem.l d0-d3,32(a1)
	movem.l d0-d3,48(a1)
	movem.l d0-d3,64(a1)
	movem.l d0-d3,80(a1)
	movem.l d0-d3,96(a1)
	movem.l d0-d3,112(a1)
	movem.l d0-d3,128(a1)
	movem.l d0-d3,144(a1)
	add.l #160,a1
	dbra d7,oop

	move.l a0,pfr
	add.l #16,pfr
	cmp.l #32,fc
	blt fj
	clr.l fc
	move.l #bufr+data+59000,pfr
fj
*	eori.w #$777,$ff8240

	; Music playback VBL call
	tst.b musflg
	bne.s bust

	move.l a6,-(sp)
what	jsr nomusic
	move.l (sp)+,a6

bust	moveq #4-1,d2 ***
	move.l #fl,a3
floop
	move.l (a3),a1
	move.l $44e,a2
	lea 160*150(a2),a2
	add.w (a1),a2

	clr.w d1
play	moveq #31-1,d0
yloopb	move.w d1,2(a2)
	move.w d1,10(a2)
	move.w d1,18(a2)
	lea 160(a2),a2
	dbra d0,yloopb

	addq.l #4,a3
	dbra d2,floop

	moveq #4-1,d2   ***
	move.l #fl,a3
fl2	addq.l #8,(a3)
	cmp.l #e2,(a3)
	blt en2
	move.l #anm,(a3)
en2	move.l (a3),a1
	move.l $44e,a2
	lea 160*150(a2),a2
	add.w (a1)+,a2

	move.l #bufr+data,a0
	add.w (a1),a0

	moveq #31-1,d0
yloop4	move.w (a0)+,d4
	or.w d4,2(a2)
	move.w (a0)+,d4
	or.w d4,10(a2)
	move.w (a0)+,d4
	or.w d4,18(a2)

	add.l #160,a2
	dbra d0,yloop4

	addq.l #4,a3
	dbra d2,fl2

*	eori.w #$777,$ff8240
 	bsr scrl

mpat	cmp.l #beep,rollercoaster
	bne.s mpat
	movem.l (sp)+,d0-d7/a0-a6

*	eori.w #$777,$ffff8240.w
	rte

col	clr.b $fffffa1b.w
	move.b #1,$fffffa21.w
	move.b #8,$fffffa1b.w
	move.l #cols,rollercoaster
	move.l #col2,$120.w
	rte

col2	move.l a6,-(sp)
	move.l rollercoaster,a6
	move.w (a6)+,$ffff8244
	bpl.s metal
	move.l pal+2,$ffff8242.w
	move.l pal+6,$ffff8246.w
	move.l pal+10,$ffff824a.w
	move.l pal+14,$ffff824e.w
	move.l pal+18,$ffff8252.w
	clr.b $fffffa1b.w
	move.b #96,$fffffa21.w
	move.b #8,$fffffa1b.w
	move.l #col3,$120.w
	addq.l #4,sp
	rte
metal	move.l a6,rollercoaster
	move.l (sp)+,a6
	rte

col3	move.l #col5,$120.w
	move.b #35,lined
	move.l a6,u2
	lea bufr+data+discol,a6

	clr.b $fffffa1b.w
	move.b #1,$fffffa21.w
	move.b #8,$fffffa1b.w
	rte

col4	move.w (a6)+,$ffff8244.w
	bpl.s dumb
*	move.w #$770,$ffff8240.w
	move.l #newtb,$120.w
dumb	rte

u2	ds.l 1

alc5	move.l #alc5b,$120.w
	clr.b $fffffa1b.w
	move.b #34,$fffffa21.w
	move.b #8,$fffffa1b.w
	clr.l $ffff8240.w
	clr.l $ffff8244.w
	clr.l $ffff8248.w
	clr.l $ffff824c.w
	clr.l $ffff8250.w
	rte

alc5b	move.w #$070,$ffff8244.w
	move.w #$555,$ffff8246.w
	move.w #$444,$ffff8250.w
	move.w #$333,$ffff8252.w
	move.l u2(pc),a6
	clr.b $fffffa1b.w
	move.b #1,$fffffa21.w
	move.b #8,$fffffa1b.w
	move.l #col4,$120.w
	rte

col5	move.l (a6)+,$ffff8242.w
	move.l (a6)+,$ffff8246.w
	move.l (a6)+,$ffff824a.w
	move.l (a6)+,$ffff824e.w
	subq.b #1,lined
	bne.s wcal
	move.w #$070,$ffff8244.w
	move.w #$555,$ffff8246.w
	move.w #$444,$ffff8250.w
	move.w #$333,$ffff8252.w
	move.l u2(pc),a6
	move.l #col4,$120.w
wcal	rte

col6	move.l a6,-(sp)
	move.l rollercoaster,a6
	move.l (a6)+,$ffff8242.w
	move.w (a6)+,$ffff8246.w
	bpl.s wcal2
	clr.b $fffffa1b.w
wcal2	move.l a6,rollercoaster
	move.l (sp)+,a6
	rte


newtb	clr.b   $fffffa1b.w
	movem.l d0-d1/a0-a1,-(sp)
	move.w  #$fa21,a1
	move.b  #2,(a1)
	move.b  #8,$fffffa1b.w

	move.b  #1,(a1)

	move.b  (a1),d0
wait	cmp.b   (a1),d0
	beq     wait

	clr.b   $ffff820a.w
	moveq   #3,d0
nopi2	nop
	dbf     d0,nopi2
	move.b  #2,$ffff820a.w

	movem.l (sp)+,d0-d1/a0-a1
	move.l #beep,rollercoaster
	move.l #col6,$120.w
	rte




cols	dc.w $000,$101,$202,$303
	dc.w $404,$505,$606,$707
	dc.w $716,$725,$734,$743
	dc.w $752,$761,$770,$671
	dc.w $572,$473,$374,$275
	dc.w $176,$077,$167,$257
	dc.w $347,$437,$326,$215
	dc.w $104,$8003

	dcb.w 6,$000
	dc.w $400,$500,$600,$700
	dc.w $000,$110,$220,$330,$440,$550,$660,$770
	dc.w $000,$010,$020,$030,$040,$050,$060,$070
	dc.w $161,$252,$343,$434,$525,$616,$707,$606
	dc.w $000,$001,$002,$003,$004,$005,$006,$007
	dc.w $116,$225,$334,$443,$552,$661,$770,$760
	dc.w $750,$740,$730,$720,$710,$700,$600,$500
	dc.w $400,$300,$200,$100
	ds.w 2
	dc.w $8000

lined	dc.b 34

beep	dc.w $007,$110,$007,$107,$220,$107,$207,$330,$207
	dc.w $307,$440,$307,$407,$550,$407,$507,$660,$507
	dc.w $607,$770,$607,$777,$760,$777,$127,$750,$127
	dc.w $237,$740,$237,$347,$730,$347,$437,$631,$437
	dc.w $527,$532,$527,$617,$433,$617,$707,$334,$707
	dc.w $606,$235,$606,$505,$136,$505,$404,$037,$404
	dc.w $303,$047,$303,$202,$057,$202,$203,$067,$203
	dc.w $204,$077,$204,$205,$076,$205,$206,$075,$206
	dc.w $000,$074,$000,$000,$073,$000,$000,$062,$000
	dc.w $000,$051,$000,$000,$040,$000,$000,$030,$000
	dc.w $000,$020,$000,$000,$010,$000,$000,$000,$000


	dcb.w 11*3,$777
	dc.w $700,$070,$8007

cdis	dc.b 	0,1,2,3,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,3,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
cedis	dc.b 0,1,2,3,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,3,2,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0


nocur	dc.b 27,"f"
cmes	dc.b "                 WELCOME TO THE INTERESTING VERTICAL SCROLLERSf WITH BULGING AND STRETCHING VARIANTSe  GREETINGS TO ROBEf PHANTOM \f THE SAINTf FALCONf MARTYNf GREATGUY"
	dc.b " AND SISTER MELf DIGITAL INSANITYf XXX INTERNATIONALf "
	dc.b "THE LOST BOYSf THE CAREBEARSf ULMf TEXf AENIGMATICAf OMEGAf SYNCf TNT CREWf LEVEL \af DELTA FORCEf DYNAMIC DUOf ATGf "
	dc.b "THE BLACK MONOLITH TEAMf THE PHALANXf PAULO SIMOESf FLEXIBLE FRONTf AND ANYBODY ELSE WHO THINKS THEY DESERVE A MENTION        "
ecmes
cmesp	dc.l cmes
colpp	dc.l scrcol
dispo	dc.l cdis
cpp	ds.l 1
pointer	ds.l 1
ovbl	ds.l 1
fc	ds.l 1
oa2	ds.l 1
addr	ds.l 1
fak	ds.l 1
fl	dc.l anm,anm+72,anm+144,anm+216,anm+288,anm+288+72
anm
	incbin "fuji2.pth"
e2
presh
	move.l #fuji+34,a0
	move.l #bufr+data,a1
	moveq #10-1,d7
mloop	moveq #16-1,d1

	moveq #32-1,d2
yloop3	clr.w (a1)+
	move.l (a0)+,(a1)+
	dbra d2,yloop3
	sub.l #128,a0
	sub.l #192,a1
preloop
	moveq #32-1,d2
yloop5	move.w (a1)+,190(a1)
	move.l (a1)+,188(a1)
	dbra d2,yloop5

scroll	movem.l d0-d4/a0,-(sp)
	clr.l d2
	move.l a1,a0
	moveq #32-1,d0
syloop2	move.w (a0),d3
	lsl.w #1,d3
	move.w d3,(a0)
	addq.l #2,a0
	move.w (a0),d3
	lsl.w #1,d3
	scs d2
	neg.b d2
	move.w d3,(a0)
	add.w d2,-2(a0)
	addq.l #2,a0
	move.w (a0),d3
	lsl.w #1,d3
	scs d2
	neg.b d2
	move.w d3,(a0)
	add.w d2,-2(a0)
	addq.l #2,a0
	dbra d0,syloop2
	movem.l (sp)+,d0-d4/a0

	dbra d1,preloop

	add.l #128,a0
	dbra d7,mloop

 	rts



fuji	incbin "fuji.dat"

pfr	ds.l 1
pb	dc.b 15
sc	ds.l 1

dis	movem.l d0-d6/a0-a4,-(sp)
cn	move.l #f,a2
	move.l #hi,a3
	move.l #am,a4
	moveq #4-1,d2

la	move.l #bufr+data+31000,a0
	add.l (a2)+,a0
	move.l #bufr+data+48000,a1
	add.l (a3)+,a1
	moveq #10-1,d1
	move.l (a4)+,d5
	move.l (a4)+,d4
	move.l (a4)+,d6
t
	move.l d5,d0
ayloop2	move.l (a0)+,(a1)
	move.l (a0)+,4(a1)
	move.l (a0)+,8(a1)
	move.l (a0)+,12(a1)
	add.l #160,a1
	dbra d0,ayloop2
	sub.l d6,a1
	sub.l d4,a0
	dbra d1,t
	dbra d2,la

	move.l #f,a2
	add.l #32*16,(a2)
	cmp.l #32*16*32,(a2)
	bne.s n
	clr.l (a2)
	*move.l #-32*16,(a2)
n	addq.l #4,a2
	add.l #32*16*2,(a2)
	cmp.l #32*16*32,(a2)
	bne.s n2
	clr.l (a2)
n2	addq.l #4,a2
	add.l #32*16*4,(a2)
	cmp.l #32*16*32,(a2)
	bne.s n3
	clr.l (a2)
n3	addq.l #4,a2
	add.l #32*16*8,(a2)
	cmp.l #32*16*32,(a2)
	bne.s n4
	clr.l (a2)
n4	movem.l (sp)+,d0-d6/a0-a4
	rts

rotshif	movem.l d0-d7/a0-a6,-(sp)
	move.l #bufr+data+31000,a1

	move.l #para+34+512,a0

	move.l #32-1,d0
ayloop	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	dbra d0,ayloop
	sub.l #32*16,a1

	move.l #32-1,d7

pre	moveq #32-1,d0
	move.l a1,-(sp)

roty	move.l #bs,a2
	moveq #8-1,d1
x	move.w (a1),d4
	lsl.w #1,d4
	scs.b (a2)
	neg.b (a2)+
	move.b d2,d3
	move.w d4,(a1)+
	dbra d1,x

	sub.l #16,a1
	move.w 6(a1),d1
	add.b -(a2),d1
	move.w d1,6(a1)
	move.w 4(a1),d1
	add.b -(a2),d1
	move.w d1,4(a1)
	move.w 2(a1),d1
	add.b -(a2),d1
	move.w d1,2(a1)
	move.w (a1),d1
	add.b -(a2),d1
	move.w d1,(a1)

	move.w 14(a1),d1
	add.b -(a2),d1
	move.w d1,14(a1)
	move.w 12(a1),d1
	add.b -(a2),d1
	move.w d1,12(a1)
	move.w 10(a1),d1
	add.b -(a2),d1
	move.w d1,10(a1)
	move.w 8(a1),d1
	add.b -(a2),d1
	move.w d1,8(a1)
	add.l #16,a1
	dbra d0,roty

	move.l (sp)+,a1
	move.l a1,a2
	add.l #16*32,a2
	moveq #32-1,d0
cpy2	move.l (a1)+,(a2)+
	move.l (a1)+,(a2)+
	move.l (a1)+,(a2)+
	move.l (a1)+,(a2)+
	dbra d0,cpy2
	dbra d7,pre

	movem.l (sp)+,d0-d7/a0-a6
	rts


hblon	lea bufr+mfpstr,a0
	move.b $fffffa07.w,(a0)+
	move.b $fffffa09.w,(a0)+
	move.b $fffffa13.w,(a0)+
	move.b $fffffa15.w,(a0)+
	move.l $70.w,(a0)+
	move.l $118.w,(a0)+
	move.l $120.w,(a0)+
	move.l $8.w,(a0)+
	move.l $c.w,(a0)+
	move.l $10.w,(a0)+
	move.l $20.w,(a0)+
	; move.l #exit,$8.w
	; move.l #exit,$c.w
	; move.l #exit,$10.w
	; move.l #exit,$20.w
	clr.b $fffffa07.w
	clr.b $fffffa09.w
	bclr #3,$fffffa17.w

	move.l #nkey,$118.w
	move.l #vbl,$70.w
	move.l #nul2,$120.w

*	bset #6,$fffffa09.w
*	bset #6,$fffffa15.w
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


hbloff	clr.b $fffffa1b.w
	lea bufr+mfpstr,a0
	move.b (a0)+,$fffffa07.w
	move.b (a0)+,$fffffa09.w
	move.b (a0)+,$fffffa13.w
	move.b (a0)+,$fffffa15.w
	bset #3,$fffffa17.w
	move.l (a0)+,$70.w
	move.l (a0)+,$118.w
	move.l (a0)+,$120.w
	move.l (a0)+,$8.w
	move.l (a0)+,$c.w
	move.l (a0)+,$10.w
	move.l (a0)+,$20.w
	bset #6,$fffffa09.w
	bset #6,$fffffa15.w


	move.b #8,$fffffc02.w
	move.b #7,$ffff8800.w
	move.b #%11111111,$ffff8802.w
	rts



setmes	lea mess,a0
	move.w #((emes-mess))-1,d0
suba	cmp.b #32,(a0)
	bne.s nospac
	move.b #"A"+47,(a0)
nospac	sub.b #"A",(a0)+
	dbra d0,suba

	moveq #10,d1
	lea mess,a0
	lea frm,a1
	moveq #11-1,d0
putbuf	clr.l d2
	move.b (a0)+,d2
	lsl.l d1,d2
	move.l d2,(a1)+
	dbra d0,putbuf

	rts

shftft	lea bigfont,a0
	lea bufr+data,a1
	move.l #47*4*16/4,d0
clop	move.l (a0)+,(a1)+
	dbra d0,clop

	lea bufr+data,a0
	lea bufr+data+font+1024,a1
	moveq #47-1,d7   * NO. OF LETTERS
loopa	lea bufr+data+font,a2
	moveq #16-1,d6   * 16 lines
loopb	clr.l (a1)+
	clr.l (a2)+
	move.l (a0),(a1)+
	move.l (a0)+,(a2)+
	dbra d6,loopb

	moveq #7-1,d6    * NO. OF SHIFTS
shlop	lea bufr+data+font,a2
	moveq #16-1,d4   * NO. OF LINES
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

	lea bufr+data+font,a2
	moveq #32-1,d5   * 64 pixels * 16 lines /8
stlop	move.l (a2)+,(a1)+
	dbra d5,stlop
	dbra d6,shlop
	dbra d7,loopa

	lea bufr+data+font+1024,a0   * FONT TAKES UP data TO data+46000
	lea bufr+data+font,a1
	move.l #(47*16*8),d0
backit	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	dbra d0,backit

	move.l #256-1,d0
clend	clr.l (a1)+
	dbra d0,clend

	rts

scrl	move.l $44e,a4
	lea 200*160(a4),a4
	lea 38*160(a4),a4
	lea bufr+data+font,a3
	move.w pixl,d0
	lsl.w #7,d0
	add.w d0,a3
	lea 4(a3),a0
	lea 0(a4),a1
	lea frm,a2
	add.l (a2),a0
	moveq #16-1,d0	* height
yl1	move.w (a0)+,(a1)
	move.w (a0)+,8(a1)
	addq.w #4,a0
	lea 160(a1),a1
	dbra d0,yl1

	lea 0(a3),a0
	lea 0(a4),a1
	add.l #144,a1
	add.l 40(a2),a0
	moveq #16-1,d0	* height
yl2	move.w (a0)+,(a1)
	move.w (a0)+,8(a1)
	addq.w #4,a0
	lea 160(a1),a1
	dbra d0,yl2

	lea 0(a4),a1
	lea 16(a1),a1
	moveq #4-1,d0
mploop	lea 0(a3),a0
	addq.l #8,a2
	add.l (a2),a0
	moveq #16-1,d1     * height
yl3	move.w (a0)+,(a1)
	move.w (a0)+,8(a1)
	move.w (a0)+,16(a1)
	move.w (a0)+,24(a1)
	lea 160(a1),a1
	dbra d1,yl3
	sub.l #160*16-32,a1
	dbra d0,mploop

	lea 0(a4),a1
*	lea 8(a1),a1
	lea frm,a2
	subq.l #4,a2
	moveq #5-1,d0
mloop2	lea 0(a3),a0
	addq.l #8,a2
	add.l (a2),a0
	moveq #16-1,d1     * height
yl4	movem.w (a0)+,d4-d7
	or.w d4,(a1)
	or.w d5,8(a1)
	or.w d6,16(a1)
	or.w d7,24(a1)
	lea 160(a1),a1
	dbra d1,yl4
	sub.l #160*16-32,a1
	dbra d0,mloop2

	addq.w #1,pixl
	cmp.w #8,pixl
	bne nonlt

	clr.w pixl
	lea frm+4,a0
	moveq #10-1,d0
lft	move.l (a0)+,-8(a0)
	dbra d0,lft

	clr.l d0
	addq.l #1,pmes
	cmp.l #emes,pmes
	bne.s nowrap

	move.l #mess,pmes

nowrap	move.l pmes,a1
	move.b (a1)+,d0
	lsl.l #8,d0
	lsl.l #2,d0
	move.l d0,-4(a0)

nonlt	rts

pallfc	not.l fak
	bne ijj
	lea bufr+data+discol+16,a0
	moveq #33-1,d7
jim	move.l (a0),-16(a0)
	move.l 4(a0),-12(a0)
	move.l 8(a0),-8(a0)
	move.l 12(a0),-4(a0)
	add.l #16,a0
	dbra d7,jim
	addq.l #2,colpp
	cmp.l #mojo,colpp
	bne jim5
	move.l #scrcol,colpp
jim5	addq.l #8,cpp
	cmp.l #64,cpp
	bne jim6
	clr.l cpp
	addq.l #1,cmesp
	cmp.l #ecmes,cmesp
	blt jim6
	move.l #cmes,cmesp
jim6	move.l cmesp,a0
	clr.l d0
	move.b (a0),d0
	sub.b #"A"-1,d0
	bpl.s simsad
	clr.w d0
simsad	lea smfont,a1
	lsl.w #6,d0
	add.l d0,a1
	add.l cpp,a1
	lea bufr+data+discol+33*16,a0
	move.l colpp,a2
	moveq #8-1,d7
jim2	tst.b (a1)+
	bne jim3
	clr.w (a0)+
	bra.s jim4
jim3	move.w (a2),(a0)+
jim4	dbra d7,jim2

ijj	rts

ngrphx	move.b #-1,scron
	move.l #alc5,col3+2

	addq.l #4,numg
	cmp.l #enumg,numg
	blt.s blaah
	move.l #numgl,numg
blaah	move.l numg(pc),a0
	move.l (a0),a0

	move.l $44e.w,a1
	lea 128*160(a1),a1
	moveq #2*34-1,d7
ltile2	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	dbra d7,ltile2
	clr.b scron
	move.l #col5,col3+2

waxyw	cmp.b $fffffc02.w,d0
	beq.s waxyw
	bra rd


numg	dc.l numgl
numgl	dc.l pasc2,pasc,pasc3,pasc4,pasc5,pasc6,pasc7,pasc8,pasc9
enumg

osp	ds.l 1
scron	ds.b 1

scrcol	dc.w $700,$710,$721,$732,$743,$754,$765,$776,$777,$676,$575,$474,$373,$272,$171,$070,$071,$072,$073,$074,$075,$076,$077,$176,$275,$374,$473,$572,$671,$770,$771,$772,$773,$774,$775,$776,$777,$766,$755,$744,$733,$722,$711
mojo

pmes	dc.l mess+10
mess	dc.b "             PRESSING THE FUNCTION KEYS PRODUCES STRANGE EFFECTSeee         kOKf NOT STRANGE SO MUCH AS PREDICTABLEl          "
	dc.b "THIS IS THE CYBERPUNKS SECOND DEMOf SECOND VERSIONe           "
	dc.b "THE SCREEN TOOK ABOUT ^ DAYS TO WRITE ORIGINALLYf AND ABOUT ANOTHER ^ DAYS FOR THE REjWRITEe            THE DAY AFTER WE FINISHED THIS SCREENf WE GOT OUR EXAM RESULTS kGCSEmSl  ZAX GOT b mAmSf ] mBmS AND ] mCmSf AND VILM GOT ` mAmS AND"
	dc.b " ` mBmSe           PRETTY GOOD RESULTS, WE FEELeee           "
	dc.b "THIS SCREEN WAS ORIGINALLY SENT INTO ST USER MAGAZINE kIN ITS ORIGINAL FORMlf BUT WAS SENT BACK A YEAR LATER WITH A CARD SAYING THAT IT WAS mNOT THE SORT OF THING WE PUBLISHm eee  IEe CRAPe            "
	dc.b "            THESE SCREENS ALL USED TO HAVE MESSAGES WHICH TOOK HALF AN HOUR OR SO TO READf BUT WE KEEP GOING BACK AND DELETING BITS THAT WE DONmT LIKE UNTIL THEREmS VIRTUALLY NOTHING LEFT     kHE SAYS DELETING ANOTHER ^ LINESgl           "
emes

pixl	dc.w 4
frm	ds.l 11

tile	dc.w $aaaa,$6666,$1e1e,$0101

hbc	ds.b 1
hangwir	ds.l 1
musflg	ds.w 1
musnm	dc.b -1
bufck	ds.l 1
	ds.l 2
bs	ds.l 28
f	ds.l 28
hi	dc.l 0,160*6,160*16,160*32
am	dc.l 6-1,6*16,160*6-16,10-1,10*16,160*10-16
	dc.l 16-1,16*16,160*16-16,32-1,32*16,160*32-16

rollercoaster	ds.l 1

musiclist:
	dc.l music1,1
	dc.l music3,1
	dc.l music4,1
	dc.l music2,0
	dc.l music1,0

pal	incbin "brickz.col"

bigfont	incbin "3216fnt3.dat"

smfont	ds.w 32
	incbin "smfont.dat"
e_smfont
	EVEN

pasc	incbin "pallscr.dat"
pasc2	incbin "pallscr2.dat"
pasc3	incbin "pallscr3.dat"
pasc4	incbin "pallscr4.dat"
pasc5	incbin "pallscr5.dat"
; These scroller patterns were removed from the version on The Pleasuredemo to save space
pasc6	incbin "pallscr6.dat"
pasc7	incbin "pallscr7.dat"
pasc8	incbin "pallscr8.dat"
pasc9	incbin "pallscr9.dat"

	EVEN
para	incbin "layer.dat"

	EVEN
pic	incbin "brickz.dat"

	; Dummy music files. Replace them with music from the SNDH archive if you want music.
	EVEN
music1	;incbin "menu213.msx"
	dcb.l 3,$4e750000		; 3 x rts
	EVEN
music2	;incbin "menu117.msx"
	dcb.l 3,$4e750000
	EVEN
music3	;incbin "tcbtrack.msx"
	dcb.l 3,$4e750000
	EVEN
music4	;incbin "teramis1.msx"
	dcb.l 3,$4e750000
	
	RSRESET

bufr	ds.l 1
o44e	rs.l 1
orez	rs.l 1
opal	rs.l 8
mfpstr	rs.l 14
stack	rs.l 500
staktop	rs.w 1

data	rs.w 100000/2
font	rs.w 50000/2
discol	rs.w 8*34
enkkk	rs.w 1
