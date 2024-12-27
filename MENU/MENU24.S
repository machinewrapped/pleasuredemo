numscrn		equ 9           ; number of screens
topline		equ (1*26)-1    ; scanline where border is gone
textline 	equ 68		; first line of text
textcols 	equ 20		; number of columns of text

smlfntlines 	equ 14		; number of lines in small font
smlfntlets	equ 16

tracklets	equ 18		; number of tracking sprites
tracklines	equ 16		; number of lines in tracking sprites
trackbplanes	equ 2		; number of bitplanes in tracking sprites
tletbytes	equ (tracklines*trackbplanes)	; number of bytes in a line of tracking sprites
trackshift	equ 8		; number of pixels to shift tracking sprites

logolines 	equ 48		; number of lines in logo
logowidth 	equ 20		; number of columns in logo

toplines 	equ 53		; number of lines in top border
bodylines	equ 200		; number of lines in the main screen (200)
bottomlines	equ 35		; number of lines in bottom border
scanline_w	equ 160		; bytes per scanline (closed borders)
widescanline_w	equ 230		; bytes per scanline (open borders)

open_first 	equ 221		; line number where the left and right borders are opened
open_count 	equ 34		; number of lines with open borders

screen_size	equ (scanline_w*bodylines)+(widescanline_w*open_count)+(scanline_w*bottomlines)

scrollchars	equ 11		; number of characters in the scroller
bigfontchrs	equ 47		; number of characters in the scroller font
bigfontheight	equ 32		; number of lines in the scroller font
bigfontbplanes	equ 3		; number of bitplanes in the scroller font
bigfontwbytes	equ bigfontbplanes*4	; number of bytes in a line of the scroller font
bigfontshfbytes	equ bigfontbplanes*6	; number of bytes in a line of the preshifted scroller font
bigfontshfsize	equ bigfontchrs*bigfontheight*bigfontshfbytes	; size of the preshifted scroller font in bytes

bigfontcodesize	equ 3000	; size of the scrolling font generated code


	; check for magic value indicating we were called from the bootstrap
	cmp.l #"PDOM",d0
	bne.s standalone

	; Save the return address
	move.l (sp)+,retadr

	; Check for a pre-selected screen
	subq.w #1,d7
	bmi.s no_selection
	ext.l d7

	; Press the down key to get the selected screen (look, it's just easier this way)
press_down
	bsr dnhan

	dbra d7,press_down

no_selection
	; scrolling message offset
	tst.l d6
	beq.s standalone

	add.l d6,pmes

standalone
	; enter supervisor mode
	clr.l -(sp)
	move #32,-(sp)
	trap #1
	addq.l #6,sp
	move.l d0,osp

	; save the palette
	movem.l $ffff8240.w,d0-d7
	movem.l d0-d7,opal

	; Save the screen address and resolution
	move.l $44e.w,oscr
	move.b $ffff8260.w,d0
	andi.w #%11,d0
	move.w d0,orez

	; set up the stack
	lea stacktop+bufr,sp

	move.w #-1,-(sp)	; Turn off the cursor
	clr.w -(sp)
	move.w #21,-(sp)
	trap #14
	addq.l #6,sp

	; set the palette to black whilst we build the screen
	movem.l black,d0-d7
	; movem.l wblack,d0-d7
	movem.l d0-d7,$ffff8240.w

	bsr clrscrn		; Clear the screen

	; bsr initmusic		; Initialise the music

	bsr preshift_scrfont	; preshift the main font
	bsr codegen_scroller	; Generate custom code for the scroller shifts

	bsr presh		; preshift the character sprites
	bsr mpaf		; Preprocess the tracker path for the sprites

	bsr setup_screen	; Prepare the screen
	
ready	bsr hblon		; Enable interrupts

wait	move.b $fffffc02.w,d0	; Wait for a key press
	bmi.s wait
	
	cmp.b #$48,d0		; Was it the up arrow?
	bne.s nup
	
	bsr uphan

	bra.s wait_fr
	
nup	cmp.b #$50,d0		; Was it the down arrow?
	bne.s ndow

	bsr dnhan

wait_fr	move.l $466,d0
	addq.l #5,d0
paus	cmp.l $466,d0
	bne.s paus
	bra.s wait

ndow	cmp.b #$39,d0		; Was it the space bar?
	bne.s wait

exit	bsr hbloff		; Disable interrupts

	movem.l opal,d0-d7	; Restore original palette
	movem.l d0-d7,$ffff8240.w

	move.w orez(pc),-(sp)	; Restore the original screen address and resolution
	move.l oscr(pc),-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	; Mute the soundchip
	move.b #7,$ffff8800.w
	move.b #%11111111,$ffff8802.w

	; Exit supervisor mode and restore the system stack
	move.l osp,-(sp)
	move #32,-(sp)
	trap #1
	addq.l #6,sp

	; check for return address
	move.l retadr,a0
	cmpa.l #0,a0
	beq.s quit

	; Return the scroller offset and selected screen number to the bootstrap
	move.l #"PMEN",d0
	move.l selscr,d7
	move.l pmes,d6
	sub.l #mes,d6

	jmp (a0)	; return to the bootstrap

quit
	clr.w -(sp)
	trap #1
	
; Clear the screen
clrscrn
	movem.l d0-d1/a0-a1,-(sp)
	move.l frontbuf,a0
	move.l backbuf,a1
	moveq #0,d0
	move.l #screen_size/16-1,d1
.clrsloop
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a0)+
	move.l d0,(a1)+
	move.l d0,(a1)+
	move.l d0,(a1)+
	move.l d0,(a1)+
	dbra d1,.clrsloop

	movem.l (sp)+,d0-d1/a0-a1
	rts


; Copy the selected music (index in d0) to its required address and call its init routine
initmusic:
	movem.l d0-d2/a0-a3,-(sp)  ; Save registers

	; look up the tune data
	move.w tune(pc),d0
	lea tunes,a1
	lsl.w #4,d0
	move.l (a1,d0.w),a0	; address of music data
	move.l 4(a1,d0.w),a2	; end of music file
	move.l 8(a1,d0.w),d0	; selected tune

	; check if this music needs to be located at a specific address (only applies to the MSX music, won't be true for SNDH)
	cmp.w #"**",8(a0)
	bne.s mus_init

	; "relocate" the music
	move.l 10(a0),a1
	move.l a1,a3

copmus:
	move.l (a0)+,(a1)+
	cmp.l a0,a2
	bgt.s copmus

	move.l a3,a0			; New address of music data
	
mus_init:
;	addq.l #4,a3			; VBL handler is at offset 4 in the original MSX music file
	addq.l #8,a0			; VBL handler is at offset 8 in the SNDH music file
	move.l a0,musicv+2
	subq.l #4,a0
	jsr (a0)		; call the selected music's init routine

	movem.l (sp)+,d0-d2/a0-a3  ; Restore registers
	rts

hblon	; Set up interrupts
	lea mfpstr,a0
	move.b $fffffa07.w,(a0)+	; Save current interrupt register values
	move.b $fffffa09.w,(a0)+
	move.b $fffffa13.w,(a0)+
	move.b $fffffa15.w,(a0)+
	move.l $68.w,(a0)+		; Level 2 (HBL) interrupt handler
	move.l $70.w,(a0)+		; Level 4 (VBL) interrupt handler
	move.l $118.w,(a0)+		; MFP keyboard interrupt handler
	move.l $120.w,(a0)+		; MFP HBL interrupt handler
	clr.b $fffffa07.w		; Clear MFP interrupt enable register A
	clr.b $fffffa09.w		; Clear MFP interrupt enable register B
	bclr #3,$fffffa17.w		; Clear bit 3 in Vector register (automatic end of interrupt mode)
	move.l #nkey,$118.w		; Set null routine as the keyboard interrupt handler

	move.w #37,-(sp)		; vsync
	trap #14
	addq.l #2,sp

	clr.b $fffffa1b.w		; Timer b control register
	bset #0,$fffffa07.w		; Enable HBL interrupt in MFP interrupt enable register A
	bset #0,$fffffa13.w		; Enable HBL interrupt in MFP interrupt mask register A

	move.l #vblmain,$70.w		; Set VBL handler
	rts

nkey	rte				; Null keyboard interrupt handler (can't afford to spend time on this)

; nkey	bclr #6,$fffa11			; Clear the keyboard interrupt flag
; 	rte

hbloff	clr.b $fffffa1b.w          ; Clear Timer B control register to disable HBL interrupts
	lea mfpstr,a0
	move.b (a0)+,$fffffa07.w  ; Restore MFP interrupt enable register A
	move.b (a0)+,$fffffa09.w  ; Restore MFP interrupt enable register B
	move.b (a0)+,$fffffa13.w  ; Restore MFP interrupt mask register A
	move.b (a0)+,$fffffa15.w  ; Restore MFP interrupt mask register B
	bset #3,$fffffa17.w       ; Set bit 3 in Vector register (manual end of interrupt mode)
	move.l (a0)+,$68.w        ; Restore level 2 HBL interrupt
	move.l (a0)+,$70.w        ; Restore level 4 VBL interrupt handler
	move.l (a0)+,$118.w       ; Restore keyboard handler
	move.l (a0)+,$120.w       ; Restore HBL counter
	rts

synch	subq.w	#1,cdown	; Countdown on level 2 interrupt
	rte
cdown	ds.w 1

; The main VBL interrupt handler
vblmain	movem.l d0-d7/a0-a6,-(sp)
	move.w sr,-(sp)

	clr.b	$ffff8260.w		; Low resolution

	move.l $68.w,-(sp)		; Save Level 2 interrupt
	move.l #synch,$68.w		; Setup the countdown
	move.w #33,cdown
	move.w #$2100,sr

	; set top palette
	movem.l pall2,d0-d7
	movem.l d0-d7,$ffff8240.w

	addq.l #1,$466.w		; Increment the frame counter

	; install first hbl routine
	move.l #hb1b,$120.w
	
	clr.b $fffffa1b.w		; Clear Timer B control register
	move.b #53,$fffffa21.w		; Wait for 53 scanlines
	move.b #8,$fffffa1b.w		; Enable timer B
*	move.w #$777,$ff8240

	; Swap the front and back screen buffers
	move.l backbuf,d0
	move.l frontbuf,backbuf
	move.l d0,frontbuf
	move.l d0,$44e.w
	lsr.w #8,d0
	move.l d0,$ffff8200.w

syncl2	stop #$2100			; Sync with level 2 interrupt
	tst.w cdown
	bpl.s syncl2

	move.w	#$17,d0
syncdelay
	dbf	d0,syncdelay

	move.b	#0,$ffff820a.w
	dcb.w 16,$4e71			; 64 cycles
	move.b	#2,$ffff820a.w

	move.l (sp)+,$68.w		; Restore Level 2 interrupt
	move.w (sp)+,sr
*	bra end
		
	move.w #$000,$ffff8240.w

	; bset #5,$fffffa09.w		; Re-enable 200Hz timer interrupt
	; bset #5,$fffffa15.w		; (this will mess up the border opening)

	bsr dis2			; Draw the tracking sprites

	bsr draw_scroller		; Draw the scroller

	; bra.s end

musicv	jsr nomusic			; Call the music player

end	; move.w #$200,$ffff8240.w	; See how much of the frame is left

	movem.l (sp)+,d0-d7/a0-a6
	rte

; Dummy music playback routine
nomusic:
	rts

; The first HBL interrupt handler
hb1b	move.l pallrt,$ffff8248.w	; Set the palette for the tracking sprites
	move.l pallrt+4,$ffff824c.w	; we avoid modifying any registers in this interrupt (not sure why)
	move.l pallrt+8,$ffff8250.w
	move.l pallrt+12,$ffff8254.w
	move.l pallrt+16,$ffff8258.w
	move.l pallrt+20,$ffff825c.w

	move.l #hb2,$120.w		; Set the next HBL routine
	clr.b $fffffa1b.w		; Clear Timer B control register
	move.b #1,$fffffa21.w		; Set Timer B data to 1
	move.b #8,$fffffa1b.w		; Set Timer B control register to 8

	move.l #hblist,hblpnt		; Set up the list of HBL configs

	bclr #0,$fffffa0f.w		; Clear the interrupt in service flag
	rte

; The second HBL interrupt handler
hb2	move.l a0,-(sp)			; Save registers
	move.w d0,-(sp)
	move.l hblpnt,a0		; Load the next HBL config
	move.l (a0)+,$ffff8240.w	; Set the palette
	move.l (a0)+,$ffff8244.w
	move.l (a0)+,$120.w		; Set the next HBL routine
	move.w (a0)+,d0			; Set the Timer B counter
	clr.b $fffffa1b.w		; Clear Timer B control register
	move.b d0,$fffffa21.w		; Set Timer B data
	move.b #8,$fffffa1b.w		; Set Timer B control register
	move.l a0,hblpnt			; Save the new HBL config pointer
	move.w (sp)+,d0			; Restore registers
	move.l (sp)+,a0
	bclr #0,$fffffa0f.w		; Clear the interrupt in service flag
	rte

; The third HBL interrupt handler
hb3	clr.w $ffff8240.w		; Black background
	move.l #hb4,$120.w		; Set the next HBL routine
	clr.b $fffffa1b.w
	move.b #12,$fffffa21.w
	move.b #8,$fffffa1b.w
	bclr #0,$fffffa0f.w		; Clear the interrupt in service flag
	rte

; The fourth HBL interrupt handler
hb4	move.w #$700,$ffff8240.w	; Red background
	move.l #hb2,$120.w		; Set the default HBL routine
	clr.b $fffffa1b.w
	move.b #1,$fffffa21.w
	move.b #8,$fffffa1b.w
	bclr #0,$fffffa0f.w
	rte

; Routines to break the borders

waithbl	movea.l #$fffa21,a0		; Read the current Timer B counter
	move.b (a0),d0
label	cmp.b (a0),d0			; Wait for the counter to change
	beq.s label
	rts

; The border-obliterating timer B interrupt!!!
; This is based on code published in ST News
hbl_open
	movem.l	d0-d6/a0-a6,-(a7)

	; Set up the palette for the scroller
	movem.l	palette,d0-d7
	movem.l	d0-d7,$ffff8240.w

	bclr #5,$fffffa15.w		; Mask 200Hz timer interrupt

	; Wait for an hbl
	jsr waithbl

	; Disable the HBL interrupt
	clr.b $fffffa1b.w
	move.b #-1,$fffffa21.w
	move.b #8,$fffffa1b.w

	movea.w	#$8260,a1		; Resolution
	movea.w	#$8209,a2		; Video address counter (low)
	movea.l	#delaynop,a3
	movea.l	#hbls,a4
	movea.l	#$27308,a5
	movea.w	#$8240,a6		; Palette
	moveq	#0,d1			; 50hz/lorez
	moveq	#2,d2			; 60hz/hirez
	moveq	#0,d3
	move.l	#0,d4

	jsr	waithbl

	movea.w	#$820a,a0		; Display frequency

	moveq	#2,d0	    		; Loop counter
clock_w	tst.b	(a2)			; Wait for the clock cycle LSB to be non-zero
	beq.s	clock_w
	move.b	(a2),d3			; Read the clock counter LSB
	adda.l	d3,a3			; Skip nops to synchronise with the video out
	jmp	(a3)

delaynop
	dcb.w 105,$4e71			; 420 cycles

borderloop_1
	nop
	move.b	d2,(a1)			; hires
	nop
	move.b	d1,(a1)			; lores
	move.w	(a4)+,$ffff824e.w	; Set palette entry 7

	dcb.w 85,$4e71			; 340 cycles

	move.b	d1,(a0)			; 50hz
	move.b	d2,(a0)			; 60hz

	dcb.w 13,$4e71			; 52 cycles

	move.b	d2,(a1)
	nop
	move.b	d1,(a1)

	dcb.w 8,$4e71			; 32 cycles

	dbf	d0,borderloop_1

	move.b	d2,(a1)			; hires
	nop
	move.b	d1,(a1)			; lores

	dcb.w 89,$4e71			; 356 cycles

	move.b	d1,(a0)			; 50hz
	move.b	d2,(a0)			; 60hz

	dcb.w 13,$4e71			; 52 cycles

	move.b	d2,(a1)			; hires
	nop
	move.b	d1,(a1)			; lores

	dcb.w 9,$4e71			; 36 cycles

	move.b	d1,(a0)			; 50hz

	moveq	#27,d0			; Line counter
border_loop2
	move.b	d2,(a1)			; hires
	nop
	move.b	d1,(a1)			; lores
	nop
	move.b	d2,(a0)			; 50hz

	move.w (a4)+,$ffff824e.w	; Set palette entry 7

	dcb.w 82,$4e71			; 328 cycles

	move.b	d1,(a0)			; 50hz
	move.b	d2,(a0)			; 60hz

	dcb.w 13,$4e71			; 52 cycles

	move.b	d2,(a1)			; hires
	nop
	move.b	d1,(a1)			; lores

	dcb.w 9,$4e71			; 36 cycles

	dbf d0,border_loop2

	; bset #5,$fffffa15.w		; Unmask 200Hz timer interrupt

	bclr #0,$fffffa0f		; Clear the interrupt in service flag

	movem.l	(a7)+,d0-d6/a0-a6	; Restore registers
	rte

; end of border-obliterating timer B interrupt!!!

; Handle the up arrow key
uphan	move.l selpnt,a6
	cmp.l #slist,a6
	ble wait

	move.w #37,-(sp)		; vsync
	trap #14
	addq.l #2,sp

	clr.w (a6)
	move.l #hb2,8(a6)
	move.w #smlfntlines,12(a6)
	sub.l #smlfntlines,a6
	move.w #$700,(a6)
	move.l #hb3,8(a6)
	move.w #1,12(a6)
	move.l a6,selpnt

	subq.l #1,selscr
	rts
	
; Handle the down arrow key
dnhan	move.l selpnt,a6
	cmp.l #elist,a6
	bge wait
	move.w #37,-(sp)
	trap #14
	addq.l #2,sp
	clr.w (a6)
	move.l #hb2,8(a6)
	move.w #smlfntlines,12(a6)
	add.l #smlfntlines,a6
	move.w #$700,(a6)
	move.l #hb3,8(a6)
	move.w #1,12(a6)
	move.l a6,selpnt

	addq.l #1,selscr	
	rts

; Draw the scroller
draw_scroller	
	move.l scroll_shift,a0			; Get the current shift position
	move.l (a0)+,a3			; Get the character data
	move.l (a0),a4			; Get the draw routine
	jsr (a4)			; Call the draw routine

	addq.l #8,scroll_shift			; Advance the shift position
	cmp.l #e_scroll_shifts,scroll_shift		; Check if we've looped the shifts
	bne.s escrl

	move.l #scroll_shifts,scroll_shift		; Reset the shift position

	addq.l #1,pmes			; Advance the scroller message pointer
	cmp.l #emes,pmes		; Check if we've reached the end of the message
	bne.s escrl
	move.l #mes,pmes

escrl	rts

; Preshift the scroller font
preshift_scrfont
	lea scrfont,a0
	lea bufr+font,a1

	; Copy font data into a larger buffer with space for the preshifted characters
	move.w #(bigfontchrs*bigfontheight)-1,d7
cops1	clr.l (a1)+
	clr.w (a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	dbra d7,cops1
	
	lea bufr+font,a0
	move.w #(bigfontchrs*bigfontheight)-1,d7
shif2	moveq #bigfontbplanes-1,d6
bitpln	move.w (a0),d0		; Get 3 bitplanes of font data
	move.w 6(a0),d1
	move.w 12(a0),d2
	move.w d2,d3		; Copy bitplanes 2 and 3 to d3 and d4
	move.w d1,d4
	lsr.w #8,d3		; d3,d4 = upper byte of bitplanes 2 and 3
	lsr.w #8,d4
	lsl.w #8,d2		; d0,d1,d2 = left-shifted bitplanes 1,2,3
	lsl.w #8,d1
	lsl.w #8,d0
	add.w d3,d1		; Add the upper byte to the shifted bitplane (why? why only for bitplanes 2 and 3?)
	add.w d4,d0

	move.w d0,(a1)		; Store the preshifted bitplanes
	move.w d1,6(a1)
	move.w d2,12(a1)

	addq.l #2,a0		; Advance to the next 16 pixel block
	addq.l #2,a1
	dbra d6,bitpln

	add.l #12,a0		; Advance to the next line
	add.l #12,a1

	dbra d7,shif2
	rts

; This function pre-processes the scrolling message font data, 
; generating draw routines for 32-pixel aligned characters on 460 pixel wide scanlines (open borders)
; Gemerates one version for with a half character at the right edge of the screen and one with a half
; character at the left edge of the screen. Alternating these and 8-pixel pre-shifted font data gives one character of scroll.
codegen_scroller
	lea bufr+fontcode,a0

	; Write a branch offset to the letter loop branch instruction.
	; This is a totally insane thing to hardcode!
	; I assume it was established by running the codegen in the debugger and seeing how much code it produced for each character!
	move.w #$fc5e,sdraw1_bra+2
	move.w #$fc5e,sdraw2_bra+2

	; copy draw functions to a code buffer, unrolling line loops and adding screen offsets

	; start at first character (may be clipped by screen edge)
	lea scroller_draw1(pc),a1

u_cpy1	move.w (a1)+,(a0)+		; copy prologue
	cmp.l #sdraw1_cpy1,a1
	blt.s u_cpy1

	clr.l d0			; clear screen offset

	moveq #bigfontheight-1,d7

	; copy sdraw1_cpy1 for each line, adding the screen offset
u_cpy2	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	cmp.l #sdraw1_cpy2,a1
	blt.s u_cpy2			; copy until sdraw1_cpy2

	lea sdraw1_cpy1(pc),a1		; reset code template pointer
	add.l #widescanline_w,d0	; add one scanline to the screen offset
	dbra d7,u_cpy2			; repeat for all lines in the font

	lea sdraw1_cpy2(pc),a1		; reset code pointer
u_line1
	move.w (a1)+,(a0)+
	cmp.l #sdraw1_line,a1
	blt.s u_line1			; copy until loop start

	clr.l d0			; clear screen offset

	moveq #bigfontheight-1,d7	; Number of lines in one character
unroll_1
	lea sdraw1_line(pc),a1		; unroll the line loop, adding the screen offset
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+

	add.l #widescanline_w,d0	; add one scanline to the screen offset
	dbra d7,unroll_1
	
u_rhs	move.w (a1)+,(a0)+
	cmp.l #sdraw1_rhs,a1
	blt.s u_rhs			; copy until rhs handler
	
	; Handle the half character at the right edge of the screen
	clr.l d0			; Reset the screen offset
	moveq #bigfontheight-1,d7	; Unroll the handler for the RHS column
unroll_2
	lea sdraw1_rhs(pc),a1
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	add.l #widescanline_w,d0
	dbra d7,unroll_2

u_esdraw1
	move.w (a1)+,(a0)+
	cmp.l #e_sdraw1,a1
	blt.s u_esdraw1		; copy until end of sdraw1
	
	; second set of font draw routines
	lea bufr+fontcode+bigfontcodesize,a0
	lea scroller_draw2(pc),a1

u_lhs2
	move.w (a1)+,(a0)+
	cmp.l #sdraw2_lhs,a1
	blt.s u_lhs2		; copy prologue

	clr.l d0		; clear screen offset

	; Unroll the half-char loop and adjust offsets
	moveq #bigfontheight-1,d7
unroll_3
	lea sdraw2_lhs(pc),a1
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	add.l #widescanline_w,d0
	dbra d7,unroll_3		; repeat for all lines in the font

	; Copy until line loop
u_line2
	move.w (a1)+,(a0)+
	cmp.l #sdraw2_line,a1
	blt.s u_line2

	clr.l d0			; clear screen offset

	; Unroll the full char loop
	moveq #bigfontheight-1,d7
unroll_4
	lea sdraw2_line(pc),a1		; Unroll the loop
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+			
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	move.w (a1)+,(a0)+
	move.w (a1)+,(a0)
	add.w d0,(a0)+
	add.l #widescanline_w,d0
	dbra d7,unroll_4
	
u_esdraw2
	move.w (a1)+,(a0)+
	cmp.l #e_sdraw2,a1
	blt.s u_esdraw2			; copy until end of sdraw2
	
	rts

; Draw routine template for the scroller used by codegen
; Font data is a 32 pixel wide character with 3 bitplanes, in a 48 pixel wide buffer for the preshift
; draw1 renders the scroller aligned on whole character steps
scroller_draw1
	moveq #9,d4

	; Get the screen address and calculate the start of the scroller area
	move.l $44e,a1
	lea scanline_w*bodylines(a1),a1
	lea scanline_w*topline(a1),a1

	move.l pmes,a2		; Get the next character in the scroller message
	clr.w d0
	move.b (a2)+,d0
	sub.b #"A"-1,d0
	bpl.s sdraw1_space
	clr.w d0		; Blank space character... we could just not draw it?
sdraw1_space
	move.w d0,d1		; Calculate 576 x character index to get the character data (we should use a LUT)
	lsl.w d4,d0		; x 512
	lsl.w #6,d1		; x 64
	add.w d1,d0		; x 576
	
	lea (a3),a0		; Character data address
	lea (a0,d0.w),a0

sdraw1_cpy1	
	move.l (a0)+,0(a1)	; Copy 3 bitplanes x 32 pixels to the screen buffer
	move.w (a0)+,4(a1)
	move.l (a0)+,8(a1)
	move.w (a0)+,12(a1)
	move.l (a0)+,16(a1)
	move.w (a0)+,20(a1)

sdraw1_cpy2
	add.l #16,a1		; Advance 32 pixels

	; loop for the number of characters in the scroller
	moveq #scrollchars-1,d6
sdraw1_loop
	clr.w d0
	move.b (a2)+,d0
	sub.b #"A"-1,d0
	bpl.s sdraw1_space2
	clr.w d0
sdraw1_space2	
	move.w d0,d1		; Calculate 576 x character index to get the character data (we should use a LUT)
	lsl.w d4,d0		; x 512
	lsl.w #6,d1		; x 64
	add.w d1,d0		; x 576

	lea (a3),a0
	lea (a0,d0.w),a0
	
sdraw1_line	
	move.l (a0)+,d0		; Or the overlapping character data with the screen buffer
	or.l d0,0(a1)
	move.w (a0)+,d0
	or.w d0,4(a1)
	move.l (a0)+,8(a1)	; Write the non-overlapping character data
	move.w (a0)+,12(a1)
	move.l (a0)+,16(a1)
	move.w (a0)+,20(a1)
sdraw1_eline	
	add.l #16,a1		; Advance 32 pixels

sdraw1_bra dbra d6,sdraw1_loop	; Loop branch ... this offset will be patched by codegen

	; Get the next character
	clr.w d0
	move.b (a2)+,d0
	sub.b #"A"-1,d0
	bpl.s sdraw1_space3
	clr.w d0
sdraw1_space3	
	move.w d0,d1
	lsl.w d4,d0		; x 512
	lsl.w #6,d1		; x 64
	add.w d1,d0		; 576 x character index
	
	lea (a3),a0		; Character data address
	lea (a0,d0.w),a0
	
sdraw1_rhs
	move.l (a0)+,d0		; Or the clipped character data with the screen buffer
	or.l d0,0(a1)
	move.w (a0)+,d0
	or.w d0,4(a1)
	move.l (a0)+,8(a1)	; Write the non-overlapping character data
	move.w (a0)+,12(a1)
	addq.l #6,a0		; Advance 16 pixels
	rts

e_sdraw1 nop

; draw2 renders the scroller aligned on half-character steps
scroller_draw2	
	moveq #9,d4

	; Get the screen address and calculate the start of the scroller area
	move.l $44e,a1
	lea scanline_w*bodylines(a1),a1
	lea scanline_w*topline(a1),a1

	move.l pmes,a2		; Get the next character in the scroller message
	clr.w d0
	move.b (a2)+,d0
	sub.b #"A"-1,d0
	bpl.s sdraw2_space
	clr.w d0
sdraw2_space	
	move.w d0,d1		; Calculate 576 x character index to get the character data
	lsl.w d4,d0
	lsl.w #6,d1
	add.w d1,d0
	lea (a3),a0
	lea (a0,d0.w),a0
	
sdraw2_lhs	
	addq.l #6,a0		; Advance 16 pixels
	move.l (a0)+,0(a1)	; Copy 3 bitplane font data to the screen buffer
	move.w (a0)+,4(a1)
	move.l (a0)+,8(a1)
	move.w (a0)+,12(a1)

	addq.l #8,a1			; Advance 16 pixels
	moveq #(scrollchars+1)-1,d6	; Number of characters (including partial first and last characters)

sdraw2_loop
	clr.w d0		; Get the next character
	move.b (a2)+,d0
	sub.b #"A"-1,d0
	bpl.s sdraw2_space2
	clr.w d0
sdraw2_space2	
	move.w d0,d1		; Calculate 576 x character index to get the character data
	lsl.w d4,d0
	lsl.w #6,d1
	add.w d1,d0	
	lea (a3),a0
	lea (a0,d0.w),a0
	
sdraw2_line	
	move.l (a0)+,d0		; Or the overlapping character data
	or.l d0,0(a1)
	move.w (a0)+,d0
	or.w d0,4(a1)
	move.l (a0)+,8(a1)	; Write the non-overlapping character data
	move.w (a0)+,12(a1)
	move.l (a0)+,16(a1)
	move.w (a0)+,20(a1)
	
	add.l #16,a1	; Advance 32 pixels

sdraw2_bra dbra d6,sdraw2_loop
	rts

e_sdraw2 nop	
	; end of scroller drawing routines

; table of font data and draw routines for the 4 x 8 pixel shifts needed to move the scroller by a full character (32 pixels)
; Alternates between using the shifted font data (offset by 8 pixels) and the half-character offset draw routine
scroll_shifts	dc.l bufr+font,bufr+fontcode				; unshifted font data, first set of draw routines
		dc.l bufr+font+bigfontshfsize,bufr+fontcode		; shifted font data, first set of draw routines
		dc.l bufr+font,bufr+fontcode+bigfontcodesize		; unshifted font data, second set of draw routines
		dc.l bufr+font+bigfontshfsize,bufr+fontcode+bigfontcodesize	; shifted font data, second set of draw routines
e_scroll_shifts	dc.w 1
	

; Set up the screen with fixed assets
setup_screen	
	; Clear the front and back buffers
	move.l backbuf,a0
	move.l frontbuf,a2

	; Calculate the end address of the back buffer
	move.l a0,a1
	add.l screen_size,a1

	clr.l d0
cls	move.l d0,(a0)+		; Clear the back buffer
	move.l d0,(a0)+
	move.l d0,(a2)+		; Clear the front buffer
	move.l d0,(a2)+
	cmp.l a0,a1
	bgt.s cls

	lea plog,a0
	move.l backbuf,a1
	move.l frontbuf,a2
	lea scanline_w*2(a1),a1
	lea scanline_w*2(a2),a2
	move.w #(logolines*logowidth)-1,d7
cplog	move.l (a0),(a1)
	move.l (a0)+,(a2)
	addq.l #8,a1
	addq.l #8,a2
	dbra d7,cplog

	move.l backbuf,a1
	move.l frontbuf,a2
	lea scanline_w*textline(a1),a1
	lea scanline_w*textline(a2),a2
	lea text,a3
	moveq #numscrn-1,d7
ltxt	bsr dtext
	add.l #textcols,a3
	lea scanline_w*smlfntlines(a1),a1
	lea scanline_w*smlfntlines(a2),a2
	dbra d7,ltxt

	rts

; Display text in a3 using the small font at screen addresses in a1 and a2
dtext	movem.l d0-d7/a0-a6,-(sp)

	; Loop over each character
	moveq #textcols-1,d7

coltxt	clr.l d0
	move.b (a3)+,d0		; Get the character
	sub.b #"A",d0
	bmi.s colspace

	; Calculate the offset in the font data
	mulu #4*smlfntlines,d0
	lea smlfnt(pc),a0	
	add.w d0,a0

	; Draw the character
	clr.w d1
	moveq #smlfntlines-1,d6	
dline	move.w (a0),(a1,d1.w)	; Write 2 bitplanes to both screens
	move.w (a0)+,(a2,d1.w)
	move.w (a0),2(a1,d1.w)
	move.w (a0)+,2(a2,d1.w)
	add.w #scanline_w,d1
	dbra d6,dline

colspace
	addq.l #8,a1		; Advance to the next character position
	addq.l #8,a2
	dbra d7,coltxt

	movem.l (sp)+,d0-d7/a0-a6
	rts

; *********

; Preshift the tracker sprites and generate display code
presh	lea letters,a5
	lea bufr+code,a2		; code buffer
	lea bufr+udraw,a4		; undraw code buffer
	lea bufr+routlist,a6		; routine list

	moveq #tracklets-1,d7
letts	moveq #tracklines-1,d6
shifs	move.l a2,(a6)+			; Draw routine start address
	move.l a4,(a6)+			; Undraw routine start address
	lea (a5),a0			; Letter data

	bsr shif
	bsr maskmak
	bsr codegen

	dbra d6,shifs

	lea tletbytes(a5),a5		; Next letter
	dbra d7,letts
	rts

; Shift the tracker sprite data
shif	movem.l d0-d7/a0-a6,-(sp)
	lea bufr+letrouts,a1

	moveq #trackshift-1,d7		; Number of shifts

shif_l	clr.l d0			; Read 16 pixels x 2 bitplanes into 32 bit registers
	clr.l d1
	move.w (a0)+,d0
	move.w (a0)+,d1
	lsl.l d6,d0			; shift by d6 bits
	lsl.l d6,d1
	move.w d0,4(a1)			; write the low words
	move.w d1,6(a1)
	swap d0				; write the high words
	swap d1
	move.w d0,(a1)
	move.w d1,2(a1)

	addq.l #8,a1			; advance output by 32 pixels
	dbra d7,shif_l

	movem.l (sp)+,d0-d7/a0-a6
	rts


; Generate the mask data for the tracker sprites
maskmak	movem.l d0-d7/a0-a6,-(sp)
	lea bufr+letrouts,a0
	lea bufr+maskrouts,a1
loopmsk	movem.w (a0)+,d0-d1
	or.w d1,d0
	not.w d0
	move.w d0,(a1)+
	move.w d0,(a1)+
	cmp.l #bufr+maskrouts,a0
	ble.s loopmsk
	movem.l (sp)+,d0-d7/a0-a6
	rts

; Generate the code for the tracker sprites
codegen	movem.l d0-d7/a0-a1/a3/a5-a6,-(sp)
	lea bufr+letrouts,a0
	lea bufr+maskrouts,a1
	moveq #8,d2
	move.l #152,d3
	move.l #scanline_w,d0
	
	moveq #8,d2
	move.w #152,d3
	move.w #scanline_w,d0
	
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
	
dis2	add.l #scanline_w*105,$44e.w
	move.l ppaf,a2
	addq.l #4,a2
	lea sprtxt,a3
	clr.l d0
	moveq #39-1,d7
dlet	tst.l (a3)
	bne.s jump
	addq.l #8,a2
	addq.l #4,a3
	bra.s endw
jump	move.l (a3)+,a0
	move.l $44e,a1
	addq.l #4,a1
	add.w (a2)+,a1
	move.w (a2)+,d1
	move.l 4(a0,d1.w),a0
	jsr (a0)
	addq.l #8,a2
endw	dbra d7,dlet

	addq.l #4,ppaf
	move.l ppaf,a2
	cmp.l pepaf,a2
	blt.s nrap
	move.l #bufr+path,ppaf
	move.l ppaf,a2
nrap	lea sprtxt,a3
	moveq #39-1,d7
dlet2	tst.l (a3)
	bne.s jump2
	addq.l #8,a2
	addq.l #4,a3
	bra.s endb
jump2	addq.l #8,a2
	move.l (a3)+,a0
	move.l $44e,a1
	addq.l #4,a1
	add.w (a2)+,a1
	move.w (a2)+,d1
	move.l (a0,d1.w),a0
	jsr (a0)
endb	dbra d7,dlet2
	sub.l #scanline_w*105,$44e.w
	rts


mpaf	lea pathseq(pc),a0
	lea bufr+path,a1
mpaf_1	clr.w d0
	move.b (a0)+,d0
	lsl.w #2,d0
	lea plist(pc),a2
	move.l 4(a2,d0.w),a3
	move.l (a2,d0.w),a2
mpaf2	move.w (a2)+,(a1)+
	cmp.l a2,a3
	bgt.s mpaf2
	cmp.l #epathsq,a0
	blt.s mpaf_1
	move.l a1,pepaf

	lea pathseq(pc),a0
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


; Address of the character data for each character in the tracker message
sprtxt	dc.l bufr+routlist+8*144
	dc.l bufr+routlist+8*32
	dc.l bufr+routlist+8*32
	dc.l bufr+routlist+8*96
	dc.l bufr+routlist+8*48
	dc.l bufr+routlist+8*176
	dc.l 0
	dc.l bufr+routlist+8*128
	dc.l bufr+routlist+8*144
	dc.l bufr+routlist+8*32
	dc.l bufr+routlist+8*256
	dc.l 0
	dc.l bufr+routlist+8*240
	dc.l bufr+routlist+8*256
	dc.l bufr+routlist+8*32
	dc.l bufr+routlist+8*224
	dc.l bufr+routlist+8*32
	dc.l bufr+routlist+8*96
	dc.l bufr+routlist+8*128
	dc.l bufr+routlist+8*176
	dc.l bufr+routlist+8*208
	dc.l bufr+routlist+8*32
	dc.l bufr+routlist+8*192
	dc.l bufr+routlist+8*112
	dc.l 0
	dc.l bufr+routlist+8*176
	dc.l bufr+routlist+8*160
	dc.l bufr+routlist+8*144
	dc.l bufr+routlist+8*128
	dc.l bufr+routlist+8*112
	dc.l bufr+routlist+8*96
	dc.l bufr+routlist+8*32
	dc.l bufr+routlist+8*80
	dc.l bufr+routlist+8*64
	dc.l bufr+routlist+8*48
	dc.l 0
	dc.l bufr+routlist+8*32
	dc.l bufr+routlist+8*16
	dc.l bufr+routlist+8*0


ortw	ds.w 16

letters	incbin "tracker.dat"		; "font" for the tracker message

ppaf	dc.l bufr+path
pepaf	ds.l 1

tune	dc.w 0
tunes	dc.l music,emusic,1,0
	dc.l music,emusic,2,0

plist	dc.l path1,path2,path3,path4,path5,path6,path7,lpath

pathseq	dc.b 0,0,0,0,1,3,4,4,2,3,5,5,5,6,6,6,3,4,2,2
epathsq	dc.b 0

off	ds.l 1

hblcount	ds.w 1
save68	ds.l 1

; menu selection pointer
selpnt	dc.l slist

; line pointer
hblpnt	dc.l hblist

; RGB changes, hblank routines, line counts
; table of palette entries and HBL routines, with the number of scanlines each should be active for
hblist	dc.l $0000203,$4250647,hb2		; unused line
	dc.w smlfntlines

slist   dc.l $7000320,$5400760,hb3		; first screen selected by default
	dc.w 1
        dc.l $0000300,$5200740,hb2		; second screen
        dc.w smlfntlines
        dc.l $0000223,$4450667,hb2		; third screen
        dc.w smlfntlines
        dc.l $0000313,$5350757,hb2		; fourth screen
        dc.w smlfntlines
	dc.l $0000332,$5540776,hb2		; fifth screen
	dc.w smlfntlines
        dc.l $0000322,$5440766,hb2		; sixth screen
        dc.w smlfntlines
        dc.l $0000233,$4550677,hb2		; seventh screen
        dc.w smlfntlines
        dc.l $0000232,$4540676,hb2		; eighth screen
        dc.w smlfntlines
elist   dc.l $0000030,$2500470,hb2		; ninth screen
        dc.w smlfntlines

        dc.l $0000333,$5550777,hb2		; unused line
        dc.w smlfntlines

	; wait the remaining number of lines to reach the top of the scrolling message
	dc.l $0000332,$5540776,hbl_open	; Open the borders
	dc.w open_first-toplines-(smlfntlines*11)

text	dc.b " ULTRAjMEGA SCROLLER"
	dc.b "  CLASS IN A GLASS  "
	dc.b "   THE SUMMER DEMO  "
	dc.b "    THE LOoE DEMO   "
	dc.b "     REFLEXIONS     "
	dc.b "   THE HELIX DEMO   "
    	dc.b " SOUL PSYCHEDELICIDE"
	dc.b "  THE REPTILE HOUSE "
	dc.b "     SMALL BALLS    "
	dc.b "      DUMMY TEXT    "
	dc.b "      DUMMY TEXT    "


scroll_shift	dc.l scroll_shifts

pmes	dc.l mes
mes	include "menu.msg"
emes	dc.b "              "

pall2	dc.w $000,$312,$534,$756
	dc.w $321,$312,$534,$756
	dc.w $543,$312,$534,$756
	dc.w $765,$312,$534,$756

pallrt	dc.w $321,$321,$321,$321,$543,$543,$543,$543,$765,$765,$765,$765

palette dc.w $000,$211,$322,$433,$544,$655,$766,$430 
	dc.w $527,$111,$222,$333,$444,$555,$666,$000

hbls	ds.w 3
	dc.w $012,$012,$012,$023,$023,$034,$034,$034,$045,$045,$056,$056,$067,$067,$067,$067

backbuf		dc.l $64000
frontbuf	dc.l $74000

bufpnt	dc.l bufr

mfpstr	ds.l 10

wblack	dc.w $777
black	ds.l 8
opal	ds.l 8
oscr	ds.l 1
orez	ds.w 1

selscr	dc.l 0
osp	ds.l 1
oldscr	ds.l 1
newscr	ds.l 1
retadr  dc.l 0


plog	incbin "pdome2.dat"			; Pleasuredome logo
smlfnt	incbin "1614fnt.dat"			; Small font for screen names

scrfont	ds.w bigfontwbytes*bigfontheight/2	; Empty character (space)
	incbin "menufnt2.dat"			; Big font for the scroller

path1	incbin "menu.pth" 
path2	incbin "menu2.pth" 
path3	incbin "menu3.pth" 
path4	incbin "menu4.pth" 
path5	incbin "menu5.pth" 
path6	incbin "menu6.pth" 
path7	incbin "menu7.pth" 
lpath	ds.w 1

; Music not included in the Github source - you can look for an equivalent rip on the SNDH archive
; music	incbin "jambala.msx"
; emusic	ds.w 1

; Dummy music data - just 3 RTS entries to mimic the SNDH header
music	dcb.w 3,$4e750000
emusic	ds.w 1

; Start of uninitialized data
bufr	ds.w 1

	RSRESET

stack		rs.l 200			; Space for our stack (we don't need much)
stacktop	rs.w 1

font		rs.w bigfontshfsize		; 2 x preshifted font data (one for each 8 pixel shift)
fontcode	rs.w bigfontcodesize		; 2 x generated code size (one for each 8 pixel shift)

routlist	rs.l 8*20*16
letrouts	rs.w 64/2
maskrouts	rs.w 64/2

code		rs.w 61000/2
udraw		rs.w 16000/2

path		rs.w 1			; Should be able to calculate the size of the path data, but we don't really need to
