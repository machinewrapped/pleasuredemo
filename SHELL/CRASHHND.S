; Install custom crash handlers
install_crash_handlers:
	move.l a0,-(sp)
	lea ocrash(a6),a0
	move.l $8.w,(a0)+
	move.l $c.w,(a0)+
	move.l $10.w,(a0)+
	move.l $14.w,(a0)+
	lea crash(pc),a0
	move.l a0,$8.w
	move.l a0,$c.w
	; move.l a0,$10.w
	; move.l a0,$14.w
	move.l (sp)+,a0
	rts

; Restore the original crash handlers
restore_crash_handlers:
	move.l a0,-(sp)
	lea ocrash(a6),a0
	move.l (a0)+,$8.w
	move.l (a0)+,$c.w
	move.l (a0)+,$10.w
	move.l (a0)+,$14.w
	move.l (sp)+,a0
	rts

; Custom crash handler
crash:
	move.l sp,crashbuf+60		; Save the stack pointer
	lea stacktop+bufr(pc),sp	; Reset to a valid address

	movem.l d0-d7/a0-a6,crashbuf	; Save register contents

	lea txtcrash(pc),a0
	bsr print

	lea txtstack(pc),a0
	move.l crashbuf+60(pc),a1
	bsr printaddr

	; Display register contents
	lea txtregisters(pc),a0
	bsr print

	lea txtregval(pc),a0
	lea regnames(pc),a1
	lea crashbuf,a2
	lea hexchr(pc),a3
	moveq #4-1,d7
	moveq #4-1,d6
l_crashreg
	move.b (a1)+,1(a0)
	move.b (a1)+,2(a0)
	move.l (a2)+,d0
	lea 13(a0),a4
	bsr crash_hex
	bsr print

	dbra d6,l_crashreg
	lea newline(pc),a0
	bsr print
	lea txtregval(pc),a0
	moveq #4-1,d6
	dbra d7,l_crashreg

crash_stack
	move.l crashbuf+60(pc),a1	; Original stack pointer
	move.l $436,a2		; Top of user memory
	cmpa.l a1,a2
	bmi.s crash_nostack

	lea txtstack_con(pc),a0
	bsr print

	moveq #2-1,d7
	moveq #4-1,d6
	lea txtstackval(pc),a0
l_crashstack
	move.l (a1)+,d0		; Original stack contents
	lea 9(a0),a4
	bsr crash_hex
	bsr print
	dbra d6,l_crashstack
	lea newline(pc),a0
	bsr print
	moveq #4-1,d6
	lea txtstackval(pc),a0
	dbra d7,l_crashstack

crash_nostack
	; Wait for a keypress
	move.w #$ff,-(sp)
	move.w #6,-(sp)
	trap #1
	addq.l #4,sp

	; Try to exit cleanly
e_crash	bra going
	; bra gone

crash_hex
	moveq #8-1,d5	; Convert the value in d0 to 8 hex digits backwards from a4
l_tohexloop
	move.b d0,d1
	andi.w #$f,d1
	move.b (a3,d1.w),-(a4)
	lsr.l #4,d0
	dbra d5,l_tohexloop
	rts


