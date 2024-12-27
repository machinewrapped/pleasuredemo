; The Ultramega Scroller
; Originally written in 1990 by Zax as Colorshock 2, a riff on the TCB Colorshock demo
; Refreshed in 1991 with a more aesthetically pleasing colour scheme and new name
; Updated again in 1992 with better sample playback and a faster scroller (in pixel terms)
; Updated in 2024 with resampled audio (not included in the Github source) and a few more lines of scroller (possible by doing more work in the VBLANK)
; Also commented the code, added named constants and improved labels and use of subroutines

samplerate equ 15650		; Sample rate of the sample data (TODO: reduce by 200Hz to account for the lines where no sound is played?)

; Number of samples in each loop of the sample data
loop1	equ 33850
loop2	equ 34574
loop3	equ 33941
loop4	equ 69313
loop4a 	equ 34962
loop5	equ 69079
loop5a	equ 34555

looppoint1	equ loop1
looppoint2	equ loop1+loop2
looppoint3	equ loop1+loop2+loop3
looppoint4	equ loop1+loop2+loop3+loop4
looppoint4a	equ loop1+loop2+loop3+loop4a
looppoint5	equ loop1+loop2+loop3+loop4+loop5
looppoint5a	equ loop1+loop2+loop3+loop4+loop5a

screen_lo	equ $72000	; Screen address in low memory
screen_hi	equ $d0000	; Screen address in high memory
screen_size	equ $d000	; Size of the screen in bytes (we open the top border even though we don't draw anything in it)
line_bytes	equ 160		; Number of bytes in a line of the screen

scancode_space	equ $39		; Scancode for the space key
scancode_up	equ $48		; Scancode for the up arrow key
scancode_down	equ $50		; Scancode for the down arrow key

numlines 	equ 136		; Number of lines we can draw (actually we draw 2 lines at a time, so it is 272)
samples_to_skip	equ 6		; Number of samples to skip for each line we don't draw

bg_width 	equ 58		; Width of a line in the background colour table
bg_height	equ 256		; Height of the background colour table
bg_maxspeed 	equ 32
bg_maxchange	equ bg_width*bg_maxspeed	; Maximum change in the background colour table per frame

bgcol_lines	equ 196		; Number of lines in the background colour table
bgcol_size	equ bgcol_lines*bg_width	; Size of the background colour table in bytes

bigfont_h 	equ 16		; Height of the big font (in colour blocks)
bigfont_w 	equ 27		; Width of the big font (in colour blocks)
bigfont_chars	equ 27		; Number of characters in the big font (including space)
bigfont_lines	equ bigfont_h*bigfont_chars	; Total number of lines in the big font

bfcol_lines	equ 128				; Number of lines in the font colour table
bfcol_size	equ bg_width*bfcol_lines	; Size of the font colour table in bytes
bfcol_offset	equ 8*bg_width			; Offset in the font colour table to align with the scroller

litmes_line	equ 220		; Line offset of the little message
litmes_offset	equ litmes_line*line_bytes

logo_line	equ 38		; Line to draw the logo on
logo_x		equ 7*8		; X position of the logo in 16 pixel blocks
logo_offset	equ logo_line*line_bytes+logo_x
logo_height	equ 62		; Height of the logo in lines

draw_routine_bufsize equ 152000	; Size of the buffer for the display routines

	; check for magic value indicating we were called from the bootstrap
	cmp.l #"PDOM",d0
	bne.s standalone

	move.l (sp)+,retadr
	bra.s standalone

retadr	dc.l 0

standalone
	; Enter supervisor mode
	clr.l -(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp

	; Save the system state
	move.l d0,osp
	move.w sr,osr

	; Save the screen address and resolution
	move.l $44e.w,oscr
	move.b $ffff8260.w,d0
	andi.w #%11,d0
	move.w d0,orez

	; Save the palette
	movem.l $ffff8240.w,d0-d7
	movem.l d0-d7,opal

	; Wipe memory
	bsr clear_memory

	; Set up the stack
	lea bufr+stack_top,sp

	move.w #255,d7
littst	bsr litscr
	dbra d7,littst

	; Set the screen to black using our clean memory
	; move.w #$777,bufr	; TEMP: set white background for debugging
	movem.l bufr,d0-d7
	movem.l d0-d7,$ffff8240.w
	
	; Set low resolution and move the screen down in memory
	clr.w -(sp)
	move.l #screen_lo,-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	; Read MMU memory configuration to see how much memory we have
	move.b $ffff8001.w,d0
	andi.w #$f,d0
	tst.b d0
	beq hmeg
	cmp.b #1,d0
	beq hmeg
	cmp.b #4,d0
	beq hmeg

	; Set the screen address to high memory (we have the memory)
	clr.w -(sp)
	pea screen_hi
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	; print message about loading one mb samples
	pea onemt(pc)
swallow	move.w #9,-(sp)
	trap #1
	addq.l #6,sp

	; Install palette fade interrupt in the VBL interrupt list (guess nobody else is using it)
	move.l $4d2.w,o4d2
	move.l #pup,$4d2.w

	; Try to load the sample data
	lea filenam(pc),a5
	lea bufr+samluv,a6
	bsr lfile
	tst.l d7
	bpl.s nmsorry

	pea nofile(pc)
	move.w #9,-(sp)
	trap #1
	addq.l #6,sp

	; Wait for a keypress
	move.w #7,-(sp)
	trap #1
	addq.l #2,sp

	; Cancel the palette fade
	; move.l o4d2,$4d2.w

	; bra sadpunk

	; Let's run the screen anyway, we can zero out the sound out table to avoid playing noise
	lea sout(pc),a0
	lea esout(pc),a1
	moveq #0,d0
.nosam	move.w d0,(a0)+
	cmpa.l a1,a0
	ble.s .nosam

nmsorry	move.l d7,retsz

	; Fade text to white
	move.l #$777,pset+2

	bsr clear_screen

	bsr init_loops

	bsr sound_on

	bsr init_interrupts

	; Draw the logo
	bsr putlog

	; Build font data
	bsr mfont

	; Build the routines to draw the font in colours
	bsr mrouts

	; Make the colour tables
	bsr makpal
	bsr makpal3

ready_to_go:
	; Install the real VBL handler
	move.l #vblmain,$70.w

	; Install null keyboard handler
	move.l #nulkey,$118.w

	; Handle input until something says we should quit
	bsr handle_input

time_to_quit:
	; Epilogue
	bsr restore_interrupts

	bsr sound_off

sadpunk	movem.l opal,d0-d7			; Restore the original palette
	movem.l d0-d7,$ffff8240.w

	move.w orez(pc),-(sp)	; Restore the original screen address and resolution
	move.l oscr(pc),-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	move.l o4d2,$4d2.w			; Restore VBL interrupt

	move.w osr(pc),sr			; Restore the status register

	; exit supervisor mode
	move.l osp,-(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp
	
	; check for return address
	move.l retadr,d0
	tst.l d0
	beq.s quit

	; Return to the bootstrap
	move.l d0,a0
	jmp (a0)

quit	; Exit the program
	clr.w -(sp)
	trap #1

handle_input:
	; Wait for the next level 4 interrupt (vsync)
	stop #$2300
	
	; wait for a keypress
	move.b $fffffc02.w,d0
	bmi.s handle_input

	cmp.b #scancode_space,d0	; test for the space key
	beq xit

	cmp.b #scancode_down,d0		; is it the down arrow?
	bne.s nd

	cmp.l #-bg_maxchange,bgad+2	; check whether we can change the scroll speed (background add)
	blt.s handle_input
	sub.l #bg_width,bgad+2		; add bg_width to the background add (change scroll speed)
	bra.s dag

nd	cmp.b #scancode_up,d0		; is it the up arrow?
	bne.s handle_input

	cmp.l #bg_maxchange,bgad+2	; check whether we can change the scroll speed (background add)
	bgt.s handle_input
	add.l #bg_width,bgad+2		; subtract bg_width from the background add (change scroll speed)
	
dag	move.l $466.w,d0		; Get the current vbl count
	addq.l #8,d0			; Add 8 to the vbl count (this is to delay the key repeat)

wvbl	cmp.l $466,d0			; Wait until the frame count catches up
	bgt.s wvbl

	bra.s handle_input		; Return to the wait key loop

xit	rts

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

; Set the absolute address of the loop points
init_loops:
	movem.l d0/a0-a1,-(sp)

	move.l #bufr+samluv,d0
	lea sptr(pc),a0
	lea esptr(pc),a1
.loop_l add.l d0,(a0)+
	cmp.l a1,a0
	bne.s .loop_l

	movem.l (sp)+,d0/a0-a1
	rts

init_interrupts:
	lea mfpstr(pc),a0

	move.w #$2700,sr		; Disable interrupts

	move.l $68.w,(a0)+		; Save the level 2 interrupt handler
	
	move.l $70.w,(a0)+		; Save current VBL handler and install a null VBL handler

	move.l $118.w,(a0)+		; Save MFP keyboard interrupt handler

	; Save MFP interrupt configuration
	move.b $fffffa07.w,(a0)+
	move.b $fffffa09.w,(a0)+
	move.b $fffffa0b.w,(a0)+
	move.b $fffffa0d.w,(a0)+
	move.b $fffffa0f.w,(a0)+
	move.b $fffffa11.w,(a0)+
	move.b $fffffa13.w,(a0)+
	move.b $fffffa15.w,(a0)+

	; Install null VBL handler to open up the top border until we're ready to scroll
	move.l #nulvbl,$70.w

	; Clear MFP interrupt mask A&B
	clr.b $fffffa13.w
	clr.b $fffffa15.w

	move.w #$2300,sr		; Enable interrupts
	rts

restore_interrupts:
	move.w #$2700,sr		; Disable interrupts

	lea mfpstr(pc),a0
	move.l (a0)+,$68.w		; Restore the level 2 interrupt handler
	move.l (a0)+,$70.w		; Restore the original VBL handler
	move.l (a0)+,$118.w		; Restore the MFP keyboard interrupt handler

	; Restore the MFP interrupt configuration
	move.b (a0)+,$fffffa07.w
	move.b (a0)+,$fffffa09.w
	move.b (a0)+,$fffffa0b.w
	move.b (a0)+,$fffffa0d.w
	move.b (a0)+,$fffffa0f.w
	move.b (a0)+,$fffffa11.w
	move.b (a0)+,$fffffa13.w
	move.b (a0)+,$fffffa15.w

	move.w #$2300,sr		; Enable interrupts
	rts

; Null keyboard handler - can't spare the cycles to do anything
nulkey	rte

; VBL handler with no sampled sound output
nulvbl	movem.l d0-d7/a0-a6,-(sp)
	move.w sr,-(sp)

	; Switch to low resolution
	clr.b	$ffff8260.w

	; install a countdown handler  Level 2 interrupt
	move.w #$21,cdown
	move.l $68.w,-(sp)
	move.l #synch_l2_noaudio,$68.w
	move.w #$2100,sr
	
nulvbl_syncl2
	stop #$2100
	tst.w cdown
	bpl.s nulvbl_syncl2		; Wait until the countdown reaches zero

	; Open the top border to give the logo its correct position
	move.w #$17,d0
syncdel	dbf d0,syncdel

	move.b #0,$ffff820a.w	; 60hz
	dcb.w 16,$4e71		; 16 nops
	move.b #2,$ffff820a.w	; 50hz
	
	addq.l #1,$466.w

	; Restore system state
	move.l (sp)+,$68.w
	move.w (sp)+,sr
	movem.l (sp)+,d0-d7/a0-a6
	rte

; Level 2 interrupt routine that carries on playing sample data
synch_l2_audio:
	clr.w d7
	move.b (a4)+,d7		; Assume nobody else will touch a4,a5,a6 or care about d7
	add.b #$80,d7		; Convert to unsigned byte
	lsl.w #3,d7
	move.w 4(a5,d7.w),d6	; Look up the sound chip register values
	move.l (a5,d7.w),d7
	movep.l d7,0(a6)		; Move peripheral data - writes to alternate bytes
	movep.w d6,0(a6)

synch_l2_noaudio:
	subq.w	#1,cdown
	rte
cdown	ds.w 1

; The real VBL handler - plays sound
vblmain	movem.l d0-d7/a0-a6,-(sp)
	move.w sr,-(sp)

	; Set up the sample output table and the soundchip register in a5&a6
	lea sout(pc),a5
	lea $ffff8800.w,a6

	; Get the current sample playback position
	move.l start(pc),a4

	; Sync with level 2 interrupt whilst playing audio
	; NOTE: this uses d6-d7/a5-a6 and does not save or restore them
	move.l #synch_l2_audio,$68.w
	move.w #$21,cdown
	move.w #$2100,sr

	; Advance frame count
	addq.l #1,$466.w

	; Check whether the end of the current sample has been reached, and advance to the next sample
	cmp.l endsm,a4
	blt.s vbl_syncstart
	addq.l #1,songp

chme	cmp.l #esong,songp	; Check whether the end of the song has been reached (self-modifying code)
	blt.s vbl_norepeat

chme2	move.l #song,songp	; Loop back to the start of the song

vbl_norepeat	
	move.l songp,a0		; Get the next sample number to use (self-modifying code)
	clr.w d0
	move.b (a0),d0
	lsl.w #3,d0

	lea sptr,a0		; Look up the start of the sample data
	add.w d0,a0
	sub.l endsm,a4		; Subtract the previous loop end to get a relative offset
	add.l (a0),a4		; Add the new loop start to the sample pointer
	move.l 4(a0),endsm	; Save the new loop end

vbl_syncstart:
	; Scroll the background (uses no registers)
	bsr colourscroll

	; Update the big scroller (uses d0,a0-a1)
	bsr bigscrl

	; Update the little scroller (uses d0-d1/a0-a1)
	bsr litscr

	; Set up addresses for the sync routine
	movea.w #$8209,a1		; Video address pointer
	movea.w #$8240,a0		; Video palette register
	move.l bgcol_pointer,a2		; Background colour table pointer
	move.l display_routine,a3	; Display routine list

vbl_syncl2
	stop #$2100
	tst.w cdown
	bpl.s vbl_syncl2	; Wait for the countdown to reach zero
	
	; Disable level 2 interrupt
	move.w #$2300,sr

	; Wait until the end of the scanline
	move.w	#12,d2
vbl_delay dbra d2,vbl_delay

	; Open the top border
	move.b #0,$ffff820a.w
	dcb.w 16,$4e71		; 16 nops
	move.b #2,$ffff820a.w

	moveq #6,d2
vbl_delay2 dbra d2,vbl_delay2

*	move.w #$200,$ffff8240.w

*	bra snarf
	
; Wait for video adress pointer register to turn positive - this means the screen is being drawn
sync	move.b (a1),d0
	bmi.s sync

	moveq #15,d1			; Subtract from 15
	and.b d1,d0			; Mask off the higher bits
	sub.b d0,d1			; Smaller value for bigger offsets
	lsl.w d1,d0			; Variable shift to sync (4 cycles for every 2 steps)

	moveq #25,d0
vbl_delay3 dbra d0,vbl_delay3		; Sync delay

	move.l bfcol_pointer,a5		; Font colour table

	move.l a7,ostck		; Save the stack pointer
	lea sout,a7		; Use a7 for sample output table pointer
	
	; Jump to the first routine in the display routine list
	move.l (a3)+,a1
	jmp (a1)

vbl_end	clr.w (a0)		; We're done with the display routine list

	move.l ostck,a7		; Restore the stack pointer in a7

snarf	move.w (a7)+,sr			; Restore the status register

	; lea samples_to_skip(a4),a4	; Advance the sample pointer to account for the lines where we aren't playing any sound
	move.l a4,start			; Save the new sample pointer

*	move.w #$777,$ffff8240.w

	; restore the system state
	movem.l (sp)+,d0-d7/a0-a6
 	rte

; Advance the pointers in the colour table
; The amount to add is adjusted by the keyboard handler... there are bg_width colour changes per line
colourscroll:
bgad	add.l #bg_width*1,bgcol_pointer			; Increment the background colour table pointer (self-modifying code)
	cmp.l #bufr+bgcols+bgcol_size-1,bgcol_pointer	; Check whether the background colour pointer has reached line 196
	blt.s kick

	move.w #1,goodin			; Record the fact we have filled the colour table at least once
	sub.l #bgcol_size,bgcol_pointer		; Jump back by the size of the colour table
	bra.s kick2

kick	tst.w goodin	; check whether this is our first kick (if not, the second half of the table is not yet full)
	beq.s kick2

	cmp.l #bufr+bgcols,bgcol_pointer		; Check whether we're on the first line... if so, we just looped?
	bgt.s kick2

	add.l #bgcol_size,bgcol_pointer		; Advance the background colour pointer to the second copy of the colour table

kick2	add.l #bg_width*2,bfcol_pointer		; Scroll the font colour pointer by 2 lines

	cmp.l #bufr+umscols+bfcol_size-1,bfcol_pointer	; Check whether colour pointer has reached the end of the colour table
	blt.s ebgscrl

	sub.l #bfcol_size,bfcol_pointer		 ; Jump back bfcol_lines

ebgscrl	rts

; Big scroller
bigscrl	subq.b #1,sflg			; 8 lines per block (stretch the font)
	bne.s sblok
	move.b #4,sflg			; We add 2 lines at a time so 4 frames per block

	addq.l #4,routine_pointer	; Advance the draw routine pointer
	subq.b #1,bflg			; Decrement the character lines counter
	bne.s sblok			; We're still in a character

	move.b #bigfont_h,bflg		; Start a new character

	lea p_bigmess(pc),a0		; Load the address of the message position
	addq.l #1,(a0)			; Advance one character in the big message

	cmp.l #e_bigmess,(a0)		; Check if we've looped
	blt.s scrl_nowrap

	move.l #bigmess+5,(a0)		; Loop the message, minus the delay spaces

scrl_nowrap
	move.l (a0),a0			; Get the address of the current character
	clr.l d0
	move.b (a0),d0			; Get the character

	cmp.b #" ",d0			; Check if it's a space
	beq.s scrl_space

	sub.b #"A"-1,d0			; Subtract an A
	lsl.l #6,d0			; Multiply by 64 (4 x bigfont_h)
	add.l #bufr+jumplist,d0		; Calculate the address of the draw routine for the character
	move.l d0,routine_pointer	; Store it

sblok	move.l routine_pointer(pc),a0	; Get the draw routine for the current character
	move.l (a0),a0

	move.l display_routine(pc),a1	; Write the draw routine address to the display routine buffer... twice
	move.l a0,(a1)+
	move.l a0,(a1)+
	move.l a1,display_routine	; Update the position in the display routine buffer

	move.l a0,numlines*4(a1)	; Write a copy of the display routine to the mirror display buffer
	move.l a0,(numlines+1)*4(a1)

	move.l #vbl_end,(numlines+2)*4(a1)	; Write the VBL end address to a point in the display routine buffer

	cmp.l #bufr+routs+(4*(numlines+2)),a1	; Check if we've reached the end of the display routine buffer
	blt.s scrl_no_buffer_wrap

	move.l #bufr+routs,display_routine
	move.l #vbl_end,(a1)			; Return to the end of the VBL routine after the last line

scrl_no_buffer_wrap
	rts

scrl_space:
	move.l #bufr+jumplist,routine_pointer
	bra.s sblok

; Clear screen memory
clear_screen:
	move.l $44e.w,a0
	clr.l d0
	move.w #screen_size/8-1,d7
cls	move.l d0,(a0)+
	move.l d0,(a0)+
	dbra d7,cls
	rts

; Wipe memory up to the file buffer
clear_memory:
	lea bufr(pc),a0
	move.l a0,a1
	adda.l #samluv,a1
	moveq #0,d0
clmem	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	cmp.l a0,a1
	bgt.s clmem
	rts

; Make background colour table
makpal	lea bufr+bgcols,a0
	clr.w d0
	clr.w d1
	clr.w d2
	move.w #460-1,d7
lines	moveq #28,d5
	moveq #8-1,d6
colums	move.w d0,d3
	or.w d1,d3
	or.w d2,d3
	move.w d3,(a0,d5.w)
	subq.w #4,d5
	move.w d3,(a0)+
	add.w #$100,d0
	cmp.w #$700,d0
	ble.s nrrst
	clr.w d0
nrrst	dbra d6,colums
	lea -14(a0),a1
	lea 14(a0),a0
	moveq #14-1,d6
copx	move.w (a1)+,(a0)+
	dbra d6,copx
	
	add.w add_green,d1
	cmp.w #$070,d1
	blt.s ngrst
	move.w #-$010,add_green
ngrst	tst.w d1
	bne.s ngr2
	move.w #$010,add_green
	add.w add_blue,d2
	cmp.w #$007,d2
	blt.s nbrst
	move.w #-$001,add_blue
nbrst	tst.w d2
	bne.s ngr2
	move.w #$001,add_blue
ngr2	dbra d7,lines
	rts

; Make the colour table for the font
makpal3	lea hites(pc),a3			; Height offset of each column
	lea bufr+umscols,a1			; First copy of the colour table
	lea bufr+umscols+bfcol_size,a2		; Second copy of the colour table

	moveq #bg_width/2-1,d6
.ccols	lea col2(pc),a0
	add.w (a3)+,a0
	move.w #bfcol_lines-1,d7		; Number of lines in the foreground colour table
.cline	move.w (a0),(a1)			; Copy the colour to the first and second copies of the colour table
	move.w (a0)+,(a2)
	adda.w #bg_width,a1			; Next line in the colour table
	adda.w #bg_width,a2
	dbra d7,.cline

	suba.w #bfcol_size-2,a1			; Jump back to the start of the colour table and advance to the next column
	suba.w #bfcol_size-2,a2

	dbra d6,.ccols
	rts
	

; Make the output routines for the big scroller font
mfont	lea umfont(pc),a0		; a0: font data
	lea bufr+umsrouts,a1		; a1: output buffer
	lea bufr+jumplist,a2		; a2: jump list (address of each line render routine)

	move.w #bigfont_lines-1,d7	; Total lines in the font

	move.b (a0)+,d5			; First byte in the first character
flins	move.l a1,(a2)+			; Save the routine address in the jump list

	; Write a word of the background colour first
	move.w #$3092,(a1)+		; MOVE.W (A2),(A0)
*	move.w #$30aa,(a1)+
*	move.w #2,(a1)+
	moveq #4,d4

	moveq #3-1,d6			; Number of bytes in one row of the font
	moveq #7,d3			; Bit number
ntest	move.w #$30aa,d0		; MOVE.W x(a2),(a0)
	btst d3,d5			; Test the bit in the font data
	beq.s bgrd			; Branch if the bit is clear
	move.w #$30ad,d0		; MOVE.W x(a5),(a0)
bgrd	move.w d0,(a1)+			; Write the instruction to the output buffer
	move.w d4,(a1)+			; Write the offset in the colour table to the output buffer
	addq.w #2,d4			; Next offset
	subq.w #1,d3			; Next bit
	bpl.s ntest

	moveq #7,d3			; Reset the bit number
	move.b (a0)+,d5			; Get the next byte
	dbra d6,ntest			; Loop for all the bytes in the row
*	move.w #$30aa,(a1)+
*	move.w #52,(a1)+
*	move.w #$1c80,(a1)+
*	move.w #$1d5c,(a1)+
*	move.w #2,(a1)+
*	move.w #$1c81,(a1)+
*	move.w #$1d5c,(a1)+
*	move.w #2,(a1)+

	move.w #$4250,(a1)+		; CLR.W (A0)+
	
	; Play the next sample
	move.l #$4240101c,(a1)+		; CLR.W D0, MOVE.B (a4)+,D0
	move.l #$06000080,(a1)+		; ADDI.B #$80,D0
	move.w #$e748,(a1)+		; LSL.W #3,D0, 
	move.l #$32370004,(a1)+		; MOVE.W 4(a7,D0.W),D1
	move.l #$20370000,(a1)+		; MOVE.L 0(a7,D0.W),D0
	move.l #$01ce0000,(a1)+		; MOVEP.L d0,0(a6)
	move.l #$038e0000,(a1)+		; MOVEP.W d1,0(a6)

	move.w #85-1,d6			; 85 NOPs for the HBLANK
nopl	move.w #$4e71,(a1)+
	dbra d6,nopl

	; Play the next sample
	move.l #$4240101c,(a1)+		; CLR.W D0, MOVE.B (a4)+,D0
	move.l #$06000080,(a1)+		; ADDI.B #$80,D0
	move.w #$e748,(a1)+		; LSL.W #3,D0, 
	move.l #$32370004,(a1)+		; MOVE.W 4(a7,D0.W),D1
	move.l #$20370000,(a1)+		; MOVE.L 0(a7,D0.W),D0
	move.l #$01ce0000,(a1)+		; MOVEP.L d0,0(a6)
	move.l #$038e0000,(a1)+		; MOVEP.W d1,0(a6)

	move.l #$dafc003a,(a1)+		; ADDA.W #$3a,A5
	move.l #$d4fc003a,(a1)+		; ADDA.W #$3a,A2
	move.l #$225b4ed1,(a1)+		; MOVEA.L (a3)+,A1; JUMP (A1)
	dbra d7,flins
	
	rts

; Populate the routine jump buffer with blank lines
mrouts	lea bufr+routs,a1
	lea bufr+umsrouts,a0
	move.l #vbl_end,(a1)+
	move.w #numlines,d7
mout	move.l a0,(a1)+
	dbra d7,mout
	rts

; Draw the UMS logo
putlog	lea umslog(pc),a0
	move.l $44e.w,a1
	lea logo_offset(a1),a1
	moveq #logo_height-1,d7
loglin	move.l (a0)+,(a1)
	move.l (a0)+,4(a1)
	move.l (a0)+,8(a1)
	move.l (a0)+,12(a1)
	move.l (a0)+,16(a1)
	move.l (a0)+,20(a1)
	move.l (a0)+,24(a1)
	move.l (a0)+,28(a1)
	move.l (a0)+,32(a1)
	move.l (a0)+,36(a1)
	move.l (a0)+,40(a1)
	move.l (a0)+,44(a1)
	lea line_bytes(a1),a1
	dbra d7,loglin
	
	lea logpals(pc),a0
	lea $ffff8240.w,a1
pset	move.l #0,(a1)
fuplp	movem.l (a0)+,d0-d2
	movem.l d0-d2,4(a1)
	move.l $466.w,d0
	addq.l #5,d0
blah	cmp.l $466.w,d0
	bgt.s blah
	cmp.l #endpal,a0
	bne.s fuplp
	
	rts

; Early return when the little scroller is paused
pawzd	subq.w #1,pawz
	rts

; Draw the little scroller (which doesn't scroll)
litscr	tst.w pawz			; Check for a pause in the message
	bne.s pawzd

	move.w oset(pc),d1		; Get the character offset
	move.l $44e.w,a1
	add.l #litmes_offset,a1		; Add the screen offset
	lea (a1,d1.w),a1

	move.l plitm(pc),a0
	clr.w d0
	move.b (a0),d0
	sub.b #"A",d0
	bmi space
	
	lsl.w #3,d0			; 8 bytes per character
	lea lfont(pc),a0		; Get the character data
	lea (a0,d0.w),a0
	move.b (a0)+,(a1)
	move.b (a0)+,line_bytes(a1)
	move.b (a0)+,line_bytes*2(a1)
	move.b (a0)+,line_bytes*3(a1)
	move.b (a0)+,line_bytes*4(a1)
	move.b (a0)+,line_bytes*5(a1)
	move.b (a0)+,line_bytes*6(a1)
	move.b (a0)+,line_bytes*7(a1)
	
stormy	move.w #2,pawz
	move.w addme(pc),d0
	add.w d0,oset
	move.w addme+2(pc),addme
	move.w d0,addme+2
	
	addq.l #1,plitm
	cmp.l #elm,plitm
	blt.s bossa
	move.l #litmes,plitm
bossa	subq.w #1,carc
	bgt.s nova
	move.w #40,carc
	clr.w oset
	move.w #50,pawz

nova	rts
	
space	clr.b (a1)
	clr.b line_bytes(a1)
	clr.b line_bytes*2(a1)
	clr.b line_bytes*3(a1)
	clr.b line_bytes*4(a1)
	clr.b line_bytes*5(a1)
	clr.b line_bytes*6(a1)
	clr.b line_bytes*7(a1)
	bra.s stormy

; If we are running on a machine with 512KB of RAM we only load the first two loops worth of sample data
hmeg	move.w #-1,hmflag

	; Cut the sample data at the 3rd loop point
	move.l #looppoint3,flenf+2
	; Patch in the half meg loop sequence
	move.l #esong2,chme+2
	move.l #song2,chme2+2
	move.l #song2,songp
	pea hlfmt(pc)

	bra swallow

**************************************
* LOAD FILE - A5=FILENAME, A6=BUFFER *
* RETURN D7=LENGTH OF FILE	     *
**************************************

lfile	movem.l d0-d6/a0-a6,-(sp)

	clr.w -(sp)
	pea (a5)
	move.w #$3d,-(sp)
	trap #1
	addq.l #8,sp
	tst.w d0
	bmi lerr
	move.w d0,d6
	
	pea (a6)
flenf	pea $7fffffff
	move.w d6,-(sp)
	move.w #$3f,-(sp)
	trap #1
	lea 12(sp),sp
	tst.l d0
	bmi lerr
	move.l d0,d7
	
	move.w d6,-(sp)
	move.w #$3e,-(sp)
	trap #1
	addq.l #4,sp

	movem.l (sp)+,d0-d6/a0-a6
	rts


lerr	move.l #-1,d7
	movem.l (sp)+,d0-d6/a0-a6
	rts

; Palette fade up routine
pup	subq.w #1,dpup
	bgt.s epup
	move.w #5,dpup
	add.w #$111,pupdt
	move.w pupdt(pc),$ffff825e.w
	cmp.w #$777,pupdt
	bne.s epup
	move.w #125,dpup
	move.l #pdn,$4d2.w
epup	rts

; Palette fade down routine
pdn	subq.w #1,dpup
	bgt.s epup
	move.w #5,dpup
	sub.w #$111,pupdt
	move.w pupdt(pc),$ffff825e.w
	tst.w pupdt
	bne.s epup
	move.l o4d2,$4d2.w
	rts

dpup	dc.w 5
pupdt	ds.w 1

onemt	dc.b 27,"Y",42,32,"PLEASE WAIT - LOADING ONE MEG SAMPLES...",0
hlfmt	dc.b 27,"Y",42,32,"PLEASE WAIT - LOADING HALF MEG SAMPLES...",0
nofile	dc.b 27,"Y",43,32,"SAMPLE FILE NOT FOUND (PRESS A KEY)",0

filenam	dc.b "U2NORM.SPL",0

retsz	ds.l 1
hmflag	ds.w 1

; Set up the loop points in the sample
sptr	dc.l 0,looppoint1
	dc.l looppoint1,looppoint2
	dc.l looppoint2,looppoint3
	dc.l looppoint3,looppoint4
	dc.l looppoint4,looppoint5
	dc.l looppoint3,looppoint4a
	dc.l looppoint4a,looppoint4
	dc.l looppoint4,looppoint5a
esptr	dc.w 0

songp	dc.l song

start	dc.l bufr+samluv
endsm	dc.l bufr+samluv+loop1

; Loop pattern for the 1MB samples
song	dc.b 0,0,0,0,1,1,0,0,1,1,0,1,2,2,2,2,3,4,3,4,5,5,4,2,2,0,0,1,0,2,2,6,6,2,2
esong

; Loop pattern for the 512KB samples
song2	dc.b 0,0,0,0,1,1,1,1,0,0,0,0,1,1,1,1,2,2
esong2

logpals	ds.w 6
	dc.w $000,$100,$100,$000,$001,$001
	dc.w $000,$100,$200,$000,$001,$002
	dc.w $100,$200,$311,$001,$002,$113
	dc.w $100,$311,$422,$001,$113,$224
	dc.w $200,$311,$533,$002,$113,$335
	dc.w $200,$422,$644,$002,$224,$446
	dc.w $311,$533,$755,$113,$335,$557
endpal

pawz	ds.w 1
addme	dc.w 1,7
oset	ds.w 1
carc	dc.w 40

; Message for the little scroller (which doesn't scroll)
plitm	dc.l litmes
litmes	include "litmes24.s"
elm

; Message for the big scroller (which does scroll but is unreadable)
p_bigmess dc.l bigmess
bigmess	dc.b "        THE ULTRAMEGA SCROLLER CODED BY ZAX"
	dc.b "  THE BIGGEST PARALLAX FIVE HUNDRED AND TWELVE COLOUR SCROLLER YOU WILL EVER SEE"
	dc.b "    IS THERE ANY POINT IN WRITING THIS MESSAGE WHEN YOU CANT READ IT  "
e_bigmess

; Table of height offsets for each column in the foreground colour (it's a nice landscape effect)
hites	dc.w 4,6,8,6,8,6,4,2,0,0,-2,-2,-2,0,0,2,4,6,6,4,4,4,2,2,2,2,4,4,6,6,8,6,4,2,0

; Table of colours for the foreground colour table
col2	ds.w 11
	dcb.w 9,$100
	dcb.w 8,$200
	dcb.w 7,$300
	dcb.w 6,$400
	dcb.w 6,$500
	dcb.w 5,$600
	dcb.w 5,$700
	dcb.w 4,$710
	dcb.w 4,$720
	dcb.w 3,$730
	dcb.w 3,$740
	dcb.w 2,$750
	dcb.w 1,$760
	dcb.w 1,$010
	dcb.w 2,$020
	dcb.w 3,$030
	dcb.w 4,$040
	dcb.w 5,$050
	dcb.w 6,$060
	dcb.w 6,$070
	dcb.w 7,$171
	dcb.w 7,$272
	dcb.w 8,$373
	dcb.w 8,$474
	dcb.w 8,$575

	dcb.w 9,$100
	dcb.w 8,$200
	dcb.w 7,$300
	dcb.w 6,$400
	dcb.w 6,$500
	dcb.w 5,$600
	dcb.w 5,$700
	dcb.w 4,$710
	dcb.w 4,$720
	dcb.w 3,$730
	dcb.w 3,$740
	dcb.w 2,$750
	dcb.w 1,$760
	dcb.w 1,$010
	dcb.w 2,$020
	dcb.w 3,$030
	dcb.w 4,$040
	dcb.w 5,$050
	dcb.w 6,$060
	dcb.w 6,$070
	dcb.w 7,$171
	dcb.w 7,$272
	dcb.w 8,$373
	dcb.w 8,$474
	dcb.w 9,$575
	dcb.w 9,$676
	

e	ds.w 110

display_routine	dc.l bufr+routs
routine_pointer	dc.l bufr+jumplist

bgcol_pointer	dc.l bufr+bgblack			; Position in the background colour table
bfcol_pointer	dc.l bufr+umscols-bfcol_offset		; Position in the font colour table (offset to align with the scroller)

add_green	dc.w $010
add_blue	dc.w $001

sflg		dc.b 8
bflg		dc.b 16

mfpstr	ds.l 10		; Storage space for system state

ostck	ds.l 1		; Temporary storage for stack pointer during the sync routine
osp	ds.l 1		; Long-term storage for the supervisor stack pointer we arrived with
opal	ds.l 8
op7	ds.b 1
oscr	ds.l 1
orez	ds.w 1
o4d2	ds.l 1
osr	ds.w 1
goodin	ds.w 1

	align 2
lfont	incbin "8x8big.fnt"	; 8x8 font (for the little message)
	align 2
sout	incbin "bigsout.tab"	; Sample output table
esout	align 2

umslog	incbin "umslog2.dat"	; UMS logoB

umfont	ds.w 24			; Space character
	incbin "umfont.dat"	; "Big" font data

	RSRESET
bufr	ds.l 1

stack		rs.w 1000
stack_top 	rs.w 1	
	
routs		rs.l (numlines+5)*2		; List of display routine pointers

jumplist 	rs.l 450			; List of jump addresses for the display routines... number of characters in the font times... 8?

bgblack		rs.w bg_width*150/2		; Background colour table starting at black
bgcols		rs.w bg_width*bg_height		; Background colour table starting with colours (two copies)

umscols		rs.w bfcol_size*2		; The foreground colour double-ring buffer

umsrouts	rs.w draw_routine_bufsize/2	; Buffer for the draw routines for each line of the font

samluv		rs.w 1				; Sample data buffer

***	91362 bytes without colours in letters
