; New bootstrap for The Pleasuredemo
; Written in 2024 by Zax of The Cyberpunks
;
; The original bootstrap loaded screens at a fixed memory address without relocation data,
; and does not work well under emulation or with modern TOS versions.
; 
; This version supports fully relocatable TOS files with optional compression with Pack-Ice 2.1
; It has been written from scratch and should be assembled with VASM.
;
; It can be configured to run the 1992 or 2024 configurations of The Pleasuredemo,
; but since the menu for the 1992 version crashes under emulation there are no current plans to release it.

screen_address		equ $78000
screen_data_size	equ 16
screen_data_shift	equ 4
non_relocatable_address	equ $10000	; Try to load non-relocatable screens at the correct address

legacy_bootstrap	equ 0
debug_build		equ 0

start
	; Enter supervisor mode
	clr.l -(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp

	; Load the buffer address in a6
	lea bufr(pc),a6

	move.l d0,osp(a6)

	; Save the status register
	move.w sr,osr(a6)

	; Write sentinel value to check for stack corruption
	move.l #"PNKS",stack(a6)
	move.l #"PNKS",userstack(a6)

	; bsr calculate_checksum

	; Set the stack pointer
	lea stacktop(a6),sp

	; Save the original palette, screen address and resolution
	movem.l $ffff8240.w,d0-d7
	movem.l d0-d7,opal(a6)
	move.b $ffff8260.w,ores(a6)
	move.l $44e.w,oscr(a6)
	move.l $70.w,ovbl(a6)
	move.l $120.w,ohbl(a6)
	move.l $68.w,otimerb(a6)

	bsr install_crash_handlers

	bsr prologue

	lea scintro(pc),a0

	; TODO: fade VBL
	move.w #$000,$ffff8240.w	; Set the background colour
	move.w #$777,$ffff825e.w	; Set the text colour (low resolution)
	move.w #$777,$ffff8246.w	; Set the text colour (medium resolution)

ready
	; Save the current screen data
	move.l a0,loadme

	; Call the load routine
	move.l 4(a0),a1
	move.l (a0),a0
	jsr (a1)

	; Check if load was successful
	tst.l d0
	beq no_go

loaded
	; Save the start address
	move.l a0,a2

	; Exit supervisor mode and reset the supervisor stack pointer
	move.l osp+bufr(pc),-(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp

	; Set the usermode stack pointer to a safe place
	lea userstack+bufr(pc),sp

	IF debug_build
	lea txtstack(pc),a0
	move.l sp,a1
	bsr printaddr

	lea txtready(pc),a0
	bsr print

	bsr waitkeygem
	ENDIF

	; Check the stack sentinels
	lea bufr(pc),a6
	cmp.l #"PNKS",stack(a6)
	bne stack_corrupted
	cmp.l #"PNKS",userstack(a6)
	bne stack_corrupted

	; Set low resolution screen
	; clr.w -(sp)
	; move.l #screen_address,-(sp)
	; move.l (sp),-(sp)
	; move.w #5,-(sp)
	; trap #14
	; lea 12(sp),sp

	; Set return address, background colour and magic number
	move.l loadme(pc),a1
	; move.l 12(a1),$ffff8240.w
	move.l 8(a1),a0
	move.l a0,-(sp)
	move.l #"PDOM",d0

	; jump to the screen
go:	jmp (a2)

comeback:
	; Enter supervisor mode and reset the stack
	clr.l -(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp

	lea stacktop+bufr(pc),sp

	; Restore resolution and system state
	move.w osr+bufr(pc),sr
	move.l ovbl+bufr(pc),$70.w
	move.l ohbl+bufr(pc),$120.w
	move.l otimerb+bufr(pc),$68.w

	; Set the screen address
	move.w bufr+ores(pc),-(sp)
	move.l #screen_address,-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	bsr clrscrn

	; Clear memory - don't trust our screens
	lea filebuf+bufr(pc),a0
	move.l #screen_address,a1
	bsr clrmem

	bsr sndoff

	; bsr waitkey

	move.l nextscreen(pc),a0
	bra ready

no_go:	; We were unable to load the screen - return to the menu
	lea txtloadfail(pc),a0
	bsr print

	move.l loadme,a0
	move.l (a0),a0
	bsr print

	bsr waitkey

	move.l #scmenu,nextscreen
	bra ready

going:
	; Restore the system state
	movem.l bufr+opal(pc),d0-d7
	movem.l d0-d7,$ffff8240.w
	move.b ores+bufr(pc),$ffff8260.w
	move.b ores+bufr(pc),$ffff8260.w
	move.l oscr+bufr(pc),$44e.w
	move.l ovbl+bufr(pc),$70.w
	move.l ohbl+bufr(pc),$120.w
	move.l otimerb+bufr(pc),$68.w
	move.w osr+bufr(pc),sr

	bsr restore_crash_handlers

gone:
	; Exit supervisor mode and restore the original stack
	move.l bufr+osp(pc),-(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp

	; Exit the program
	clr.w -(sp)
	trap #1

; Wait for a keypress by polling the hardware register
waitkey:
	move.b $fffffc02.w,d0
	bmi.s waitkey

	; Escape
	cmp.b #1,d0
	bne.s noesc

	; Exit the program
	addq.l #4,sp
	bra.s going

noesc
	; Space
	cmp.b #$39,d0
	bne.s waitkey

	rts

; Wait for a keypress by asking GEM nicely
waitkeygem:
	move.w #7,-(sp)
	trap #1
	addq.l #2,sp
	rts

;
; Demo loading and execution
;

prologue:
	; Set the screen address
	move.w #-1,-(sp)
	move.l #screen_address,-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	move.w #37,-(sp)		; vsync
	trap #14
	addq.l #2,sp

	; Clear screen and print system status text
	bsr clrscrn

	lea txtprologue(pc),a0
	bsr print

	IF debug_build
	lea txtloaded(pc),a0
	lea start(pc),a1
	bsr printaddr

	lea tfilebuffer(pc),a0
	lea bufr+filebuf(pc),a1
	bsr printaddr

	lea txtscreen(pc),a0
	move.l $44e.w,a1
	bsr printaddr

	lea txtstack(pc),a0
	move.l sp,a1
	bsr printaddr
	ENDIF

	rts

load_intro:
	; Load the intro screen
	; Returns the size of the file in d0 and the executable start address in a0 (or 0 if error)
	lea fnam0(pc),a0
	lea bufr+filebuf(pc),a1
	bsr loadtos

	move.l #scmenu,nextscreen
	rts

load_menu:
	; Load the menu screen
	; TODO: check if the menu is saved in high memory and skip the load
	; Returns the size of the file in d0 and the executable start address in a0 (or 0 if error)
	lea fmenu(pc),a0
	lea bufr+filebuf(pc),a1
	bsr loadtos

	move.w menusel(pc),d7
	move.l menuscroff(pc),d6		; Offset in the scrolling message on the menu screen

	rts

load_legacy_menu:
	; Load the menu screen for the 1992 Pleasuredemo
	lea fmenu(pc),a0
	lea bufr+filebuf(pc),a1
	bsr loadtos

	clr.l -(sp)	; Position in the scrolling message (we use an offset in the new bootstrap)
	clr.w -(sp)	; Tune number... we don't have that in the new bootstrap

	rts

return_menu:
	; Return from the menu screen
	; check if d7 contains the magic number
	cmp.l #"PMEN",d0
	bne comeback

	; Check the stack sentinels
	lea bufr(pc),a6
	cmp.l #"PNKS",stack(a6)
	bne stack_corrupted
	cmp.l #"PNKS",userstack(a6)
	bne stack_corrupted

	IF debug_build
	; Check the checksum
	; bsr verify_checksum

	lea txt_ret_menu(pc),a0
	bsr print

	; Show the stack pointer
	lea txtstack(pc),a0
	move.l sp,a1
	bsr printaddr
	ENDIF

	; Assume d7 is the selected screen, d6 is the scroller offset, ...
	move.l d7,d0
	lsl.w #screen_data_shift,d0
	lea screens(pc),a0
	lea escreens(pc),a1
	add.w d0,a0
	cmpa.l a1,a0
	bge.s invalid_screen

	move.w d7,menusel
	move.l d6,menuscroff

	move.l a0,nextscreen
	bra comeback
	
invalid_screen:
	lea txtinvalid(pc),a0
	bsr print

	move.l d7,d0
	bsr printdec

	bsr waitkey

	move.l #scmenu,nextscreen
	bra ready

return_legacy_menu:
	; Scroller position and selected screen pushed onto the stack
	move.l (sp)+,d7
	move.l (sp)+,d6

	; Check the stack sentinels
	lea bufr(pc),a6
	cmp.l #"PNKS",stack(a6)
	bne stack_corrupted
	cmp.l #"PNKS",userstack(a6)
	bne stack_corrupted

	IF debug_build
	lea txt_ret_menu(pc),a0
	bsr print

	; Show the stack pointer
	lea txtstack(pc),a0
	move.l sp,a1
	bsr printaddr
	ENDIF

	move.l d7,d0
	lsl.w #screen_data_shift,d0
	lea screens(pc),a0
	lea escreens(pc),a1
	add.w d0,a0
	cmpa.l a1,a0
	bge.s invalid_screen

	move.w d7,menusel
	move.l d6,menuscroff

	move.l a0,nextscreen
	bra comeback

load_screen:
	; Load the screen file
	; Returns the size of the file in d0 and the executable start address in a0 (or 0 if error)
	lea bufr+filebuf(pc),a1
	bsr loadtos

	rts

return_screen:
	; Return from a screen - load the menu
	move.l #scmenu,nextscreen

	; Check the stack sentinels
	lea bufr(pc),a6
	cmp.l #"PNKS",stack(a6)
	bne.s stack_corrupted
	cmp.l #"PNKS",userstack(a6)
	bne.s stack_corrupted

	IF debug_build
	; Check the checksum
	; bsr verify_checksum

	lea txt_return(pc),a0
	bsr print

	lea txtstack(pc),a0
	move.l sp,a1
	bsr printaddr
	ENDIF

	bra comeback


stack_corrupted:
	; Warn that the stack sentinels have been corrupted
	; If the stack is corrupt we might not be able to do much
	lea tstackcorrupt(pc),a0
	bsr print

	bsr waitkey

	bra crash

;
; Utility functions
;

sndoff
	pea nosound(pc)
	move.w #32,-(sp)
	trap #14
	addq.l #6,sp
	rts

clrscrn:
	movem.l d0-d1/a0,-(sp)
	; Clear the screen
	move.l $44e.w,a0
	moveq #0,d0
	move.l #32000/4-1,d1
clrsloop
	move.l d0,(a0)+
	dbra d1,clrsloop

	movem.l (sp)+,d0-d1/a0
	rts

clrmem:
	; Clear memory from a0 to a1
	movem.l d0-d7/a0-a2,-(sp)

	; Round end address to multiple of 32 bytes
	move.l a1,d0
	sub.l a0,d0
	lsr.l #5,d0
	lsl.l #5,d0
	add.l a0,d0
	move.l d0,a2

	movem.l zeroes(pc),d0-d7
l_clrmem
	movem.l d0-d7,-(a2)
	cmpa.l a0,a2
	bgt.s l_clrmem

	movem.l (sp)+,d0-d7/a0-a2
	rts

; print loaded {filename in a0} at address {a1} with size {d0}
prloaded:
	IF debug_build
	move.l a2,-(sp)
	move.l a0,a2

	lea txtfload(pc),a0
	bsr print

	move.l a2,a0
	bsr.s print

	move.l a1,a0
	bsr.s praddrsize

	move.l (sp)+,a2
	ENDIF
	rts

praddrsize:
	; print the address in a0 and the size in d0
	IF debug_build
	move.l d0,-(sp)
	move.l a0,-(sp)
	lea txtfaddr(pc),a0
	bsr.s print
	move.l (sp),d0
	bsr.s printhex
	lea txtfsize(pc),a0
	bsr.s print
	move.l (sp)+,a0
	move.l (sp)+,d0
	bsr.s printdec
	ENDIF
	rts

	
; print the text in a0
print:	movem.l d0/a1-a2,-(sp)

	move.l a0,-(sp)
	move.w #9,-(sp)
	trap #1
	addq.l #2,sp
	move.l (sp)+,a0

	movem.l (sp)+,d0/a1-a2
	rts

printaddr:
	; print the message in a0 followed by the address in a1
	move.l d0,-(sp)
	bsr.s print
	move.l a1,d0
	bsr.s printhex
	move.l (sp)+,d0
	rts

printhex:
	; print the hex value in d0
	movem.l d0-d1/a0-a1,-(sp)

	lea bufr+eprntbuf(pc),a0
	lea hexchr(pc),a1

	clr.b -(a0)
hexloop move.l d0,d1
	andi.l #$f,d1
	move.b (a1,d1.w),-(a0)
	lsr.l #4,d0
	bne.s hexloop

	bsr.s print

	movem.l (sp)+,d0-d1/a0-a1
	rts

; print the decimal value in d0
printdec:
	movem.l d0/a0,-(sp)

	lea bufr+eprntbuf(pc),a0
	clr.b -(a0)

decloop divu #10,d0
	swap d0
	add.b #"0",d0       ; Map digit to the character set
	move.b d0,-(a0)
	clr.w d0
	swap d0
	tst.l d0
	bne.s decloop

	bsr print

	movem.l (sp)+,d0/a0
	rts

loadtos:
	; Load TOS file with filename in a0 into memory at a1 and relocate it.
	; Returns the size of the file in d0 and the executable start address in a0
	bsr.s load
	tst.l d0
	beq.s loadtoserr

	; check if the file is relocatable
	cmpi.w #$601a,(a0)
	bne.s tos_nonrel

	move.b #1,is_relocatable
	move.l a1,a0
	bsr relocate

	cmpa.l #0,a0
	beq.s loadtoserr

	rts

tos_nonrel:
	; Try to copy non-relocatable screens to the fixed start address
	lea non_relocatable_address,a1

	lea bufr+filebuf(pc),a2
	cmp.l a2,a1
	bmi.s nonrelerr
	
	lea (a0,d0.l),a2
	lea (a1,d0.l),a1
l_tos_copy
	move.w -(a2),-(a1)
	cmpa.l a2,a0
	bne.s l_tos_copy

	move.b #0,is_relocatable
	move.l a1,a0	; Return the new address
	rts

loadtoserr:
	lea ttoserr(pc),a0
	bsr print
	clr.l d0
	move.l d0,a0
	rts

nonrelerr:
	lea tnonrelerr(pc),a0
	bsr print
	clr.l d0
	move.l d0,a0
	rts

load:
	; Load the file with filename at a0 into memory at a1. Returns the size of the file in d0
	movem.l d1-d2/a1-a4,-(sp)

	move.l a0,a2
	lea txtload(pc),a0
	bsr print
	move.l a2,a0
	bsr print

	; open file
	clr.w -(sp)         ; mode (read only)
	pea (a0)            ; filename
	move.w #61,-(sp)    ; function
	trap #1
	addq.l #8,sp
	move.l d0,d1        ; save file handle
	bpl.s load_exists

	; Try loading the file with .ICE extension
	move.l a0,a3
	lea bufr+filenameBuffer(pc),a4
load_as_ice:
	move.b (a3)+,d0
	move.b d0,(a4)+
	cmpi.b #".",d0
	bne.s load_as_ice

	move.b #"I",(a4)+
	move.b #"C",(a4)+
	move.b #"E",(a4)+
	clr.b (a4)+

try_open_file:
	lea bufr+filenameBuffer(pc),a4
	clr.w -(sp)         ; mode (read only)
	pea (a4)            ; filename with .ICE extension
	move.w #61,-(sp)    ; function
	trap #1
	addq.l #8,sp

	move.l d0,d1        ; save file handle
	bpl.s packed_file_exists

	bra.s loaderr

packed_file_exists:
	lea tfilefound(pc),a0
	bsr print

	move.l a4,a0
	bsr print

load_exists:

	; read file
	lea screen_address,a2	; Allow loading from the file buffer to the screen address
	sub.l a1,a2
	move.l a1,-(sp)     ; buffer address
	move.l a2,-(sp)     ; buffer size
	move.w d1,-(sp)     ; file handle
	move.w #63,-(sp)    ; function
	trap #1
	add.l #12,sp
	move.l d0,d2        ; save read size

	; close file
	move.w d1,-(sp)     ; file handle
	move.w #62,-(sp)
	trap #1
	addq.l #4,sp

	IF debug_build
	move.l a1,a0
	move.l d2,d0
	bsr prloaded
	ENDIF

	cmpi.l #'Ice!',(a1)		; Data packed?
	bne.s eload

	lea tpacked(pc),a0
	bsr print

load_packed
	move.l a1,a0			; Restore the data start address
	move.l 8(a0),d2			; Return the unpacked data size
	bsr decrunch

	bra.s eload

loaderr	lea txteload(pc),a0
	bsr print

	move.l a2,a0
	bsr print

	lea newline(pc),a0
	bsr print

	clr.l d2

eload	move.l a1,a0			; Address of the loaded file
	move.l d2,d0			; Size of the loaded file
	movem.l (sp)+,d1-d2/a1-a4
	rts

relocate:
	; Apply the relocation table to a .TOS file
	; Based on routine by Torbjørn Ose
	; a0 - address of the file
	; returns the executable start address in a0
	movem.l d0-d2/a1-a2,-(sp)

	cmpi.w #$601a,(a0)
	bne.s noheadr

	lea $1c(a0),a1     ; program start address
	move.l a1,d1

	move.l 2(a0),d0     ; Length of PROGRAM (Text)
	add.l 6(a0),d0      ; Length of INITIALISED DATA
	lea 0(a0,d0.l),a2   ; end of text + data

	IF debug_build
	; Temporary print of program end address
	move.l a2,a1
	move.l a0,-(sp)
	lea teprog(pc),a0
	bsr printaddr
	move.l (sp)+,a0
	ENDIF

	move.l d1,a1

	add.l 14(a0),d0     ; Length of SYMBOL TABLE

	lea 0(a1,d0.l),a0   ; address of RELOCATION TABLE

	move.l (a0)+,d0     ; offset of first relocatable address
	add.l d0,a1         ; first address
	add.l d1,(a1)       ; relocate it
	moveq.l #1,d2       ; count of relocations

reloop
	cmpa.l a2,a1         ; end of text + data
	bhs.s reltoohigh

	move.l a1,d0        ; is address even?
	btst.l #0,d0    
	bne.s relodd

	clr.l d0            ; get next byte from table
	move.b (a0)+,d0
	beq.s relocated     ; end of table

	addq.l #1,d2        ; increment relocation count

	cmp.b #1,d0         ; 1 is a 254 byte jump
	beq.s jump

	add.l d0,a1         ; find next absolute address
	add.l d1,(a1)       ; and relocate it

	bra.s reloop        ; next item

jump
	add.l #254,a1       ; jump 254 bytes
	bra.s reloop

relocated
	move.l d1,a0

erelocate
	movem.l (sp)+,d0-d2/a1-a2
	rts

noheadr
	; no TOS header magic value
	IF debug_build
	lea tnoheadr(pc),a0
	bsr print
	ENDIF

	suba.l a0,a0
	bra.s erelocate

reltoohigh
	IF debug_build
	; relocation address past end of text + data
	lea trelover(pc),a0
	bsr printaddr

	; temp, confirm the end address
	move.l a2,a1
	lea taddrerr(pc),a0
	bsr printaddr
	ENDIF

	suba.l a0,a0
	bra.s erelocate

relodd
	; odd relocation address
	IF debug_build
	lea trelodd(pc),a0
	bsr printaddr
	ENDIF

	suba.l a0,a0
	bra.s erelocate

;
; Debug routines
	IF debug_build

calculate_checksum:
	; Calculate the checksum of the boostrap from start to checksum
	; and store it in checksum
	movem.l d0/a0-a1,-(sp)
	moveq #0,d0
	lea start(pc),a0
	lea checksum_end(pc),a1
.checksum_loop
	add.l (a0)+,d0			; Simple checksum
	cmpa.l a1,a0
	bmi.s .checksum_loop

	lea checksum(pc),a0
	move.l d0,(a0)			; Store the checksum
	movem.l (sp)+,d0/a0-a1
	rts

verify_checksum:
	; Verify the checksum of the boostrap from start to checksum
	; If it has changed, display a message and crash
	movem.l d0-d1/a0-a1,-(sp)

	moveq #0,d0
	lea start(pc),a0
	lea checksum_end(pc),a1
.checksum_verify
	add.l (a0)+,d0
	cmpa.l a1,a0
	bmi.s .checksum_verify

	lea checksum(pc),a0
	move.l (a0),d1			; Read the stored checksum
	cmp.l d0,d1
	bne.s checksum_fail

	movem.l (sp)+,d0-d1/a0-a1
	rts
	
checksum_fail:
	lea tchecksumfail(pc),a0
	bsr print
	bsr waitkeygem

	bra crash
		
	ENDIF
; End of debug routines

;
; Include the IcePack decruncher
	include "decrunch.s"

;
; Crash handler
	include "crashhnd.s"

;
; Data section
;

	IFEQ legacy_bootstrap

;
; Screens for the 2024 Configuration of the Pleasuredemo
;
fmenu dc.b "menu24.tos",0,0
fnam0 dc.b "intro.tos",0,0
fnam1 dc.b "newums.tos",0,0
fnam2 dc.b "clasglas.tos",0,0
fnam3 dc.b "summer.tos",0,0
fnam4 dc.b "lovedemo.tos",0,0
fnam5 dc.b "reflexon.tos",0,0
fnam6 dc.b "helix.tos",0,0
fnam7 dc.b "soulpsyc.tos",0,0
fnam8 dc.b "repthous.tos",0,0
fnam9 dc.b "3dformat.tos",0,0

; Load table - filename, load routine, return routine, magic number
scintro dc.l fnam0,load_intro,comeback,$777
scmenu  dc.l fmenu,load_menu,return_menu,$000
screens	dc.l fnam1,load_screen,return_screen,$000
	dc.l fnam2,load_screen,return_screen,$000
	dc.l fnam3,load_screen,return_screen,$000
sclove	dc.l fnam4,load_screen,return_screen,$000
	dc.l fnam5,load_screen,return_screen,$000
	dc.l fnam6,load_screen,return_screen,$000
	dc.l fnam7,load_screen,return_screen,$000
	dc.l fnam8,load_screen,return_screen,$000
	dc.l fnam9,load_screen,return_screen,$000
escreens dc.w $ffff 

	ELSE

;
; Screens for the 1992 Configuration of the Pleasuredemo
;
fnam0	dc.b "intro.ice",0,0
fmenu	dc.b "menu.ice",0,0
fnam1	dc.b "stform91.ice",0,0
fnam2	dc.b "stuser91.ice",0,0
fnam3	dc.b "adrdem3.ice",0,0
fnam4	dc.b "preview2.ice",0,0
fnam5	dc.b "adrdem5.ice",0,0
fnam6	dc.b "helix.ice",0,0
fnam7	dc.b "love.ice",0,0
fnam8	dc.b "reflexon.ice",0,0
fnam9	dc.b "dbmenu.ice",0,0
fnam10	dc.b "summer.ice",0
fnam11	dc.b "ums.ice",0

; Load table for the original Pleasuredemo - filename, load routine, return routine, magic number
scintro dc.l fnam0,load_intro,comeback,$777
scmenu  dc.l fmenu,load_legacy_menu,return_legacy_menu,$000
screens	dc.l fnam1,load_screen,return_screen,$000
	dc.l fnam2,load_screen,return_screen,$000
	dc.l fnam3,load_screen,return_screen,$000
	dc.l fnam4,load_screen,return_screen,$000
	dc.l fnam5,load_screen,return_screen,$000
	dc.l fnam6,load_screen,return_screen,$000
	dc.l fnam7,load_screen,return_screen,$000
	dc.l fnam8,load_screen,return_screen,$000
	dc.l fnam9,load_screen,return_screen,$000
	dc.l fnam10,load_screen,return_screen,$000
	dc.l fnam11,load_screen,return_screen,$000
escreens dc.w $ffff 

	ENDIF

txtprologue	dc.b 27,"E",27,"f","NEW BOOTSTRAP FOR THE PLEASUREDEMO",10,13,0

tpacked		dc.b 10,13,"Data is packed - unpacking",0
txtloadfail 	dc.b 10,13,"Failed to load screen ",0
txtinvalid	dc.b 10,13,"Invalid screen selection ",0

tfilefound	dc.b 10,13,"Found file ",0
txtload		dc.b 10,13,"Loading file ",0
txteload	dc.b 10,13,"Error loading file ",0

	IF debug_build
txtready	dc.b 10,13,"Ready to go!",10,13,0
txtloaded	dc.b 10,13,"Loaded at address 0x",0
txtfload	dc.b 10,13,"Loaded ",0
txtfaddr	dc.b " addr 0x",0
txtfsize	dc.b " size ",0
tfilebuffer	dc.b 10,13,"File buffer at address 0x",0
teprog		dc.b 10,13,"Program end address 0x",0
txt_return	dc.b 27,"E",27,"f","Returning to The Pleasuredemo",10,13,0
txt_ret_menu	dc.b 27,"E",27,"f","Returning from the menu",10,13,0
txtscreen	dc.b 10,13,"Screen memory at address 0x",0
tchecksumfail	dc.b 27,"E",27,"f","Bootstrap checksum failed! Memory corruption",0
taddrerr	dc.b 10,13,10,13,"Error at address 0x",0
tnoheadr	dc.b 10,13,"HEADER WORD DOES NOT MATCH",0
trelover	dc.b 10,13,"RELOCATION ADDRESS PAST END 0x",0
trelodd 	dc.b 10,13,"ODD RELOCATION ADDRESS 0x",0
	ENDIF


tstackcorrupt	dc.b 27,"E",27,"f","Stack corruption detected!",0

txtcrash	dc.b 27,"E",27,"f","Well done, you crashed The Pleasuredemo!",10,13,0
txtstack	dc.b 10,13,"Stack pointer 0x",0
txtstack_con	dc.b 10,13,"Stack contents:",10,13,0
txtregisters	dc.b 10,13,"Registers:",10,13,0
regnames	dc.w "d0","d1","d2","d3","d4","d5","d6","d7","a0","a1","a2","a3","a4","a5","a6","sp",0
txtregval	dc.b "   :          ",0
txtstackval	dc.b "         ",0

ttoserr		dc.b 10,13,"ERROR LOADING TOS FILE",10,13,0
tnonrelerr	dc.b 10,13,"ADDRESS TOO LOW FOR NON-RELOCATABLE FILE",10,13,0

newline dc.b 10,13,0
spcchr	dc.b " ",0
hexchr	dc.b "0123456789abcdef"

nosound	dc.b 10,0,9,0,8,0,$ff,0,0,0,0

zeroes	ds.l 8

checksum_end	ds.l 1		; The point we checksum too (everything before here should be read-only)
checksum	ds.l 1		; Space to hold checksum

loadme		ds.l 1

nextscreen 	dc.l scmenu	; Next screen to load
is_relocatable 	dc.w 1		; Is the screen relocatable?

menusel	   	ds.w 1		; Selected screen
menuscroff 	ds.l 1		; Main menu scroller offset

crashbuf ds.l 24	; Space to store register and stack contents on crash

	align 4

bufr   RSRESET
osp	rs.l 1
osr	rs.w 1
opal	rs.l 8
ores	rs.b 1
oscr	rs.l 1
ovbl	rs.l 1
ohbl	rs.l 1
otimerb	rs.l 1
ocrash	rs.l 8

filenameBuffer	rs.w 12/2	; Buffer to generate the filename with .ICE extension

prntbuf     rs.b 32		; Buffer for text formatting
eprntbuf    rs.l 10

stack		rs.l 200	; Space for the bootstrap stack (we don't need much)
stacktop 	rs.l 10
userstack	rs.l 500	; Space for the usermode stack (who knows how much we need?)
userstacktop	rs.l 10

filebuf rs.w 1
