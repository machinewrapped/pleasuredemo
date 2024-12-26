screen_width		equ 160		; Width of the screen in bytes
screen_extra_bytes	equ 256*35	; Approximation (has to be a multiple of 256)
screen_size		equ 32000+screen_extra_bytes
stack_margin		equ 1000	; Space between screen and stack (should be zero if we're well behaved)

reflection_top	equ 150			; Top line of the reflection

num_balls	equ 12			; Number of balls
num_ball_paths	equ 5
ball_path_size	equ (num_balls+1)*4	; Size of a ball pattern (kind of a dumb way to do this)

num_stars	equ 80			; Number of stars
star_size	equ 6			; Size of a star in bytes
star_spacing	equ 24			; Spacing between stars in bytes

numtabs		equ 20
tabmes_lines	equ 42

one_line	equ screen_width
two_lines	equ screen_width*2
three_lines	equ screen_width*3
four_lines	equ screen_width*4
five_lines	equ screen_width*5
six_lines	equ screen_width*6
seven_lines	equ screen_width*7
eight_lines	equ screen_width*8
nine_lines	equ screen_width*9
ten_lines	equ screen_width*10
eleven_lines	equ screen_width*11

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

	; save the palette
	movem.l $ffff8240.w,d0-d7
	movem.l d0-d7,opal

	; Save the resolution
	move.b $ffff8260.w,d0
	andi.w #%11,d0
	move.w d0,orez
	
	; Save the screen address
	move.l $44e.w,a0
	move.l a0,o44e

	; Shift the screen address to make room for the open border
	sub.l #screen_extra_bytes,a0
	move.l a0,backbuf
	move.l a0,a1
	sub.l #screen_size,a1
	move.l a1,frontbuf

	; Put the stack below the screen
	lea -stack_margin(a1),sp

	move.l #screen_size/4-1,d7
clrscr	clr.l (a0)+
	clr.l (a1)+
	dbra d7,clrscr

	; Set the screen address
	clr.w -(sp)
	move.l backbuf,-(sp)
	move.l frontbuf,-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	bsr preggy
	bsr mstars

	; Disable the music since we're not putting it on github
	move.w #-1,disable_music

	; move.w #1,d0
	; jsr music

	bsr setup_interrupts

	move.l #vblmain,$70.w		; Set VBL handler
	; move.l #dbgvbl,$70.w		; Set simple VBL handler for debug

wait_key:	; Keyboard handling loop
	stop #$2300
	move.b $fffffc02.w,d0
	bmi.s wait_key
	
handle_key:
	cmp.b #$39,d0
	beq xit

	sub.b #$3b,d0				; Subtract F1
	bmi.s wait_key

	cmp.b #num_ball_paths,d0		; Check if we're selecting a ball path
	bge msx
	
	mulu #ball_path_size,d0			; Calculate the offset to the ball pattern
	lea ball_patterns,a0
	lea (a0,d0.w),a0
	move.l 4(a0),d1
	cmp.l p_ballpath,d1
	beq.s wait_key
	
	move.w #-1,disable_music		; Disable the music

	movem.l d0/a0,-(sp)

	move.b #1,wait_vbl
l_waitvbl	
	tst.b wait_vbl
	bne.s l_waitvbl

	move.b #-1,disable_balls		; Disable the balls
	
	move.l backbuf,$44e.w			; Erase balls from screen 1
	bsr undraw_balls

	movem.l draw_pattern,d0-d7		; Copy the draw pattern to the undraw pattern
	movem.l d0-d7,undraw_pattern
	movem.l draw_pattern+32,d0-d3
	movem.l d0-d3,undraw_pattern+32

	move.l frontbuf,$44e.w			; Erase balls from screen 2
	bsr undraw_balls
	
	movem.l (sp)+,d0/a0
		
	move.l (a0)+,e_ballpath			; Copy the new ball pattern
	move.l (a0),p_ballpath
	lea draw_pattern(pc),a1
	moveq #num_balls-1,d7
cabby	move.l (a0)+,(a1)+
	dbra d7,cabby
	
	clr.b disable_balls			; Re-enable the balls
	clr.w disable_music			; Re-enable the music
	bra wait_key

msx	cmp.b #10,d0
	bge wait_key
	
	move.w #-1,disable_music

	; ext.w d0
	; sub.w #5,d0
	; lsl.w #3,d0
	; lea musix,a0
	; move.l (a0,d0.w),a1
	; move.l 4(a0,d0.w),d0
	; lea 4(a1),a0
	; move.l a0,vblump+2
	; jsr (a1)

	clr.w disable_music

.iceblink	
	tst.b $fffffc02.w		; debounce key
	bpl.s .iceblink

	bra wait_key

xit	bsr restore_interrupts

	bsr sound_off

	move.w orez,-(sp)
	move.l o44e,-(sp)
	move.l o44e,-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	movem.l opal,d0-d7	; Restore original palette
	movem.l d0-d7,$ffff8240.w

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

nul	rte

col1	move.b #1,$fffffa21.w				; First HBL interrupt handler
	move.l #col2,$120.w
	rte

col2	move.l pally2,$ffff8240.w			; Second HBL interrupt handler (set the relection palette)
	move.l pally2+4,$ffff8244.w
	move.b #1,$fffffa21.w
	move.l #col3,$120.w
	rte

col3	move.w blues,$ffff8240.w			; Third HBL interrupt handler (update the palette for the distance effect)
	bpl.s naarg
	move.l pally3,$ffff8248.w
	move.l pally3,$ffff824c.w
	move.l pally3+4,$ffff8250.w
	move.l pally3+4,$ffff8254.w
	move.l pally3+8,$ffff8258.w
	move.l pally3+8,$ffff825c.w
	move.l #col3b,$120.w
	move.l col3+2,col3b+2
	addq.l #2,col3b+2
naarg	addq.l #2,col3+2
	rte

col3b	move.w blues,$ffff8240.w			; Third HBL interrupt handler part B
	bpl.s nmarg

	move.w pally4+12,$ffff8242.w
	move.l pally4+14,$ffff8244.w
	move.l pally4,$ffff8248.w
	move.l pally4,$ffff824c.w
	move.l pally4+4,$ffff8250.w
	move.l pally4+4,$ffff8254.w
	move.l pally4+8,$ffff8258.w
	move.l pally4+8,$ffff825c.w

	move.l #col4,$120.w				; Set up the next HBL interrupt handler
	move.l col3b+2,col4+2
	addq.l #2,col4+2
nmarg	addq.l #2,col3b+2
	rte

col4	move.w blues,$ffff8240.w			; Fourth HBL interrupt handler
	bpl.s naargr
	move.b #3,$fffffa21.w
	move.l #col5,$120.w
	move.l col4+2,col6+2				; Set up the palette for the next HBL interrupt handler
naargr	addq.l #2,col4+2
	rte

col5	move.w #$017,$ffff8240			; Fifth HBL interrupt handler
	move.l #col6,$120
	movem.l d0-d7/a0-a6,-(sp)			; Waste some time
	movem.l d1-d2/a1-a6,-(sp)
	movem.l (sp)+,d1-d2/a1-a6
	movem.l (sp)+,d0-d7/a0-a6
	addq.l #2,col6+2

	andi.b #$fd,$ffff820a
	move.w #$027,$ffff8240
	nop
	nop
	nop
	nop
	nop
	ori.b #2,$ffff820a					; Open the bottom border
	move.w pally5+12,$ffff8242.w
	move.l pally5+14,$ffff8244.w
	move.l pally5,$ffff8248.w
	move.l pally5,$ffff824c.w
	move.l pally5+4,$ffff8250.w
	move.l pally5+4,$ffff8254.w
	move.l pally5+8,$ffff8258.w
	move.l pally5+8,$ffff825c.w
	move.b #1,$fffffa21.w
	clr.b border_open
	rte

col6	move.w blues,$ffff8240.w				; Final HBL interrupt handler
	addq.l #2,col6+2
	rte


vblmain	movem.l d0-d7/a0-a6,-(sp)

	move.l backbuf,d0		; Swap screens
	move.l frontbuf,backbuf
	move.l d0,frontbuf
	move.l d0,$44e.w
	lsr.w #8,d0
	move.l d0,$ffff8200.w

	move.l #blues,col3+2		; Set up the palette pointer for the HBL interrupt
	move.l #col1,$120.w

	move.b #8,$fffffa1b.w				; Timer B event count mode
	move.b #reflection_top-1,$fffffa21.w		; Timer B control register (first HBL interrupt)

	bset #0,$fffffa07.w		; Enable HBL interrupt in MFP interrupt enable register A
	bset #0,$fffffa13.w		; Enable HBL interrupt in MFP interrupt mask register A

	movem.l pally,d0-d7		; Set the initial palette
	movem.l d0-d7,$ffff8240.w

	clr.b wait_vbl

	bsr ustaz			; Undraw stars
	bsr starz			; Draw stars

	tst.b disable_balls
	bne.s nabl

	move.l $44e.w,a4
	bsr undraw_balls		; Clear balls
	bsr ballz			; Draw balls

nabl	tst.w disable_music		; Check if music is on
	bne.s nomus

vblump	jsr music+4			; Call the music player

nomus	bsr mestabs			; The message tablets
	
	bsr reflex			; The reflexion logo

	lea border_open(pc),a0
	move.b #1,(a0)
.blug	stop #$2100
	tst.b (a0)			; Wait until all the bottom border is open
	bne.s .blug
*	move.w #$777,$ffff8240.w

	addq.l #1,$466.w		; Increment the frame counter

	movem.l (sp)+,d0-d7/a0-a6
	rte

; Temporary vbl handler that just draws the scroller
dbgvbl	movem.l d0-d7/a0-a6,-(sp)

	; Swap the front and back screen buffers
	move.l backbuf,d0
	move.l frontbuf,backbuf
	move.l d0,frontbuf
	move.l d0,$44e.w
	lsr.w #8,d0
	move.l d0,$ffff8200.w

	tst.w disable_music
	bne.s dbg_nomus

	move.l vblump+2,a1
	; jsr (a1)

dbg_nomus:
	; bsr reflex			; The reflexion logo

	bsr ustaz			; Undraw stars
	bsr starz			; Draw stars

	clr.b wait_vbl
	addq.l #1,$466.w		; Increment the frame counter

	movem.l (sp)+,d0-d7/a0-a6
	rte


; Set up interrupts
setup_interrupts:
	lea mfpstr,a0
	move.w sr,(a0)+

	move.w #$2700,sr		; Disable interrupts
	move.l $68.w,(a0)+		; Level 2 (HBL) interrupt handler
	move.l $70.w,(a0)+		; Level 4 (VBL) interrupt handler
	move.l $118.w,(a0)+		; MFP keyboard interrupt handler
	move.l $120.w,(a0)+		; MFP HBL interrupt handler
	move.b $fffffa07.w,(a0)+	; Save current interrupt register values
	move.b $fffffa09.w,(a0)+
	move.b $fffffa13.w,(a0)+
	move.b $fffffa15.w,(a0)+

	bclr #3,$fffffa17.w		; Clear bit 3 in Vector register (automatic end of interrupt mode)

	clr.b $fffffa07.w		; Clear MFP interrupt enable register A
	clr.b $fffffa09.w		; Clear MFP interrupt enable register B

	clr.b $fffffa13.w		; Clear MFP interrupt mask register A
	clr.b $fffffa15.w		; Clear MFP interrupt mask register B

	; bclr #0,$fffffa13.w		; Mask MFP HBL interrupt (Timer B)
	; bclr #5,$fffffa13.w		; Mask MFP Timer A interrupt
	; bclr #4,$fffffa15.w		; Mask MFP Timer D interupt (USART)
	; bclr #5,$fffffa15.w		; Mask Timer C interrupt

	move.l #nkey,$118.w		; Set null routine as the keyboard interrupt handler

	move.w #$2300,sr		; Enable VBL and MFP interrupts

	rts

nkey	bclr #6,$fffffa11.w		; Clear the keyboard interrupt flag
 	rte

restore_interrupts:
	move.w #$2700,sr

	lea mfpstr,a0
	move.w (a0)+,d0
	move.l (a0)+,$68.w        ; Restore level 2 HBL interrupt
	move.l (a0)+,$70.w        ; Restore level 4 VBL interrupt handler
	move.l (a0)+,$118.w       ; Restore keyboard handler
	move.l (a0)+,$120.w       ; Restore HBL counter
	move.b (a0)+,$fffffa07.w  ; Restore MFP interrupt enable register A
	move.b (a0)+,$fffffa09.w  ; Restore MFP interrupt enable register B
	move.b (a0)+,$fffffa13.w  ; Restore MFP interrupt mask register A
	move.b (a0)+,$fffffa15.w  ; Restore MFP interrupt mask register B

	move.b #7,$ffff8800.w		; Mute the sound
	move.b #%11111111,$ffff8802.w

	move.w d0,sr
	rts

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

mestabs	addq.l #8,ppaf
xanth	cmp.l #epth,ppaf		; Check if the path has ended
	blt.s naf

	move.l #paf,ppaf		; Advance the message
	move.l #epth,xanth+2

	move.l pmes,a0			; Check if we should switch to path 2
	tst.w 40(a0)
	beq.s pam1

	move.l #paf2,ppaf
	move.l #epth2,xanth+2
	
pam1	add.l #42,pmes			; Advance the message
	cmp.l #emes-10,pmes
	blt.s naf			; Check if we've reached the end of the message
	move.l #mesij,pmes

naf	move.l ppaf,a6			; Path pointer
	move.l pmes,a5			; Message pointer
	lea grfix,a3			; Graphics data
	move.l $44e.w,a4		; Screen address

	moveq #numtabs-1,d7
tabs	move.w (a6)+,d6
	clr.l screen_width*(reflection_top-1)(a4)
	lea (a4,d6.w),a1
	move.w (a5)+,d6
	bmi tdbzz
	lea (a3,d6.w),a0
	move.w (a6)+,d6
	bmi.s tdbz
	clr.l -one_line(a1)
	clr.l -two_lines(a1)
lynz	move.l (a0)+,(a1)
	lea one_line(a1),a1
	dbra d6,lynz

	clr.l (a1)
	clr.l one_line(a1)
	tst.w (a6)
	bmi.s ovlap
	add.w (a6)+,a1
	clr.l -two_lines(a1)
	move.l (a0)+,-one_line(a1)
	move.l (a0)+,(a1)
	move.l (a0)+,one_line(a1)
	move.l (a0)+,two_lines(a1)
	move.l (a0)+,three_lines(a1)
	move.l (a0)+,four_lines(a1)
	move.l (a0)+,five_lines(a1)
	move.l (a0)+,six_lines(a1)
	move.l (a0)+,seven_lines(a1)
	move.l (a0)+,eight_lines(a1)
	move.l (a0)+,nine_lines(a1)
	clr.l ten_lines(a1)
	clr.l eleven_lines(a1)
	addq.l #2,a6
tdb	addq.l #8,a4
 	dbra d7,tabs
	
	rts

tdbz	clr.l screen_width*(reflection_top-1)(a4)
	clr.l screen_width*(reflection_top)(a4)
	clr.l screen_width*(reflection_top+1)(a4)
	addq.l #8,a4
	addq.l #4,a6
	dbra d7,tabs
	rts

tdbzz	addq.l #8,a4
	addq.l #6,a6
	dbra d7,tabs
	rts

ovlap	move.w (a6)+,d6
	neg.w d6
	add.w (a6)+,a0
lynz2	move.l (a0)+,(a1)
	lea screen_width(a1),a1
	dbra d6,lynz2
	clr.l (a1)
	clr.l screen_width(a1)
	addq.l #8,a4
	dbra d7,tabs
	rts

****************************

undraw_balls	lea undraw_pattern(pc),a5
	move.l $44e.w,a4
	addq.l #4,a4
	clr.l d0
	moveq #num_balls-1,d1
calz	move.l (a5)+,a6
	move.w (a6),d6
	lea (a4,d6.w),a1
	tst.w 6(a6)
	bmi.s submrg
	
	moveq #8-1,d7
kiln1	move.l d0,(a1)
	move.l d0,8(a1)
	move.l d0,screen_width(a1)
	move.l d0,screen_width+8(a1)
	lea two_lines(a1),a1
	dbra d7,kiln1
	
	add.w 6(a6),a1
	moveq #6-1,d7
kiln2	move.l d0,(a1)
	move.l d0,8(a1)
	move.l d0,screen_width(a1)
	move.l d0,screen_width+8(a1)
	lea two_lines(a1),a1
	dbra d7,kiln2
	dbra d1,calz
	movem.l draw_pattern,d0-d7
	movem.l d0-d7,undraw_pattern
	movem.l draw_pattern+32,d0-d3
	movem.l d0-d3,undraw_pattern+32
	rts

submrg	moveq #27-1,d7
kiln	move.l d0,(a1)
	move.l d0,8(a1)
	lea screen_width(a1),a1
	dbra d7,kiln
	dbra d1,calz
	movem.l draw_pattern,d0-d7
	movem.l d0-d7,undraw_pattern
	movem.l draw_pattern+32,d0-d3
	movem.l d0-d3,undraw_pattern+32
	rts

ballz	lea draw_pattern,a5
	lea bufr+grfax,a3
	move.l $44e.w,a4
	addq.l #4,a4
	moveq #num_balls-1,d7
bals	add.l #10,(a5)
	move.l e_ballpath,d6
	cmp.l (a5),d6
	bgt.s nag
	move.l p_ballpath,(a5)

nag	move.l (a5)+,a6
	move.w (a6)+,d6
	lea (a4,d6.w),a1
	move.w (a6)+,d6
	lea (a3,d6.w),a0
	move.w (a6)+,d6
	bmi.s tdba
linz	movem.l (a0)+,d0-d3
	and.l d0,(a1)
	and.l d1,8(a1)
	or.l d2,(a1)
	or.l d3,8(a1)
	lea screen_width(a1),a1
	dbra d6,linz

	tst.w (a6)
	bmi.s ovlbl
	add.w (a6)+,a1
	moveq #11-1,d6
rfln	movem.l (a0)+,d0-d3
	and.l d0,(a1)
	and.l d1,8(a1)
	or.l d2,(a1)
	or.l d3,8(a1)
	lea screen_width(a1),a1
	dbra d6,rfln
	addq.l #2,a6
boz 	dbra d7,bals
	rts

tdba	addq.l #4,a6
	dbra d7,bals
	rts

ovlbl	move.w (a6)+,d6
	neg.w d6
	add.w #4,d6
	add.w (a6)+,a0
	sub.w #48,a0
linz2	movem.l (a0)+,d0-d3
	and.l d0,(a1)
	and.l d1,8(a1)
	or.l d2,(a1)
	or.l d3,8(a1)
	lea screen_width(a1),a1
	dbra d6,linz2
	dbra d7,bals
	rts

preggy	lea bdata(pc),a0
	lea bufr+grfax,a1
	moveq #27-1,d7
dada	move.w (a0),d0
	or.w 2(a0),d0
	not.w d0
	move.w d0,(a1)+
	move.w d0,(a1)+
	move.l #-1,(a1)+
	move.l (a0)+,(a1)+
	clr.l (a1)+
	dbra d7,dada
	
	lea bufr+grfax,a0
	move.w #27*15*2-1,d7
hmmm	movem.w (a0)+,d0-d3
	move.w d2,d4
	lsr.w #1,d4
	roxr.w #1,d0
	roxr.w #1,d2
	move.w d3,d4
	lsr.w #1,d4
	roxr.w #1,d1
	roxr.w #1,d3
	movem.w d0-d3,(a1)
	addq.l #8,a1
	dbra d7,hmmm
	rts

***********************

reflex	addq.l #4,praf
	cmp.l #erth,praf
	blt.s narf
	move.l #rpaf,praf
narf	move.l praf,a6
	lea rfix,a0
	move.l $44e,a4
	addq.l #8,a4
	moveq #9-1,d7
flex	move.w (a6)+,d6
	lea (a4,d6.w),a1
	clr.l -three_lines(a1)
	clr.l 8-three_lines(a1)
	clr.l -two_lines(a1)
	clr.l 8-two_lines(a1)
	clr.l -screen_width(a1)
	clr.l 8-screen_width(a1)
	moveq #24-1,d6
rynz	move.l (a0)+,(a1)
	move.l (a0)+,8(a1)
	lea screen_width(a1),a1
	dbra d6,rynz
	clr.l (a1)
	clr.l 8(a1)
	clr.l screen_width(a1)
	clr.l screen_width+8(a1)
	clr.l two_lines(a1)
	clr.l two_lines+8(a1)
	add.w (a6)+,a1
	clr.l -screen_width(a1)
	clr.l 8-screen_width(a1)
	clr.l -two_lines(a1)
	clr.l 8-two_lines(a1)
	moveq #16-1,d6
rynz2	move.l (a0)+,(a1)
	move.l (a0)+,8(a1)
	lea screen_width(a1),a1
	dbra d6,rynz2
	clr.l (a1)
	clr.l 8(a1)
rdb	add.l #16,a4
	addq.l #8,a6
 	dbra d7,flex
	
	rts

****************

mstars	lea starpath(pc),a0		; Precalculate screen offset and shift pattern for each point on the star paths
	lea bufr+stark,a1
stl_1	clr.l d0
	clr.l d1
	move.b (a0)+,d0			; Read the x and y coordinates of the star
	move.b (a0)+,d1
	sub.w #110,d0			; Centre the star field
	sub.w #110,d1
*	sub.w d2,d1
	
	move.w #-400,d4			; Initial depth for the star?
	move.l (a0)+,d2			; Z speed (x65536)

stl_2	move.w d0,d5			; Project the star into screen space
	move.w d1,d6
	bsr prost

	tst.w d5			; Check if the star is off-screen
	ble.s etpth
	cmp.w #319,d5
	bgt.s etpth
	tst.w d6
	bgt.s etpth
	cmp.w #-150,d6			; Check if the star is off the top of the screen
	blt.s etpth

	move.w d0,-(sp)

	move.w d6,d0			; Reflect the star
	neg.w d0
	asr.w #1,d0
	muls #screen_width,d0

	muls #screen_width,d6
	move.w d6,(a1)

	move.w d5,d6			; Calculate the screen offset
	lsr.w #4,d6
	lsl.w #3,d6
	add.w d6,(a1)+

	move.w d0,(a1)
	add.w d6,(a1)+

	lsl.w #1,d6			; Calculate the shift pattern for the star (TODO: look-up table anyone?)
	sub.w d6,d5
	andi.w #$f,d5
	move.w #$8000,d6
	lsr.w d5,d6
	move.w d6,(a1)+

	swap d4
	add.l d2,d4
	swap d4

	move.w (sp)+,d0
	bra.s stl_2				; Loop whilst the star is visible

etpth	cmp.l #starpathend,a0			; Loop until we reach the end of the star paths
	blt.s stl_1
	
	; Make a second copy of the star data so that we don't have to check for wrap on every star
	lea bufr+stark,a0
	move.l a1,endstar
	lea bufr+estark,a2
cop2	move.l (a0)+,(a1)+
	cmp.l a1,a2
	bgt.s cop2
	rts	

; Project a star into screen-space
prost	movem.l d0-d4/d7,-(sp)
	neg.w d4
	ext.l d4
	move.l #200,d3		projection centre
	add.l d4,d3
	bne.s stad
	moveq #-128,d5
	moveq #-128,d6
	bra.s nstar
	
stad	lsl.l #8,d4
	divs d3,d4
	move.w d4,d3
	move.w d5,d7
	muls d5,d3
	lsr.l #8,d3
	sub.w d3,d7
	add.w #150,d7	x offset
	move.w d7,d5
	
	muls d6,d4
	lsr.l #8,d4
	sub.w d4,d6
	neg.w d6
*	add.w #100,d6
*	add.w #22+29,d6   	y offset
	movem.l (sp)+,d0-d4/d7
nstar	rts

; Undraw the stars
ustaz	move.l frontbuf(pc),a4
	lea screen_width*reflection_top(a4),a4
	move.l pstar(pc),a5
	clr.w d0
	move #num_stars-1,d7
ulop	move.w (a5)+,d6
	move.w (a5)+,d5
	adda.w #(star_size*star_spacing)+2,a5
	move.w d0,(a4,d6.w)
	move.w d0,(a4,d5.w)
	dbra d7,ulop
	rts

; Draw the stars
starz	move.l backbuf(pc),a4
	lea screen_width*reflection_top(a4),a4

	move #num_stars-1,d7
	move.l pstar(pc),a5
	addq.l #star_size,a5
	cmp.l endstar(pc),a5
	blt.s ok_star
	move.l #bufr+stark,a5
ok_star	move.l a5,pstar

l_starz	move.w (a5)+,d6
	move.w (a5)+,d4
	move.w (a5)+,d5
	adda.w #star_size*star_spacing,a5
	or.w d5,(a4,d6.w)			; Star
	or.w d5,(a4,d4.w)			; Reflection
	dbra d7,l_starz
	rts

pstar	dc.l bufr+stark
endstar	ds.l 1

starpath:	
	incbin "newst.dat"
starpathend

rfix	incbin "reflexon.dat"
praf	dc.l rpaf
rpaf	incbin "reflex.pth"
erth	incbin "reflew.dat"

	ds.w 1

bdata	incbin "redball2.dat"

draw_pattern:
	dc.l pab,pab+50,pab+100,pab+150
	dc.l pab+200,pab+250,pab+300,pab+350
	dc.l pab+400,pab+450,pab+400,pab+450

undraw_pattern:	
	dc.l pab,pab+50,pab+100,pab+150
	dc.l pab+200,pab+250,pab+300,pab+350
	dc.l pab+400,pab+450,pab+400,pab+450

pab	incbin "balls.pth"
epab
pab2	incbin "balls2.pth"
epab2
pab3	incbin "balls3.pth"
epab3
pab4	incbin "balls4.pth"
epab4
pab5	incbin "balls5.pth"
epab5

p_ballpath	dc.l pab
e_ballpath	dc.l epab

ball_patterns:
	dc.l epab2,pab2,pab2+50,pab2+100,pab2+150,pab2+200,pab2+250,pab2+300,pab2+350,pab2+400,pab2+450,pab2+500,pab2+550
	dc.l epab3,pab3,pab3+50,pab3+100,pab3+150,pab3+200,pab3+250,pab3+300,pab3+350,pab3+400,pab3+450,pab3+500,pab3+550
	dc.l epab4,pab4,pab4+40,pab4+80,pab4+120,pab4+160,pab4+200,pab4+240,pab4+280,pab4+320,pab4+360,pab4+400,pab4+440
	dc.l epab5,pab5,pab5+50,pab5+100,pab5+150,pab5+200,pab5+250,pab5+300,pab5+350,pab5+400,pab5+450,pab5+500,pab5+550
	dc.l epab,pab,pab+50,pab+100,pab+150,pab+200,pab+250,pab+300,pab+350,pab+400,pab+450,pab+500,pab+550

pmes	dc.l mesij
mesij	incbin "mesij2.dat"
emes

pally	dc.w $000,$333,$555,$777
	dc.w $100,$100,$100,$100
	dc.w $400,$400,$400,$400
	dc.w $700,$700,$700,$700
pally2	dc.w $001,$111,$333,$555
pally3	dc.w $000,$000,$200,$200,$500,$500
pally4	dc.w $100,$100,$300,$300,$600,$600,$222,$444,$666
pally5	dc.w $100,$100,$400,$400,$700,$700,$333,$555,$777

grfix	incbin "fonttabs.dat"
ppaf	dc.l paf
paf	incbin "mestabs.pth"
epth	incbin "meswabs.pth"
paf2	incbin "mestabs2.pth"
epth2	incbin "meswabs.pth"

; Palette for the bottom border. Uses the MSB to indicate when to progress to the next interrupt handler
blues	dc.w $001,$001,$002,$002,$003,$002,$003,$003,$003,$004,$003,$004,$004,$004,$8004
	dc.w $005,$004,$005,$005,$005,$005,$005,$006,$005,$006,$006,$8006
	dc.w $006,$006,$006,$007,$006,$007,$007,$007,$007,$007,$007,$007,$017,$007,$017,$017,$017,$017,$017,$017,$8027
	dc.w $027,$027,$027,$027,$027,$027,$027,$027,$037,$027,$037,$037,$037,$037,$037,$037,$037,$037,$037,$037,$037,$047,$037
	dc.w $047,$047,$047,$047,$047,$047,$047,$047,$047,$047,$047,$047,$057,$047,$057,$057,$057,$057,$057,$057,$057,$057,$057,$057,$057,$057
	
osp	ds.l 1

disable_music	ds.w 1
; musix	dc.l music2,1
; 	dc.l music3,1
; 	dc.l music4,2
; 	dc.l music4,4
; 	dc.l music,1
; emusix

backbuf		dc.l $70000
frontbuf	dc.l $60000

mfpstr	ds.l 10

o44e	ds.l 1
orez	ds.w 1
opal	ds.l 8
o118	ds.l 1
ovbl	ds.l 1
wait_vbl	ds.b 1
disable_balls	ds.b 1
border_open	ds.b 1
op7	ds.b 1
pntr	ds.l 1
omfp	ds.l 1	
oh	ds.l 1

music	ds.l 2		; dummy MSX header

; music	incbin "madmax3.msx"
; 	ds.l 1
; music2	incbin "tlbfave.msx"
; 	ds.l 1
; music3	incbin "tcbmenu.msx"
; 	ds.l 1
; music4	incbin "mlines.msx"

bufr	ds.l 1

	RSRESET

stack		rs.w 1000
stacktop	rs.w 1
stark		rs.w 25000/2		; space for 2 copies of the star data
estark		rs.w 1
grfax		rs.w 4000

