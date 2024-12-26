; Border-breaking loop
; Timed loops that mostly do nothing between border breaks except for playing sample data every other line
; Then draws and undraws balls at the end of the loops
; a0: video synchronisation mode
; a1: hires/lores
; a4: sample data
; a5: sample output table
; a6: soundchip register
; d0: 0 (lores/60hz)
; d1: 2 (hires/50hz)
; d2: loop counter
sync:

; 	move.w #23,d2			; = 23=74/75 NOPs (292/300 cycles), 22=72/3 NOPs (288-92 cycles) 21=70 NOPs (280 cycles)
; .syndel	dbf d2,.syndel		; delay loop (12*d2+16 cycles?)

	; Play the first sample
	clr.w d7
	move.b (a4)+,d7			; Assume nobody else will touch a4,a5,a6 or care about d7
	lsl.w #3,d7
	move.w 4(a5,d7.w),d6		; Look up the sound chip register values
	move.l (a5,d7.w),d7
	movep.l d7,0(a6)		; Move peripheral data - writes to alternate bytes
	movep.w d6,0(a6)
	dcb.w 47,$4e71

	; Open the top border
	move.b #0,$ffff820a.w		; Switch to 60hz
	dcb.w 16,$4e71			; 16 nops
	move.b #2,$ffff820a.w		; switch to 50hz

	move.w	#$2700,sr		; No interrupts

	moveq	#$c,d0
	sub.b	$ffff8209.w,d0		; Read the clock timer
	lsl.w	d0,d0			; Variable shift to synchronise the CPU (4 cycles per 2 shift places)

	lea	$ffff820a.w,a0		; Synchronisation mode
	movea.w	#$8260,a1		; Resolution
	moveq	#2,d1			; 60hz/hirez
	moveq	#0,d0			; 50hz/lorez

	dcb.w 51,$4e71			; 50 nops (200 cycles)

	moveq	#15,d2			; another delay (8+8+16*2=48 cycles)
	lsr.w	d2,d2

	move #226,d2			; line count

; a loop of 224 lines with extremely precise timing,
; switching between hires and lores modes 50/60hz to evade the conditions
; where the video output chip would switch off the signal during the borders

sync_loop1
	; break the left border
	nop
	move.b	d1,(a1)			; hirez
	nop
	move.b	d0,(a1)			; lorez

	; No sample output
	; dcb.w 89,$4e71			; 89 nops (356 cycles)

	; play the next sample (88 cycles)
	; clr.w d7
	; move.b (a4)+,d7			; get the sample volume
	; lsl.w #3,d7			; convert to an offset
	; move.l (a5,d7.w),(a6)		; Write the soundchip registers
	; move.l 4(a5,d7.w),(a6)
	; dcb.w 67,$4e71			; 67 nops (268 cycles) ... yes we should do something with this time

	; Alternate sample output (108 cycles)
	clr.w d7
	move.b (a4)+,d7			; Assume nobody else will touch a4,a5,a6 or care about d7
	lsl.w #3,d7
	move.w 4(a5,d7.w),d6		; Look up the sound chip register values
	move.l (a5,d7.w),d7
	movep.l d7,0(a6)		; Move peripheral data - writes to alternate bytes
	movep.w d6,0(a6)
	dcb.w 62,$4e71			; 62 nops (248 cycles)

	move.b	d0,(a0)			; 60hz (stabilise the signal)
	move.b	d1,(a0)			; 50hz
	
	; dcb.w 13,$4e71			; 13 nops (52 cycles)

	dcb.w 5,$4e71			; 5 nops (20 cycles)
	move.w #syncmarker,$ffff8240.w	; TEMP: show the sync timing (32 cycles)
	move.w #$000,$ffff8240.w

	; Break the right broder
	move.b	d1,(a1)			; hirez	
	nop
	move.b	d0,(a1)			; lorez
	
	dcb.w 8,$4e71			; 8 nops (32 cycles)
	
	dbf d2,sync_loop1		; next line (10 cycles)

; break the lower border
	move.b	d1,(a1)			; hirez	(left border)
	nop
	move.b	d0,(a1)			; lorez

	; No sample output
	; dcb.w 89,$4e71			; 89 nops (356 cycles)

	; play the next sample (88 cycles)
	; clr.w d7
	; move.b (a4)+,d7			; get the sample volume
	; lsl.w #3,d7			; convert to an offset
	; move.l (a5,d7.w),(a6)		; Write the soundchip registers
	; move.l 4(a5,d7.w),(a6)
	; dcb.w 67,$4e71			; 67 nops (268 cycles) ... yes we should do something with this time

	; Alternate sample output (108 cycles)
	clr.w d7
	move.b (a4)+,d7			; Assume nobody else will touch a4,a5,a6 or care about d7
	lsl.w #3,d7
	move.w 4(a5,d7.w),d6		; Look up the sound chip register values
	move.l (a5,d7.w),d7
	movep.l d7,0(a6)		; Move peripheral data - writes to alternate bytes
	movep.w d6,0(a6)
	dcb.w 62,$4e71			; 62 nops (248 cycles)

	move.b	d0,(a0)			; 60hz
	move.b	d1,(a0)			; 50hz

	; dcb.w 13,$4e71			; 13 nops (52 cycles)

	dcb.w 5,$4e71			; 5 nops (20 cycles)
	move.w #$707,$ffff8240.w	; TEMP: show the sync timing (32 cycles)
	move.w #$000,$ffff8240.w

	move.b	d1,(a1)			; hirez (right border)
	nop
	move.b	d0,(a1)			; lorez

	dcb.w 9,$4e71			; 8 nops (32 cycles)

	move.b	d0,(a0)			; 60hz (bottom border)

	moveq	#40,d2			; Remaining lines

	move.b	d1,(a1)			; hirez (left border)
	nop
	move.b	d0,(a1)			; lorez
	nop
	move.b	d1,(a0)			; 50hz

	; No sample output
	; dcb.w 86,$4e71		; 86 nops (344 cycles)

	; play the next sample (88 cycles)
	; clr.w d7
	; move.b (a4)+,d7			; get the sample volume
	; lsl.w #3,d7			; convert to an offset
	; move.l (a5,d7.w),(a6)		; Write the soundchip registers
	; move.l 4(a5,d7.w),(a6)
	; dcb.w 64,$4e71			; 64 nops (256 cycles)

	; Alternate sample output (108 cycles)
	clr.w d7
	move.b (a4)+,d7			; Assume nobody else will touch a4,a5,a6 or care about d7
	lsl.w #3,d7
	move.w 4(a5,d7.w),d6		; Look up the sound chip register values
	move.l (a5,d7.w),d7
	movep.l d7,0(a6)		; Move peripheral data - writes to alternate bytes
	movep.w d6,0(a6)
	dcb.w 59,$4e71			; 59 nops (236 cycles)

	move.b	d0,(a0)			; 60hz
	move.b	d1,(a0)			; 50hz

	; dcb.w 13,$4e71			; 13 nops (52 cycles)

	dcb.w 5,$4e71			; 5 nops (20 cycles)
	move.w #$770,$ffff8240.w	; TEMP: show the sync timing (32 cycles)
	move.w #$000,$ffff8240.w

	move.b	d1,(a1)			; hirez (right border)
	nop
	move.b	d0,(a1)			; lorez

	dcb.w 11,$4e71

; bottom border loop
sync_loop2
	; break the left border
	nop
	move.b	d1,(a1)			; hirez
	nop
	move.b	d0,(a1)			; lorez

	; No sample output
	; dcb.w 89,$4e71			; 89 nops (356 cycles)

	; play the next sample (88 cycles)
	; clr.w d7
	; move.b (a4)+,d7			; get the sample volume
	; lsl.w #3,d7			; convert to an offset
	; move.l (a5,d7.w),(a6)		; Write the soundchip registers
	; move.l 4(a5,d7.w),(a6)
	; dcb.w 67,$4e71			; 67 nops (268 cycles) ... yes we should do something with this time

	; Alternate sample output (108 cycles)
	clr.w d7
	move.b (a4)+,d7			; Assume nobody else will touch a4,a5,a6 or care about d7
	lsl.w #3,d7
	move.w 4(a5,d7.w),d6		; Look up the sound chip register values
	move.l (a5,d7.w),d7
	movep.l d7,0(a6)		; Move peripheral data - writes to alternate bytes
	movep.w d6,0(a6)
	dcb.w 62,$4e71			; 62 nops (248 cycles)

	move.b	d0,(a0)			; 60hz (stabilise the signal)
	move.b	d1,(a0)			; 50hz
	
	; dcb.w 13,$4e71			; 13 nops (52 cycles)

	dcb.w 5,$4e71			; 5 nops (20 cycles)
	move.w #syncmarker,$ffff8240.w	; TEMP: show the sync timing (32 cycles)
	move.w #$000,$ffff8240.w

	; Break the right broder
	move.b	d1,(a1)			; hirez	
	nop
	move.b	d0,(a1)			; lorez
	
	dcb.w 8,$4e71			; 8 nops (32 cycles)
	
	dbf d2,sync_loop2
