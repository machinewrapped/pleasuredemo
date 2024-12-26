; The Helix Demo
; Written in 1991 (possibly earlier) by Vilm of The Cyberpunks
; Adapated in 2024 to work with the new bootstrap for The Pleasuredemo or to run as a standalone TOS program.

stackmargin	equ 1000
stackspace	equ 1000
screensize	equ 32000

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
	addq.l #6,a7
	move.l d0,stack

	; Put the stack below the screen
	move.l $44e.w,a0
	lea -stackmargin(a0),sp

	move.l a0,oscr
	move.b $ffff8260.w,d0
	andi.w #%11,d0
	move.w d0,orez

	movem.l $ffff8240.w,d0-d7
	movem.l d0-d7,opal

	movem.l bl,d0-d7
	movem.l d0-d7,$ffff8240.w

	; Switch to low resolution (don't move the screen)
	clr.w -(sp)
	move.l #-1,-(sp)
	move.l #-1,-(sp)
	move.w #5,-(sp)
	trap #14
	add.l #12,sp

	; clr.w d0
	; bsr initmusic

	bsr shift

	bsr clrscrn

	move.w #$070,$ffff8248.w
		
	move.w #37,-(sp)
	trap #14
	addq.l #2,sp
	
	lea cols,a6
	bsr hblon
	
	; Wait for a key
x	tst.b key
	bmi.s x
	
	move.b #7,$ffff8800.w
	move.b #%11111111,$ffff8802.w
	bsr hbloff

	bsr clrscrn

	movem.l opal,d0-d7
	movem.l d0-d7,$ff8240

	move.l stack,-(a7)
	move.w #$20,-(sp)
	trap #1
	addq.l #6,sp

	move.w orez(pc),-(sp)	; Restore the original screen address and resolution
	move.l oscr(pc),-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	; check for return address
	move.l retadr(pc),d0
	tst.l d0
	beq.s byebye

	move.l d0,a0
	jmp (a0)

byebye	clr.w -(sp)
	trap #1

; initmusic:
; 	lea music(pc),a0
; 	cmp.w #"**",8(a0)
; 	bne.s sad_guy

; 	; Copy the music to its required location
; 	move.l music+10(pc),a1
; 	lea 4(a1),a2
; 	move.l a2,pld+2
; 	move.l a1,sad_guy+2
; 	lea emusic(pc),a2
; shame	move.l (a0)+,(a1)+
; 	cmp.l a0,a2
; 	bgt.s shame
	
; sad_guy	jsr music
; 	rts

clrscrn:
	move.l #screensize/8-1,d0
	move.l $44e.w,a0
	moveq #0,d1
cls2	move.l d1,(a0)+
	move.l d1,(a0)+
	dbra d0,cls2
	rts

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
	move.l #helix,$70.w
	move.l #col,$120.w
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


key	dc.b $ff
joycm	ds.b 1
mousx	ds.b 1
mousy	ds.b 1
mousb	ds.b 1

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
	rts


col	move.l (a6)+,$ff8242
	move.w scol,$ff8250
	subq.l #1,fc
	bne.s hq
	move.w #$050,$ff8248
	move.w #$030,$ff8250
	move.w #$070,$ff8258
	move.w #$050,$ff824c
	move.w #$030,$ff8254
	move.w #$070,$ff825c
	
	move.l #colr2,$120
hq	bclr #0,$fffa0f
	rte
	
colr2	move.w (a6),$ff824a
	move.w (a6),$ff8252
	move.w (a6),$ff825a 
	move.l (a6)+,$ff8242
	subq.l #1,fc2
	bne.s hq2
	move.l #col3,$120
hq2	bclr #0,$fffa0f
	rte
	
col3	move.w 174(a6),$ff8248
	move.w scol,$ff8250
	move.l (a6)+,$ff8242
	bclr #0,$fffa0f
	rte
	

shift	lea path,a0
ff	addq.l #2,a0
	move.w (a0),d0
	lsl.w #6,d0
	move.w d0,(a0)+
	cmp.l #epath,a0
	bne ff
	
	lea logo,a0
	move.l st,a1
	move.l #31-1,d0
c1	clr.l (a1)+
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
	dbra d0,c1
	move.l st,a0
	move.l #31*15-1,d0
c2	moveq #17-1,d1
c3	
	move.w (a0)+,d2
	lsl.w #1,d2
	move.w d2,(a1)+
	move.w (a0)+,d2
	lsl.w #1,d2
	move.w d2,(a1)+
	
	move.w (a0),d2
	rol.w #1,d2
	andi.w #1,d2
	add.w d2,-4(a1)
	move.w 2(a0),d2
	rol.w #1,d2
	andi.w #1,d2
	add.w d2,-2(a1)
	
	dbra d1,c3
	dbra d0,c2

	lea font,a0
	move.l $44e.w,a1
	move.l #(32*48)/4-1,d0
s1	move.l (a0)+,(a1)+
	dbra d0,s1
	lea free,a0
	move.l $44e.w,a1
	moveq #49-1,d0
s2	moveq #16-1,d1
s5	clr.w (a0)+
	move.w (a1)+,(a0)+
	dbra d1,s5
	move.l a0,a2
	sub.l #64,a0
	moveq #16-1,d1
s3	moveq #15-1,d2
s4	move.l (a0)+,d3
	lsl.l #1,d3
	move.l d3,(a2)+
	dbra d2,s4
	dbra d1,s3
	move.l a2,a0
	dbra d0,s2
	*move.l a0,st
	rts

helix	lea cols,a6
	clr.w $ff8240
	move.l #col,$120
	clr.b $fffffa1b.w
	move.b #4,$fffffa21.w
	move.b #8,$fffffa1b.w
	 
	move.l #7,fc
	move.l #8,fc2
	subq.l #1,stp
	bne jka
	move.l #40,stp
	cmp.w #$777,scol
	beq jka
	move.w scol,$ff8250
	add.w #$111,scol
jka	cmp.w #$777,scol
	bne df
	move.w #$666,scol
df	move.l $44e.w,a0
	add.l #100*160,a0
	moveq #48-1,d5
bs1	move.b 5(a0),4(a0)
	move.b 12(a0),5(a0)
	move.b 13(a0),12(a0)
	move.b 20(a0),13(a0)
	move.b 21(a0),20(a0)
	move.b 28(a0),21(a0)
	move.b 29(a0),28(a0)
	move.b 36(a0),29(a0)
	move.b 37(a0),36(a0)
	move.b 44(a0),37(a0)
	move.b 45(a0),44(a0)
	move.b 52(a0),45(a0)
	move.b 53(a0),52(a0)
	move.b 60(a0),53(a0)
	move.b 61(a0),60(a0)
	move.b 68(a0),61(a0)
	move.b 69(a0),68(a0)
	move.b 76(a0),69(a0)
	move.b 77(a0),76(a0)
	move.b 84(a0),77(a0)
	move.b 85(a0),84(a0)
	move.b 92(a0),85(a0)
	move.b 93(a0),92(a0)
	move.b 100(a0),93(a0)
	move.b 101(a0),100(a0)
	move.b 108(a0),101(a0)
	move.b 109(a0),108(a0)
	move.b 116(a0),109(a0)
	move.b 117(a0),116(a0)
	move.b 124(a0),117(a0)
	move.b 125(a0),124(a0)
	move.b 132(a0),125(a0)
	move.b 133(a0),132(a0)
	move.b 140(a0),133(a0)
	move.b 141(a0),140(a0)
	move.b 148(a0),141(a0)
	move.b 149(a0),148(a0)
	move.b 156(a0),149(a0)
	move.b 157(a0),156(a0)
	move.b 165(a0),164(a0)
	move.b 172(a0),165(a0)
	move.b 173(a0),172(a0)
	move.b 180(a0),173(a0)
	move.b 181(a0),180(a0)
	move.b 188(a0),181(a0)
	move.b 189(a0),188(a0)
	move.b 196(a0),189(a0)
	move.b 197(a0),196(a0)
	move.b 204(a0),197(a0)
	move.b 205(a0),204(a0)
	move.b 212(a0),205(a0)
	move.b 213(a0),212(a0)
	move.b 220(a0),213(a0)
	move.b 221(a0),220(a0)
	move.b 228(a0),221(a0)
	move.b 229(a0),228(a0)
	move.b 236(a0),229(a0)
	move.b 237(a0),236(a0)
	move.b 244(a0),237(a0)
	move.b 245(a0),244(a0)
	move.b 252(a0),245(a0)
	move.b 253(a0),252(a0)
	move.b 260(a0),253(a0)
	move.b 261(a0),260(a0)
	move.b 268(a0),261(a0)
	move.b 269(a0),268(a0)
	move.b 276(a0),269(a0)
	move.b 277(a0),276(a0)
	move.b 284(a0),277(a0)
	move.b 285(a0),284(a0)
	move.b 292(a0),285(a0)
	move.b 293(a0),292(a0)
	move.b 300(a0),293(a0)
	move.b 301(a0),300(a0)
	move.b 308(a0),301(a0)
	move.b 309(a0),308(a0)
	move.b 316(a0),309(a0)
	move.b 317(a0),316(a0)
	add.l #320,a0
	dbra d5,bs1
	*move.w #$700,$ff8240
	move.l pmes2,a0
	clr.l d5
	move.b (a0),d5
	cmp.b #32,d5
	beq bs5
	sub.l #65,d5
	mulu #72,d5
	add.l line,d5
	move.l $44e.w,a1
	add.l #100*160+157,a1
	lea font2,a0
	add.l d5,a0
	lea blks,a2
	add.l fl,a2
	moveq #6-1,d5
bs2	move.w (a0),d3
	move.b (a2,d3),(a1)
	move.b 2(a2,d3),160(a1)
	move.b 4(a2,d3),320(a1)
	move.b 6(a2,d3),480(a1)
	move.b 8(a2,d3),640(a1)
	move.b 10(a2,d3),800(a1)
	move.b 12(a2,d3),960(a1)
	move.b 14(a2,d3),1120(a1)
	move.b 16(a2,d3),1280(a1)
	move.b 18(a2,d3),1440(a1)
	move.b 20(a2,d3),1600(a1)
	move.b 22(a2,d3),1760(a1)
	move.b 24(a2,d3),1920(a1)
	move.b 26(a2,d3),2080(a1)
	move.b 28(a2,d3),2240(a1)
	move.b 30(a2,d3),2400(a1)
	add.l #2560,a1
	add.l #12,a0
	dbra d5,bs2
bs6	
kk	*move.w #$700,$ff8240
	lea free+60,a0
	move.l $44e.w,a2
	move.l pmes,a1
	move.l o,d5
	sub.l d5,a0
	clr.l d1
	moveq #10,d2
	move.b -(a1),d1
	cmp.b #" ",d1
	bne db
	move.l #63+48,d1
db	sub.l #63,d1
	lsl.l d2,d1
	add.l d1,a0
db2	lea path,a1
	move.l a0,a4
	add.l o,a4
	sub.l #64,a4
h1	move.w (a1)+,d3
	move.w (a1)+,d4
	*lsl.w #6,d4
	move.w (a0,d4),(a2,d3)
	move.w -2(a0,d4),8(a2,d3)
	subq.l #4,a0
	cmp.l a0,a4
	bne h1
	move.l pmes,a3
	subq.l #1,a3
	moveq #17-1,d5
h3	lea free+60,a0
	clr.l d1
	move.b -(a3),d1
	cmp.b #" ",d1
	bne rdb
	move.l #63+48,d1
rdb	sub.l #63,d1
	lsl.l d2,d1
	add.l d1,a0
rdb2	moveq #8-1,d6
h4	move.w (a1)+,d3
	move.w (a1)+,d4
	*lsl.w #6,d4
	move.w (a0,d4),(a2,d3)
	move.w -2(a0,d4),8(a2,d3)
	*subq.l #4,a0
	*cmp.l #epath-4,a1
	*bgt h5
	move.w (a1)+,d3
	move.w (a1)+,d4
	*lsl.w #6,d4
	move.w -4(a0,d4),(a2,d3)
	move.w -6(a0,d4),8(a2,d3)
	subq.l #8,a0
	*cmp.l #epath-4,a1
	*bgt h5
	dbra d6,h4
	dbra d5,h3
h5	subq.l #4,o
	bge h2
	addq.l #1,pmes
	cmp.l #emes+20,pmes
	bne h6
	move.l #mes+20,pmes
h6	move.l #60,o
h2	move.l $44e.w,a0
	clr.w 6722(a0)
	clr.w 8(a0)
	addq.l #1,fl
	cmp.l #2,fl
	bne bs4
	clr.l fl
	addq.l #2,line
	cmp.l #12,line
	bne bs4
	clr.l line
	addq.l #1,pmes2
	cmp.l #emes2,pmes2
	bne bs4
	move.l #mes2,pmes2
bs4	
	move.l st,a0
	move.l $44e.w,a1
	lea lpo,a2
	add.l #160*31+8,a1
	moveq #31-1,d5
	move.l (a2),a3
lp1	
	move.w (a3)+,d1
	move.l (a0,d1),4(a1)
	move.l 4(a0,d1),12(a1)
	move.l 8(a0,d1),20(a1)
	move.l 12(a0,d1),28(a1)
	move.l 16(a0,d1),36(a1)
	move.l 20(a0,d1),44(a1)
	move.l 24(a0,d1),52(a1)
	move.l 28(a0,d1),60(a1)
	move.l 32(a0,d1),68(a1)
	move.l 36(a0,d1),76(a1)
	move.l 40(a0,d1),84(a1)
	move.l 44(a0,d1),92(a1)
	move.l 48(a0,d1),100(a1)
	move.l 52(a0,d1),108(a1)
	move.l 56(a0,d1),116(a1)
	move.l 60(a0,d1),124(a1)
	move.l 64(a0,d1),132(a1)
	add.l #68,a0
	add.l #160,a1
	dbra d5,lp1
	addq.l #2,(a2)
	cmp.l #ep,(a2)
	bne llj
	move.l #p,(a2)
llj	

stars	lea starpt(pc),a5
	move.l $44e.w,a0
	moveq #37-1,d7
each	move.w (a5),d6
	move.w 4(a5),d1
	cmp.w 8(a5),d1
	bmi.s norp
	clr.w (a0,d6.w)
	sub.w #8,d6
	cmp.w 2(a5),d6
	bge.s norp
	add.w #160,d6
norp	move.w 6(a5),d2
	move.w d6,(a5)
	rol.w d2,d1
	move.w d1,4(a5)
	move.w d1,(a0,d6.w)
	lea 10(a5),a5
	dbra d7,each
	
here	move.l ppth,a0
	subq.l #2,ppth
	cmp.l #path2,ppth
	bne dj
	move.l #epth2,ppth
dj	move.l pmes3,a2
	lea font3,a3
	move.l $44e.w,a4
	add.l #160*10,a4
	moveq #20-1,d0	
lp	move.l a4,a1
	clr.w d1
	move.b (a2)+,d1
	cmp.b #" ",d1
	beq sep
	sub.b #"A",d1
	lsl.w #3,d1
	add.w (a0)+,a1
	clr.b (a1)
	move.b (a3,d1.w),160(a1)
	move.b 1(a3,d1.w),320(a1)
	move.b 2(a3,d1.w),480(a1)
	move.b 3(a3,d1.w),640(a1)
	move.b 4(a3,d1.w),800(a1)
	move.b 5(a3,d1.w),960(a1)
	move.b 6(a3,d1.w),1120(a1)
	move.b 7(a3,d1.w),1280(a1)
bk	move.l a4,a1
	clr.w d1
	move.b (a2)+,d1
	cmp.b #" ",d1
	beq sep2
	sub.b #"A",d1
	lsl.w #3,d1
	add.w (a0)+,a1
	clr.b 1(a1)
	move.b (a3,d1.w),161(a1)
	move.b 1(a3,d1.w),321(a1)
	move.b 2(a3,d1.w),481(a1)
	move.b 3(a3,d1.w),641(a1)
	move.b 4(a3,d1.w),801(a1)
	move.b 5(a3,d1.w),961(a1)
	move.b 6(a3,d1.w),1121(a1)
	move.b 7(a3,d1.w),1281(a1)
bk2	addq.l #8,a4
	dbra d0,lp
	move.l lin,d0
	add.l d0,pmes3
	cmp.b #0,lco
	bne gs2
	subq.w #1,lco2
	bne gs1
	move.l #1,lin
	move.w #400,lco2
	move.b #41,lco
gs2	subq.b #1,lco
	bne gs1
	clr.l lin
gs1	cmp.l #emes3,pmes3
	bne.s pld
	move.l #mes3,pmes3

pld	jsr dummymusic

	*move.w #$777,$ff8240
	rte

dummymusic:
	rts

bs5	move.l $44e.w,a1
	add.l #100*160+157,a1
	moveq #12-1,d5
bs3a	clr.b (a1)
	clr.b 160(a1)
	clr.b 320(a1)
	clr.b 480(a1)
	clr.b 640(a1)
	clr.b 800(a1)
	clr.b 960(a1)
	clr.b 1120(a1)
	add.l #1280,a1
	dbra d5,bs3a
	bra bs6

sep	add.w (a0)+,a1
	clr.b (a1)
	clr.b 160(a1)
	clr.b 320(a1)
	clr.b 480(a1)
	clr.b 640(a1)
	clr.b 800(a1)
	clr.b 960(a1)
	clr.b 1120(a1)
	clr.b 1280(a1)
	bra bk

sep2	add.w (a0)+,a1
	clr.b 1(a1)
	clr.b 161(a1)
	clr.b 321(a1)
	clr.b 481(a1)
	clr.b 641(a1)
	clr.b 801(a1)
	clr.b 961(a1)
	clr.b 1121(a1)
	clr.b 1281(a1)
	bra bk2
	
	EVEN

path	incbin "path.dat"
epath	ds.l 1	
fl	ds.l 1
lin	dc.l 1
scol	ds.w 1
stp	dc.l 20
lco	dc.b 40
lco2	dc.w 400
pmes2	dc.l mes2
cols	ds.w 10
	dc.w $110,$770,$221,$660,$332
	dc.w $550,$443,$440,$554,$330,$665
	dc.w $220,$776,$110,$665,$220,$554,$330
	dc.w $443,$440,$332,$220,$221,$110,$110,$110,$000
	dc.w $777,$777,$777,$777,$777,$777,$777,$777
	dc.w $001,$001,$112,$112,$223,$223,$334,$334,$445
	dc.w $445,$556,$556,$667,$667,$556,$556,$445,$445
	dc.w $332,$332,$221,$221,$110,$111,$111,$121,$121
	dc.w $232,$232,$343,$343,$454,$454,$565,$565,$676
	dc.w $676,$565,$565,$454,$454,$343,$343
col2	ds.w 12
	dc.w $010,$010,$020,$020,$030,$030,$040,$040,$050,$050,$060,$060,$070,$070,$171,$171,$272,$272
	dc.w $770,$700
	ds.w 10
	dc.w $101,$101,$202,$202,$303,$303,$404,$404,$505,$505,$606,$606,$707,$707,$717,$717
	dc.w $727,$727,$737,$737,$747,$747,$757,$757,$767,$767,$757,$757
	dc.w $747,$747,$737,$737,$727,$727,$717,$717,$707,$707,$606,$606,$505,$505,$404,$404,$303,$303,$202,$202,$101,$101
	ds.w 4
f	dc.w 27,"f",0
mes	dcb.b 21," "
	dc.b "  STOP THE CAR          "
	dc.b "THIS IS THE FIRST DEMO SCREEN TO BE COMPLETELY FINISHED FOR"
	dc.b " THE PLEASUREDEMOg  ALL THE CODE AND GRAPHICS ARE BY VILM OF THE CYBERPUNKSggg       YAWN      "
	dc.b "THIS MESSAGE WILL NOW WRAP ggg             "
emes	dcb.b 21," "
mes2	dc.b "                                 "
	dc.b "eee FOLLOWERS OF OBSOLETE TRADESf DOODLING IN ETRUSCANf "
	dc.b "ADDICTS OF DRUGS NOT YET SYNTHESIZEDf BLACK MARKETEERS OF WORLD WAR IIIf "
	dc.b "EXCISORS OF TELEPATHIC SENSITIVITYf OSTEOPATHS OF THE SPIRITf INVESTIGATORS OF INFRACTIONS "
	dc.b "DENOUNCED BY BLAND PARANOID CHESS PLAYERSf SERVERS OF FRAGMENTARY WARRANTS TAKEN DOWN IN HEBEPHRENIC "
	dc.b "SHORTHAND CHARGING UNSPEAKABLE MUTILATIONS OF THE SPIRITf OFFICIALS OF UNCONSTITUTED POLICE STATESf "
	dc.b "BROKERS OF EXQUISITE DREAMS AND NOSTALGIAS TESTED ON THE SENSITIZED CELLS OF JUNK SICKNESS AND BARTERED FOR "
	dc.b "THE RAW MATERIALS OF THE WILLf DRINKERS OF THE HEAVY FLUID SEALED IN TRANSLUCENT AMBER OF DREAMSeee "
emes2	dc.b "            "
mes3	dc.b "                                        "
	dc.b "                GO AWAY                 "
	dc.b "   I HATE SCREENS WITH MANY SCROLLINES  "
	dc.b "I MIGHT AS WELL USE THIS SCROLL TO GREET"
	dc.b "                 HI ZAX                 "
	dc.b "               HI MARTYN                "
	dc.b "               HI STEVEN                "
	dc.b "                HI JOHN                 "
	dc.b "                HI CRAIG                "
	dc.b "                HI EWAN                 "
	dc.b "                HI SALLY                "
	dc.b "                 HI IAN                 "
	dc.b "               HI ANDREW                "
	dc.b "                HI SAINT                "
	dc.b "          HELLO EVERYONE ELSE           "
emes3	dc.b "                                        "

ovbl	ds.l 1
stack	ds.l 1
opal	ds.l 8
oscr	ds.l 1
orez	ds.w 1

oh	ds.l 1
saf	ds.l 1
sv	ds.l 1
pointer	ds.l 1
st	dc.l free+60000
flg	dc.b 40
pmes3	dc.l mes3
	even
pmes	dc.l mes+20
fc	dc.l 7
fc2	dc.l 8
o	dc.l 60
line	dc.l 0
mfpstr	ds.l 10

lpo	dc.l p
bl
p	ds.l 40
	dc.w 34*62,68*62,102*62,136*62,170*62,204*62,238*62,272*62
	dc.w 238*62,204*62,170*62,136*62,102*62,68*62,34*62,0
	dc.w 34*62,68*62,102*62,136*62,170*62,204*62,238*62,272*62
	dc.w 238*62,204*62,170*62,136*62,102*62,68*62,34*62,0
	dc.w 34*62,68*62,102*62,136*62,170*62,204*62,238*62,272*62
	dc.w 238*62,204*62,170*62,136*62,102*62,68*62,34*62,0
	dc.w 34*62,68*62,102*62,136*62,170*62,204*62,238*62,272*62
	dc.w 238*62,204*62,170*62,136*62,102*62,68*62,34*62,0
	ds.l 40
	dc.w 34*62,68*62,102*62,136*62,170*62,204*62,238*62,272*62
	dc.w 238*62,204*62,170*62,136*62,102*62,68*62,34*62,0
	dc.w 34*62,68*62,102*62,136*62,102*62,68*62,34*62,0
	ds.l 25
	dc.w 34*62,68*62,102*62,136*62,170*62,204*62,238*62,272*62
	dc.w 238*62,204*62,170*62,136*62,102*62,68*62,34*62,0
	ds.l 15
	dc.w 34*62,68*62,102*62,136*62,102*62,68*62,34*62,0
	dc.w 34*62,68*62,102*62,136*62,102*62,68*62,34*62,0
	dc.w 34*62,68*62,102*62,136*62,102*62,68*62,34*62,0
ep	ds.l 40
starpt	dc.w 6+(160*10)+5*8,6+(160*10),%0000000001000000,1,%1000000000000000
	dc.w 6+(160*64)+14*8,6+(160*64),%0000000000001000,1,%1000000000000000
	dc.w 6+(160*89)+19*8,6+(160*89),%0000001000000000,2,%0100000000000000
	dc.w 6+(160*108)+1*8,6+(160*108),%1000000000000000,2,%0100000000000000
	dc.w 6+(160*192)+10*8,6+(160*192),%0000000000000100,2,%0100000000000000
	dc.w 6+(160*156)+12*8,6+(160*156),%0000000010000000,3,%0010000000000000
	dc.w 6+(160*132)+1*8,6+(160*132),%0010000000000000,3,%0010000000000000
	*dc.w 6+(160*28)+3*8,6+(160*28),%0000000000000100,3,%0010000000000000
	dc.w 6+(160*179)+2*8,6+(160*179),%0000000100000000,4,%0001000000000000
	dc.w 6+(160*100)+20*8,6+(160*100),%0000000000100000,4,%0001000000000000
	dc.w 6+(160*76)+18*8,6+(160*76),%0001000000000000,4,%0001000000000000
	dc.w 6+(160*142)+11*8,6+(160*142),%0000000001000000,5,%0000100000000000
	dc.w 6+(160*115)+14*8,6+(160*115),%0000100000000000,5,%0000100000000000
	dc.w 6+(160*18)+9*8,6+(160*18),%0000000000000100,5,%0000100000000000
	
	dc.w 6+(160*15)+0*8,6+(160*15),%0000000001000000,1,%1000000000000000
	dc.w 6+(160*74)+3*8,6+(160*74),%0000000000001000,1,%1000000000000000
	dc.w 6+(160*128)+17*8,6+(160*128),%1000000000000000,2,%0100000000000000
	dc.w 6+(160*192)+15*8,6+(160*192),%0000000000000100,2,%0100000000000000
	dc.w 6+(160*116)+12*8,6+(160*116),%0000000010000000,3,%0010000000000000
	dc.w 6+(160*162)+6*8,6+(160*162),%0010000000000000,3,%0010000000000000
	dc.w 6+(160*88)+0*8,6+(160*88),%0000000000000100,3,%0010000000000000
	dc.w 6+(160*180)+4*8,6+(160*180),%0000000100000000,4,%0001000000000000
	dc.w 6+(160*140)+19*8,6+(160*140),%0000000000100000,4,%0001000000000000
	dc.w 6+(160*15)+12*8,6+(160*15),%0001000000000000,4,%0001000000000000
	dc.w 6+(160*4)+1*8,6+(160*4),%0000000001000000,5,%0000100000000000
	dc.w 6+(160*12)+2*8,6+(160*12),%0000100000000000,5,%0000100000000000
	dc.w 6+(160*27)+16*8,6+(160*20),%0000000000000100,5,%0000100000000000
	dc.w 6+(160*14)+12*8,6+(160*14),%0100000000000000,6,%0000010000000000
	dc.w 6+(160*160)+7*8,6+(160*160),%0000000100000000,4,%0001000000000000
	dc.w 6+(160*186)+19*8,6+(160*186),%0100000000000000,4,%0001000000000000
	dc.w 6+(160*70)+2*8,6+(160*70),%0001000000000000,1,%1000000000000000
	dc.w 6+(160*170)+3*8,6+(160*170),%0000000001000000,1,%1000000000000000
	dc.w 6+(160*75)+2*8,6+(160*75),%0000100000000000,5,%0000100000000000
	
	dc.w 6+(172*160)+5*8,6+(160*172),%0000000100000000,4,%0001000000000000
	dc.w 6+(152*160)+16*8,6+(160*152),%0100000000000000,4,%0001000000000000
	dc.w 6+(145*160)+7*8,6+(160*145),%0001000000000000,3,%0010000000000000
	dc.w 6+(111*160)+17*8,6+(160*111),%0000000001000000,6,%0000010000000000
	dc.w 6+(78*160)+8*8,6+(160*78),%0000100000000000,6,%0000010000000000
	
	EVEN
font2	include "f2.s"
; 	EVEN
; music	incbin "bmxsim2.msx"
; emusic
	EVEN
path2	incbin "path.pth"
epth2	incbin "path.pth"
ppth	dc.l epth2
	EVEN
font3	incbin "8x8fnt.dat"
	EVEN
blks	incbin "blks.dat"
free
font	ds.b 64
	incbin "helixfnt.dat"
	ds.w 64
logo	incbin "logo2.dat"

	EVEN
bufr	RSRESET

