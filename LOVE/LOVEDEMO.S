; The Love Demo
; Written by Vilm of The Cyberpunks in 1991
;
; Commented and updated in 2024 by Zax, to work with the new bootstrap or to run as a standalone demo.
; Music has been removed for the Github version, and the playback commented out.

screenbase 	equ $76000
screen_size 	equ 32000
line_bytes	equ 160

stack_buffer	equ $1000

quote_offset	equ line_bytes*71+24
quote_lines	equ 29
quote_width	equ 14

fade_frames	equ 8
hold_frames	equ 200

path_overflow	equ 40

font_chars	equ 32
font_height	equ 32
font_width	equ 12		; In bytes
font_char_bytes	equ font_width*font_height
font_shifts	equ 16
font_shift_bytes equ font_shifts*font_char_bytes
ascii_space	equ 32
num_chars	equ 27
end_char	equ "A"+num_chars	; After the alphabet
space_char 	equ end_char-1

wavy_chars	equ 7				; Number of characters in the message buffer for the wavy scroller
mesbuf_w	equ wavy_chars*4		; Number of bytes in one line of the message buffer
wavy_lines	equ 32				; Number of lines in the wavy scroller

group_size		equ 17			; Number of characters in the spinner
group_member_size	equ 64*12		; Number of bytes in one rotated character of the spinner
group_buffer_size	equ group_member_size*group_size

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
	move.l d0,stack

	movem.l $ffff8240.w,d0-d7
	movem.l d0-d7,opal

	move.l $44e.w,oscr
	move.b $ffff8260.w,d0
	andi.w #%11,d0
	move.w d0,orez

	; Low resolution
	clr.w -(sp)
	move.l #screenbase,-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	add.l #12,sp

	; Set up the stack
	lea font+stack_top,sp

	bsr show_quote
	movem.l mfpstr,d0-d7
	movem.l d0-d7,$ffff8240.w

	bsr preshift

	bsr generate
	clr.l d7

; 	moveq #3,d0
; musj	jsr corange

	move.l $44e,a0
	clr.l d0
	lea screen_size(a0),a1
cls	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	cmp.l a1,a0
	blt.s cls

	move.w #$227,$ffff8244.w
	move.w #$227,$ffff8246.w
	move.w #$227,$ffff8254.w
	move.w #$114,$ffff8248.w
	move.w #$114,$ffff824a.w
	move.w #$114,$ffff8258.w
	move.w #$007,$ffff8250.w
	move.w #$777,$ffff8252.w
	
	move.w #$304,$ffff8242.w
	move.w #$777,$ffff825e.w

	bsr hblon
	
waitkey:
	move.b $fffffc02.w,d0
	bmi.s waitkey
	
	cmp.b #$39,d0
	beq exit
	
	cmp.b #$3b,d0
	blt.s waitkey
	
	; sub.b #$3b,d0
	; andi.l #$ff,d0
	; lsl.w #4,d0
	; lea basher(pc),a0
	; lea ebash(pc),a1
	; adda.w d0,a0
	; cmpa.l a1,a0
	; bpl.s waitkey

	; move.l #nomusic,vbl_music+2	

	; move.l (a0),a1
	; move.l 4(a0),d0
	; move.l 8(a0),a0
	; move.l a0,-(sp)
	; jsr (a1)
	; move.l (sp)+,a0
	; move.l a0,vbl_music+2
	bra waitkey

	
exit	bsr hbloff
	
	move.w orez(pc),-(sp)	; Restore the original screen address and resolution
	move.l oscr(pc),-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	movem.l opal,d0-d7
	movem.l d0-d7,$ffff8240.w

	; Mute the soundchip
	move.b #7,$ffff8800.w
	move.b #%11111111,$ffff8802.w

end	move.l stack(pc),-(sp)
	move.w #$20,-(sp)
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
	
stack	ds.l 1

nomusic	rts

; Display the inspirational quote
show_quote:
	move.l $44e,a0
	move.l #screen_size/4-1,d0
cls2	clr.l (a0)+
	dbra d0,cls2

	clr.l $ffff8240.w
	move.w #37,-(sp)
	trap #14
	addq.l #2,sp
	move.l $44e,a0
	add.l #quote_offset,a0
	lea quote,a1
	moveq #quote_lines-1,d7
yq	moveq #quote_width-1,d6
xq	move.w (a1),(a0)
	move.w (a1)+,line_bytes(a0)
	addq.l #8,a0
	dbra d6,xq
	add.l #line_bytes+48,a0
	dbra d7,yq

	lea grey,a6
	moveq #fade_frames-1,d7
fade	move.w #37,-(sp)
	trap #14
	addq.l #2,sp
	move.w (a6)+,$ffff8242.w
	dbra d7,fade

	move.l #hold_frames-1,d7
paus	move.w #37,-(sp)
	trap #14
	addq.l #2,sp
	dbra d7,paus

	moveq #fade_frames-1,d7
fade2	move.w #37,-(sp)
	trap #14
	addq.l #2,sp
	move.w (a6)+,$ffff8242.w
	dbra d7,fade2
	rts
	
generate:
	; Set the first values for the plot routine
	lea plot+4,a0
	move.b #15,opb+1
	move.w (a0)+,draw_line
	move.b (a0)+,draw_word+1
	move.b (a0)+,draw_bit+1

	; Add the screen address and offset to the path
	lea wave_path,a0
	move.l $44e,d1
	add.l #line_bytes*32+8,d1
	move.l #(e_wave_path-wave_path)/4-1,d0
lkl	add.l d1,(a0)+
	dbra d0,lkl

	; Copy the start of the path to the end of the wave path
	lea wave_path(pc),a0
	lea e_wave_path(pc),a1
	moveq #path_overflow-1,d0
lkl2	move.l (a0)+,(a1)+
	dbra d0,lkl2
	
	; Add the screen address and offset to the bounce path
	lea bounce(pc),a0
	move.l #(e_bounce-bounce)/4-1,d0
	move.l $44e,d1
	addq.l #8,d1
lklb	add.l d1,(a0)+
	dbra d0,lklb

	; Copy the start of the bounce path to the end
	lea bounce(pc),a0
	lea e_bounce-2(pc),a1
	moveq #path_overflow-1,d0
lkl2b	move.l (a0)+,(a1)+
	dbra d0,lkl2b

	; Scale the frame list by the font size
	lea frlist,a0
lp3	addq.l #4,a0
	move.l (a0),d0
	mulu #font_char_bytes,d0
	move.l d0,(a0)+
	cmp.l #elist,a0
	bne lp3
	
	lea wavemesbuf,a1
	moveq #font_height-1,d6
	
l1	lea wave_mess,a0
	moveq #wavy_chars-1,d7
lp2	clr.l d0
	move.b (a0)+,d0
	cmp.b #ascii_space,d0
	bne.s lk
	move.b #space_char,d0

lk	sub.b #"A",d0
	muls #font_char_bytes*font_shifts,d0
	add.l #font,d0
	move.l d0,(a1)+
	dbra d7,lp2
	dbra d6,l1
	rts

	
preshift:
	move.l $44e,a0

	lea font,a1
	move.l #font_height*font_chars-1,d7
let	move.l (a1)+,(a0)+
	move.l (a1)+,(a0)+
	dbra d7,let

	lea font,a0
	move.l $44e,a1
	move.l #num_chars-1,d7
let2	move.l #font_height-1,d6
	move.l a0,a2
yloo	clr.l (a0)+
	move.l (a1)+,(a0)+
	move.l (a1)+,(a0)+
	dbra d6,yloo

	move.l #font_shifts-2,d6
shf2	move.l #font_height-1,d5
yloo2	move.w (a2),d0
	move.w 4(a2),d1
	move.w 8(a2),d2
	lsl.w #1,d0
	lsl.w #1,d1
	lsl.w #1,d2
	move.w d0,(a0)
	move.w d1,4(a0)
	move.w d2,8(a0)
	move.w 4(a2),d1
	move.w 8(a2),d2
	roxl.w #1,d1
	roxl.w #1,d2
	andi.w #1,d1
	andi.w #1,d2
	add.w d1,4(a0)
	add.w d2,(a0)
	
	move.w 2(a2),d0
	move.w 6(a2),d1
	move.w 10(a2),d2
	lsl.w #1,d0
	lsl.w #1,d1
	lsl.w #1,d2
	move.w d0,2(a0)
	move.w d1,6(a0)
	move.w d2,10(a0)
	move.w 6(a2),d1
	move.w 10(a2),d2
	roxl.w #1,d1
	roxl.w #1,d2
	andi.w #1,d1
	andi.w #1,d2
	add.w d1,6(a0)
	add.w d2,2(a0)
	
	add.l #12,a0
	add.l #12,a2
	dbra d5,yloo2
	dbra d6,shf2
	dbra d7,let2


	lea sh,a2
	lea font+group_buffer_1,a1
	moveq #8-1,d0
shrnk	move.l a2,a3
	lea tech,a0
	move.l a0,a4
	moveq #12-1,d2
frm	move.l a3,a2
	move.l a4,a0
	moveq #16-1,d1
lne	cmp.b #0,(a2)
	bne nc
	move.w (a0)+,(a1)+
	clr.w (a1)+
	bra.s nc3
nc	cmp.b #1,(a2)
	bne nc2
	clr.l (a1)+
	bra.s nc3
nc2	addq.l #2,a0
	addq.l #1,d1
nc3	addq.l #1,a2
	dbra d1,lne
	add.l #32,a4
	dbra d2,frm
	add.l #16,a3
	dbra d0,shrnk
	
	lea font+group_buffer_1+(group_member_size*7),a0
	lea font+group_buffer_1+(group_member_size*8),a1
	moveq #8-1,d7
ol1	moveq #12-1,d6
ol2	add.l #64,a0
	moveq #16-1,d5
ol3	subq.l #2,a0
	move.w -(a0),2(a1)
	clr.w (a1)
	addq.l #4,a1
	dbra d5,ol3
	add.l #64,a0
	dbra d6,ol2
	sub.l #group_member_size*2,a0
	dbra d7,ol1

	lea font+group_buffer_2,a0
	lea tech,a1
	move.l #32*12/4-1,d0
yxl	move.w (a1)+,(a0)+
	clr.w (a0)+
	move.w (a1)+,(a0)+
	clr.w (a0)+
	dbra d0,yxl
	lea font+group_buffer_2,a1
	moveq #7-1,d7
yxl2	move.w #16*12-1,d6
yxl3	move.w (a1),d0
	move.w (a1)+,d1
	lsr.w #1,d0
	lsl.b #1,d1
	move.b d1,d0			 
	move.w d0,(a0)+
	move.w (a1)+,(a0)+
	dbra d6,yxl3
	dbra d7,yxl2
	
	lea font+group_buffer_1+(group_member_size*24),a0
	lea font+group_buffer_1+(group_member_size*25),a1
	moveq #8-1,d7
ol1d	moveq #12-1,d6
ol2d	
	moveq #16-1,d5
ol3d	move.w (a0)+,2(a1)
	addq.l #2,a0
	clr.w (a1)
	addq.l #4,a1
	dbra d5,ol3d
	*add.l #64,a0
	dbra d6,ol2d
	sub.l #group_member_size*2,a0
	dbra d7,ol1d

	rts

dummy_vbl:
	addq.l #1,$466.w
	rte

vbl_routine:
	movem.l d0-d7/a0-a5,-(sp)

	addq.l #1,$466.w
	move.w #$2700,sr

	clr.w $ffff8240.w
	move.w #$227,$ffff8244.w
	move.w #$227,$ffff8246.w
	move.w #$227,$ffff8254.w
	move.w #$114,$ffff8248.w
	move.w #$114,$ffff824a.w
	move.w #$114,$ffff8258.w
	move.w #$007,$ffff8250.w
	move.w #$777,$ffff8252.w
	move.l ccol,a6			; Set up HBL palette
	move.l (a6),a6
	move.l (a6)+,$ffff8240.w	

	move.l #col,$120
	clr.b $fffffa1b.w		; Timer B stop
	move.b #8,$fffffa21.w		; Timer B data
	move.b #8,$fffffa1b.w		; Timer B event count mode
	bset #0,$fffffa07.w		; Timer B enable
	bset #0,$fffffa13.w		; Timer B mask

	move.w #$2300,sr

	bsr wavyscroll

	bsr spinners

	*move.w #$070,$ffff8240.w

	bsr drawlogo

	;move.w #$777,$ffff8240.w

	bsr yellow

	; bra.s no_music

; vbl_music:	jsr corange+4
	
no_music
	movem.l (sp)+,d0-d7/a0-a5
	*move.w #$777,$ffff8240.w
	rte

drawlogo:
	move.l $44e,a0			; Erase the vertical line
	addq.l #6,a0
	add.w opw,a0
	moveq #0,d0
	moveq #12-1,d7
ynnn	move.w d0,(a0)
	move.w d0,160(a0)
	move.w d0,320(a0)
	move.w d0,480(a0)
	move.w d0,640(a0)
	move.w d0,800(a0)
	move.w d0,960(a0)
	move.w d0,1120(a0)
	add.l #line_bytes*8,a0
	dbra d7,ynnn

	move.l $44e,a0			; Erase the horizontal line
	addq.l #6,a0
	add.w opl,a0
	moveq #5-1,d7
ynnn2	move.w d0,(a0)
	move.w d0,8(a0)
	move.w d0,16(a0)
	move.w d0,24(a0)
	add.l #32,a0
	dbra d7,ynnn2

	move.w draw_line,d0
	cmp.w opl,d0
	bne mv
	move.w draw_word,d0
	cmp.w opw,d0
	bne mv 
	move.w draw_bit,d0
	cmp.w opb,d0
	bne mv 
	move.l #1,pen
	move.l pap,a0
	move.w (a0)+,draw_line
	move.b (a0)+,draw_word+1
	move.b (a0)+,draw_bit+1
	addq.l #4,pap
	cmp.w #0,draw_line
	bne mh
	cmp.w #0,draw_word
	bne mh
	cmp.w #0,draw_bit
	bne mh
	clr.l pen
	move.l pap,a0
	move.w (a0)+,draw_line
	move.b (a0)+,draw_word+1
	move.b (a0)+,draw_bit+1
	addq.l #4,pap
mh	cmp.w #0,draw_line
	bne mh2
	cmp.w #0,draw_word
	bne mh2
	cmp.w #0,draw_bit
	bne.s mh2
	cmp.l #1,fr
	beq kka
	move.l #1,fr
	move.l fra,pap
	move.l pap,a0
	move.w (a0)+,draw_line
	move.b (a0)+,draw_word+1
	move.b (a0)+,draw_bit+1
	addq.l #4,pap
	bra.s mh2
kka	clr.l fr

	addq.l #4,ccol			; Advance the palette

	move.l pap,fra
	move.l pap,a0
	move.w (a0)+,draw_line
	move.b (a0)+,draw_word+1
	move.b (a0)+,draw_bit+1
	addq.l #4,pap
mh2	cmp.l #eplot,pap
	blt.s mv

	move.l #colst,ccol

	move.l #plot+4,pap
	move.l pap,a0
	move.w (a0)+,draw_line
	move.b (a0)+,draw_word+1
	move.b (a0)+,draw_bit+1
	addq.l #4,pap
	clr.l pen

mv	move.w draw_line,d0		; Draw line
	cmp.w opl,d0			; Plot line
	beq.s lr			; Left or right
	cmp.w opl,d0
	blt.s up			; Move up
	add.w #line_bytes,opl
	bra.s lr
up	sub.w #line_bytes,opl
lr	
	move.w draw_word,d0
	cmp.w opw,d0			; Plot word
	beq r2
	cmp.w opw,d0
	blt.s r
	subq.w #1,opb
	bge.s knt
	move.w #15,opb
	addq.w #8,opw
	bra.s knt
r	addq.w #1,opb
	cmp.w #15,opb
	ble knt
	clr.w opb
	subq.w #8,opw
	bra.s knt

r2	move.w draw_bit,d0		; Draw bit
	cmp.w opb,d0			; Plot bit
	beq.s knt
	cmp.w opb,d0
	blt.s rr
	addq.w #1,opb
	bra.s knt
rr	subq.w #1,opb
	
knt	move.l $44e,a0			; Draw vertical line
	addq.l #6,a0
	add.w opw,a0
	clr.w d0
	move.w opb,d1
	bset d1,d0
	moveq #11-1,d7
ynnnf	move.w d0,(a0)
	move.w d0,160(a0)
	move.w d0,320(a0)
	move.w d0,480(a0)
	move.w d0,640(a0)
	move.w d0,800(a0)
	move.w d0,960(a0)
	move.w d0,1120(a0)
	add.l #line_bytes*8,a0
	dbra d7,ynnnf

	move.l $44e,a0			; Draw horizontal line
	addq.l #6,a0
	add.w opl,a0
	moveq #5-1,d7
ynnn2f	move.w #$ffff,(a0)
	move.w #$ffff,8(a0)
	move.w #$ffff,16(a0)
	move.w #$ffff,24(a0)
	add.l #32,a0
	dbra d7,ynnn2f
	cmp.l #1,pen
	bne fin
	cmp.l #1,fr
	bne norm

	move.l $44e,a0
	add.w opl,a0
	add.w opw,a0
	clr.w d0
	move.w opb,d1
	bset d1,d0
	not d0
	and.w d0,(a0)
	bra.s fin
norm	
	cmp.l #1,pen
	bne fin
	move.l $44e,a0
	add.w opl,a0
	add.w opw,a0
	clr.w d0
	move.w opb,d1
	bset d1,d0
	or.w d0,(a0)

fin	rts


;
; Bouncing yellow scroller
yellow:	move.l p_yellow_rout,a0
	move.l (a0),a1
	jsr (a1)

	lea p_yellow_rout(pc),a0
	addq.l #4,(a0)
	cmp.l #e_yellow_routs,(a0)
	bne.s eyellow
	move.l #yellow_routs,(a0)

eyellow	rts

; Render the yellow scroller (version 1)
put1	move.l swpo,a0
 	clr.l d1
 	addq.l #4,swpo
 	cmp.l #e_bounce,swpo
 	ble pa1
 	move.l #bounce,swpo

pa1	move.l pyellow,a1
	moveq #10-1,d7
	lea yellow_font,a2
pa2	clr.l d0
	move.b (a1)+,d0
	sub.b #"A",d0
	lsl.w #8,d0
	move.l (a0)+,a4
	
 	subq.l #4,a4
 	add.l d1,a4
 	moveq #4-1,d6
pa3	move.l (a2,d0),(a4)
	move.l 4(a2,d0),8(a4)
	move.l 8(a2,d0),160(a4)
	move.l 12(a2,d0),168(a4)
	move.l 16(a2,d0),320(a4)
	move.l 20(a2,d0),328(a4)
	move.l 24(a2,d0),480(a4)
	move.l 28(a2,d0),488(a4)
	move.l 32(a2,d0),640(a4)
	move.l 36(a2,d0),648(a4)
	move.l 40(a2,d0),800(a4)
	move.l 44(a2,d0),808(a4)
	move.l 48(a2,d0),960(a4)
	move.l 52(a2,d0),968(a4)
	move.l 56(a2,d0),1120(a4)
	move.l 60(a2,d0),1128(a4)
	lea 8*line_bytes(a4),a4
	add.l #64,d0
	dbra d6,pa3
	add.l #16,d1
	dbra d7,pa2
	rts

; Render the yellow scroller (version 2 - 16 pixel offset)
put2	move.l swpo,a0
 	clr.l d1
 	addq.l #4,swpo
 	cmp.l #e_bounce,swpo
 	ble zpa1
 	move.l #bounce,swpo
zpa1	move.l pyellow,a1
	lea yellow_font,a2
	clr.l d0 
	move.b (a1)+,d0
	sub.b #"A",d0
	lsl.w #8,d0
	move.l (a0)+,a4
	
 	subq.l #4,a4
 	add.l d1,a4
	moveq #4-1,d6
azpa3	move.l 4(a2,d0),(a4)
	move.l 12(a2,d0),160(a4)
	move.l 20(a2,d0),320(a4)
	move.l 28(a2,d0),480(a4)
	move.l 36(a2,d0),640(a4)
	move.l 44(a2,d0),800(a4)
	move.l 52(a2,d0),960(a4)
	move.l 60(a2,d0),1120(a4)
	lea 8*line_bytes(a4),a4
	add.l #64,d0
	dbra d6,azpa3
	addq.l #8,d1
	
	moveq #9-1,d7
zpa2	clr.l d0
	move.b (a1)+,d0
	sub.b #"A",d0
	lsl.w #8,d0
	move.l (a0)+,a4
	
 	subq.l #4,a4
 	add.l d1,a4
	
	moveq #4-1,d6
zpa3	move.l (a2,d0),(a4)
	move.l 4(a2,d0),8(a4)
	move.l 8(a2,d0),160(a4)
	move.l 12(a2,d0),168(a4)
	move.l 16(a2,d0),320(a4)
	move.l 20(a2,d0),328(a4)
	move.l 24(a2,d0),480(a4)
	move.l 28(a2,d0),488(a4)
	move.l 32(a2,d0),640(a4)
	move.l 36(a2,d0),648(a4)
	move.l 40(a2,d0),800(a4)
	move.l 44(a2,d0),808(a4)
	move.l 48(a2,d0),960(a4)
	move.l 52(a2,d0),968(a4)
	move.l 56(a2,d0),1120(a4)
	move.l 60(a2,d0),1128(a4)
	lea 8*line_bytes(a4),a4
	add.l #64,d0
	dbra d6,zpa3
	add.l #16,d1
	dbra d7,zpa2
	
	clr.l d0 
	move.b (a1)+,d0
	sub.b #"A",d0
	lsl.w #8,d0
	move.l (a0)+,a4
	
 	subq.l #4,a4
 	add.l d1,a4
	
	moveq #4-1,d6
bzpa3	move.l (a2,d0),(a4)
	move.l 8(a2,d0),160(a4)
	move.l 16(a2,d0),320(a4)
	move.l 24(a2,d0),480(a4)
	move.l 32(a2,d0),640(a4)
	move.l 40(a2,d0),800(a4)
	move.l 48(a2,d0),960(a4)
	move.l 56(a2,d0),1120(a4)
	lea 8*line_bytes(a4),a4
	add.l #64,d0
	dbra d6,bzpa3
	addq.l #1,pyellow
	cmp.l #emess2,pyellow
	bne fin2
	move.l #yellowmess,pyellow
fin2	
	rts

wavyscroll:
	moveq #wavy_lines-1,d0 		; Initialize loop counter
	moveq #0,d2			; Clear d2 (used for screen offset)
	moveq #0,d1			; Clear d1 (used for wave effect offset)
	lea wave_line_rts,a3 		; Load address of wave routine table into a3
	move.l p_waveoffs,a5		; Load wave function list into a5
	lea wavemesbuf,a0		; Load address of message buffer into a0
	lea p_wavemes,a4	 		; Load address of current message pointer into a4
	
.wavyline
	moveq #0,d3
	move.w (a5),d3	 	; Load next wave offset from (a5) into d3
	add.l d3,(a3)		; Add wave offset to wave function pointer
	move.l (a3),a1	 	; Load function table pointer from (a3) into a1
	move.l (a1)+,a2	 	; Load function address into a2
	move.l (a1)+,d7	 	; Load wave offset into d7
	add.l d1,d7		; Add offset d1 to function parameter d7
	jsr (a2)		; Call the function
	
	move.l (a3),d4		; Load current function pointer into d4
	moveq #0,d3
	move.w 2(a5),d3		; Load next wave offset into d3
	add.l d3,d4	 	; Adjust d4 with another wave offset
	addq.l #8,d4		; Increment d4 to the next wave function
	cmp.l #elist,d4	 	; Check if it is the end of the list
	blt.s .ca3

	sub.l #48*8,(a3)	; Reset function pointer (move back by 48 functions)
	move.l a0,-(sp)	 	; Save message buffer pointer and wave routine table pointer
	move.l a3,-(sp)

	move.l a0,a2
	addq.l #4,a0
	move.l (a0)+,(a2)+	; Shift function pointers down by one
	move.l (a0)+,(a2)+
	move.l (a0)+,(a2)+
	move.l (a0)+,(a2)+
	move.l (a0)+,(a2)+
	move.l (a0)+,(a2)+

	addq.l #1,(a4)	 	; Move to next character in the message
	move.l (a4),a3		; Load new character pointer into a3
	clr.l d7
	move.b (a3)+,d7	 	; d7: next character in the message
	cmp.b #ascii_space,d7
	bne.s .lk2

	move.b #space_char,d7 	; If space, set character code to end of font

.lk2
	sub.b #"A",d7	 	; Convert ASCII character to index (A=0)
	moveq #11,d5		; Multiply d7 by 2048 * 3
	lsl.l d5,d7			
	move.l d7,d5
	add.l d5,d7
	add.l d5,d7
	add.l #font,d7		; Add base font address to get shifted character
	move.l d7,(a2)		; Store character address in message buffer

	cmp.l #ewavm,a3	 	; Check if end of message is reached
	bne.s .ca2
	move.l #wave_mess,(a4)	; Reset message pointer to start of message
	
.ca2
	move.l (sp)+,a3		; Restore wave routine table pointer and message buffer pointer
	move.l (sp)+,a0
	
.ca3
	add.l #12,d1	 	; Increment wave effect offset
	add.l #line_bytes,d2	; Increment screen offset
	add.l #mesbuf_w,a0	; Move to next line in message buffer
	addq.l #4,a4		; Increment message pointer
	addq.l #2,a5		; Advance wave offset pointer
	addq.l #8,(a3)		; Advance wave function pointer
	addq.l #4,a3		; Move to next function in the table
	dbra d0,.wavyline
	
	lea p_waveoffs(pc),a2	; Address of wave path pointer
	addq.l #2,(a2)	 	; Advance wave path pointer
	cmp.l #wavend-2,(a2)
	ble.s .cnt3

	move.l #waveoffs,(a2) 	; Reset wave function pointer
	
.cnt3
	move.l p_wavepath,a2	; a2: wave path pointer
	move.l (a2),a2		; a2: screen address for wave path
	subq.l #8,a2		; 16 pixels to the left
	lea heart(pc),a0	; a0: 'heart' bitmap address
	moveq #2-1,d7	 	; 2 blocks of 16 lines
	
.yes	move.l (a0)+,(a2)	; Draw 'heart' bitmap at position a2
	move.l (a0)+,160(a2)
	move.l (a0)+,320(a2)
	move.l (a0)+,480(a2)
	move.l (a0)+,640(a2)
	move.l (a0)+,800(a2)
	move.l (a0)+,960(a2)
	move.l (a0)+,1120(a2)
	move.l (a0)+,1280(a2)
	move.l (a0)+,1440(a2)
	move.l (a0)+,1600(a2)
	move.l (a0)+,1760(a2)
	move.l (a0)+,1920(a2)
	move.l (a0)+,2080(a2)
	move.l (a0)+,2240(a2)
	move.l (a0)+,2400(a2)
	lea 2560(a2),a2		; Move to next block of lines
	dbra d7,.yes
	
	move.l p_wavepath,a2	; Reload path pointer
	add.l #144,a2	 	; The RHS of the screen
	move.l (a2),a2
	add.l #144,a2

	moveq #2-1,d7	 	; 2 blocks of 16 lines	
.yes2
	move.l (a0)+,(a2)
	move.l (a0)+,160(a2)
	move.l (a0)+,320(a2)
	move.l (a0)+,480(a2)
	move.l (a0)+,640(a2)
	move.l (a0)+,800(a2)
	move.l (a0)+,960(a2)
	move.l (a0)+,1120(a2)
	move.l (a0)+,1280(a2)
	move.l (a0)+,1440(a2)
	move.l (a0)+,1600(a2)
	move.l (a0)+,1760(a2)
	move.l (a0)+,1920(a2)
	move.l (a0)+,2080(a2)
	move.l (a0)+,2240(a2)
	move.l (a0)+,2400(a2)
	lea 2560(a2),a2
	dbra d7,.yes2
	
	lea p_wavepath(pc),a2	; a2: address of wave path pointer
	addq.l #4,(a2)	 	; Advance wave path pointer
	cmp.l #e_wave_path,(a2)	; Check if end of wave path is reached
	ble.s .sw
	move.l #wave_path,(a2)	; Reset wave path pointer
	
.sw	rts
	
; Subroutine 'rout_a' - draw one line of wavy text with whole characters
rout_a:
	movem.l d5/a0-a3,-(sp)
	move.l d2,d5		; Copy screen offset d2 into d5
	move.l a4,a3		; Copy message pointer a4 into a3
	moveq #6-1,d6	 	; d6: loop counter for 6 characters
	move.l p_wavepath,a2	; a2: wave path pointer
	
leta	move.l (a0)+,a1	 	; Load character bitmap address into a1
	add.l d7,a1		; Adjust a1 with wave offset d7
	
ylp1	move.l (a2),a3	 	; Load screen address into a3
	move.b (a1),(a3,d5)	; Copy 2 bitplanes of pixel data from character bitmap to screen (*8)
	move.b 2(a1),2(a3,d5)
	move.l 4(a2),a3
	move.b 1(a1),1(a3,d5)
	move.b 3(a1),3(a3,d5)
	move.l 8(a2),a3
	move.b 4(a1),8(a3,d5)
	move.b 6(a1),10(a3,d5)
	move.l 12(a2),a3
	move.b 5(a1),9(a3,d5)
	move.b 7(a1),11(a3,d5)
	move.l 16(a2),a3
	move.b 8(a1),16(a3,d5)
	move.b 10(a1),18(a3,d5)
	move.l 20(a2),a3
	move.b 9(a1),17(a3,d5)
	move.b 11(a1),19(a3,d5)

	add.l #24,d5	 ; Advance the screen offset by 48 pixels
	add.l #24,a2	 ; Advance screen address table pointer by 48 pixels
	dbra d6,leta
	
	movem.l (sp)+,d5/a0-a3 ; Restore saved registers from the stack
	rts
	
; Subroutine 'rout_b' - draw one line of wavy text with 16 pixel offset on first character
rout_b:
	movem.l d5/a0-a3,-(sp)
	move.l d2,d5		; d5: screen offset
	move.l a4,a3		; a4: message pointer
	move.l p_wavepath,a2	; a2: ssreen address table pointer
	move.l (a0)+,a1		; a1: character bitmap address
	add.l d7,a1		; add wave offset d7 to character bitmap address
	
ylp2	addq.l #4,a1		; 16 pixel offset in character data
	move.l (a2),a3
	move.b (a1),(a3,d5)
	move.b 2(a1),2(a3,d5)
	move.l 4(a2),a3
	move.b 1(a1),1(a3,d5)
	move.b 3(a1),3(a3,d5)
	move.l 8(a2),a3
	move.b 4(a1),8(a3,d5)
	move.b 6(a1),10(a3,d5)
	move.l 12(a2),a3
	move.b 5(a1),9(a3,d5)
	move.b 7(a1),11(a3,d5)
	add.l #16,a2	 	; Advance screen address to next character
	add.l #16,d5
	
	moveq #5-1,d6	 	; Loop for 5 characters
leta2	move.l (a0)+,a1	 	; Load next character bitmap
	add.l d7,a1		; Adjust with wave offset
	
ylp12	move.l (a2),a3	 	; Copy pixel data to screen
	move.b (a1),(a3,d5)
	move.b 2(a1),2(a3,d5)
	move.l 4(a2),a3
	move.b 1(a1),1(a3,d5)
	move.b 3(a1),3(a3,d5)
	move.l 8(a2),a3
	move.b 4(a1),8(a3,d5)
	move.b 6(a1),10(a3,d5)
	move.l 12(a2),a3
	move.b 5(a1),9(a3,d5)
	move.b 7(a1),11(a3,d5)
	move.l 16(a2),a3
	move.b 8(a1),16(a3,d5)
	move.b 10(a1),18(a3,d5)
	move.l 20(a2),a3
	move.b 9(a1),17(a3,d5)
	move.b 11(a1),19(a3,d5)
	add.l #24,a2	 	; Adjust screen address for next character
	add.l #24,d5		; Adjust screen offset for next character
	dbra d6,leta2
	
	move.l (a0)+,a1	 	; Load last character bitmap
	add.l d7,a1		; Adjust with wave offset
	
ylp3	move.l (a2),a3	 	; Copy last part of pixel data
	move.b (a1),(a3,d5)
	move.b 2(a1),2(a3,d5)
	move.l 4(a2),a3
	move.b 1(a1),1(a3,d5)
	move.b 3(a1),3(a3,d5)
	
	movem.l (sp)+,d5/a0-a3 ; Restore registers
	rts
	
; Subroutine 'rout_c' - draw one line of wavy text with 32 pixel offset on first character
rout_c:
	movem.l d5/a0-a3,-(sp)
	move.l d2,d5			; d5: screen offset
	move.l a4,a3			; a4: message pointer
	move.l p_wavepath,a2	 	; a2: screen address table pointer
	move.l (a0)+,a1	 		; a1: character bitmap address
	add.l d7,a1			; Adjust with wave offset
	
ylp2c	addq.l #8,a1			; Advance character bitmap by 32 pixels
	move.l (a2),a3	 		; Copy pixel data to screen
	move.b (a1),(a3,d5)
	move.b 2(a1),2(a3,d5)
	move.l 4(a2),a3
	move.b 1(a1),1(a3,d5)
	move.b 3(a1),3(a3,d5)
	addq.l #8,a2			; Advance screen address by 32 pixels
	add.l #8,d5			; Advance screen offset
	
	moveq #5-1,d6	 		; 5 characters
leta2c	move.l (a0)+,a1	 		; Load next character bitmap
	add.l d7,a1			; Adjust with wave offset
	
ylp12c	move.l (a2),a3	 		; Copy pixel data
	move.b (a1),(a3,d5)
	move.b 2(a1),2(a3,d5)
	move.l 4(a2),a3
	move.b 1(a1),1(a3,d5)
	move.b 3(a1),3(a3,d5)
	move.l 8(a2),a3
	move.b 4(a1),8(a3,d5)
	move.b 6(a1),10(a3,d5)
	move.l 12(a2),a3
	move.b 5(a1),9(a3,d5)
	move.b 7(a1),11(a3,d5)
	move.l 16(a2),a3
	move.b 8(a1),16(a3,d5)
	move.b 10(a1),18(a3,d5)
	move.l 20(a2),a3
	move.b 9(a1),17(a3,d5)
	move.b 11(a1),19(a3,d5)
	add.l #24,a2	 		; Advance screen address by 48 pixels
	add.l #24,d5
	dbra d6,leta2c
	
	move.l (a0)+,a1			; Load last character bitmap
	add.l d7,a1			; Adjust with wave offset
	
ylp3c	move.l (a2),a3	 		; Copy final pixel data
	move.b (a1),(a3,d5)
	move.b 2(a1),2(a3,d5)
	move.l 4(a2),a3
	move.b 1(a1),1(a3,d5)
	move.b 3(a1),3(a3,d5)
	move.l 8(a2),a3
	move.b 4(a1),8(a3,d5)
	move.b 6(a1),10(a3,d5)
	move.l 12(a2),a3
	move.b 5(a1),9(a3,d5)
	move.b 7(a1),11(a3,d5)
	
	movem.l (sp)+,d5/a0-a3
	rts

;
; "Technophilia" spinners
spinners:
	*move.w #$700,$ffff8240.w
	*move.w #$707,$ffff8240.w
	subq.l #1,ohh
	bne jj
	move.l #240,ohh
	move.l spingroup1,d0
	move.l spingroup2,spingroup1
	move.l d0,spingroup2
jj	moveq #12-1,d0
	move.l spingroup1,a0
	add.l spin,a0
	subq.l #1,ps
	bne.s ka
	move.l #4,ps
	move.l asp,d7
	add.l d7,spin
	cmp.l #group_member_size*15,spin
	blt.s kad
	move.l #-group_member_size,asp
kad	tst.l spin
	bgt ka
	
	move.l #group_member_size,asp
ka	moveq #24+2,d7
	lea tech_path,a1
tt	move.l (a1),a3
	move.l (a3),a2
	sub.l #line_bytes*85,a2
	add.l d7,a2
	clr.l -160(a2)
	clr.l -320(a2)
	clr.l -480(a2)
	move.l (a0),(a2)
	move.l 4(a0),160(a2)
	move.l 8(a0),320(a2)
	move.l 12(a0),480(a2)
	move.l 16(a0),640(a2)
	move.l 20(a0),800(a2)
	move.l 24(a0),960(a2)
	move.l 28(a0),1120(a2)
	move.l 32(a0),1280(a2)
	move.l 36(a0),1440(a2)
	move.l 40(a0),1600(a2)
	move.l 44(a0),1760(a2)
	move.l 48(a0),1920(a2)
	move.l 52(a0),2080(a2)
	move.l 56(a0),2240(a2)
	move.l 60(a0),2400(a2)
	clr.l 2560(a2)
	clr.l 2720(a2)
	clr.l 2880(a2)
	add.l #64,a0
	addq.l #4,(a1)
	cmp.l #e_bounce,(a1)
	ble zoe
	move.l #bounce,(a1)
zoe	addq.l #4,a1
	addq.l #8,d7
	dbra d0,tt

	rts

; HBL interrupt routine
col:	move.l (a6)+,$ffff8240.w
	bpl.s pop
	*move.w #$607,$ffff8246.w
	move.l #$00000304,$ffff8240.w
	move.l #$04050607,$ffff8244.w
	move.l #$03300304,$ffff8248.w
	move.l #$04050607,$ffff824c.w
	move.l #$05500304,$ffff8250.w
	move.l #$04050607,$ffff8254.w
	move.l #$07700304,$ffff8258.w
	move.l #$04050607,$ffff825c.w	
	
pop	bclr #0,$fffffa0f.w			; Interrupt in service
	rte


;
; Set up the interrupts
hblon	move.w #$2700,sr
	lea mfpstr,a0
	move.l $70.w,(a0)+
	move.l $118.w,(a0)+
	move.l $120.w,(a0)+
	move.b $fffffa07.w,(a0)+
	move.b $fffffa09.w,(a0)+
	move.b $fffffa13.w,(a0)+
	move.b $fffffa15.w,(a0)+
	move.b $fffffa17.w,(a0)+
	move.b $fffffa1b.w,(a0)+

	clr.b $fffffa07.w		; Clear interrupt enable A
	clr.b $fffffa09.w		; Clear interrupt enable B

	; bclr #3,$fffffa17.w		; Automatic MFP end interrupt mode

	move.l #vbl_routine,$70.w	; Main 50Hz VBL routine
	; move.l #dummy_vbl,$70.w

	move.l #nkey,$118.w
	; bset #6,$fffffa09.w		; Enable keyboard interrupt
	; bset #6,$fffffa15.w

	; move.b #$12,$fffffc02.w		; Keyboard ACIA data

	move.w #$2300,sr
	rts

nkey	bclr #6,$fffffa11.w		; Clear interrupt in service bit
	rte				; Null keyboard interrupt handler (can't afford to spend time on this)

key	dc.b $ff
joycm	ds.b 1
mousx	ds.b 1
mousy	ds.b 1
mousb	ds.b 1

hbloff	move.w #$2700,sr
	lea mfpstr,a0
	move.l (a0)+,$70.w
	move.l (a0)+,$118.w
	move.l (a0)+,$120.w
	move.b (a0)+,$fffffa07.w
	move.b (a0)+,$fffffa09.w
	move.b (a0)+,$fffffa13.w
	move.b (a0)+,$fffffa15.w
	move.b (a0)+,$fffffa17.w
	move.b (a0)+,$fffffa1b.w
	move.w #$2300,sr
	rts

;
; Data section

ohh	dc.l 240
opl	ds.l 1
opw	ds.l 1
opb	ds.l 1

draw_line	ds.l 1
draw_word	ds.l 1
draw_bit	ds.l 1
pen		dc.l 0
pap		dc.l plot+4
ps		dc.l 4
ne		ds.w 1
fr		ds.l 1
fra		dc.l plot+4

spingroup1	dc.l font+group_buffer_1
spingroup2	dc.l font+group_buffer_1+(group_member_size*17)
asp		dc.l group_member_size
spin		ds.l 1

; basher:
; 	dc.l corange,1,corange+4,0
; 	dc.l corange,12,corange+4,0
; 	dc.l rushes,1,rushes+4,0
; 	; dc.l musx3,1,musx3+4,0
; 	dc.l chimera,1,chimera+8,0
; 	dc.l corange,3,corange+4,0
; 	; dc.l musx2,6,musx2+4,0
; 	; dc.l musx5,1,musx5+8,0
; ebash	ds.w 1

swpo	dc.l bounce

; Path pointers for the technophilia spinners
tech_path dc.l bounce,bounce+20,bounce+40,bounce+60,bounce+80
	  dc.l bounce+100,bounce+120,bounce+140,bounce+160,bounce+180,bounce+200,bounce+220

ovbl	ds.l 1
letr	ds.l 9

p_wavepath	dc.l wave_path		; Position in wave path

; Position in message for 32 lines
p_wavemes	dcb.l 32,wave_mess

; Buffer for each character and line of the wave message
wavemesbuf	ds.l 8*32

wave_line_rts	dcb.l 32,frlist

; Wave function list - duplicated before and after the primary list for ease of buffer wrapping
	dc.l rout_a,0,rout_a,1,rout_a,2,rout_a,3,rout_a,4,rout_a,5,rout_a,6,rout_a,7,rout_a,8,rout_a,9,rout_a,10,rout_a,11,rout_a,12,rout_a,13,rout_a,14,rout_a,15
	dc.l rout_b,0,rout_b,1,rout_b,2,rout_b,3,rout_b,4,rout_b,5,rout_b,6,rout_b,7,rout_b,8,rout_b,9,rout_b,10,rout_b,11,rout_b,12,rout_b,13,rout_b,14,rout_b,15
	dc.l rout_c,0,rout_c,1,rout_c,2,rout_c,3,rout_c,4,rout_c,5,rout_c,6,rout_c,7,rout_c,8,rout_c,9,rout_c,10,rout_c,11,rout_c,12,rout_c,13,rout_c,14,rout_c,15
frlist 	
	dc.l rout_a,0,rout_a,1,rout_a,2,rout_a,3,rout_a,4,rout_a,5,rout_a,6,rout_a,7,rout_a,8,rout_a,9,rout_a,10,rout_a,11,rout_a,12,rout_a,13,rout_a,14,rout_a,15
	dc.l rout_b,0,rout_b,1,rout_b,2,rout_b,3,rout_b,4,rout_b,5,rout_b,6,rout_b,7,rout_b,8,rout_b,9,rout_b,10,rout_b,11,rout_b,12,rout_b,13,rout_b,14,rout_b,15
	dc.l rout_c,0,rout_c,1,rout_c,2,rout_c,3,rout_c,4,rout_c,5,rout_c,6,rout_c,7,rout_c,8,rout_c,9,rout_c,10,rout_c,11,rout_c,12,rout_c,13,rout_c,14,rout_c,15

elist	dc.l rout_a,0,rout_a,1,rout_a,2,rout_a,3,rout_a,4,rout_a,5,rout_a,6,rout_a,7,rout_a,8,rout_a,9,rout_a,10,rout_a,11,rout_a,12,rout_a,13,rout_a,14,rout_a,15
	dc.l rout_b,0,rout_b,1,rout_b,2,rout_b,3,rout_b,4,rout_b,5,rout_b,6,rout_b,7,rout_b,8,rout_b,9,rout_b,10,rout_b,11,rout_b,12,rout_b,13,rout_b,14,rout_b,15
	dc.l rout_c,0,rout_c,1,rout_c,2,rout_c,3,rout_c,4,rout_c,5,rout_c,6,rout_c,7,rout_c,8,rout_c,9,rout_c,10,rout_c,11,rout_c,12,rout_c,13,rout_c,14,rout_c,15

p_waveoffs	dc.l waveoffs

waveoffs:
	dc.w 24,24,24,24,24,24,24,24
	dc.w 24,24,24,24,24,24,24,24
	dc.w 24,24,24,24,24,24,24,24
	dc.w 24,24,24,24,24,24,24,24
	dc.w 24,24,24,24,24,24,24,24
	dc.w 24,24,24,24,24,24,24,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 32,32,32,32,32,40,40,40,40
	dc.w 48,48,48,56,64,72,64,56,48,48,48
	dc.w 40,40,40,40,32,32,32,32,32
	dc.w 24,24,24,24,24,24,24,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16
	dc.w 24,24,32,48,56,64,72,80,88,96,88,80,72,64,56,48,32,24,24
	dc.w 24,24,24,24,24,24,24,24
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 8,8,8,8,0,0,0,0,8,16,24,32,40,32,24
	dc.w 32,32,32,32,32,40,40,40,40
	dc.w 48,48,48,56,56,48,48,48
	dc.w 40,40,40,40,32,32,32,32,32
	dc.w 8,8,8,8,8,8,8,8,8,8
	dc.w 8,8,8,8,8,8,8,8,8,8
	dc.w 8,8,8,8,8,8,8,8,8,8,16
	dc.w 24,24,32,48,56,64,72,80,88,96,88,80,72,64,56,48,32,24,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8
	dc.w 8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 24,24,32,48,56,64,72,80,88,96,88,80,72,64,56,48,32,24,24
	dc.w 32,32,32,32,32,40,40,40,40
	dc.w 48,48,48,56,56,48,48,48
	dc.w 40,40,40,40,32,32,32,32,32,24
wavend	dc.w 24,24,24,24,24,24,24,24
	dc.w 24,24,24,24,24,24,24,24
	dc.w 24,24,24,24,24,24,24,24
	dc.w 24,24,24,24,24,24,24,24
	dc.w 24,24,24,24,24,24,24,24
	dc.w 24,24,24,24,24,24,24,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 32,32,32,32,32,40,40,40,40
	dc.w 48,48,48,56,64,72,64,56,48,48,48
	dc.w 40,40,40,40,32,32,32,32,32
	dc.w 24,24,24,24,24,24,24,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8,8,16
	dc.w 24,24,32,48,56,64,72,80,88,96,88,80,72,64,56,48,32,24,24
	dc.w 24,24,24,24,24,24,24,24
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 8,8,8,8,0,0,0,0,8,16,24,32,40,32,24
	dc.w 32,32,32,32,32,40,40,40,40
	dc.w 48,48,48,56,56,48,48,48
	dc.w 40,40,40,40,32,32,32,32,32
	dc.w 8,8,8,8,8,8,8,8,8,8
	dc.w 8,8,8,8,8,8,8,8,8,8
	dc.w 8,8,8,8,8,8,8,8,8,8,16
	dc.w 24,24,32,48,56,64,72,80,88,96,88,80,72,64,56,48,32,24,24
	dc.w 16,8,8,8,8,8,8,8,8,8,8
	dc.w 8,8,8,8,8,8,8,8,8,8,16,24
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 32,32,32,40,40,48,40,40,32,32
	dc.w 24,24,32,48,56,64,72,80,88,96,88,80,72,64,56,48,32,24,24
	dc.w 32,32,32,32,32,40,40,40,40
	dc.w 48,48,48,56,56,48,48,48
	dc.w 40,40,40,40,32,32,32,32,32,24
	
wave_mess:
	dc.b "           PLEASE TRY THE FUNCTION KEYS          GREETINGS AND SALUTATIONS TO YOU ALL"
	dc.b "          THIS IS VILM OF THE CYBERPUNKS          THE CREDITS FOR THIS SCREEN ARE"
	dc.b "           YELLOW FONT BY          ZAX          ALL OTHER GRAPHICS AND ALL CODING BY          VILM                "
	dc.b "SPECIAL MENTION TO SALLY            HI              WORD TO THE WISE GUY"
	dc.b "          LET US WRAP NOW TOGETHER AND FOREVER         WOULDNT YOU                              "
ewavm	dc.b "            "

yellowmess:
	dc.b "oooooooooooooTHISooo"
	dc.b "ooooooooooooSCREENoo"
	dc.b "ooooooooooooooISoooo"
	dc.b "ooooooooooooooBYoooo"
	dc.b "oooooooooooooVILMooo"
	dc.b "ooooooooooooIToWASoo"
	dc.b "oooooooooooFINISHEDo"
	dc.b "ooooooooooooooONoooo"
	dc.b "ooooooooooo[dj[bjd\o"
	dc.b "ooooooooooooooAToooo"
	dc.b "ooooooooooo[_i]dAMoo"
	dc.b "ooooooooooooHOWoISoo"
	dc.b "ooooooooooooLIFEhhoo"
	dc.b "oooooooooooooooIoooo"
	dc.b "oooooooooooLOVEoTHEo"
	dc.b "ooooooooooooPIXIESoo"
	dc.b "oooooooooooooANDoooo"
	dc.b "ooooooooooooCARTERoo"
	dc.b "oooooooooooooANDoooo"
	dc.b "oooooooooooTEENAGEoo"
	dc.b "oooooooooooFANCLUBoo"
	dc.b "ooooooooooooPEACEooo"
	dc.b "ooooooooooooooTOoooo"
	dc.b "ooooooooooooYOUoALLo"
	dc.b "oooooooooooooLOVEooo"
	dc.b "oooooooooooooANDoooo"
	dc.b "oooooooooooBEoHAPPYo"
	dc.b "oooooooooooBYEoFROMo"
	dc.b "oooooooooooooVILMooo"
	dc.b "oooooooooooooooooooo"
	dc.b "oooooooooooooooooooo"
	dc.b "oooooooooooooooooooo"
	dc.b "oooooooooooooooooooo"
emess2	dc.b "oooooooooooooooooooo"

pyellow	dc.l yellowmess

; Pointers for the yellow bouncy message routine
yellow_routs:
	dc.l put1,put2,put1,put2,put1,put2,put1,put2,put1,put2,put1,put2,put1,put2,put1,put2,put1,put2,put1,put2
	dc.l put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1
	dc.l put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1
	dc.l put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1
	dc.l put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1
	dc.l put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1,put1
	dc.l put1,put2,put1,put2,put1,put2,put1,put2,put1,put2,put1,put2,put1,put2,put1,put2,put1,put2,put1,put2
e_yellow_routs

p_yellow_rout	dc.l yellow_routs

oscr	ds.l 1
orez	ds.w 1
opal	ds.l 8
mfpstr	ds.l 10

ccol	dc.l colst
colst	dc.l cols,cols2,cols3
cols	dc.l $0000710,$0000700,$0000600,$0000500,$0000400
	dc.l $0000410,$00000420,$0000430,$0000440,$0000450,$0000444,$80000304
	dc.l $00000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304
	dc.l $0000304,$00000304,$0000304,$0000304,$0000304,$00000304,$00000304,$0000304,$0000304
cols2	dc.l $0000717,$0000707,$0000606,$0000505,$0000404
	dc.l $0000323,$0000232,$0000141,$0000050,$0000000,$0000044,$80000033
	dc.l $00000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304
	dc.l $0000304,$00000304,$00000304,$0000304,$0000304,$00000304,$00000304,$00000304,$00000304
cols3	dc.l $0000071,$0000070,$0000060,$0000050,$0000040
	dc.l $0000040,$0000041,$0000042,$0000043,$0000044,$0000045,$80000033
	dc.l $00000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304,$0000304
	dc.l $0000304,$00000304,$00000304,$00000304,$00000304,$00000304,$00000304,$00000304,$00000304
nocur	dc.b 27,"f"
sav	ds.l 2	
grey	dc.w $000,$111,$222,$333,$444,$555,$666,$777
	dc.w $777,$666,$555,$444,$333,$222,$111,$000
sh	dc.b 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dc.b 1,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,1
	dc.b 1,1,0,0,0,0,0,0,2,2,0,0,0,0,0,0,1,1
	dc.b 1,1,1,0,0,0,0,0,2,2,2,0,0,0,0,0,1,1,1
	dc.b 1,1,1,1,0,0,0,0,2,2,2,2,0,0,0,0,1,1,1,1
	dc.b 1,1,1,1,1,0,0,0,2,2,2,2,2,0,0,0,1,1,1,1,1
	dc.b 1,1,1,1,1,1,0,0,2,2,2,2,2,2,0,0,1,1,1,1,1,1
	dc.b 1,1,1,1,1,1,1,0,2,2,2,2,2,2,2,0,1,1,1,1,1,1,1

	EVEN
plot	incbin "plot.dat"
eplot	ds.l 6

	EVEN
wave_path	incbin "wave.dat"
e_wave_path	ds.l path_overflow

	EVEN
bounce		incbin "path.dat"
e_bounce	ds.l path_overflow
	
	EVEN
tech	incbin "tech.dat"
etech

	EVEN
heart	incbin "heart.dat"

	EVEN
yellow_font	incbin "3224fnt1.dat"
yellow_space	ds.w 256/2

; 	EVEN
; corange	incbin "corange.msx"
; 	ds.w 1
; rushes	incbin "rushes.msx"
; 	ds.w 1
; chimera	incbin "chimera.snd"		; .msx?
; 	ds.w 1

	EVEN
font	incbin "font2.dat"		; Wavy scroller font
	ds.w 16*font_height		; Space character
quote	incbin "quote.dat"		; Memory is reused for the pre-shifted font

	RSRESET

shift_buffer	rs.w 100000			; space for the pre-shifted font
group_buffer_1	rs.w group_buffer_size/2	; for the spinning/flipping TECHNOPHILIA
group_buffer_2	rs.w group_buffer_size/2	; for the spinning/flipping TECHNOPHILIA
stack_size	rs.w 1000
stack_top	rs.w 1
