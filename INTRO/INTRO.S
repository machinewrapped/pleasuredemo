; Intro screen for The Pleasuredemo
;
; This screen was originally written in 1991 by The Cyberpunks, then updated in 1992 with the tracking sprites.
; It was further updated in 2024 with a third screen buffer and a new sample.
; Comments, named constants and meaningful labels were also added in 2024.
;
; The overscan code was ripped from some menu or intro, I wish I could give credit to the original author.
; It has been cleaned up and commented, and the audio has been replaced with higher quality playback.
;
; This is a very lazy screen that spends most of the frame doing NOPs, but it serves its purpose.

; dimensions of the extended screen
usable_lines	equ	272			; Usable lines (roughly)
bytesperline	equ	230
usable_bytes 	equ 	usable_lines*bytesperline
closed_line_bytes equ	160
midline		equ	125
midlineoffset	equ	(midline*bytesperline)
top_line_w	equ	58
screenbase	equ	$6f000
screenbytes	equ	$f500			; Roughly speaking? Must be a multiple of 256 and higher than usable_bytes+160
syncmarker	equ	$000;$777;		; TEMP: show the sync timing

; bricks
brick_rows	equ	5
brick_columns	equ	7
brick_lines	equ	32
brick_byte_w	equ	32
brick_byte_hw	equ	brick_byte_w/2

; balls
numballs	equ	94
numshifts	equ	16
ballpath_item	equ	4
pause_frames	equ	103

; gfx dimensions
fntlines	equ	16
ballines	equ	16
ballwidth	equ	8		; in bytes
ballbytes	equ	ballines*2

logooffsety	equ 9
logoheight 	equ 57
logo1width	equ 13
logo2width  	equ 12

logo1offset	equ (bytesperline*logooffsety)+16
logo2offset	equ (bytesperline*logooffsety)+112

message_width 	equ 22
bytes_per_char 	equ 8
message_top_line equ 82
message_left_offset equ 16
message_offset equ bytesperline*message_top_line+message_left_offset

; sample data
samplefreq	equ	6600			; 6.6kHz (thriller.sam)
numsamples	equ	256
samplebytes	equ	numsamples*8		; 2 channels, 4 bytes per channel
numvolumes	equ	4			; different volume levels

; TODO: Generate a mask for the screen and add the mask offset to path data
; 	then use the mask to have the balls go behind the logo (alternate with in front).
;	Or just redraw the logo in the sync routine... we ought to do something!

	; check for magic value indicating we were called from the bootstrap
	cmp.l #"PDOM",d0
	bne.s standalone

	move.l (sp)+,retadr

standalone:
	; enter supervisor mode and save the stack pointer
	clr.l -(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp
	move.l d0,osp

	; Save the palette
	movem.l $ffff8240.w,d0-d7
	movem.l d0-d7,opal

	; Save the screen address and resolution
	move.l $44e.w,oscr
	move.b $ffff8260.w,d0
	andi.w #%11,d0
	move.w d0,orez

	; Set a new stack pointer
	lea stacktop+bufr,sp

	; Set the palette so we can't see the bricks being drawn until the resolution is correct
	movem.l blacks(pc),d0-d7
	; movem.l wblack(pc),d0-d7			; White-black for debugging
	movem.l d0-d7,$ffff8240.w

	; Set up the screen pointers
	; Adjust by the width of one unopened line - slightly easier to do it this way than adjust in render routines (also kinda dumb)
	move.l #screenbase+closed_line_bytes,a0
	move.l a0,basescr
	move.l a0,d0
	sub.l #screenbytes,a0
	move.l a0,dispbuf
	sub.l #screenbytes,a0
	move.l a0,backbuf
	sub.l #screenbytes,a0
	move.l a0,midbuf

	cmp.l #bufr+path,a0
	bmi.s return

	; Write the base screen address to the shifter video out address
	; Honestly not clear why we do this? Usually write to $44e to change the screen address.
	lsr.w #8,d0		; only high and med bytes of the address used on original ST, stored in odd-addressed bytes
	move.l d0,$ffff8200.w

	; Generate the base screen
	bsr make_base_screen

	; Copy the base screen to the front and back buffers
	bsr copy_base_to_back

	; Pre-draw the message text on the back buffer
	bsr predraw_text

	; Copy the back buffer to the front and mid buffers
	bsr copy_back_buffer

	; preshift the balls
	bsr preshift_balls

	; Set up the ball path
	bsr make_ball_path

	; TEST THE DRAW ROUTINES
; 	move.w #256,d7
; test_loop:
; 	bsr head_ball
; 	bsr tail_ball
; 	dbra d7,test_loop

	bsr prepare_sample

	; Enable interrupts
	bsr.s interrupts_on

	; Set up the sound
	bsr sound_on

	; Wait for space key
digfire	cmp.b #$39,$fffffc02.w
	bne.s digfire

	; Turn off interrupts
	bsr interrupts_off

	; Turn off sound
	bsr sound_off

	clr.w -(sp)
	move.w #11,-(sp)
	trap #13
	addq.l #4,sp	

return	movem.l opal(pc),d0-d7
	movem.l d0-d7,$ffff8240.w

	bsr clearscreens

	move.w orez(pc),-(sp)
	move.l oscr(pc),-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	move.l osp(pc),-(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp

	; check for return address
	move.l retadr(pc),d0
	tst.l d0
	beq.s exit

	move.l d0,a0
	jmp (a0)

exit
	clr.w -(sp)
	trap #1

; Save interrupt vectors and system variables, then install our own
interrupts_on:
	lea mfpstr(pc),a0
	move.b $fffffa07.w,(a0)+
	move.b $fffffa09.w,(a0)+
	move.b $fffffa13.w,(a0)+
	move.b $fffffa15.w,(a0)+
	move.l $70.w,(a0)+
	move.l $118.w,(a0)+
	move.l $68.w,(a0)+
	clr.b $fffffa07.w
	clr.b $fffffa09.w
	bclr #3,$fffffa17.w
	move.l #nkey,$118.w		; Set the keyboard interrupt
	
	move.w #37,-(sp)
	trap #14
	addq.l #2,sp
	
	bset #0,$fffffa07.w
	bset #0,$fffffa13.w
	clr.b $fffffa1b.w
	
	; Install VBL interrupt
	move.l #vbl_main,$70.w
	rts

; Keyboard interrupt - do nothing, we can't spare the time
nkey	rte

; Restore interrupt vectors and system variables
interrupts_off:
	clr.b $fffffa1b.w
	lea mfpstr(pc),a0
	move.b (a0)+,$fffffa07.w
	move.b (a0)+,$fffffa09.w
	move.b (a0)+,$fffffa13.w
	move.b (a0)+,$fffffa15.w
	bset #3,$fffffa17.w
	move.l (a0)+,$70.w
	move.l (a0)+,$118.w
	move.l (a0)+,$68.w
	rts


; Level 2 interrupt routine that carries on playing sample data
synch_l2_audio:
	clr.w d7
	move.b (a4)+,d7			; get the sample volume
	lsl.w #3,d7			; convert to an offset
	move.l (a5,d7.w),(a6)		; Write the soundchip registers
	move.l 4(a5,d7.w),(a6)		; 76-84 cycles (writing to soundchip registers takes longer than normal memory access)

synch_l2_noaudio:
	subq.w	#1,cdown
	rte
cdown	ds.w 1

; Vertical blank handler
vbl_main:
	movem.l d0-d7/a0-a6,-(a7)

	clr.b	$ffff8260.w		; Low resolution

	; Set up the sample output table and the soundchip register in a5&a6
	lea sout(pc),a5
	lea $ffff8800.w,a6

	; Get the current sample playback position
	lea psam(pc),a4
	move.l (a4),a4

	; Sync with level 2 interrupt whilst playing audio
	; NOTE: this uses d7/a4-a6 and does not save or restore them
	move.l #synch_l2_noaudio,$68.w
	move.w #33,cdown
	move.w #$2100,sr

	; Advance frame count
	addq.l #1,$466.w

	lea pall(pc),a0			; Set the palette
	lea $ffff8240.w,a1
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+

	; Don't draw the balls until we've printed the whole message to the base screen
	cmp.l #emessage,pmes
	blt.s syncl2

	; Draw the leading ball
	bsr head_ball

	; Undraw/redraw the tail ball
	bsr tail_ball

	; nop

	; Sync Timer B
syncl2	stop #$2100		; Stop processing until the next level 2 interrupt
	tst.w cdown		; Check if we're done waiting for sync
	bpl.s syncl2

	; move.w #$2700,sr		; No interrupts (16 cycles) ... but we lose an interrupt!
	
	include "syncrot2.s"		; Execute the sync routine
	
; vbl epilogue
evbl
	; switch to black since we are no longer breaking the borders so the image is not aligned
	movem.l blacks(pc),d0-d7
	movem.l d0-d7,$ffff8240.w

	move.w #$2300,sr		; Disable level 2 interrupt

	cmp.l #esam,a4			; Check if the sample wrapped
	blt.s psamok

	lea samp(pc),a4

psamok	move.l a4,psam			; save the sample pointer

	bsr realtime_text			; draw the next character

	cmp.l #emessage,pmes
	blt.s noballs

	; swap the screens	
	move.l backbuf(pc),d0
	move.l midbuf(pc),backbuf
	move.l dispbuf(pc),midbuf
	move.l d0,dispbuf
	move.l d0,$44e.w
	sub.l #closed_line_bytes,d0		; Subtract the unopened line we added from the screen addresses
	lsr.w #8,d0
	move.l d0,$ffff8200.w

noballs
*	move.w	#$777,$ffff8240.w

	movem.l	(a7)+,d0-d7/a0-a6
	rte


sound_on:
	; Read/write mixer control register of the sound chip
	; mask out everything below bit 5 and set bits 0-5... that sounds like an or?
	lea $ffff8800.w,a1
	move.b #7,(a1)
	move.b (a1),op7
	and.w #192,d0
	add.w #63,d0
	move.b d0,2(a1)

	; Write the 'sound up' register sequence to the sound chip
	lea soundup(pc),a0
	moveq #5-1,d0
stup	move.b (a0)+,(a1)
	move.b (a0)+,2(a1)
	dbra d0,stup

	rts

soundup	dc.b 10,0,9,0,8,0,11,0,12,0
sounddn	dc.b 10,0,9,0,8,0,7,%11111111	

sound_off:
	; Write the 'sound down' register sequence to the sound chip
	; TODO: Use movep here?
	lea $ffff8800.w,a1
	lea sounddn(pc),a2
	moveq #4-1,d0
selp	move.b (a2)+,(a1)
	move.b (a2)+,2(a1)
	dbra d0,selp

	; Restore the mixer control register
	move.b #7,(a1)
	move.b op7,2(a1)

	rts
	
; Copy the start of the sample to the end for overflow
prepare_sample:
	movem.l d0/a0-a1,-(sp)

	lea samp(pc),a0
	lea esam-samp(a0),a1
	move #usable_lines-1,d0
.copsam move.b (a0)+,(a1)+
	dbra d0,.copsam

	movem.l (sp)+,d0/a0-a1
	rts

; Generate the base screen data	
make_base_screen:
	; Generate the screen background and add the logo(s)
	move.l basescr(pc),a0
	bsr drawbricks
	bsr drawlogos
	rts

; Make copies of the base screen
copy_base_screen:
	movem.l d7/a0-a2,-(sp)

	move.l basescr(pc),a0
	move.l backbuf(pc),a1
	move.l dispbuf(pc),a2
	move.l midbuf(pc),a3
	move.w #screenbytes/8-1,d7
	; TODO: optimise this with movem.l
cos_1	move.l (a0),(a1)+
	move.l (a0),(a2)+
	move.l (a0)+,(a3)+
	move.l (a0),(a1)+
	move.l (a0),(a2)+
	move.l (a0)+,(a3)+
	dbra d7,cos_1

	movem.l (sp)+,d7/a0-a2
	rts

copy_back_buffer:
	; Copy the back buffer to the display buffer and the mid buffer
	movem.l d0-d7/a0-a3,-(sp)

	move.l backbuf(pc),a0
	move.l dispbuf(pc),a1
	move.l midbuf(pc),a2
	move.l a0,a3
	adda.l #screenbytes,a3
l_copy_back_buf:
	movem.l (a0)+,d0-d7
	movem.l d0-d7,(a1)
	movem.l d0-d7,(a2)
	adda.w #32,a1
	adda.w #32,a2
	cmpa.l a0,a3
	bpl.s l_copy_back_buf

	movem.l (sp)+,d0-d7/a0-a3
	rts

copy_base_to_back:
	; Copy the base screen to the back buffer
	movem.l d0-d7/a0-a2,-(sp)

	move.l basescr(pc),a0
	move.l backbuf(pc),a1
	move.l a0,a2
	adda.l #screenbytes,a2
l_copy_base_to_back:
	movem.l (a0)+,d0-d7
	movem.l d0-d7,(a1)
	adda.w #32,a1
	cmpa.l a0,a2
	bpl.s l_copy_base_to_back

	movem.l (sp)+,d0-d7/a0-a2
	rts


; Clear the screen buffers
clearscreens:
	movem.l d0-d1/a0-a2,-(sp)
	move.l basescr(pc),a0
	move.l dispbuf(pc),a1
	move.l backbuf(pc),a2
	move.w #screenbytes/8-1,d1
	moveq #0,d0
cls_loop:
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a1)+
	move.l d0,(a1)+
	move.l d0,(a2)+
	move.l d0,(a2)+
	dbra d1,cls_loop
	movem.l (sp)+,d0-d1/a0-a2
	rts

; Build the screen data on the back buffer
; a0 - pointer to the screen buffer
drawbricks:
	movem.l d0-d7/a0-a4,-(sp)

	; Clear the unopened line first
	lea -closed_line_bytes(a0),a1
	
	moveq #top_line_w-1,d7
	moveq #0,d6
l_clrtop:
	move.l d6,(a1)+
	dbra d7,l_clrtop

	lea brick(pc),a1
	lea brick_byte_w*brick_lines(a1),a2	; End of the brick data

	move.l a0,a3
	adda.l #usable_lines*bytesperline,a3	; End of the usable screen area
	lea -brick_lines*bytesperline(a3),a4	; End of the usable screen area for the half-brick rows

l_brick_line:	
	cmpa.l a0,a3				; Have we reached the end of the usable screen?
	bmi e_brick_l

	; Write 7 columns of bricks followed by 7 columns of half-offset bricks
	movem.l (a1)+,d0-d7
	movem.l d0-d7,(a0)
	movem.l d0-d7,brick_byte_w(a0)
	movem.l d0-d7,brick_byte_w*2(a0)
	movem.l d0-d7,brick_byte_w*3(a0)
	movem.l d0-d7,brick_byte_w*4(a0)
	movem.l d0-d7,brick_byte_w*5(a0)
	movem.l d0-d7,brick_byte_w*6(a0)

	cmpa.l a0,a4			; Skip the half brick if it is off the bottom of the usable screen area
	bmi.s no_half_brick

	movem.l d4-d7,bytesperline*brick_lines(a0)
	movem.l d4-d7,bytesperline*brick_lines+brick_byte_w(a0)
	movem.l d4-d7,bytesperline*brick_lines+brick_byte_w*2(a0)
	movem.l d4-d7,bytesperline*brick_lines+brick_byte_w*3(a0)
	movem.l d4-d7,bytesperline*brick_lines+brick_byte_w*4(a0)
	movem.l d4-d7,bytesperline*brick_lines+brick_byte_w*5(a0)
	movem.l d4-d7,bytesperline*brick_lines+brick_byte_w*6(a0)
	movem.l d0-d3,bytesperline*brick_lines+brick_byte_hw(a0)
	movem.l d0-d3,bytesperline*brick_lines+brick_byte_hw+brick_byte_w(a0)
	movem.l d0-d3,bytesperline*brick_lines+brick_byte_hw+brick_byte_w*2(a0)
	movem.l d0-d3,bytesperline*brick_lines+brick_byte_hw+brick_byte_w*3(a0)
	movem.l d0-d3,bytesperline*brick_lines+brick_byte_hw+brick_byte_w*4(a0)
	movem.l d0-d3,bytesperline*brick_lines+brick_byte_hw+brick_byte_w*5(a0)
	movem.l d0-d3,bytesperline*brick_lines+brick_byte_hw+brick_byte_w*6(a0)

no_half_brick:
	adda.w #bytesperline,a0

	cmpa.l a1,a2				; Have we reached the end of the brick data?
	bgt l_brick_line

	suba.w #brick_byte_w*brick_lines,a1	; Reset the brick pointer
	adda.w #brick_lines*bytesperline,a0	; Skip the half brick line
	bra l_brick_line

e_brick_l:
	movem.l (sp)+,d0-d7/a0-a4
	rts

; Draw the logo on the screen.
; It's stored/drawn in parts because it's wider than the normal screen resolution.
; a0 - pointer to the screen address
drawlogos
	movem.l d0-d7/a0-a3,-(sp)

	; draw the 'CYBER' logo
	lea cyber(pc),a1
	lea logo1offset(a0),a2
	moveq #logo1width-1,d6
	moveq #logoheight-1,d7
	bsr.s logoline_l

	; draw the second logo
	lea punks(pc),a1
	lea logo2offset(a0),a2
	moveq #logo2width-1,d6
	moveq #logoheight-1,d7
	bsr.s logoline_l

	movem.l (sp)+,d0-d7/a0-a3
	rts

logoline_l
	move.l a2,a3		; Working screen address
	move.l d6,d5		; Counter for the width of the logo

logocol_l
	movem.w (a1)+,d0-d3	; Read 16 pixels of pixel data (4 bitplanes)

	; Generate the mask
	move.w d0,d4
	or.w d1,d4
	or.w d2,d4
	or.w d3,d4
	not.w d4

	; Cut a hole for it
	and.w d4,(a3)
	and.w d4,2(a3)
	and.w d4,4(a3)
	and.w d4,6(a3)

	; Or the pixel data
	or.w d0,(a3)+
	or.w d1,(a3)+
	or.w d2,(a3)+
	or.w d3,(a3)+
	dbra d5,logocol_l

	lea bytesperline(a2),a2
	dbra d7,logoline_l
	rts

; Pre-draw the text on the back buffer
predraw_text:
	movem.l d0-d7/a0-a4,-(sp)

	lea message(pc),a0		; message text
	lea addtxt(pc),a4		; offset add table
	move.l #message_offset,d4	; screen offset

predraw_text_char_l:
	move.l backbuf(pc),a1
	; move.l dispbuf(pc),a2
	add.l d4,a1
	; add.l d4,a2
	
	; Read the character and calculate the offset in the font
	moveq #0,d0
	move.b (a0)+,d0
	sub.b #"A",d0
	bmi.s predraw_text_nchar
	lsl.w #7,d0
	lea fnt3(pc),a3
	add.w d0,a3

	moveq #fntlines-1,d7

predraw_text_line_l:
	; Generate the 32-pixel mask
	move.l (a3)+,d0
	move.l (a3)+,d1
	move.l d0,d2
	or.l d1,d2
	move.l d2,d3
	swap d2
	or.l d3,d2
	not.l d2

	; draw on first screen
	and.l d2,(a1)
	or.l d0,(a1)+
	and.l d2,(a1)
	or.l d1,(a1)+
	lea bytesperline-8(a1),a1

	; draw on second screen
	; and.l d2,(a2)
	; and.l d2,4(a2)
	; or.l d0,(a2)
	; or.l d1,4(a2)
	; lea bytesperline(a2),a2

	dbra d7,predraw_text_line_l
	
predraw_text_nchar
	add.w (a4)+,d4
	cmp.l #eadd,a4
	blt.s endmsf

	lea addtxt(pc),a4

endmsf	
	cmp.l #emessage,a0
	blt.s predraw_text_char_l

	movem.l (sp)+,d0-d7/a0-a4
	rts

; Draw the message text on the screen during the interrupt
; We draw directly to the base screen, we aren't using the double buffer yet
realtime_text:
	cmp.l #emessage,pmes
	blt.s hasmes
	rts

hasmes	
	; Initial delay before the message is shown
	tst.b delay
	beq.s nodelay

	subq.b #1,delay
	rts

nodelay
	move.l pmes(pc),a0
	move.l basescr(pc),a1
	add.l offset(pc),a1

	; Read the character and calculate the offset in the font
	moveq #0,d0
	move.b (a0)+,d0
	move.l a0,pmes

	sub.b #"A",d0
	bmi.s imes_nchar
	lsl.w #7,d0
	lea fnt3(pc),a3
	add.w d0,a3

	moveq #fntlines-1,d4
imes_line	
	; Generate the 32-pixel mask
	move.l (a3)+,d0
	move.l (a3)+,d1
	move.l d0,d2
	or.l d1,d2
	move.l d2,d3
	swap d2
	or.l d3,d2
	not.l d2

	; draw the character
	and.l d2,(a1)
	and.l d2,4(a1)
	or.l d0,(a1)
	or.l d1,4(a1)

	lea bytesperline(a1),a1
	dbra d4,imes_line
	
imes_nchar
	; increment the screen offset
	move.l offset(pc),d0
	move.l padd(pc),a0
	add.w (a0)+,d0
	move.l d0,offset
	move.l a0,padd
	cmp.l #eadd,a0
	blt.s endms

	move.l #addtxt,padd

endms	rts

; Preshift ball and generate code to draw them
; Re-uses the buffer for the shifted data and mask for each shift
preshift_balls	
	lea ballog(pc),a5
	lea bufr+code,a2
	lea bufr+udraw,a4
	lea bufr+rlist,a6

	moveq #numshifts-1,d6
shifs	move.l a2,(a6)+
	move.l a4,(a6)+
	lea (a5),a0
	bsr.s shif			; Preshift the ball
	bsr.s maskmak			; Generate the mask data
	bsr codegen			; Generate the code to draw and undraw the balls
	dbra d6,shifs
	rts

; Preshift the ball from a 16 pixel source into a 32 pixel window
; a0 = source, a1 = destination, d6 = number of pixels to shift by
shif	movem.l d0-d1/a0-a1,-(sp)

	lea bufr+ballz,a1            ; Destination buffer
	moveq #ballines-1,d1         ; Loop counter
shif_l	moveq #0,d0
	move.w (a0)+,d0              ; Load 16-bit source data
	lsl.l d6,d0                  ; Shift by the value in d6
	move.w d0,8(a1)              ; Store lower half of shifted result
	swap d0
	move.w d0,(a1)               ; Store upper half

	; repeat for the other 3 bitplanes
	moveq #0,d0
	move.w (a0)+,d0
	lsl.l d6,d0
	move.w d0,10(a1)
	swap d0
	move.w d0,2(a1)

	moveq #0,d0
	move.w (a0)+,d0
	lsl.l d6,d0
	move.w d0,12(a1)
	swap d0
	move.w d0,4(a1)

	moveq #0,d0
	move.w (a0)+,d0
	lsl.l d6,d0
	move.w d0,14(a1)
	swap d0
	move.w d0,6(a1)

	adda.w #16,a1                ; Next line
	dbra d1,shif_l

	movem.l (sp)+,d0-d1/a0-a1    ; Restore registers
	rts


; Generate mask data for all the shifted balls
; A mask is a single 32 bit value that contains two copies of the logical NOR of the 4 bitplanes of a 16-pixel 
maskmak	movem.l d0-d1/a0-a2,-(sp)
	lea bufr+ballz,a0
	lea bufr+masp,a1
	move.l a1,a2
loopmsk	move.l (a0)+,d0
	or.l (a0)+,d0
	move.l d0,d1
	swap d1
	or.l d1,d0
	not.l d0
	move.l d0,(a1)+
	cmp.l a2,a0
	ble.s loopmsk
	movem.l (sp)+,d0-d1/a0-a2
	rts

; Generate the code to draw the balls
; a2 = output buffer for the draw routine
; a4 = output buffer for the undraw routine
codegen	movem.l d0-d7/a0-a1/a3/a5-a6,-(sp)

	lea bufr+ballz,a0
	lea bufr+masp,a1

	moveq #0,d0		; Current screen offset
	moveq #8,d2		; Alternate between advancing 8 bytes and one line minus 8 bytes
	move.w #bytesperline-8,d3

	moveq #ballines*2,d6		; 32 pixels * number of lines

lincd
	; Generate the code to draw 16 pixels
	move.l (a1)+,d1				; Read the next mask word
	beq.s solid				; Mask is solid, full word write

	cmp.l #-1,d1				; Solid mask, nothing to draw
	beq.s common

 	move.w #$2a9,(a2)+			; andi.l #xxx,d0(a1)
 	move.l d1,(a2)+
 	move.w d0,(a2)+
 	move.w #$2a9,(a2)+			; andi.l #xxx,d0+4(a1)
 	move.l d1,(a2)+
 	move.w d0,(a2)
 	addq.w #4,(a2)+

	move.w #$a9,(a2)+			; ori.l #xxx,d0(a1)
 	move.l (a0),(a2)+
 	move.w d0,(a2)+
	move.w #$a9,(a2)+			; ori.l #xxx,d0+4(a1)
 	move.l 4(a0),(a2)+
 	move.w d0,(a2)
 	addq.w #4,(a2)+

	; Generate the code to undraw 16 pixels
	move.w #$2368,(a4)+			; move.l d0(a0),d0(a1)
	move.w d0,(a4)+
	move.w d0,(a4)+
	move.w #$2368,(a4)+			; move.l d0+4(a0),d0+4(a1)
	move.w d0,(a4)
	addq.w #4,(a4)+
	move.w d0,(a4)
	addq.w #4,(a4)+

common	addq.l #8,a0				; Advance 16 pixels
	add.w d2,d0				; Advance the screen offset
	exg d2,d3				; Swap the 16 pixel/next line offsets
	dbra d6,lincd

	move.w #$4e75,(a2)+		; rts
	move.w #$4e75,(a4)+		; rts

	movem.l (sp)+,d0-d7/a0-a1/a3/a5-a6
	rts

solid	move.w #$237c,(a2)+			; move.l #xxx,d0(a1)
	move.l (a0),(a2)+
	move.w d0,(a2)+
	move.w #$237c,(a2)+			; move.l #xxx,d0+4(a1)
	move.l 4(a0),(a2)+
	move.w d0,(a2)
	addq.w #4,(a2)+
	
	move.w #$2368,(a4)+			; move.l d0(a0),d0(a1)
	move.w d0,(a4)+
	move.w d0,(a4)+
	move.w #$2368,(a4)+			; move.l d0+4(a0),d0+4(a1)
	move.w d0,(a4)
	addq.w #4,(a4)+
	move.w d0,(a4)
	addq.w #4,(a4)+
	bra.s common

; Draw the ball in a2
draw_ball:
	move.w (a2)+,d0		; Read the next ball path offset

	beq.s nobl		; If the path is empty, don't draw the ball

	move.l backbuf(pc),a1	; Get the middle line of the back buffer
	lea midlineoffset(a1),a1
	add.w d0,a1

	move.w (a2)+,d1		; Get the shift index/offset
	lea bufr+rlist,a0	; Get the draw routine address
	move.l (a0,d1.w),a0
	jsr (a0)

nobl	rts

; Draw the leading ball
head_ball:
	lea headball_p(pc),a1
	move.l (a1),a2			; Advance the position in the path
	addq.l #ballpath_item,a2		
	cmp.l endpath_p(pc),a2		; Check for the path end
	blt.s headball_nowrap

	lea bufr+path,a2		; Wrap without the pause

headball_nowrap	
	move.l a2,(a1)			; Save the updated ball path pointer

	bra.s draw_ball

; Undraw the last two balls in the path and redraw the last-2 ball
tail_ball:
	lea unball_ptr(pc),a1		; Update the unball path pointer
	move.l (a1),a2
	addq.l #ballpath_item,a2

	cmp.l endpath_p(pc),a2
	blt.s tail_nowrap

	lea bufr+path,a2

tail_nowrap	
	move.l a2,(a1)			; Save the updated unball path pointer

	; Undraw the trailing ball
	bsr.s undraw_ball

	; undraw a second ball (because we have three buffers)
	move.l unball_ptr(pc),a2
	addq.l #ballpath_item,a2
	bsr.s undraw_ball

	; Redraw the last-2 ball
	move.l unball_ptr(pc),a2
	add.l #16,a2
	bra.s draw_ball

; Undraw the ball at a2
undraw_ball
	move.w (a2)+,d0			; Read the next ball path offset
	beq.s no_unball
	move.w (a2)+,d1

	move.l backbuf(pc),a1		; Get the middle line of the back buffer
	lea midlineoffset(a1),a1
	add.w d0,a1			; Add the ball path offset

	lea bufr+rlist,a0		; Get the undraw routine address
	move.l 4(a0,d1.w),a2
	move.l basescr(pc),a0		; Get the base screen address
	lea midlineoffset(a0),a0
	add.w d0,a0
	jsr (a2)			; Call the undraw routine
	
no_unball
	rts

; Precalculate the screen offset (from the midline) and shift index for each path position
make_ball_path	
	lea bufr+pause,a0		; Start of the ball path including the pause before drawing
	lea bufr+path,a1		; Start of the actual path data

	; Fill the buffer with zeroes up to the pause point
	moveq #0,d0
kpauz	move.l d0,(a0)+
	move.l d0,(a0)+
	cmp.l a0,a1
	bgt.s kpauz

	; Load the path sequence and path table addresses
	lea path_sequence(pc),a0	; Path source data
	lea bufr+path,a1

mpaf_1	moveq #0,d0			; Read the next path segment ID
	move.b (a0)+,d0
	lsl.w #2,d0			; Multiply by 4 to get the offset in the paths list

	lea plist(pc),a2		; Get the path segment address
	move.l 4(a2,d0.w),a3		; End of the path segment
	move.l (a2,d0.w),a2		; Start of the path segment
mpaf2	move.w (a2)+,(a1)+		; Copy the path segment to the buffer
	cmp.l a2,a3			; Check for the end of the path segment
	bgt.s mpaf2

	cmp.l #epaf,a0			; Check for the end of the path sequence
	blt.s mpaf_1

	move.l a1,endpath_p	; Save the end of path pointer

	; Copy the first segment again at the end so that we don't have to check for wrap on every ball
	lea path_sequence(pc),a0
	clr.w d0
	move.b (a0)+,d0
	lsl.w #2,d0
	lea plist(pc),a2
	move.l 4(a2,d0.w),a3
	move.l (a2,d0.w),a2
mpaf2b	move.w (a2)+,(a1)+
	cmp.l a2,a3
	bgt.s mpaf2b
	rts


retadr	dc.l 0
opal	ds.l 8
osp		ds.l 1
oscr	ds.l 1
orez	ds.w 1
op7		ds.w 1
mfpstr	ds.l 10

ortw	ds.w 16

psam	dc.l samp
pmes	dc.l message
padd	dc.l addtxt

headball_p	dc.l bufr+pause+(numballs*4)
unball_ptr	dc.l bufr+pause
endpath_p	ds.l 1

plist	dc.l path1,path2,path3,lpath	; path segment address table

path_sequence	dc.b 1,1,0,0,2,2,0,0
epaf	dc.w 0

basescr	dc.l screenbase			; the base screen with no balls
backbuf	dc.l screenbase-screenbytes
dispbuf	dc.l screenbase-screenbytes*2
midbuf	dc.l screenbase-screenbytes*3

offset	dc.l message_offset

; offset to add to screen address for each character in the message
addtxt	dcb.w message_width,bytes_per_char
	dc.w bytesperline*fntlines-(message_width*bytes_per_char)	; offset to next line
eadd

delay	dc.b 100

message	dc.b "WELCOMEf MY FRIENDf TO "
	dc.b "   THE PLEASUREDEMO    "
	dc.b "                       "
	dc.b "HIT SPACE FOR MAIN MENU"
	dc.b "                       "
	dc.b " ON MENU USE UPf DOWN  "
	dc.b "  AND SPACE TO SELECT  "
	dc.b "        SCREENS        "
	dc.b "                       "
	; dc.b " TRY FUNCTION KEYS ON  "
	; dc.b "     MOST SCREENS      "
	; dc.b "                       "
emessage

looped	ds.w 1
wblack	dc.w $777
blacks	ds.l 8

fnt3	incbin "1616fn3b.dat"
ballog	incbin "ball.dat"
path1	incbin "track.pth" 
path2	incbin "track2.pth" 
path3	incbin "track3.pth" 
lpath	ds.w 1

cyber	incbin "cyber.dat"
punks	incbin "punks.dat"
brick	incbin "brick.dat"
pall	incbin "intro.pal"
	EVEN
sout	incbin "bigsout.tab"	; Sample output table
	EVEN

samp	incbin "pdome5.sam"
esam	ds.b usable_lines

	EVEN

bufr	RSRESET
stack		rs.w 500
stacktop	rs.w 20

rlist	rs.l 2*numshifts		; draw/undraw routine list for each shift of the ball
ballz	rs.w ballines*ballbytes		; buffer for shifted ball data (re-used for each shift)
masp	rs.w ballines*ballbytes		; buffer for shifted mask data (re-used for each shift)
code	rs.w 15000/2			; generated code to draw the shifted balls
udraw	rs.w 6000/2			; generated code to undraw the balls
pause	rs.l pause_frames*2		; Empty path at the start
path	rs.w 1				; Ball path data (size is immaterial)
