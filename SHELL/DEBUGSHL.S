; This debug shell is a minimal replacement for the boostrap and menu of the 1992 version of The Pleasuredemo
; It allows the non-relocatable, packed screens to be loaded and executed on Hatari or Steem when run from the AUTO folder.
screen_address		equ $78000
non_relocatable_address	equ $10000	; Try to load non-relocatable screens at the correct address

start:
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

	bra handle_keys

ready:	; Save the current screen data
	move.l a0,loadme

	; Call the load routine
	move.l 4(a0),a1
	move.l (a0),a0
	jsr (a1)

	; Check if load was successful
	tst.l d0
	beq no_go

loaded:	; Save the start address
	move.l a0,a2

	; Exit supervisor mode and reset the supervisor stack pointer
	move.l osp+bufr(pc),-(sp)
	move.w #32,-(sp)
	trap #1
	addq.l #6,sp

	; Set the usermode stack pointer to a safe place
	lea userstack+bufr(pc),sp

	lea txtstack(pc),a0
	move.l sp,a1
	bsr printaddr

	lea txtready(pc),a0
	bsr print

	bsr waitkeygem

	; Check the stack sentinels
	lea bufr(pc),a6
	cmp.l #"PNKS",stack(a6)
	bne stack_corrupted
	cmp.l #"PNKS",userstack(a6)
	bne stack_corrupted

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

	lea txtprologue(pc),a0
	bsr print

	bra handle_keys

no_go:	; We were unable to load the screen - return to the menu
	lea txtloadfail(pc),a0
	bsr print

	move.l loadme,a0
	move.l (a0),a0
	bsr print

	bsr waitkeygem

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

; Handle keypresses
handle_keys:
	move.b $fffffc02.w,d0
	bmi.s handle_keys

	lea screens(pc),a0

	; Escape
	cmp.b #1,d0
	bne.s screen_check

	; Exit the program
	addq.l #4,sp
	bra.s going

screen_check:
	move.l 12(a0),d1
	beq.s handle_keys

	cmp.b d0,d1
	beq ready

	lea 16(a0),a0
	bra.s screen_check


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

	rts

load_bootstrap:
	; Attempt to load the old or new boostrap to replace the debug bootstrap
	; TODO: load the screen then relocate to start: and copy over ourselves (with a shim in high memory)
	bra load_screen

return_bootstrap:
	; We shouldn't ever get here if the new bootstrap is loaded
	bra return_screen

load_legacy_menu:
	; Load the menu screen for the 1992 Pleasuredemo
	lea fmenu(pc),a0
	lea bufr+filebuf(pc),a1
	bsr loadtos

	clr.l -(sp)	; Position in the scrolling message (we use an offset in the new bootstrap)
	clr.w -(sp)	; Tune number... we don't have that in the new bootstrap

	rts

return_legacy_menu:
	; Scroller position and selected screen pushed onto the stack
	move.l (sp)+,d7
	move.l (sp)+,d6

	bra.s return_screen

load_screen:
	; Load the screen file
	; Returns the size of the file in d0 and the executable start address in a0 (or 0 if error)
	lea bufr+filebuf(pc),a1
	bsr loadtos

	rts

return_screen:
	; Check the stack sentinels
	lea bufr(pc),a6
	cmp.l #"PNKS",stack(a6)
	bne.s stack_corrupted
	cmp.l #"PNKS",userstack(a6)
	bne.s stack_corrupted

	lea txt_return(pc),a0
	bsr print

	lea txtstack(pc),a0
	move.l sp,a1
	bsr printaddr

	bra comeback

stack_corrupted:
	; Warn that the stack sentinels have been corrupted
	; If the stack is corrupt we might not be able to do much
	lea tstackcorrupt(pc),a0
	bsr print

	bsr waitkeygem

	bra crash

;
; Utility functions
;

sndoff:
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
	move.l a2,-(sp)
	move.l a0,a2

	lea txtfload(pc),a0
	bsr print

	move.l a2,a0
	bsr.s print

	move.l a1,a0
	bsr.s praddrsize

	move.l (sp)+,a2
	rts

praddrsize:
	; print the address in a0 and the size in d0
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

	move.l a1,a0
	move.l d2,d0
	bsr prloaded

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

	; Temporary print of program end address
	move.l a2,a1
	move.l a0,-(sp)
	lea teprog(pc),a0
	bsr printaddr
	move.l (sp)+,a0

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
	btst.l #0,d0    bne.s relodd

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
	lea tnoheadr(pc),a0
	bsr print

	suba.l a0,a0
	bra.s erelocate

reltoohigh
	; relocation address past end of text + data
	lea trelover(pc),a0
	bsr printaddr

	; temp, confirm the end address
	move.l a2,a1
	lea taddrerr(pc),a0
	bsr printaddr

	suba.l a0,a0
	bra.s erelocate

relodd
	; odd relocation address
	lea trelodd(pc),a0
	bsr printaddr

	suba.l a0,a0
	bra.s erelocate

;
; Include the IcePack decruncher
	include "decrunch.s"

;
; Crash handler
	include "crashhnd.s"

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
fnam9	dc.b "summer.ice",0
fnam10	dc.b "ums2.ice",0
fnam11	dc.b "ums1.ice",0
fnam12	dc.b "dbmenu.ice",0,0
fnamx	dc.b "demo.xxx",0,0
fnamxx	dc.b "newshel.xxx",0
	EVEN

; Load table for the original Pleasuredemo - filename, load routine, return routine, keycode
screens	dc.l fnam0,load_screen,comeback,$39
	dc.l fmenu,load_legacy_menu,return_legacy_menu,$32
	dc.l fnam1,load_screen,return_screen,$2
	dc.l fnam2,load_screen,return_screen,$3
	dc.l fnam3,load_screen,return_screen,$4
	dc.l fnam4,load_screen,return_screen,$5
	dc.l fnam5,load_screen,return_screen,$6
	dc.l fnam6,load_screen,return_screen,$7
	dc.l fnam7,load_screen,return_screen,$8
	dc.l fnam8,load_screen,return_screen,$9
	dc.l fnam9,load_screen,return_screen,$a
	dc.l fnam10,load_screen,return_screen,$0b
	dc.l fnam11,load_screen,return_screen,$16
	dc.l fnam12,load_screen,return_screen,$31
	dc.l fnamx,load_bootstrap,return_bootstrap,$2d
	dc.l fnamxx,load_bootstrap,return_bootstrap,$2c
sc_none	dc.l 0,0,0,0

txtprologue	dc.b 27,"E",27,"f","DEBUG BOOTSTRAP FOR THE PLEASUREDEMO",10,13,10,13
		dc.b "SPACE. INTRO",10,13
		dc.b "1. SOUL PSYCHEDELICIDE",10,13
		dc.b "2. THE REPTILE HOUSE",10,13
		dc.b "3. THE CHRISTMAS DEMO",10,13
		dc.b "4. THE PREVIEW DEMO",10,13
		dc.b "5. CLASS IN A GLASS",10,13
		dc.b "6. THE HELIX DEMO",10,13
		dc.b "7. THE LOVE DEMO",10,13
		dc.b "8. REFLEXIONS",10,13
		dc.b "9. THE SUMMER DEMO",10,13
		dc.b "0. ULTRA-MEGA SCROLLER",10,13
		dc.b "M. THE MAIN MENU",10,13
		dc.b "N. THE MUSICAL MENU",10,13
		dc.b "U. THE ORIGINAL UMS",10,13
		dc.b "X. TRY TO RUN THE ORIGINAL BOOTSTRAP",10,13
		dc.b "Z. TRY TO RUN THE NEW BOOTSTRAP",10,13
		dc.b "ESC. QUIT",10,13,0

tpacked		dc.b 10,13,"Data is packed - unpacking",0
txtloadfail 	dc.b 10,13,"Failed to load screen ",0
txtinvalid	dc.b 10,13,"Invalid screen selection ",0

txtload		dc.b 27,"E",27,"f","Loading file ",0
txteload	dc.b 10,13,"Error loading file ",0
tfilefound	dc.b 10,13,"Found file ",0

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
taddrerr	dc.b 10,13,10,13,"Error at address 0x",0
tnoheadr	dc.b 10,13,"HEADER WORD DOES NOT MATCH",0
trelover	dc.b 10,13,"RELOCATION ADDRESS PAST END 0x",0
trelodd 	dc.b 10,13,"ODD RELOCATION ADDRESS 0x",0

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

newline 	dc.b 10,13,0
hexchr		dc.b "0123456789abcdef"

nosound	dc.b 10,0,9,0,8,0,$ff,0,0,0,0

zeroes	ds.l 8

loadme		ds.l 1
is_relocatable 	dc.w 1		; Is the screen relocatable?

crashbuf ds.l 24	; Space to store register and stack contents on crash

	EVEN

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
