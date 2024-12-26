screen	equ $78000

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

	lea bufr,a1
	move.l a2,a2
	adda.l #bufr_end,a2
cls	clr.l (a1)+
	clr.l (a1)+
	cmp.l a1,a2
	bgt.s cls

	; Save the screen address and resolution
	lea bufr,a6
	movem.l $ffff8240.w,d0-d7
	movem.l d0-d7,opal(a6)
	move.l $44e.w,o44e(a6)
	move.b $ffff8260.w,d0
	andi.w #%11,d0
	move.w d0,orez(a6)

	clr.w -(sp)			; Low resolution
	move.l #screen,-(sp)
	move.l #screen,-(sp)
	move.w #5,-(sp)
	trap #14
	add.l #12,sp
	
	move #1,-(sp)
	move #0,-(Sp)
	move #21,-(sp)
	trap #14
	addq.l #6,sp

	move.l screen1,a1
	move.l screen2,a2
	move.l #4000,d0
	moveq #0,d1
cls2	move.l d1,(a1)+
	move.l d1,(a1)+
	move.l d1,(a2)+
	move.l d1,(a2)+
	dbra d0,cls2

	bsr prepth
	bsr prelog
	bsr preah
	bsr prering
	bsr presh
	bsr doubcol
	bsr conrt
	bsr prefnt

	movem.l pallete,d0-d7
	movem.l d0-d7,$ffff8240.w

	; move.w #9,d7
	; bsr start_music

	bsr hblon
	
wait_key
	move.b key,d7
	bmi.s wait_key

	cmp.b #$39,d7
	beq.s gone
	
	sub.b #$3b,d7
	bmi.s wait_key
	cmp.b #9,d7
	bgt.s wait_key
	
	; bsr start_music

	bra.s wait_key

gone	bsr hbloff
	
	move.b #7,$ffff8800.w
	move.b #%11111111,$ffff8802.w

	lea bufr,a6
	move.w orez(a6),-(sp)	; Restore the original screen address and resolution
	move.l o44e(a6),-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	movem.l opal(a6),d0-d7
	movem.l d0-d7,$ffff8240.w

	move.l stack,-(sp)
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

vbl	movem.l d0-d7/a0-a6,-(sp)

	clr.b $fffffa1b.w
	move.b #1,$fffffa21.w
	move.b #8,$fffffa1b.w
	lea bufr+scrcol,a6
	lea $ffff8240.w,a5
	
	move.l screen1,d0
	move.l screen2,screen1
	move.l d0,screen2
	move.l d0,$44e
	lsr.l #8,d0
	move.b d0,$ffff8203.w
	lsr.w #8,d0
	move.b d0,$ffff8201.w
	
	bsr kills
	bsr shadis
	bsr wavey
	bsr vols
	bsr bouns
	bsr barz

	; Music playback VBL routine
	; tst.w muson
	; bmi.s nosum

; vblump	jsr zoolk+8

nosum	movem.l (sp)+,d0-d7/a0-a6
*	move.w #$777,$ffff8240.w
	rte

col	move.w (a6)+,(a5)
	move.w (a6),$2(a5)
	move.w (a6),$6(a5)
	move.w (a6),$a(a5)
	move.w (a6),$e(a5)
	move.w (a6),$12(a5)
	move.w (a6),$16(a5)
	move.w (a6),$1a(a5)
	move.w (a6)+,$1e(a5)
	move.w (a6)+,$4(a5)
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

doubcol	lea col2,a0
	lea bufr+colset,a1
expnd	move.w (a0)+,d0
	move.w d0,(a1)+
	ori.w #$888,d0
	move.w d0,(a1)+
	cmp.l #ecols,a0
	blt.s expnd

	lea secs,a0
	lea bufr+sec+4,a1
exd	move.w (a0)+,d0
	move.w d0,d1
	ori.w #$888,d1
	move.w d0,-4(a1)
	move.w d0,(a1)+
	move.w d0,(a1)+
	move.w d1,(a1)+
	move.w d0,(a1)+
	move.w d1,(a1)+
	move.w d1,(a1)+
	move.w d1,(a1)+
	cmp.l #esec,a0
	blt.s exd

	lea mets,a0
	lea bufr+metals+4,a1
exd2	move.w (a0)+,d0
	move.w d0,-4(a1)
	move.w d0,(a1)+
	move.w d0,(a1)+
	move.w d0,(a1)+
	move.w d0,(a1)+
	move.w d0,(a1)+
	cmp.l #emet,a0
	blt.s exd2

	lea bufr+colset,a0
	lea bufr+sec,a1
	lea bufr+metals,a2
	lea bufr+scrcol,a3
	move.w #200-1,d7
makrt	move.w (a0)+,(a3)+
	move.w (a1)+,(a3)+
	move.w (a2)+,(a3)+
	dbra d7,makrt
	rts

; start_music:
; 	movem.l d0/a0-a4,-(sp)
; 	ext.w d7

; 	lea mtable,a0			; Table of music specs
; 	lsl.w #4,d7
; 	adda.w d7,a0

; 	cmpa.l #emtable,a0
; 	bpl.s .nomus

; 	move.w #-1,muson

; 	lea $ffff8800.w,a1		; Silence the sound chip
; 	moveq #0,d0
; 	move.b #8,(a1)
; 	move.b d0,2(a1)
; 	move.b #9,(a1)
; 	move.b d0,2(a1)
; 	move.b #10,(a1)
; 	move.b d0,2(a1)

; 	move.l (a0),a4			; Start of music file
; 	move.l 4(a0),a1			; VBL routine
; 	move.l a1,vblump+2

; 	move.l 12(a0),d0

; 	move.l (a0),a1			; Start of music file

; 	cmp.w #"**",8(a1)
; 	bne.s .relocatable

; 	move.l 8(a0),a2			; End of music file
; 	move.l 10(a1),a3		; Required memory address
; 	lea 4(a3),a4
; 	move.l a4,vblump+2		; Update the VBL routine
; 	move.l a3,a4			; Start of music file

; .copymusic
; 	move.l (a1)+,(a3)+
; 	cmp.l a2,a1
; 	blt.s .copymusic

; .relocatable

; 	jsr (a4)

; 	clr.w muson

; 	move.b #-1,key

; .nomus	movem.l (sp)+,d0/a0-a4
; 	rts
		

prefnt	lea fon,a0
	lea bufr+font,a1
	moveq #45-1,d7
letrs	lea bufr+temp,a2
	moveq #32-1,d6
copfst	clr.b (a2)+
	move.b (a0)+,(a2)+
	move.b (a0)+,(a2)+
	move.b (a0)+,(a2)+
	move.b (a0)+,(a2)+
	clr.b (a2)+
	dbra d6,copfst

	bsr extmp

	lea bufr+temp,a2

	moveq #12,d5
	moveq #32-1,d6
shfts	movem.w (a2)+,d0-d2
	move.w d1,d3
	lsr.w d5,d3
	lsl.w #4,d0
	add.w d3,d0
	move.w d2,d3
	lsr.w d5,d3
	lsl.w #4,d1
	add.w d3,d1
	lsl.w #4,d2
	movem.w d0-d2,-6(a2)
	dbra d6,shfts

	bsr extmp

	dbra d7,letrs
	
	bsr premes

	rts

extmp	lea (a1),a2
	lea bufr+temp,a3
	moveq #32-1,d6
fuck	move.b (a3)+,(a1)
	move.b (a3)+,32(a1)
	move.b (a3)+,64(a1)
	move.b (a3)+,96(a1)
	move.b (a3)+,128(a1)
	addq.l #1,a3
	addq.l #1,a1
	dbra d6,fuck
	lea 5*32(a2),a1
	rts


wavey	move.l $44e,d1
	addq.l #2,pht
	cmp.l #eht,pht
	blt.s nobby
	move.l #hite,pht
nobby	move.l pht,a1

	move.l pmes,d0
	move.l pmes2,pmes
	move.l d0,pmes2
	
	addq.l #4,pmes
chem	cmp.l #0,pmes
	blt.s frankie
	sub.l #(emes-mesij)*20,pmes
	sub.l #(emes-mesij)*20,pmes2
frankie	move.l pmes,a0	

	lea offl,a3
	clr.b d0
	moveq #40-1,d7
colums	move.l (a0)+,a2
	move.l d1,a4
	add.w (a3)+,a4
	add.w (a1)+,a4
	move.b d0,-160(a4)
	move.b d0,(a4)
	move.b d0,160(a4)
	move.b d0,320(a4)
	move.b (a2)+,480(a4)
	move.b (a2)+,640(a4)
	move.b (a2)+,800(a4)
	move.b (a2)+,960(a4)
	move.b (a2)+,1120(a4)
	move.b (a2)+,1280(a4)
	move.b (a2)+,1440(a4)
	move.b (a2)+,1600(a4)
	move.b (a2)+,1760(a4)
	move.b (a2)+,1920(a4)
	move.b (a2)+,2080(a4)
	move.b (a2)+,2240(a4)
	move.b (a2)+,2400(a4)
	move.b (a2)+,2560(a4)
	move.b (a2)+,2720(a4)
	move.b (a2)+,2880(a4)
	move.b (a2)+,3040(a4)
	move.b (a2)+,3200(a4)
	move.b (a2)+,3360(a4)
	move.b (a2)+,3520(a4)
	move.b (a2)+,3680(a4)
	move.b (a2)+,3840(a4)
	move.b (a2)+,4000(a4)
	move.b (a2)+,4160(a4)
	move.b (a2)+,4320(a4)
	move.b (a2)+,4480(a4)
	move.b (a2)+,4640(a4)
	move.b (a2)+,4800(a4)
	move.b (a2)+,4960(a4)
	move.b (a2)+,5120(a4)
	move.b d0,5280(a4)
	move.b d0,5440(a4)
	move.b d0,5600(a4)
	move.b d0,5760(a4)
	dbra d7,colums

	rts

premes	lea mesij,a0
	lea bufr+mes,a1
	lea bufr+mes2,a5
	lea emes,a2
	
	lea bufr+font,a3
	move.w #(emes-mesij)-1,d7
char	clr.l d0
	move.b (a0)+,d0
	cmp.b #32,d0
	bne.s nosp
	move.b #"A"-1,d0
nosp	sub.b #"A"-1,d0
	mulu #5*64,d0
	lea (a3,d0.w),a4
	addq.l #1,a4
	move.l a4,(a1)+
	add.l #32,a4
	move.l a4,(a1)+
	add.l #32,a4
	move.l a4,(a1)+
	add.l #32,a4
	move.l a4,(a1)+
	add.l #32,a4
	move.l a4,(a1)+

	add.l #32,a4
	move.l a4,(a5)+
	add.l #32,a4
	move.l a4,(a5)+
	add.l #32,a4
	move.l a4,(a5)+
	add.l #32,a4
	move.l a4,(a5)+
	add.l #32,a4
	move.l a4,(a5)+

	cmp.l a2,a0
	blt.s char
	
	move.l a1,chem+2
	
	moveq #50-1,d7
blan	move.l #bufr+font,(a1)+
	move.l #bufr+font,(a5)+
	dbra d7,blan
	rts
	

kills	lea bufr+rlist+4,a0

	move.l pring,a3

	move.l $44e,a4
	addq.l #4,a4
	clr.l d0
	moveq #16-1,d7
kill30	move.w (a3)+,d1
	lea (a4,d1.w),a1
	move.w (a3)+,d1
	move.l (a0,d1.w),a2
	jsr (a2)
	
	dbra d7,kill30

	move.l $44e,a4
	add.l #116,a4

	move.l pring2,a3

	clr.l d0
	moveq #16-1,d7
kill20	move.w (a3)+,d1
	lea (a4,d1.w),a1
	move.w (a3)+,d1
	move.l (a0,d1.w),a2
	jsr (a2)
	
	dbra d7,kill20

	move.l $44e,a4
	add.l #112*160+60,a4

	move.l pring3,a3

	clr.l d0
	moveq #16-1,d7
kill10	move.w (a3)+,d1
	lea (a4,d1.w),a1
	move.w (a3)+,d1
	move.l (a0,d1.w),a2
	jsr (a2)
	
	dbra d7,kill10
	
	rts

vols	add.w #4*16,cring
	cmp.w #8*4*16,cring
	blt.s stsp
	clr.w cring

stsp	clr.w d0
	move.b #8,$ffff8800.w
	move.b $ffff8800.w,d0
	andi.w #%1111,d0
	lsl.w #8,d0
	lsl.w #1,d0

	lea bufr+rings,a3
	add.w cring,a3
	lea (a3,d0.w),a3
	move.l oring,pring
	move.l a3,oring
	
	move.l $44e,a4
	addq.l #4,a4

	lea bufr+rlist,a0
	moveq #16-1,d7
plot30	move.w (a3)+,d1
	lea (a4,d1.w),a1
	move.w (a3)+,d1
	move.l (a0,d1.w),a2
	jsr (a2)
	
	dbra d7,plot30
	
	clr.w d0
	move.b #9,$ffff8800.w
	move.b $ffff8800.w,d0
	andi.w #%1111,d0
	lsl.w #8,d0
	lsl.w #1,d0

	move.l $44e,a4
	add.l #116,a4

	lea bufr+rings,a3
	add.w cring,a3
	lea (a3,d0.w),a3
	move.l oring2,pring2
	move.l a3,oring2
	
	lea bufr+rlist,a0
	moveq #16-1,d7
plot20	move.w (a3)+,d1
	lea (a4,d1.w),a1
	move.w (a3)+,d1
	move.l (a0,d1.w),a2
	jsr (a2)
	
	dbra d7,plot20

	clr.w d0
	move.b #10,$ffff8800.w
	move.b $ffff8800.w,d0
	andi.w #%1111,d0
	lsl.w #8,d0
	lsl.w #1,d0

	move.l $44e,a4
	add.l #112*160+60,a4

	lea bufr+rings,a3
	add.w cring,a3
	lea (a3,d0.w),a3
	move.l oring3,pring3
	move.l a3,oring3
	
	lea bufr+rlist,a0
	moveq #16-1,d7
plot10	move.w (a3)+,d1
	lea (a4,d1.w),a1
	move.w (a3)+,d1
	move.l (a0,d1.w),a2
	jsr (a2)
	
	dbra d7,plot10

	rts

presh	lea ball,a5
	lea bufr+code,a2
	lea bufr+udraw,a4
	lea bufr+rlist,a6

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
	lea bufr+balls,a1
	moveq #8-1,d7
shif_l	clr.l d0
	move.w (a0)+,d0
	lsl.l d6,d0
	clr.l d1
	move.w (a0)+,d1
	lsl.l d6,d1
	move.w d0,4(a1)
	move.w d1,6(a1)
	swap d0
	swap d1
	move.w d0,(a1)
	move.w d1,2(a1)
	addq.l #8,a1
	dbra d7,shif_l
	movem.l (sp)+,d0-d7/a0-a6
	rts


maskmak	movem.l d0-d7/a0-a6,-(sp)
	lea bufr+balls,a0
	lea bufr+masp,a1
loopmsk	movem.w (a0)+,d0-d1
	or.w d1,d0
	not.w d0
	move.w d0,(a1)+
	move.w d0,(a1)+
	cmp.l #bufr+masp,a0
	ble.s loopmsk
	movem.l (sp)+,d0-d7/a0-a6
	rts

codegen	movem.l d0-d7/a0-a1/a3/a5-a6,-(sp)
	lea bufr+balls,a0
	lea bufr+masp,a1
	moveq #8,d2
	move.l #152,d3
	move.l #160,d0
	
	moveq #8,d2
	move.w #152,d3
	move.w #160,d0
	
	move.l (a1)+,d1
	cmp.l #-1,d1
	beq.s nfwrd
 	move.w #$291,(a2)+
 	move.l d1,(a2)+
 	move.w #$91,(a2)+
 	move.l (a0),(a2)+
 	move.w #$2280,(a4)+

nfwrd	move.l (a1)+,d1
	cmp.l #-1,d1
	beq.s nswrd
 	move.w #$2a9,(a2)+
 	move.l d1,(a2)+
 	move.w #8,(a2)+
	move.w #$a9,(a2)+
 	move.l 4(a0),(a2)+
 	move.w #8,(a2)+
	move.w #$2340,(a4)+
	move.w #8,(a4)+

nswrd	addq.l #8,a0
	moveq #7*2-1,d6
lincd	move.l (a1)+,d1
	beq.s solid
	cmp.l #-1,d1
	beq.s common

 	move.w #$2a9,(a2)+
 	move.l d1,(a2)+
 	move.w d0,(a2)+
	
	move.w #$a9,(a2)+
 	move.l (a0),(a2)+
 	move.w d0,(a2)+

	move.w #$2340,(a4)+
	move.w d0,(a4)+
	
common	addq.l #4,a0
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
	move.w #$2340,(a4)+
	move.w d0,(a4)+
	bra.s common


prering	lea ring(pc),a0
	lea bufr+rings,a1
	lea erng(pc),a2
xy_os	clr.l d0
	clr.l d1
	move.b (a0)+,d0
	move.b (a0)+,d1
	move.w d0,d2
	andi.w #%1111,d2
	lsl.w #3,d2
	mulu #160,d1
	lsr.w #4,d0
	lsl.w #3,d0
	add.w d0,d1
	move.w d1,(a1)+
	move.w d2,(a1)+
	cmp.l a2,a0
	blt.s xy_os
	rts
	

bouns	move.l $44e,a1
	addq.l #2,a1
	lea lett,a2
	addq.l #2,pah
piss	cmp.l #0,pah
	blt.s noba
	move.l #bufr+andh,pah
noba	move.l pah,a0

	lea offi,a3
	clr.w d0
	moveq #8-1,d7
cola	lea (a1),a4
	add.w (a3)+,a4
	add.w (a0)+,a4
	move.w d0,-160(a4)
	move.w d0,-152(a4)
	move.w d0,(a4)
	move.w d0,8(a4)
	move.w d0,160(a4)
	move.w d0,168(a4)
	move.w d0,320(a4)
	move.w d0,328(a4)
	move.w (a2)+,480(a4)
	move.w (a2)+,488(a4)
	move.w (a2)+,640(a4)
	move.w (a2)+,648(a4)
	move.w (a2)+,800(a4)
	move.w (a2)+,808(a4)
	move.w (a2)+,960(a4)
	move.w (a2)+,968(a4)
	move.w (a2)+,1120(a4)
	move.w (a2)+,1128(a4)
	move.w (a2)+,1280(a4)
	move.w (a2)+,1288(a4)
	move.w (a2)+,1440(a4)
	move.w (a2)+,1448(a4)
	move.w (a2)+,1600(a4)
	move.w (a2)+,1608(a4)
	move.w (a2)+,1760(a4)
	move.w (a2)+,1768(a4)
	move.w (a2)+,1920(a4)
	move.w (a2)+,1928(a4)
	move.w (a2)+,2080(a4)
	move.w (a2)+,2088(a4)
	move.w (a2)+,2240(a4)
	move.w (a2)+,2248(a4)
	move.w (a2)+,2400(a4)
	move.w (a2)+,2408(a4)
	move.w (a2)+,2560(a4)
	move.w (a2)+,2568(a4)
	move.w (a2)+,2720(a4)
	move.w (a2)+,2728(a4)
	move.w (a2)+,2880(a4)
	move.w (a2)+,2888(a4)
	move.w (a2)+,3040(a4)
	move.w (a2)+,3048(a4)
	move.w (a2)+,3200(a4)
	move.w (a2)+,3208(a4)
	move.w (a2)+,3360(a4)
	move.w (a2)+,3368(a4)
	move.w (a2)+,3520(a4)
	move.w (a2)+,3528(a4)
	move.w (a2)+,3680(a4)
	move.w (a2)+,3688(a4)
	move.w (a2)+,3840(a4)
	move.w (a2)+,3848(a4)
	move.w d0,4000(a4)
	move.w d0,4008(a4)
	move.w d0,4160(a4)
	move.w d0,4168(a4)
	move.w d0,4320(a4)
	move.w d0,4328(a4)
	move.w d0,4480(a4)
	move.w d0,4488(a4)
	add.w #16,a0
	dbra d7,cola

	rts

preah	lea bufr+andh,a1
	moveq #2-1,d7
copies	lea aht(pc),a0
	lea eaht(pc),a2
tms160	clr.w d0
	move.b (a0)+,d0
	mulu #160,d0
	move.w d0,(a1)+
	cmp.l a2,a0
	blt.s tms160
bog	move.l a1,piss+2
	move.w #$4e71,bog
	move.w #$4e71,bog+2
	move.w #$4e71,bog+4
	dbra d7,copies
	rts


shadis	move.l $44e,a4
	addq.l #4,a4
	lea bufr+shake,a2
	addq.l #6,pspth
	move.l epth,chk+2
chk	cmp.l #0,pspth
	blt.s stdis
	move.l #bufr+spth,pspth

stdis	move.l pspth,a3
	move.w (a3)+,d0
	lea (a4,d0.w),a4

	move.w (a3)+,d0
	lea (a4,d0.w),a1
	move.w (a3)+,d0
	lea (a2,d0.w),a0
	clr.l d1
	move.l d1,(a1)
	move.l d1,8(a1)
	move.l d1,16(a1)
	move.l d1,24(a1)
	move.l d1,32(a1)
	move.l d1,40(a1)
	move.l d1,48(a1)
	move.l d1,56(a1)
	move.l d1,64(a1)
	lea 160(a4),a4
	addq.l #2,a3

	move.w (a3)+,d0
	lea (a4,d0.w),a1
	move.w (a3)+,d0
	lea (a2,d0.w),a0
	clr.l d1
	move.l d1,(a1)
	move.l d1,8(a1)
	move.l d1,16(a1)
	move.l d1,24(a1)
	move.l d1,32(a1)
	move.l d1,40(a1)
	move.l d1,48(a1)
	move.l d1,56(a1)
	move.l d1,64(a1)
	lea 160(a4),a4
	addq.l #2,a3

	move.w (a3)+,d0
	lea (a4,d0.w),a1
	move.w (a3)+,d0
	lea (a2,d0.w),a0
	clr.l d1
	move.l d1,(a1)
	move.l d1,8(a1)
	move.l d1,16(a1)
	move.l d1,24(a1)
	move.l d1,32(a1)
	move.l d1,40(a1)
	move.l d1,48(a1)
	move.l d1,56(a1)
	move.l d1,64(a1)
	lea 160(a4),a4
	addq.l #2,a3

	move.w (a3)+,d0
	lea (a4,d0.w),a1
	move.w (a3)+,d0
	lea (a2,d0.w),a0
	clr.l d1
	move.l d1,(a1)
	move.l d1,8(a1)
	move.l d1,16(a1)
	move.l d1,24(a1)
	move.l d1,32(a1)
	move.l d1,40(a1)
	move.l d1,48(a1)
	move.l d1,56(a1)
	move.l d1,64(a1)
	lea 160(a4),a4
	addq.l #2,a3

	moveq #48-1,d7
sh_l	move.w (a3)+,d0
	lea (a4,d0.w),a1
	move.w (a3)+,d0
	lea (a2,d0.w),a0
	move.l (a0)+,(a1)
	move.l (a0)+,8(a1)
	move.l (a0)+,16(a1)
	move.l (a0)+,24(a1)
	move.l (a0)+,32(a1)
	move.l (a0)+,40(a1)
	move.l (a0)+,48(a1)
	move.l (a0)+,56(a1)
	move.l (a0)+,64(a1)
	lea 36(a2),a2
	lea 160(a4),a4
	addq.l #2,a3
	dbra d7,sh_l

	move.w (a3)+,d0
	lea (a4,d0.w),a1
	move.w (a3)+,d0
	lea (a2,d0.w),a0
	clr.l d1
	move.l d1,(a1)
	move.l d1,8(a1)
	move.l d1,16(a1)
	move.l d1,24(a1)
	move.l d1,32(a1)
	move.l d1,40(a1)
	move.l d1,48(a1)
	move.l d1,56(a1)
	move.l d1,64(a1)
	lea 160(a4),a4
	addq.l #2,a3

	move.w (a3)+,d0
	lea (a4,d0.w),a1
	move.w (a3)+,d0
	lea (a2,d0.w),a0
	clr.l d1
	move.l d1,(a1)
	move.l d1,8(a1)
	move.l d1,16(a1)
	move.l d1,24(a1)
	move.l d1,32(a1)
	move.l d1,40(a1)
	move.l d1,48(a1)
	move.l d1,56(a1)
	move.l d1,64(a1)
	lea 160(a4),a4
	addq.l #2,a3

	rts


prelog	lea shak,a0
	lea bufr+shake,a1
	
	moveq #48-1,d7
first	clr.l (a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	dbra d7,first
	
	lea bufr+shake,a0
	lea cdown,a6
	move.l #16*48,(a6)
log_sl	move.l 32(a0),d0
	lsl.w #1,d0
	move.l d0,32(a1)
	movem.l (a0),d0-d7
	roxl.w #1,d7
	roxl.w #1,d6
	roxl.w #1,d5
	roxl.w #1,d4
	roxl.w #1,d3
	roxl.w #1,d2
	roxl.w #1,d1
	roxl.w #1,d0
	movem.l d0-d7,(a1)
	move.w 32(a0),d0
	lsl.w #1,d0
	move.w d0,32(a1)
	movem.l -2(a0),d0-d7
	roxl.w #1,d7
	roxl.w #1,d6
	roxl.w #1,d5
	roxl.w #1,d4
	roxl.w #1,d3
	roxl.w #1,d2
	roxl.w #1,d1
	roxl.w #1,d0
	move.w d0,(a1)
	move.w d1,4(a1)
	move.w d2,8(a1)
	move.w d3,12(a1)
	move.w d4,16(a1)
	move.w d5,20(a1)
	move.w d6,24(a1)
	move.w d7,28(a1)
	lea 36(a0),a0
	lea 36(a1),a1
	subq.l #1,(a6)
	bne.s log_sl
	rts
	
prepth	lea path,a0
	lea bufr+spth,a1
	lea epth,a2
bloks	move.w (a0)+,d7
	bra.s pwyp
iter	lea slist,a3
	move.w (a0),d6
	lsl.w #2,d6
	move.l 4(a3,d6.w),a4
	move.l (a3,d6.w),a3
coord	clr.w d0
	clr.w d1
	move.b (a3)+,d0
	move.b (a3)+,d1
	move.w d0,d2
	andi.w #%1111,d2
	moveq #15,d3
	sub.w d2,d3
	mulu #1728,d3
	lsr.w #4,d0
	lsl.w #3,d0
	mulu #160,d1
	move.w d1,(a1)+
	move.w d0,(a1)+
	move.w d3,(a1)+
eetr	cmp.l a4,a3
	blt.s coord
pwyp	dbra d7,iter
	addq.l #2,a0
	cmp.l a2,a0
	blt.s bloks

	move.l a1,epth
	lea bufr+spth,a0
	moveq #100-1,d7
wrap	move.l (a0)+,(a1)+
	dbra d7,wrap

	rts

conrt	lea bufr+const,a0
	move.l #$33580000,d0
	move.w #200-1,d7
makeit	move.l d0,(a0)+
	addq.l #6,d0
	dbra d7,makeit
	move.w #$4e75,(a0)+
	rts
	
	

barz	lea bufr+colset,a0
	lea bufr+scrcol,a1
	jsr bufr+const
	
	lea bars,a0
	lea bufr+scrcol,a1
	
	addq.l #2,pbar
	cmp.l #ebar,pbar
	blt.s jimi
	move.l #bpth,pbar
jimi	move.l pbar,a2

	moveq #11-1,d7
barcnt	move.w (a2)+,d0
	lea (a1,d0.w),a3
	move.w (a0)+,(a3)
	move.w (a0)+,6(a3)
	move.w (a0)+,12(a3)
	move.w (a0)+,18(a3)
	move.w (a0)+,24(a3)
	move.w (a0)+,30(a3)
	move.w (a0)+,36(a3)
	addq.l #8,a2
	dbra d7,barcnt

	rts


bars	dc.w $000,$001,$112,$223,$112,$001,$000
	dc.w $000,$111,$222,$333,$222,$111,$000
	dc.w $010,$121,$232,$343,$232,$121,$010

	dc.w $111,$222,$333,$444,$333,$222,$111
	dc.w $100,$211,$322,$433,$322,$211,$100

	dc.w $222,$333,$444,$555,$444,$333,$222
	dc.w $212,$323,$434,$545,$434,$323,$212

	dc.w $333,$444,$555,$666,$555,$444,$333
	dc.w $221,$332,$443,$554,$443,$332,$221

	dc.w $444,$555,$666,$777,$666,$555,$444
	dc.w $344,$455,$566,$677,$566,$455,$344

	EVEN
bpth	incbin "bars.pth"
ebar	incbin "bars.pth"
pbar	dc.l bpth	

cdown	ds.l 1
shak	incbin "shake.dat"

pspth	dc.l bufr+spth
path	dc.w 250,0,8,1,5,2,5,3,5,4,3,2,1,6,4,5,3,1
epth

slist	dc.l shk1,shk2,shk3,shk4,shk5,shk6,shk7,shk8

	EVEN
shk1	dc.b 90,30
shk2	incbin "vsine.pth"
shk3	incbin "vhsine.pth"
shk4	incbin "vhsine2.pth"
shk5	incbin "hsine2.pth"
shk6	incbin "dhsine.pth"
shk7	incbin "hsine.pth"
shk8

pah	dc.l bufr+andh
aht	incbin "andy.pth"
eaht

	EVEN
lett	incbin "androids.dat"

offi	dc.w 16,32,48,64,80,96,112,128


cring	ds.w 1
pring	dc.l bufr+rings
pring2	dc.l bufr+rings
pring3	dc.l bufr+rings
oring	dc.l bufr+rings
oring2	dc.l bufr+rings
oring3	dc.l bufr+rings
ring	incbin "rings2.dat"
erng
	EVEN
ball	incbin "ball.dat"

ortw	ds.w 16

pht	dc.l hite
hite	incbin "wavey2.pth"
eht	incbin "wavey2.pth"

fon	ds.l 32
	incbin "sim1.fnt"

johnny	ds.b 1
pmes	dc.l bufr+mes2
pmes2	dc.l bufr+mes

mesij	include "mesij.msg"
emes	dc.b "         "
eemes

charset	dc.b "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?'""() "

offl	dc.w 0,1,8,9,16,17,24,25,32,33,40,41,48,49,56,57,64,65,72,73,80,81
	dc.w 88,89,96,97,104,105,112,113,120,121,128,129,136,137,144,145,152,153

col2	dc.w $100,$200,$300
	dc.w $400,$500,$600,$700
	dc.w $100,$200,$300
	dc.w $400,$500,$600,$700
	dc.w $710,$720
	dc.w $100,$200,$300
	dc.w $400,$500,$600,$700
	dc.w $710,$720,$730,$740
	dc.w $100,$200,$300
	dc.w $400,$500,$600,$700
	dc.w $710,$720,$730,$740
	dc.w $750,$760,$770
	dc.w $771,$772,$773,$774,$775
	dc.w $776,$777,$776,$775,$773,$772,$771,$770
	dc.w $760,$750,$740,$730
	dc.w $720,$710,$700,$600
	dc.w $500,$400,$300,$200
	dc.w $100
	dc.w $740,$730,$720,$710,$700,$600
	dc.w $500,$400,$300,$200
	dc.w $100,$720,$710,$700,$600
	dc.w $500,$400,$300,$200
	dc.w $100,$700,$600
	dc.w $500,$400,$300,$200,$100,$500,$400,$300,$200,$100,$000
ecols

secs	dc.w $000,$100,$210,$320,$430,$540,$650,$760,$761,$752,$743,$734,$725,$716,$707,$617,$527,$437,$347,$257,$167,$067,$056,$045,$034,$023,$012,$001
esec

mets	dc.w $001,$112,$223,$334,$445,$556,$667,$556,$445,$334,$223,$112,$001,$010,$121,$232,$343,$454,$565,$676,$565,$454,$343,$232,$121,$010,$100,$211,$322,$433,$544,$655,$766,$655,$544,$433,$322,$211,$100
emet


pallete	dc.w $000,$000,$007,$000,$020,$000,$020,$000,$050,$000,$050,$000,$070,$000,$070,$000

screen1	dc.l $76000
screen2	dc.l $64000

ovbl	ds.l 1
stack	ds.l 1
mfpstr	ds.l 10
muson	ds.w 1

; mtable	dc.l ace2,ace2+4,emusix,1
; 	dc.l iball,iball+4,zoolk,1
; 	dc.l sabot2,sabot2+4,iball,1
; 	dc.l monty2,monty2+4,sabot2,0
; 	dc.l ik_mus,ik_mus+4,monty2,0
; 	dc.l ik_ii,ik_ii+4,ik_mus,0
; 	dc.l thrust,thrust+4,ik_ii,1
; 	dc.l monty2,monty2+4,sabot2,6
; 	dc.l monty2,monty2+4,sabot2,9
; 	dc.l zoolk,zoolk+8,ace2,1
; emtable

; 	EVEN
; thrust	incbin "thrust.msx"
; 	EVEN
; ik_ii	incbin "ikII.msx"
; 	EVEN
; ik_mus	incbin "ik.msx"
; 	EVEN
; monty2	incbin "monty2.msx"
; 	EVEN
; sabot2	incbin "labello.msx"	;"sabotr2.snd"
; 	EVEN
; iball	incbin "iball.msx"
; 	EVEN
; zoolk	incbin "zoolook.snd"
; 	EVEN
; ace2	incbin "ace2.msx"
; emusix

	EVEN
bufr	RSRESET
o44e	rs.l 1
orez	rs.l 1
opal	rs.l 8


andh	rs.w (eaht-aht)*2
rlist	rs.l 8*2*16
balls	rs.w 64/2
masp	rs.w 100/2
code	rs.w 3000/2
udraw	rs.w 1000/2
const	rs.l 210
scrcol	rs.w 600
colset	rs.w 300
metals	rs.w 300
sec	rs.w 300
temp	rs.w 3*32
font	rs.b 32*5*45*2
mes2	rs.l (eemes-mesij)*5
mes	rs.l (eemes-mesij)*5
	rs.w 200
rings	rs.w (erng-ring)
	rs.w 200
shake	rs.w 30000/2
spth	rs.w 50000/2
bufr_end rs.w 1
