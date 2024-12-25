screen_width		equ 320
screen_height		equ 200
bytes_per_line		equ 160

screen_extra_bytes	equ $4000
base_screen_bytes	equ 32000
screen_bytes		equ base_screen_bytes+screen_extra_bytes
bottom_border_line	equ 198+29

num_stars		equ 80
star_size		equ 4
star_spacing		equ star_size*22
star_bitplane		equ 4
star_offset		equ (bytes_per_line*100)+star_bitplane
star_bits		equ $8000

num_presets		equ 10
num_palettes		equ 10
num_special_keys	equ 18

initial_object		equ 8
num_objects		equ 9
max_points		equ 100
num_sizes		equ 11
num_shifts		equ 16
ball_bytes		equ 256
transform_steps		equ 16

projection_centre	equ 200
min_z			equ -3600
max_z			equ 180
z_range			equ projection_centre-min_z
y_zero_line		equ 70

intro_z_step		equ 4
zoom_step		equ 75
max_zoom		equ 3000

num_axes		equ 3
min_x_coord		equ -16
min_y_coord		equ (-y_zero_line)-16

fade_delay_frames	equ 8

scancode_f1		equ $3b
scancode_num1		equ $02
scancode_q		equ $10
scancode_dot		equ $34
scancode_shift		equ $2a
scancode_rshift		equ $36
scancode_ctrl		equ $1d
scancode_release	equ $80			; Added to scancode for key up events


	; check for magic value indicating we were called from the bootstrap
	cmp.l #"PDOM",d0
	bne.s standalone

	move.l (sp)+,retadr
	bra.s standalone

retadr	ds.l 1

standalone
	; Enter supervisor mode
	clr.l -(sp)
	move.w #$20,-(sp)
	trap #1
	addq.l #6,sp
	move.l d0,stack

	; Set up the stack
	lea bufr+stacktop,sp

	; Save the palette and resolution
	movem.l $ffff8240.w,d0-d7
	movem.l d0-d7,opal

	move.w #4,-(sp)
	trap #14
	move.w d0,orez

	; Set up the screen pointers allowing an extra 16KB for the open borders
	move.l $44e.w,d0
	move.l d0,o44e
	sub.l #screen_extra_bytes,d0
	move.l d0,stund
	move.l d0,screen2
	sub.l #$c000,d0
	move.l d0,screen1

	; Set the screen address and low resolution
	clr.w -(sp)
	move.l screen2(pc),-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp

	; Disable the cursor
	pea cursoff(pc)
	move.w #9,-(sp)
	trap #1
	addq.l #6,sp

	; Clear both screens and an arbitrary amount of buffer memory
	move.l screen1(pc),a0
	move.l screen2(pc),a1
	lea bufr,a3
	move.l a1,a2
	add.l #screen_bytes,a2
	moveq #0,d0
clrs2	move.l d0,(a0)+		; Clear screen 1
	move.l d0,(a1)+		; Clear screen 2
	move.l d0,(a3)+		; Clear buffer memory
	move.l d0,(a3)+
	cmp.l a1,a2
	bge.s clrs2

	lea bufr+udofs,a0	; Initialise the undraw offsets to screen 1
	move.l screen1(pc),d0
	move.w #200-1,d7
fud	move.l d0,(a0)+
	dbra d7,fud

	tst.w $ffff8240.w	; Check if the screen is already black
	beq.s already_black

	lea ftb(pc),a5		; Fade to black
	lea $ffff8240.w,a6	
fatb	move.w (a5)+,(a6)
	moveq #fade_delay_frames-1,d7
delf	move.w #37,-(sp)
	trap #14
	addq.w #2,sp
	dbra d7,delf		; Delay fade

	cmp.l #eftb,a5
	blt.s fatb		; Loop until the fade is complete

already_black:
	; Set the palette to hide the help text
	movem.l hhelp(pc),d0-d7
	movem.l d0-d7,$ffff8240.w
	
	moveq #initial_object,d0	; Select the initial object
	bsr init_object

	moveq #0,d0			; Move the shape forward by the projection distance (behind the screen)
	moveq #10,d1
	move.w #projection_centre,d2
	bsr fixco

	; Make a copy of the initial object coordinates
	move.l e_coords(pc),a2
	move.l p_coords(pc),a0
	lea bufr+x,a1
bakup	move.l (a0)+,(a1)+
	cmp.l a2,a0
	blt.s bakup

	bsr prestar		; Pre-calculate stars
	bsr preshift		; Pre-shift the balls
	bsr dish		; Display the help text
	bsr make_zsizes		; Make the table of z-coordinate to ball size

	moveq #1,d0		; Start the music
	bsr music

	moveq #0,d0		; Translate the object to the screen plane
	moveq #0,d1
	move.w #projection_centre,d2
	bsr fixco

	bsr setup_interrupts		; Enable interrupts

	lea hhelp+8(pc),a6
	lea ftb2(pc),a5
fatb2	move.w (a5),(a6)
	move.w (a5)+,16(a6)
	move.l $466.w,d7
	addq.l #8,d7
delf2	cmp.l $466.w,d7
	bne.s delf2
	cmp.l #eftb2,a5
	blt.s fatb2		; Fade to black 2

	clr.l $466.w		; Reset the frame counter

; Initial sequence - object enters the screen from behind the camera
intro_loop:
	bsr swap_screens

	move.w #37,-(sp)		; Wait for the next VBL
	trap #14
	addq.l #2,sp

	bsr rotx			; Rotate the object around the x axis (to update the working positions)
	
	bsr proj			; Project the object onto the screen
	bsr udraw			; Undraw the object
	bsr draw_it			; Draw the object
	
	lea bufr+z,a0			; Move the object into the screen
	moveq #40-1,d7			; TODO: this should not be hard-coded
wow	subq.w #intro_z_step,(a0)+
	subq.w #intro_z_step,(a0)+
	dbra d7,wow
	
	tst.w bufr+z			; Loop until it is in position
	bgt.s intro_loop

	move.b #scancode_f1+9,d0	; Select a pleasing preset
	bsr preset

mainloop:
	bsr swap_screens

	bsr wait_vbls

	bsr render_object			; Render the 3D object

	bsr update_angles			; Update the object rotation

	bsr.s handle_keys			; Handle key presses

	bra.s mainloop				; Restart the main loop

; Handle key presses
handle_keys:
	tst.b single_step
	bne.s wait_key

	move.b key(pc),d0
	bpl.s process_key

	rts

wait_key:
	stop #$2300
	move.b key(pc),d0
	bmi.s wait_key

.wait_release
	stop #$2300
	move.b key(pc),d1
	cmp.b d0,d1
	beq.s .wait_release

process_key:
	cmp.b #scancode_f1,d0
	blt.s not_preset

	cmp.b #scancode_f1+num_presets,d0
	blt preset

not_preset
	cmp.b #scancode_num1,d0
	blt.s not_number
	
	cmp.b #scancode_num1+num_objects-1,d0
	ble change_object

not_number	
	cmp.b #scancode_q,d0
	blt.s not_palette
	
	cmp.b #scancode_q+num_palettes,d0
	blt change_palette
	
not_palette
	cmp.b #scancode_dot,d0
	bne.s not_single_step

	not.b single_step
	rts

not_single_step
	lea keylist(pc),a0			; One of the special keys
	lea routlist(pc),a1
	moveq #num_special_keys-1,d7
	
	tst.b ctrl_key				; If control is pressed, use list 3
	beq.s no_ctrl
	lea routlist_ctrl(pc),a1

no_ctrl	tst.b shift_key				; If shift is pressed, use list 2
	beq.s keychk
	lea routlist_sh(pc),a1

keychk	cmp.b (a0)+,d0				; Find the matching key
	dbeq d7,keychk
	tst.b d7				; Check if we reached the end of the list
	bmi.s .no_key
	
	move.w d7,d6				; Otherwise, convert the index to an offset
	lsl.w #2,d6
	move.l (a1,d6),a0			; Look up the key handler
	jsr (a0)				; Call the key handler

.no_key	rts

; Start the exit sequence
quit	bsr swap_screens

	bsr wait_vbls

	bsr render_object
	
	bsr update_angles				; Update the object rotation
	
	add.w #zoom_step,zoom			; Zoom out
	cmp.w #max_zoom,zoom			; Until we reach the maximum zoom
	blt.s quit

; Exit the program
exit	bsr restore_interrupts				; Turn off interrupts

	lea $ffff8800.w,a0			; Mute the sound
	move.b #7,(a0)
	move.b #$ff,2(a0)
	move.b #8,(a0)
	clr.b 2(a0)
	move.b #9,(a0)
	clr.b 2(a0)
	move.b #10,(a0)
	clr.b 2(a0)

	move.l screen1(pc),a0			; Clear the screen
	move.l screen2(pc),a1
	move.l a1,a2
	adda.l #screen_bytes,a2
	moveq #0,d0
clrs3	move.l d0,(a0)+
	move.l d0,(a1)+
	cmp.l a1,a2
	bge.s clrs3

	move.w orez(pc),-(sp)			; Restore the resolution and original screen address
	move.l o44e(pc),-(sp)
	move.l (sp),-(sp)
	move.w #5,-(sp)
	trap #14
	lea 12(sp),sp
	
	movem.l opal(pc),d0-d7			; Restore the palette
	movem.l d0-d7,$ffff8240.w

	move.l stack(pc),-(a7)			; Exit supervisor mode
	move.w #$20,-(sp)
	trap #1
	addq.l #6,sp
		
	move.l retadr(pc),d0			; check for a return address
	tst.l d0
	beq.s byebye

	move.l d0,a0
	jmp (a0)

byebye	clr.w -(sp)
	trap #1

; Core routines to render the 3D object
render_object:
	bsr rotx				; Rotate the object around the x,y,z axes
	bsr roty
	bsr rotz

	bsr move_cam				; Move the object relative to the camera
	
	bsr proj				; Project the object onto the screen

	bsr udraw				; Undraw the object
	bsr draw_it				; Draw the object

	rts

; Swap the double-buffered screens
swap_screens:
	move.l screen1(pc),d0
	move.l screen2(pc),screen1
	move.l d0,screen2
	lsr.w #8,d0
	move.l d0,$ffff8200.w
	rts

; Wait until the target VBL is reached then update the next target
wait_vbls:
	move.l $466.w,d0			; Wait for the target frame
	cmp.l svbl(pc),d0
	bge.s .nvbl

	stop #$2300
	bra.s wait_vbls

.nvbl	add.w vbl_delay(pc),d0
	move.l d0,svbl

	rts

; Wait for a keypress if single step mode is enabled
wait_step:
	tst.b single_step
	beq.s .nowait

.wkey	stop #$2300
	move.b key(pc),d0
	bmi.s .wkey

.wrelease
	stop #$2300
	move.b key(pc),d1
	cmp.b d0,d1
	beq.s .wrelease

.nowait	rts

null_key:	rts

add_x	sub.w #13,d7
	lsl.w #1,d7

	lea xm(pc),a5
	lea axtxt(pc),a6
	cmp.b #"_",1(a6)
	beq burnr

	add.w d7,(a5)

	tst.w d7
	bmi dec_txt
	bra atxt


add_y	sub.w #12,d7
	lsl.w #1,d7
	lea ym(pc),a5
	lea aytxt(pc),a6
	cmp.b #"_",1(a6)
	beq burnr

	add.w d7,(a5)

	tst.w d7
	bmi dec_txt
	bra atxt

add_z	sub.w #9,d7
	lsl.w #1,d7
	lea zoom(pc),a5
	lea aztxt(pc),a6
	cmp.b #"_",1(a6)
	beq burnr

	add.w d7,(a5)

	tst.w d7
	bmi dec_txt
	bra atxt

rot_z	sub.w #9,d7
	lea zng(pc),a5
	lea sztxt(pc),a6
	cmp.b #"_",2(a6)
	beq burnr

	add.w d7,(a5)

	tst.w d7
	bmi dec_txt
	bra atxt

rot_x	sub.w #12,d7
	lea xng(pc),a5
	lea sytxt(pc),a6
	cmp.b #"_",2(a6)
	beq.s burnr

	add.w d7,(a5)

	tst.w d7
	bmi dec_txt
	bra atxt

rot_y	sub.w #13,d7
	lea yng(pc),a5
	lea sxtxt(pc),a6
	cmp.b #"_",2(a6)
	beq.s burnr

	add.w d7,(a5)

	tst.w d7
	bmi dec_txt
	bra atxt

	rts

mov_z	sub.w #9,d7
	lsl.w #1,d7
	lea bufr+z,a0
	lea zoff(pc),a5
	lea ztxt(pc),a6
	cmp.b #"_",1(a6)
	beq.s burn
	bra.s modco

mov_y	sub.w #12,d7
	lsl.w #1,d7
	lea bufr+y,a0
	lea yoff(pc),a5
	lea ytxt(pc),a6
	cmp.b #"_",1(a6)
	beq.s burn
	bra.s modco

burnr	tst.w d7
	bpl.s bmar
	cmp.b #"i",(a6)
	beq.s nurnr
	add.w d7,(a5)

	tst.w d7
	bmi dec_txt
	bra.s atxt

nurnr	rts

bmar	cmp.b #"i",(a6)
	bne.s nurnr
	tst.w d7
	bmi dec_txt
	bra.s atxt
	add.w d7,(a5)

burn	tst.w d7
	bpl.s bma
	cmp.b #"i",(a6)
	bne.s modco
	rts

bma	cmp.b #"i",(a6)
	beq.s modco
	rts

mov_x	sub.w #13,d7
	lsl.w #1,d7
	lea bufr+x(pc),a0
	lea xoff(pc),a5
	lea xtxt(pc),a6
	cmp.b #"_",1(a6)
	beq.s burn

; Modify the object co-ordinates
modco	add.w d7,(a5)
	move.w numpoints(pc),d0
	subq.w #1,d0
addon	add.w d7,(a0)+
	dbra d0,addon
	tst.w d7
	bmi dec_txt

; Add to a text field
atxt	cmp.b #"i",(a6)
	beq.s atn
	add.b d7,3(a6)
	cmp.b #"d",3(a6)
	ble.s nad
	sub.b #10,3(a6)
	addq.b #1,2(a6)
	cmp.b #"d",2(a6)
	ble.s nad
	sub.b #10,2(a6)
	addq.b #1,1(a6)
	cmp.b #"d",1(a6)
	ble.s nad
	move.l #" [[[",(a6)
nad	cmp.l #"i[[[",(a6)
	beq.s atxt
	bsr dtxt
	rts

atn	sub.b d7,3(a6)
	cmp.b #"[",3(a6)
	bge.s nad2
	add.b #10,3(a6)
	subq.b #1,2(a6)
	cmp.b #"[",2(a6)
	bge.s nad2
	add.b #10,2(a6)
	subq.b #1,1(a6)
	cmp.b #"[",1(a6)
	bge.s nad2
	move.l #" [[[",(a6)
nad2	cmp.l #"i[[[",(a6)
	beq.s atn
	bsr dtxt
	rts

 ; Decrement a text field
dec_txt	cmp.b #"i",(a6)
	beq.s postv
	add.b d7,3(a6)
	cmp.b #"[",3(a6)
	bge.s nad3
	add.b #10,3(a6)
	subq.b #1,2(a6)
	cmp.b #"[",2(a6)
	bge.s nad3
	add.b #10,2(a6)
	subq.b #1,1(a6)
	cmp.b #"[",1(a6)
	bge.s nad3
	move.l #"i[[[",(a6)
nad3	cmp.l #"i[[[",(a6)
	beq.s dec_txt
	bsr.s dtxt
	rts
	
postv	sub.b d7,3(a6)
	cmp.b #"d",3(a6)
	ble.s nad4
	sub.b #10,3(a6)
	addq.b #1,2(a6)
	cmp.b #"d",2(a6)
	ble.s nad4
	sub.b #10,2(a6)
	addq.b #1,1(a6)
	cmp.b #"d",1(a6)
	ble.s nad4
	move.l #"ifff",(a6)
nad4	cmp.l #"i[[[",(a6)
	beq.s postv
	bsr.s dtxt
	rts

; Display text string in a6
dtxt	move.l a0,-(sp)
	move.l screen1(pc),a1			; Draw the text on both buffers
	move.l screen2(pc),a2
	add.l 4(a6),a1
	add.l 4(a6),a2
	lea f8x8(pc),a0
	
	move.w #1,d1
	move.w #7,d2

letlop2	clr.w d7
	move.b (a6)+,d7
	beq .etxt

	sub.b #"A",d7
	bpl.s .is_chr

	clr.b 6(a1)				; Draw a space
	clr.b 166(a1)
	clr.b 326(a1)
	clr.b 486(a1)
	clr.b 646(a1)
	clr.b 806(a1)
	clr.b 966(a1)
	clr.b 1126(a1)
	clr.b 6(a2)
	clr.b 166(a2)
	clr.b 326(a2)
	clr.b 486(a2)
	clr.b 646(a2)
	clr.b 806(a2)
	clr.b 966(a2)
	clr.b 1126(a2)
	bra.s .elet

.is_chr	lsl.w #3,d7			; Draw a character
	move.b (a0,d7.w),6(a1)
	move.b 1(a0,d7.w),166(a1)
	move.b 2(a0,d7.w),326(a1)
	move.b 3(a0,d7.w),486(a1)
	move.b 4(a0,d7.w),646(a1)
	move.b 5(a0,d7.w),806(a1)
	move.b 6(a0,d7.w),966(a1)
	move.b 7(a0,d7.w),1126(a1)
	move.b (a0,d7.w),6(a2)
	move.b 1(a0,d7.w),166(a2)
	move.b 2(a0,d7.w),326(a2)
	move.b 3(a0,d7.w),486(a2)
	move.b 4(a0,d7.w),646(a2)
	move.b 5(a0,d7.w),806(a2)
	move.b 6(a0,d7.w),966(a2)
	move.b 7(a0,d7.w),1126(a2)
.elet	add.w d1,a1
	add.w d1,a2
	exg d1,d2
	bra letlop2

.etxt	move.l (sp)+,a0
	rts


clr_angles:
	clr.l xang
	clr.w zang
	rts

clr_rots:
	clr.l xng
	clr.w zng
	lea sytxt(pc),a6
	move.l #" [[[",(a6)
	bsr dtxt
	lea sxtxt(pc),a6
	move.l #" [[[",(a6)
	bsr dtxt
	lea sztxt(pc),a6
	move.l #" [[[",(a6)
	bsr dtxt

	rts

; Toggle the palette buffers to hide/show the help text	
help	move.l a0,-(sp)
	move.l b_palette(pc),a0
	move.l f_palette(pc),b_palette
	move.l a0,f_palette
	move.b #$ff,key
	move.l (sp)+,a0
	rts

; Reset all rotations and offsets to the original values
restr	move.l e_coords(pc),a2
	move.l p_coords(pc),a0
	lea bufr+x(pc),a1
roop	move.l (a0)+,(a1)+
	cmp.l a2,a0
	blt.s roop
	
	clr.l xoff
	clr.w zoff
	clr.l xang
	clr.w zang
	clr.l xng
	clr.w zng
	clr.l xm
	clr.w zoom

	lea xtxt(pc),a6
	move.l #" [[[",(a6)
	bsr dtxt
	lea ytxt(pc),a6
	move.l #" [[[",(a6)
	bsr dtxt
	lea ztxt(pc),a6
	move.l #" [[[",(a6)
	bsr dtxt

	lea sytxt(pc),a6
	move.l #" [[[",(a6)
	bsr dtxt
	lea sxtxt(pc),a6
	move.l #" [[[",(a6)
	bsr dtxt
	lea sztxt(pc),a6
	move.l #" [[[",(a6)
	bsr dtxt

	lea aytxt(pc),a6
	move.l #" [[[",(a6)
	bsr dtxt
	lea axtxt(pc),a6
	move.l #" [[[",(a6)
	bsr dtxt
	lea aztxt(pc),a6
	move.l #" [[[",(a6)
	bsr dtxt

	rts

preset	move.l pisp(pc),a0
	andi.w #$ff,d0
	sub.b #scancode_f1,d0
	lsl.w #2,d0
	move.l (a0,d0.w),a0
	
	move.l a0,-(sp)
	bsr restr
	move.l (sp)+,a0

	movem.w (a0)+,d0-d2
	movem.w d0-d2,xoff
	bsr fixco
	move.l (a0)+,xang
	move.w (a0)+,zang
	move.l (a0)+,xng
	move.w (a0)+,zng
	move.l (a0)+,xm
	move.w (a0)+,zoom

	move.b #$ff,key

	lea xtxt(pc),a6
	move.l (a0)+,(a6)
	bsr dtxt
	lea ytxt(pc),a6
	move.l (a0)+,(a6)
	bsr dtxt
	lea ztxt(pc),a6
	move.l (a0)+,(a6)
	bsr dtxt

	lea sytxt(pc),a6
	move.l (a0)+,(a6)
	bsr dtxt
	lea sxtxt(pc),a6
	move.l (a0)+,(a6)
	bsr dtxt
	lea sztxt(pc),a6
	move.l (a0)+,(a6)
	bsr dtxt

	lea axtxt(pc),a6
	move.l (a0)+,(a6)
	bsr dtxt
	lea aytxt(pc),a6
	move.l (a0)+,(a6)
	bsr dtxt
	lea aztxt(pc),a6
	move.l (a0)+,(a6)
	bsr dtxt

	rts

; Fixup object2 co-ordinates (target transform)
; d0: X offset
; d1: Y offset
; d2: Z offset
fixco2	movem.l a0-a2/d4-d7,-(sp)	; Save working registers
	move.w 8(a0),d7			; Read the number of points
	lea bufr(pc),a2
	lea x2(a2),a0			; Set up the pointers to the x2, y2 and z2 buffers
	lea y2(a2),a1
	lea z2(a2),a2	
	bra.s fixcom			; Jump to the common code

; Fixup object co-ordinates
; d0: X offset
; d1: Y offset
; d2: Z offset
fixco	movem.l a0-a2/d4-d7,-(sp)	; Save working registers

	lea bufr(pc),a2
	lea x(a2),a0		; Set up the pointers to the x, y and z buffers
	lea y(a2),a1
	lea z(a2),a2

	move.w numpoints(pc),d7	; Read the number of points in the current object

fixcom	btst #0,d7			; If the number of points is odd, round up
	beq.s .even
	addq.w #1,d7

.even	move.w d0,d4		; Duplicate the 16 bits offsets in d0-d2 in the upper 16 bits
	move.w d1,d5
	move.w d2,d6
	swap d0
	swap d1
	swap d2
	move.w d4,d0
	move.w d5,d1
	move.w d6,d2

	lsr.w #1,d7		; Divide the number of points by 2
	subq.w #1,d7		; Subtract one for the loop counter
mosco	add.l d0,(a0)+		; Add the values in d0-d2 to the x,y and z buffers
	add.l d1,(a1)+
	add.l d2,(a2)+
	dbra d7,mosco

	movem.l (sp)+,a0-a2/d4-d7	; Restore the registers
	rts

; Rotate points about the X axis
; [1    0     0  ]
; [0  cos  -sin  ]
; [0  sin   cos  ]
rotx	movem.l d0-d7/a0-a6,-(sp)
	lea sin(pc),a0
	lea cos(pc),a1
	move.w xang(pc),d0	; Get X rotation angle
	add.w d0,d0		; Index to offset in the sin/cos tables
	move.w (a1,d0.w),d1	; cos xang
	move.w (a0,d0.w),d0	; sin xang
	lea bufr+y(pc),a0	; y coordinates
	lea bufr+z(pc),a1	; z coordinates
	lea bufr+x(pc),a4	; x coordinates
	lea bufr+yn,a2		; new y coordinates
	lea bufr+zn,a3		; new z coordinates
	lea bufr+xn,a5		; new x coordinates

	move.w numpoints(pc),d7
	subq.w #1,d7
x1	move.w (a4)+,(a5)+	; X stays the same
	move.w (a0)+,d2		; Load Y
	move.w d2,d4		; Save Y for Z calculation
	muls d1,d2		; Y * cos
	move.w (a1),d3		; Load Z
	muls d0,d3		; Z * sin
	add.l d3,d2		; Y * cos + Z * sin
	add.l d2,d2		; * 2 for 16 bit fixed point precision
	swap d2			; Get the integer part
	move.w d2,(a2)+		; Store new Y
	move.w (a1)+,d3		; Load Z
	muls d1,d3		; Z * cos
	add.l d3,d3		; * 2 for 16 bit fixed point precision
	swap d3			; Get the integer part
	muls d0,d4		; Y * sin
	add.l d4,d4		; * 2 for 16 bit fixed point precision
	swap d4			; Get the integer part
	sub.w d4,d3		; Z * cos - Y * sin
	move.w d3,(a3)+		; Store new Z
	dbra d7,x1

	movem.l (sp)+,d0-d7/a0-a6
	rts

; Rotate points about the Y axis
; [ cos  0  sin ]
; [  0   1   0  ]
; [-sin  0  cos ]
roty	movem.l d0-d7/a0-a6,-(sp)

	lea sin(pc),a0
	lea cos(pc),a1
	move.w yang(pc),d0	; Get Y rotation angle
	add.w d0,d0		; Index to offset in the sin/cos tables
	move.w (a1,d0.w),d1	; cos yang
	move.w (a0,d0.w),d0	; sin yang
	lea bufr+zn,a1		; z coordinates
	lea bufr+xn,a4		; x coordinates

	move.w numpoints(pc),d7
	subq.w #1,d7
y1	move.w (a4),d2		; Load X
	move.w d2,d4		; Save X for Z calculation
	muls d1,d2		; X * cos
	add.l d2,d2		; * 2 for 16 bit fixed point precision
	swap d2			; Get the integer part
	move.w (a1),d3		; Load Z
	muls d0,d3		; Z * sin
	add.l d3,d3		; * 2 for 16 bit fixed point precision
	swap d3			; Get the integer part
	sub.w d3,d2		; X * cos - Z * sin
	move.w d2,(a4)+		; Store new X
;	moveq #0,d3		; Clear for multiplication
	move.w (a1),d3		; Load Z
	muls d1,d3		; Z * cos
	add.l d3,d3		; * 2 for 16 bit fixed point precision
	swap d3			; Get the integer part
	muls d0,d4		; X * sin
	add.l d4,d4		; * 2 for 16 bit fixed point precision
	swap d4			; Get the integer part
	add.w d4,d3		; Z * cos + X * sin
	move.w d3,(a1)+		; Store new Z
	dbra d7,y1

	movem.l (sp)+,d0-d7/a0-a6
	rts

; Rotate points about the Z axis
; [cos  -sin  0]
; [sin   cos  0]
; [ 0     0   1]
rotz	movem.l d0-d7/a0-a6,-(sp)

	lea sin(pc),a0
	lea cos(pc),a1
	move.w zang(pc),d0
	add.w d0,d0		; Index to offset in the sin/cos tables
	move.w (a1,d0.w),d1	; cos zang
	move.w (a0,d0.w),d0	; sin zang
	lea bufr+yn,a0		; y coordinates
	lea bufr+xn,a4		; x coordinates

	move.w numpoints(pc),d7
	subq.w #1,d7
z1	move.w (a4),d2		; Load X
	move.w d2,d4		; Save X for Y calculation
	muls d1,d2		; X * cos
	move.w (a0),d3		; Load Y
	muls d0,d3		; Y * sin
	sub.l d3,d2		; X * cos - Y * sin
	add.l d2,d2		; * 2 for 16 bit fixed point precision
	swap d2			; Get the integer part
	move.w d2,(a4)+		; Store new X

	move.w (a0),d3		; Load Y
	muls d1,d3		; Y * cos
	muls d0,d4		; X * sin
	add.l d3,d4		; X * sin + Y * cos
	add.l d4,d4		; * 2 for 16 bit fixed point precision
	swap d4			; Get the integer part
	move.w d4,(a0)+		; Store new Y

	dbra d7,z1

	movem.l (sp)+,d0-d7/a0-a6
	rts

; Move the object relative to the camera
move_cam:
	movem.l d0-d2/d7/a0-a2,-(sp)

	lea bufr+xn,a0
	lea bufr+yn,a1
	lea bufr+zn,a2
	move.w xm(pc),d0	
	move.w ym(pc),d1	
	move.w zoom(pc),d2
	move.w numpoints(pc),d7
	subq.w #1,d7
mrelop	sub.w d0,(a0)+
	sub.w d1,(a1)+
	sub.w d2,(a2)+
	dbra d7,mrelop

	movem.l (sp)+,d0-d2/d7/a0-a2
	rts


; Project the object coordinates onto the screen
; Formula: screen_coordinate = object_coordinate * (projection_centre / (projection_centre + z))
proj	movem.l	d0-d5/a1-a5,-(sp)

	lea	bufr+xn,a1			; X coordinates in 3D space
	lea	bufr+yn,a2			; Y coordinates in 3D space
	lea	bufr+zn,a3			; Z coordinates in 3D space
	lea	bufr+xp,a4			; Projected X coordinates on screen
	lea	bufr+yp,a5			; Projected Y coordinates on screen

	move.w	#projection_centre,d5		; Load projection centre constant
	ext.l	d5				; Sign extend to long

	move.w	numpoints(pc),d0		; Get number of points to project
	subq.w	#1,d0				; Subtract one for dbra loop counter

projloop
	move.w	(a3)+,d4			; Get Z coordinate
	neg.w	d4				; Negate Z (because +Z is into screen)
	ext.l	d4				; Sign extend to long
	move.l	d5,d3				; d3 = projection_centre
	add.l	d4,d3				; d3 = projection_centre + z
	bne.s	pers1				; If not zero, do perspective projection

	; point is at exactly z = -projection_centre
	move.w	#500,d1				; Set X&Y outside the screen
	addq.l	#2,a1				; Skip X coordinate
	addq.l	#2,a2				; Skip Y coordinate
	move.w	d1,(a4)+			; Store offscreen X
	move.w	d1,(a5)+			; Store offscreen Y
	bra.s	parend				; Next point
	
pers1	lsl.l	#8,d4				; d4 = z * 256 (fixed point scaling)
	divs	d3,d4				; d4 = (z * 256) / (projection_centre + z)
	move.w	d4,d3				; Save scale factor for Y calculation
	
	move.w	(a1)+,d1			; Get X coordinate
	move.w	d1,d2				; Save original X
	muls	d1,d3				; d3 = x * scale
	lsr.l	#8,d3				; Convert back from fixed point
	sub.w	d3,d2				; d2 = x - (x * scale) = x * (1 - scale)
	add.w	#150,d2				; Add X offset for screen centre
	move.w	d2,(a4)+			; Store projected X
	
	move.w	(a2)+,d2			; Get Y coordinate
	muls	d2,d4				; d4 = y * scale
	lsr.l	#8,d4				; Convert back from fixed point
	sub.w	d4,d2				; d2 = y - (y * scale) = y * (1 - scale)
	neg.w	d2				; Flip Y coordinate (screen Y goes down)
	add.w	#22+29,d2			; Add Y offset for screen centre
	move.w	d2,(a5)+			; Store projected Y

parend	dbra	d0,projloop			; Next point

	movem.l	(sp)+,d0-d5/a1-a5		; Restore registers
	rts


; Update rotation angles
update_angles:	
	movem.l d0/d7/a0-a1,-(sp)
	lea xang(pc),a0				; a0: Current angles
	neg.w yng				; negate x&y directions (I guess it's to make the controls more intuitive)
	neg.w zng
	lea xng(pc),a1				; a1: rotation speeds
	move #360,d6				; d6: maximum angle
	moveq #num_axes-1,d7			; d7: loop counter
loopy	move.w (a1)+,d0				; d0: rotation speed
	bmi.s .negrot
	add.w d0,(a0)				; Add the rotation speed to the current angle
	cmp.w (a0)+,d6				; Check if the angle is greater than 359
	bgt.s .eloop
	sub.w d6,-2(a0)				; Subtract 360 from the angle
	bra.s .eloop
.negrot	add.w d0,(a0)+				; Subtract the rotation speed from the current angle
	bge.s .eloop				; Check if the angle is less than 0
	add.w d6,-2(a0)				; Add 360 to the angle
.eloop	dbra d7,loopy
	
endrot	neg.w yng				; revert x&y directions
	neg.w zng

	movem.l (sp)+,d0/d7/a0-a1
	rts

; Draw the object
draw_it:
	movem.l d0-d7/a0-a6,-(sp)

	lea bufr(pc),a1
	lea sizes(a1),a0			; Table of ball sizes
	lea sizn(a1),a1				; Something for the undraw?
	move.w numpoints(pc),d7			; Current ball count
	lsr.w #4,d7				; Divide count by 16
copszs	move.l (a0)+,(a1)+			; Copy 32 bytes (8 bytes for each ball)
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	move.l (a0)+,(a1)+
	dbra d7,copszs

	lea bufr+xp,a3				; a3: projected x coordinates
	lea bufr+yp,a4				; a4: projected y coordinates

	move.l undraw1(pc),a6			; a6: undraw routines
	move.l undraw2(pc),undraw1		; Swap the undraw buffers
	move.l a6,undraw2
	move.w num_undraw2(pc),num_undraw1	; Swap the undraw counts
	clr.w num_undraw2

	move.l screen1(pc),a5			; a5: screen buffer
	lea y_zero_line*bytes_per_line(a5),a5	; screen address offset (so we can use signed 16-bit offsets)

	move.w numpoints(pc),dead		; Set up the loop counters and screen pointers (self-modifying code to save registers)
	subq.w #1,dead				; Subtract one for the loop counter
	add.w #$7c00,dead			; Add the opcode for moveq n,d6
	move.w #$7000,dead2			; Add the opcode for moveq 0,d0

	move.l #bufr+zn,dead3+2			; Z coordinates
	move.l #bufr+sizn,dead4+2		; Ball sizes
	move.l #bufr+xp,dead5+2			; Projected X coordinates
	move.l #bufr+yp,dead6+2			; Projected Y coordinates

draw_loop:

	; Sort the balls by Z coordinate - this is probably very inefficient

dead3	lea bufr+zn,a0				; a0: Z coordinates
dead2	moveq #0,d0				; d0: ball number
	
	move.w (a0),headon+2			; Read the Z coordinate and save it in headon+2
	lea (a0),a2				; a2: Z coordinates
	move.w (a0)+,d1				; Read the Z coordinate again (why?)
	move.w d0,d7				; d7: ball number
	addq.w #1,d0
dead	moveq #0,d6				; Read the loop counter - this instruction is modified at runtime
	beq.s headon

zsort	move.w (a0)+,d2				; Read the next Z coordinate
	cmp.w d1,d2				; Check if it is greater than the previous Z coordinate
	bge.s zs1				; If it is, skip the swap

	move.w -2(a0),d1			; Swap the Z coordinates
	lea -2(a0),a2				; Update the write pointer
	move.w d0,d7
zs1	addq.w #1,d0
	dbra d6,zsort				; Sort loop

headon	move.w #0,(a2)				; Write the Z coordinate (this instruction is modified at runtime)

	lsl.w #1,d7				; Convert the ball number to an offset
	ext.l d7
	
	cmp.w #max_z,d1				; Check if the Z coordinate is clipped
	bge clipped

	cmp.w #min_z,d1
	blt clipped
	
	lea bufr+zsizes+3600*2,a0		; Offset in the Z-sizes table : 3600*2 = the Z=0 plane
	add.w d1,d1
	add.w d1,a0
	move.w (a0),moradd+2			; Get the Z-size and update the offset in the draw routine list
	
sized	move.l #bufr+sizn,sizer+2		; Update the offset in the ball sizes table
	add.l d7,sizer+2
	
sizer	move.w bufr+sizn,d0			; Read the ball size
	add.w d0,moradd+2			; Add the ball size to the draw routine offset
	cmp.w #ball_bytes*10,moradd+2			; Check if the offset is so high the ball is too small to see
	bgt clipped
	
	tst.w moradd+2				; Check if the offset is valid
	bpl.s ra
	
	clr.w moradd+2				; If not, set the offset to zero - draw a full-size ball

ra	move.w (a3,d7),d0			; Read the projected X and Y coordinates for the ball
	move.w (a4,d7),d1

	cmp.w #screen_width,d0			; Check if the ball is clipped on X or Y
	bge.s clipped
	cmp.w #min_x_coord,d0
	ble.s clipped
	cmp.w #screen_height,d1
	bge.s clipped
	cmp.w #min_y_coord,d1
	ble.s clipped

	clr.w pfloyd+2			; What is pink floyd doing? clipping balls at the left and right edges of the screen?
	tst.w d0
	bpl.s nc2
	add.w #16,d0
	move.w #8,pfloyd+2
	
nc2	cmp.w #304,d0
	ble.s nc3
	move.w #4,pfloyd+2	

nc3	lsl.w #5,d1			; Convert the Y coordinate to a screen offset (MULU #160)
	move.w d1,d4
	lsl.w #2,d1
	add.w d4,d1
	
	move.w d0,d2			; Convert the X coordinate to a screen offset and bitmask
	lsr.w #4,d2
	lsl.w #3,d2
	add.w d1,d2
	andi.w #%1111,d0		; Shift number (modulo of X coordinate / 16)
	lea (a5,d2.w),a1		; a1: screen buffer address
	move.l a1,(a6)+			; Save the undraw address
	addq.w #1,num_undraw2		; Increment the undraw count
	
	lsl.w #4,d0			; Convert the shift number to an offset
pfloyd	add.w #0,d0
	lea bufr+codelist,a0

moradd	add.w #0,d0			; Offset into the draw routine list (self-modifying code)
	move.l (a0,d0.w),a0
	jsr (a0)

clipped	lea bufr+sizn,a0
dead4	move.w bufr+sizn,(a0,d7.w)
dead5	move.w bufr+xp,(a3,d7.w)
dead6	move.w bufr+yp,(a4,d7.w)

	addq.w #1,dead2
	addq.l #2,dead3+2
	addq.l #2,dead4+2
	addq.l #2,dead5+2
	addq.l #2,dead6+2
	subq.b #1,dead+1
	bpl draw_loop

	movem.l (sp)+,d0-d7/a0-a6
	rts

; Undraw the balls
udraw	movem.l d0-d2/a0-a1,-(sp)

	move.l undraw1(pc),a1		; a1: undraw addresses
	moveq #0,d0
	move.w num_undraw1(pc),d2	; d2: number of balls to undraw
	subq.w #1,d2			; Subtract one for the loop counter
	bpl.s udraw_loop		; Start the undraw loop

	movem.l (sp)+,d0-d2/a0-a1
	rts

udraw_loop:
	move.l (a1)+,d1			; Read the undraw address
	bmi goodbye			; If the address is negative, we're done

	cmp.l #bufr,d1			; Make sure the address is at least above the code area
	blt.s goodbye

	move.l d1,a0			; Set the undraw address in a0
	move.l d0,(a0)			; Write a whole lot of zeros to the screen buffer
	move.l d0,8(a0)			; 16 cycles per write... can it be done faster?
	move.l d0,160(a0)
	move.l d0,168(a0)
	move.l d0,320(a0)
	move.l d0,328(a0)
	move.l d0,480(a0)
	move.l d0,488(a0)
	move.l d0,640(a0)
	move.l d0,648(a0)
	move.l d0,800(a0)
	move.l d0,808(a0)
	move.l d0,960(a0)
	move.l d0,968(a0)
	move.l d0,1120(a0)
	move.l d0,1128(a0)
	move.l d0,1280(a0)
	move.l d0,1288(a0)
	move.l d0,1440(a0)
	move.l d0,1448(a0)
	move.l d0,1600(a0)
	move.l d0,1608(a0)
	move.l d0,1760(a0)
	move.l d0,1768(a0)
	move.l d0,1920(a0)
	move.l d0,1928(a0)
	move.l d0,2080(a0)
	move.l d0,2088(a0)
	move.l d0,2240(a0)
	move.l d0,2248(a0)
	;move.l d0,2400(a0)
	;move.l d0,2408(a0)
	;move.l d0,2560(a0)
	;move.l d0,2568(a0)
	;move.l d0,2720(a0)
	;move.l d0,2728(a0)
	;move.l d0,2880(a0)
	;move.l d0,2888(a0)
	;move.l d0,3040(a0)
	;move.l d0,3048(a0)
	
goodbye	dbra d2,udraw_loop

	movem.l (sp)+,d0-d2/a0-a1
	rts

; Store the state of the interrupt handlers and install our own
setup_interrupts:
	lea mfpstr(pc),a0
	move.b $fffffa07.w,(a0)+
	move.b $fffffa09.w,(a0)+
	move.b $fffffa13.w,(a0)+
	move.b $fffffa15.w,(a0)+
	move.l $70.w,(a0)+
	move.l $118.w,(a0)+
	move.l $120.w,(a0)+
	move.l $8.w,(a0)+
	move.l $c.w,(a0)+
	move.l $10.w,(a0)+
	move.l $20.w,(a0)+
	; move.l #exit,$8.w
	; move.l #exit,$c.w
	; move.l #exit,$10.w
	; move.l #exit,$20.w

	clr.b $fffffa07.w
	clr.b $fffffa09.w
	bclr #3,$fffffa17.w
	move.l #nkey,$118.w
	move.l #vbl_main,$70.w
	; move.l #vbl_null,$70.w
	move.l #nul2,$120.w
	bset #6,$fffffa09.w
	bset #6,$fffffa15.w
	bset #0,$fffffa07.w
	bset #0,$fffffa13.w
	move.b #$12,$fffffc02.w
	rts

; Keyboard handler
nkey:	move.w d0,-(sp)
	move.w d1,-(sp)
	move.b $fffffc02.w,d0		; Read the keyboard status
	cmp.b #$ff,d0			; Check if it's a joystick input
	beq.s joyst
	
	move.b d0,d1			; Save the key code
	andi.b #$fc,d0			; Check if it's mouse data
	cmp.b #$f8,d0
	beq.s mous

	; Check for modifier keys
	cmp.b #scancode_shift,d1
	beq.s shfton
	
	cmp.b #scancode_shift+scancode_release,d1
	beq.s shftoff

	cmp.b #scancode_rshift,d1
	beq.s shfton

	cmp.b #scancode_rshift+scancode_release,d1
	beq.s shftoff
	
	cmp.b #scancode_ctrl,d1
	beq.s ctrlon
	
	cmp.b #scancode_ctrl+scancode_release,d1
	beq.s ctrloff
	
	move.b d1,key			; It's a real key, save the key code

ekey	move.w (sp)+,d1
	move.w (sp)+,d0
	rte

joyst	move.l #gjoy,$118.w		; Next value is a joystick input
	bra.s ekey

gjoy	move.b $fffffc02.w,joycm	; Read the joystick input
	move.l #nkey,$118.w
nul2	rte

mous	move.l #gmous1,$118.w		; Next value is mouse data
	move.b d1,mousb
	bra.s ekey

gmous1	move.b $fffffc02.w,mousx	; Read the mouse X data
	move.l #gmous2,$118.w
	rte

gmous2	move.b $fffffc02.w,mousy	; Read the mouse Y data
	move.l #nkey,$118.w
	rte

shfton	move.b #1,shift_key		; Set the shift key flag
	bra.s ekey

shftoff clr.b shift_key			; Clear the shift key flag
	bra.s ekey

ctrlon	move.b #1,ctrl_key		; Set the control key flag
	bra.s ekey

ctrloff clr.b ctrl_key			; Clear the control key flag
	bra.s ekey

; Restore the interrupt handlers and the MFP registers to their original state
restore_interrupts:
	clr.b $fffffa1b.w
	lea mfpstr(pc),a0
	move.b (a0)+,$fffffa07.w
	move.b (a0)+,$fffffa09.w
	move.b (a0)+,$fffffa13.w
	move.b (a0)+,$fffffa15.w
	bset #3,$fffffa17.w
	move.l (a0)+,$70.w
	move.l (a0)+,$118.w
	move.l (a0)+,$120.w
	move.l (a0)+,$8.w
	move.l (a0)+,$c.w
	move.l (a0)+,$10.w
	move.l (a0)+,$20.w


	move.b #8,$fffffc02.w
	move.b #7,$ffff8800.w
	move.b #%11111111,$ffff8802.w
	rts

sync	subq.b #1,hbl_count
	rte

; Main VBL handler
vbl_main:
	movem.l d0-d7/a0-a6,-(sp)		; Save the registers
	move.l $68.w,-(sp)			; Save the Level 2 interrupt vector
	move.w sr,-(sp)				; Save the status register

	move.l #sync,$68.w			; Set the Level 2 interrupt vector to sync
	move.w #$2700,sr			; Disable interrupts
	move.b #32,hbl_count			; Set the number of HBLs to wait before the sync
	
	move.l f_palette(pc),a0			; Set the current palette (double buffered based on the help text visibility)
	movem.l (a0),d0-d7
	movem.l d0-d7,$ffff8240.w

	clr.b $ffff8260.w			; Set low resolution
	move.b #2,$ffff820a.w			; Set 50Hz mode
	
	stop #$2100				; Stop until first HBL

	bsr undraw_stars			; Undraw stars from previous frame
	bsr draw_stars				; Draw new stars
	bsr palette_fade
	
	clr.b $fffffa1b.w			; Clear Timer B control register
	move.b #bottom_border_line,$fffffa21.w	; Set the number of lines to wait to open the bottom border
	move.b #8,$fffffa1b.w			; Set Timer B to event mode
	move.l #open_bottom_border,$120.w	; Set the Timer B interrupt handler	
	
.wait_hbl
	stop #$2100				; Stop until next HBL
	tst.b hbl_count
	bpl.s .wait_hbl

	moveq #23,d7				; Delay until the end of the scanline
delay	dbra d7,delay

	clr.b $ffff820a.w			; Switch to 60Hz mode
	dcb.w 16,$4e71				; 16 NOPs (64 cycles)
	move.b #2,$ffff820a.w			; Switch to 50Hz mode

	move.w (sp)+,sr				; Restore the status register
	move.l (sp)+,$68.w			; Restore the Level 2 interrupt vector

;	bsr music+4			; Music VBL routine (+4 for the original .MSX, +8 for SNDH)
	bsr music+8			; Music VBL routine (+4 for the original .MSX, +8 for SNDH)

	addq.l #1,$466.w		; Increment the frame counter

	movem.l (sp)+,d0-d7/a0-a6
	rte

; Null VBL handler - just increment the frame counter
vbl_null:
	addq.l #1,$466.w		; Increment the frame counter
	rte

open_bottom_border:
	move.l d0,-(sp)			; Save the registers
	move.w sr,-(sp)

	move.w #$2700,sr		; Disable interrupts
	move.b #10,$fffffa21.w		; Set the timer B data register
	move.b $fffffa21.w,d0		; Read the current timer B data register
whbl	cmp.b $fffffa21.w,d0		; Check if the timer B data register has changed
	beq.s whbl

	move.w (sp)+,sr			; Restore the registers
	move.l (sp)+,d0

	clr.b $fffffa1b.w			; Clear Timer B control register

chme1	move.l #$7700300,$ffff8240+16.w		; Set the palette
chme2	move.l #$5000700,$ffff8240+20.w
chme3	move.l #$7700300,$ffff8240+24.w
chme4	move.l #$5000700,$ffff8240+28.w

	movem.l d0-d7/a0-a6,-(sp)		; Kill some time
	movem.l a0-a6,-(sp)
	movem.l (sp)+,a0-a6
	movem.l (sp)+,d0-d7/a0-a6

	andi.b #$fd,$ffff820a.w			; Switch to 60Hz mode
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	ori.b #2,$ffff820a.w			; Switch to 50Hz mode
	rte


; Undraw stars
undraw_stars:
	movem.l d0-d2/a0-a1,-(sp)

	move.l stund(pc),a0		; Screen address adjusted for signed offsets
	lea star_offset(a0),a0

	move.l pstar(pc),a1		; Buffer of star offsets

	clr.w d0
	moveq #num_stars-1,d2
ulop	move.w (a1)+,d1
	lea star_spacing+2(a1),a1
	move.w d0,(a0,d1.w)
	dbra d2,ulop

	movem.l (sp)+,d0-d2/a0-a1
	rts

; Draw stars
draw_stars:
	movem.l d5-d7/a4-a5,-(sp)
	move.l screen2(pc),a4			; Draw buffer
	move.l a4,stund				; Will be the next undraw buffer

	lea star_offset(a4),a4

	moveq #num_stars-1,d7
	move.l pstar(pc),a5			; Star pointer
	addq.l #star_size,a5			; Increment the star pointer
	move.l a5,pstar

	cmp.l endst(pc),a5			; Check for wrap
	blt.s .star_loop
	lea bufr+stark,a5
	move.l a5,pstar

.star_loop
	move.w (a5)+,d6				; Offset
	move.w (a5)+,d5				; Bit-pattern
	lea star_spacing(a5),a5
	or.w d5,(a4,d6.w)			; Draw the star
	dbra d7,.star_loop

	movem.l (sp)+,d5-d7/a4-a5
	rts

; Pre-calculate star data and duplicate it for faster drawing
prestar:
	movem.l d0-d1/a0-a2,-(sp)

	lea stpth+2(pc),a0			; Star bit batterns
	lea estr(pc),a1				; End of star paths
prlop	move.l #star_bits,d0			; Star bit pattern
	move.w (a0),d1				; Shift count
	lsr.w d1,d0				; Shift the bits
	move.w d0,(a0)				; Write the bit pattern
	addq.l #star_size,a0			; Next star
	cmp.l a1,a0
	blt.s prlop				; Loop over all star points

	lea stpth(pc),a0			; Star offsets
	lea bufr+stark,a1			; Star buffer
	lea estr(pc),a2				; End of star paths

.starcop1
	move.l (a0)+,(a1)+			; Copy the star offsets
	cmp.l a0,a2
	bgt.s .starcop1

	lea bufr+stark,a0			; Star buffer
	move.l a1,endst				; Save the end of the star buffer

	lea bufr+estark,a2			; End of star buffer
.starcop2
	move.l (a0)+,(a1)+			; Make another copy of the star offsets so we don't have to check for wrap every star
	cmp.l a1,a2
	bgt.s .starcop2

	movem.l (sp)+,d0-d1/a0-a2
	rts

; Display help text
dish	movem.l d0-d7/a0-a6,-(sp)

	lea f8x8(pc),a0			; Font
	move.l screen1(pc),a1		; Screen buffers
	move.l screen2(pc),a2
	lea messg(pc),a3		; Message text

	moveq #1,d1			; Alternate screen memory offsets (1 bitplane low-res text)
	moveq #7,d2
	moveq #0,d0
	lea (a1),a5
	lea (a2),a6
letloop	clr.w d7
	move.b (a3)+,d7
	bne.s nendl			; Check for end of line

	cmp.l #ness,a3			; Check for end of text
	ble.s .next_line

	movem.l (sp)+,d0-d7/a0-a6
	rts

.next_line
	lea bytes_per_line*8(a5),a5	; Move to the next line
	lea bytes_per_line*8(a6),a6
	lea (a5),a1
	lea (a6),a2
	moveq #1,d1			; Reset the character offsets
	moveq #7,d2
	bra.s letloop

nendl	sub.b #"A",d7			; Convert the character to an offset
	bmi.s spac
	lsl.w #3,d7

	move.b (a0,d7.w),6(a1)		; Copy the character to the screen
	move.b 1(a0,d7.w),166(a1)
	move.b 2(a0,d7.w),326(a1)
	move.b 3(a0,d7.w),486(a1)
	move.b 4(a0,d7.w),646(a1)
	move.b 5(a0,d7.w),806(a1)
	move.b 6(a0,d7.w),966(a1)
	move.b 7(a0,d7.w),1126(a1)
	move.b (a0,d7.w),6(a2)		; Copy the character to the second screen
	move.b 1(a0,d7.w),166(a2)
	move.b 2(a0,d7.w),326(a2)
	move.b 3(a0,d7.w),486(a2)
	move.b 4(a0,d7.w),646(a2)
	move.b 5(a0,d7.w),806(a2)
	move.b 6(a0,d7.w),966(a2)
	move.b 7(a0,d7.w),1126(a2)
spac	add.w d1,a1			; Move to the next character
	add.w d1,a2
	exg d1,d2			; Swap the character offsets
	bra letloop


; Preshift the sprite data and generate the code to draw it
preshift:
	lea sprite(pc),a5
	lea bufr+code,a2
	lea bufr+code2,a3
	lea bufr+code3,a4
	lea bufr+codelist(pc),a6
	moveq #0,d5
	moveq #num_sizes-1,d7
.sizes	moveq #num_shifts-1,d6
.shifs	move.l a2,(a6)+
	move.l a3,(a6)+
	move.l a4,(a6)+
	move.l d5,(a6)+
	lea (a5),a0

	bsr.s shif		; Generate shifted sprite data
	bsr.s maskmak		; Generate mask data
	bsr.s codegen		; Generate the code to draw the sprite

	dbra d6,.shifs
	lea 64(a5),a5
	dbra d7,.sizes
	rts

; Generate shifted sprite data for one sprite
shif	movem.l d0-d7/a0-a6,-(sp)

	lea bufr+balls,a1
	moveq #16-1,d7
.shif_l	moveq #0,d0
	move.w (a0)+,d0
	lsl.l d6,d0
	moveq #0,d1
	move.w (a0)+,d1
	lsl.l d6,d1
	move.w d0,4(a1)
	move.w d1,6(a1)
	swap d0
	swap d1
	move.w d0,(a1)
	move.w d1,2(a1)
	addq.l #8,a1
	dbra d7,.shif_l

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

*****

codegen	movem.l d0-d7/a0-a1/a5-a6,-(sp)
	lea bufr+balls,a0
	lea bufr+masp,a1
	moveq #8,d2
	move.l #152,d3
	move.l #160,d0
	
	move.l (a1)+,d1
	cmp.l #-1,d1
	beq.s nfwrd
 	move.w #$291,(a2)+
 	move.l d1,(a2)+
 	move.w #$91,(a2)+
 	move.l (a0),(a2)+

	move.w #$291,(a3)+
	move.l d1,(a3)+
 	move.w #$91,(a3)+
 	move.l (a0),(a3)+

nfwrd	move.l (a1)+,d1
	cmp.l #-1,d1
	beq.s nswrd
 	move.w #$2a9,(a2)+
 	move.l d1,(a2)+
 	move.w #8,(a2)+
	move.w #$a9,(a2)+
 	move.l 4(a0),(a2)+
 	move.w #8,(a2)+

	move.w #$291,(a4)+
	move.l 4(a0),(a4)+
 	move.w #$91,(a4)+
 	move.l 4(a0),(a4)+

nswrd	addq.l #8,a0
	moveq #15*2-1,d6
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

	cmp.w #152,d2
	bne.s nmfc3
	subq.w #8,d0

nmfc3 	move.w #$2a9,(a3)+
 	move.l d1,(a3)+
 	move.w d0,(a3)+
	
	move.w #$a9,(a3)+
 	move.l (a0),(a3)+
 	move.w d0,(a3)+

	cmp.w #152,d2
	bne.s common
	addq.w #8,d0

common	addq.l #4,a0
	add.w d2,d0
	exg d2,d3
	exg a3,a4
	dbra d6,lincd
	move.w #$4e75,(a2)+
	move.w #$4e75,(a3)+
	move.w #$4e75,(a4)+
	movem.l (sp)+,d0-d7/a0-a1/a5-a6
	rts


solid	move.w #$237c,(a2)+
	move.l (a0),(a2)+
	move.w d0,(a2)+
	move.w #$2340,(a4)+
	move.w d0,(a4)+
	bra.s common

; Make look-up table of Z-coordinate to ball size
make_zsizes:
	lea bufr+zsizes,a0		; Get the Z-sizes buffer
	lea zsize_table(pc),a1		; Get the Z-sizes table
.mzszs1	move.w (a1)+,d7			; Get the count
	move.w (a1)+,d0			; Get the value
	subq.w #1,d7			; Set up the branch counter
.mzszs2	move.w d0,(a0)+			; Copy the value in d0 to the buffer d7 times
	dbra d7,.mzszs2

	cmp.l #ezszt,a1			; Check for the end of the Z-sizes buffer
	blt.s .mzszs1			; If not, loop
	rts

; Set up the initial object
; d0: Object number
init_object:
	move.b d0,current_obj
	lsl.w #4,d0			; Multiply the index by 16
	lea objlist(pc),a0		; Pointer to the object list
	add.w d0,a0			; Point to the object definition

	move.l (a0),a1			; Object data start
	move.l 4(a0),a2			; Object data end
	move.l 12(a0),pisp		; Presets list
	
	move.l a1,p_coords		; Save the object data start and end
	move.l a2,e_coords
	move.w 10(a0),vbl_delay		; Object update rate

	lea bufr+x(pc),a3		; Copy the object data to the buffer
.copob	move.l (a1)+,(a3)+
	cmp.l a2,a1
	blt.s .copob

	move.w xoff(pc),d0		; Load the X,Y,Z offsets
	move.w yoff(pc),d1
	move.w zoff(pc),d2
	bsr fixco2			; Fix up the object points with the offsets

	move.w 8(a0),d0			; Get the number of points
	move.w d0,numpoints		; Save the number of points

	rts

; Change the current object
; d0: Object number
change_object:
	cmp.b current_obj(pc),d0	; Check if the object has changed
	bne.s nsobj

	rts				; If not, continue with the current object

nsobj	move.b d0,current_obj		; Not the Same Object

	move.w #transform_steps-1,trformcount	; Number of transformation steps

	subq.b #2,d0			; Convert object number to index
	andi.l #$f,d0

	lsl.w #4,d0			; Multiply the index by 16
	lea objlist(pc),a0		; Pointer to the object list
	add.w d0,a0			; Point to the object definition

	move.l (a0),a1			; Object data start
	move.l 4(a0),a2			; Object data end
	move.l 12(a0),pisp		; Presets list
	
	move.l a1,p_coords		; Save the object data start and end
	move.l a2,e_coords
	move.w 10(a0),vbl_delay		; Object update rate

	lea bufr+x2(pc),a3		; Copy the object data to the buffer
copco	move.l (a1)+,(a3)+
	cmp.l a2,a1
	blt.s copco

	move.w xoff(pc),d0		; Load the X,Y,Z offsets
	move.w yoff(pc),d1
	move.w zoff(pc),d2
	bsr fixco2			; Fix up the object points with the offsets

*	bra d

	move.w 8(a0),d0
	cmp.w numpoints(pc),d0
	beq slimy
	blt.s lesbls
	
	move.w d0,d7
	move.w numpoints(pc),d6
	move.w d0,numpoints2
	move.w d0,numpoints
	sub.w d6,d7
	lsl.w #1,d6
	subq.w #1,d7
	move.l p_coords(pc),a1
	lea (a1,d6.w),a3
	lea bufr+x2(pc),a4
	lea bufr+x(pc),a5
	add.w d6,a4
	add.w d6,a5
	movem.w xoff(pc),d0-d2
menisc	move.w 200(a3),200(a4)
	move.w 400(a3),400(a4)
	move.w 600(a3),600(a4)
	move.w (a3),(a4)
	
	add.w d1,200(a4)
	add.w d2,400(a4)
	add.w d0,(a4)+

	move.w 200(a3),200(a5)
	move.w 400(a3),400(a5)
	move.w #ball_bytes*num_sizes,600(a5)
	move.w (a3)+,(a5)
	
	add.w d1,200(a5)
	add.w d2,400(a5)
	add.w d0,(a5)+

	dbra d7,menisc
	
	bra.s transform_object

lesbls	move.w d0,d6
	move.w numpoints(pc),d7
	move.w d0,numpoints2
	sub.w d6,d7
	lsl.w #1,d6
	subq.w #1,d7
	bmi.s transform_object
	lea bufr+x(pc),a4
	lea bufr+x2(pc),a5
	add.w d6,a4
	add.w d6,a5
blind	move.w 200(a4),200(a5)
	move.w 400(a4),400(a5)
	move.w #ball_bytes*num_sizes,600(a5)
	move.w (a4)+,(a5)+
	dbra d7,blind
	bra.s transform_object

slimy	move.w numpoints(pc),numpoints2
	
; Transform object
transform_object:
	bsr swap_screens
	bsr wait_vbls
	bsr wait_step

	bsr render_object

	bsr update_angles

	lea bufr+x(pc),a0
	lea bufr+x2(pc),a1
	move.w numpoints(pc),d7
	subq.w #1,d7
chex	move.w (a1)+,d0
	cmp.w (a0),d0
	beq.s same
	add.w (a0),d0
	asr.w #1,d0
	move.w d0,(a0)

same	addq.l #2,a0
	dbra d7,chex
	
	lea bufr+y(pc),a0
	lea bufr+y2(pc),a1
	move.w numpoints(pc),d7
	subq.w #1,d7
chexb	move.w (a1)+,d0
	cmp.w (a0),d0
	beq.s sameb
	add.w (a0),d0
	asr.w #1,d0
	move.w d0,(a0)
sameb	addq.l #2,a0
	dbra d7,chexb
	
	lea bufr+z(pc),a0
	lea bufr+z2(pc),a1
	move.w numpoints(pc),d7
	subq.w #1,d7
chexc	move.w (a1)+,d0
	cmp.w (a0),d0
	beq.s samec
	add.w (a0),d0
	asr.w #1,d0
	move.w d0,(a0)
samec	addq.l #2,a0
	dbra d7,chexc
	
	lea bufr+sizes(pc),a0
	lea bufr+sz2(pc),a1
	move.w numpoints(pc),d7
	subq.w #1,d7
chexd	move.w (a1)+,d0
	cmp.w (a0),d0
	beq.s samed
	bgt.s neadd
	sub.w #ball_bytes,(a0)
	bra.s samed
neadd	add.w #ball_bytes,(a0)
samed	addq.l #2,a0
	dbra d7,chexd

	cmp.b #$62,key
	beq.s sodit

	subq.w #1,trformcount
	bne transform_object

sodit	move.w numpoints2(pc),numpoints
	rts

; Change the palette immediately
change_palette
	sub.b #scancode_q,d0		; Convert keycode to palette index
	ext.w d0
	lsl.w #3,d0			; Multiply by 8 (palette entry size, 4 x 16-bit RGB values)
	lea bcols(pc),a0		; Get the palette address
	move.w (a0,d0.w),dpal		; Save the new palette in dpal
	move.l 2(a0,d0.w),dpal+2
	
	move.l f_palette(pc),a0		; Get the current palette
	move.w 2(a0),curp		; Save the palette in curp (current palette)
	move.l 4(a0),curp+2
	
	rts

; Fade the palette to the target
palette_fade:
	subq.b #1,palette_fade_delay
	beq.s .palette_next

	rts

.palette_next
	move.b #8,palette_fade_delay	; Reset the palette fade delay

	lea curp(pc),a0			; Get the current palette
	lea dpal(pc),a1			; Get the display palette
	
; Change palette loop
chpl	moveq #0,d0			; Load the current palette entry and the display palette entry
	moveq #0,d1
	move.w (a0),d0
	move.w (a1),d1
	
	cmp.w d0,d1			; Compare the current and display palette entries
	beq.s chpl_2			; If they are the same the fade is done
	
	swap d0				; Shift the current palette entry and the display palette entry to the high word
	swap d1
	lsr.l #4,d0			; Shift the blue colour component to the low word
	lsr.l #4,d1
	cmp.w d0,d1			; If they are the same, this colour component is done
	beq.s echr
	blt.s tlow			; If the current palette entry is too low, add 1

	addq.w #$001,(a0)
	bra.s echr

tlow	subq.w #$001,(a0)		; If the current palette entry is too high, subtract 1

echr	clr.w d0			; Now for the greens
	clr.w d1

	lsr.l #4,d0
	lsr.l #4,d1
	cmp.w d0,d1
	beq.s echr2
	blt.s tlow2
	add.w #$010,(a0)
	bra.s echr2
tlow2	sub.w #$010,(a0)

echr2	clr.w d0			; And finally the reds
	clr.w d1
	
	lsr.l #4,d0
	lsr.l #4,d1
	cmp.w d0,d1
	beq.s chpl_2
	blt.s tlow3
	add.w #$100,(a0)
	bra.s chpl_2
tlow3	sub.w #$100,(a0)

chpl_2	addq.l #2,a0			; Move to the next palette entry
	addq.l #2,a1
	cmp.l #dpal,a0
	blt.s chpl

	move.w curp(pc),d0			; Get the current palette values
	move.l curp+2(pc),d2

	; Copy them into the matching palette entries for different bitplane masks
	move.w d0,chme1+4		; Instructions that set the palette each VBL
	move.l d2,chme2+2
	move.w d0,chme3+4
	move.l d2,chme4+2
	
	move.w d0,dhelp+2		; Palette values for displayed help text
	move.l d2,dhelp+4
	move.w d0,dhelp+10
	move.l d2,dhelp+12

	move.w d0,hhelp+2		; Palette values for hidden help text
	move.l d2,hhelp+4
	move.w d0,hhelp+10
	move.l d2,hhelp+12
	move.w d0,hhelp+18
	move.l d2,hhelp+20
	move.w d0,hhelp+26
	move.l d2,hhelp+28
echinv	rts

; Keycodes for the interactions (reverse order to the routine list!)
keylist	dc.b $01,$0f,$62,$4d,$48,$4b,$50,$47,$6b,$52,$6a,$66,$6c,$68,$67,$6e,$6f,$39

; Routines for the interactions (with and without shift and control)
routlist	dc.l quit,null_key,null_key,null_key,null_key,null_key,clr_angles,null_key,mov_z,clr_rots,mov_z,mov_y,mov_x,mov_y,mov_x,help,help,restr
routlist_sh	dc.l quit,null_key,null_key,null_key,null_key,null_key,clr_angles,null_key,rot_z,clr_rots,rot_z,rot_x,rot_y,rot_x,rot_y,help,help,restr
routlist_ctrl	dc.l quit,null_key,null_key,null_key,null_key,null_key,clr_angles,null_key,add_z,clr_rots,add_z,add_y,add_x,add_y,add_x,help,help,restr

key	dc.b $ff
joycm	ds.b 1
mousx	ds.b 1
mousy	ds.b 1
mousb	ds.b 1
shift_key	ds.b 1
ctrl_key	ds.b 1
single_step	ds.b 1
mfpstr	ds.l 14

; Count, offset into the ball data
zsize_table:
	dc.w 800,10*ball_bytes
	dc.w 800,9*ball_bytes
	dc.w 800,8*ball_bytes
	dc.w 450,7*ball_bytes
	dc.w 300,6*ball_bytes
	dc.w 160,5*ball_bytes
	dc.w 110,4*ball_bytes
	dc.w 70,3*ball_bytes
	dc.w 70,2*ball_bytes
	dc.w 90,ball_bytes
	dc.w 50,0
	dc.w 30,-ball_bytes
	dc.w 55,-2*ball_bytes
ezszt

curp	dc.w $300,$500,$700
dpal	dc.w $300,$500,$700

;START, END
;NO. POINTS, UPDATE RATE
;PRESET LIST

objlist
	dc.l object8,endobj8
	dc.w 72,4
	dc.l presets8
	dc.l object6,endobj6
	dc.w 80,4
	dc.l presets6
	dc.l object7,endobj7
	dc.w 64,4
	dc.l presets7
	dc.l object2,endobj2
	dc.w 44,3
	dc.l presets2
	dc.l object4,endobj4
	dc.w 55,3
	dc.l presets4
	dc.l object5,endobj5
	dc.w 64,4
	dc.l presets5
	dc.l object3,endobj3
	dc.w 96,3
	dc.l presets3
	dc.l object1,endobj1
	dc.w 80,3
	dc.l presets1
	dc.l object9,endobj9
	dc.w 58,3
	dc.l presets9

; Pointer to the current preset list
pisp	dc.l presets9

; Lists of presets for each object
presets1	dc.l pres3,pres2,pres,pres4,pres5,pres6,pres7,pres8,pres9,pres10
presets2	dc.l pres26,pres15,pres16,pres20,pres22,pres19,pres21,pres8,pres9,pres18
presets3	dc.l pres17,pres14,pres3,pres25,pres5,pres6,pres7,pres8,pres9,pres24
presets4	dc.l pres,pres14,pres3,pres20,pres5,pres6,pres7,pres26,pres9,pres22
presets5	dc.l pres26,pres14,pres3,pres20,pres5,pres6,pres7,pres8,pres9,pres24
presets6	dc.l pres17,pres14,pres3,pres4,pres5,pres6,pres7,pres8,pres9,pres24
presets7	dc.l pres14,pres,pres3,pres20,pres5,pres6,pres7,pres8,pres9,pres23
presets8	dc.l pres11,pres12,pres3,pres4,pres13,pres6,pres7,pres8,pres9,pres14
presets9	dc.l pres25,pres15,pres2,pres9,pres30,pres29,pres12,pres19,pres20,pres28
presetsX	dc.l pres,pres2,pres3,pres4,pres5,pres6,pres7,pres8,pres9,pres10

	include "presets.s"

	include "helptext.s"

ftb	dc.w $777,$666,$555,$444,$333,$222,$111,$000
eftb

ftb2	dc.w $000,$111,$222,$333
eftb2


ortw	ds.w 16

off	ds.l 1

xtxt	dc.b " [[["
	dc.l 160*(216+32)+8
ytxt	dc.b " [[["
	dc.l 160*(216+32)+40
ztxt	dc.b " [[["
	dc.l 160*(216+32)+72
sxtxt	dc.b " [[["
	dc.l 160*(216+32)+72+32+32
sytxt	dc.b " [[["
	dc.l 160*(216+32)+72+32
sztxt	dc.b " [[["
	dc.l 160*(224+32)+24

axtxt	dc.b " [[["
	dc.l 160*(224+32)+24+32
aytxt	dc.b " [[["
	dc.l 160*(224+32)+24+32*2
aztxt	dc.b " [[["
	dc.l 160*(224+32)+24+32*3

pstar	dc.l bufr+stark
endst	ds.l 1

	EVEN
f8x8	incbin "8x8font.dat"

orez	ds.w 1
cursoff	dc.b 27,"f",0

	EVEN
sin	incbin "bigsin.dat"
cos	incbin "bigcos.dat"

	EVEN
sprite	incbin "balls.dat"


p_coords	dc.l object9
e_coords	dc.l endobj9

trformcount	ds.w 1
numpoints	dc.w 58			; NUMBER OF POINTS
current_obj	dc.b num_objects+1	; CURRENT OBJECT
vbl_delay	dc.w 4			; UPDATE RATE (number of VBLs between updates)
numpoints2	ds.w 1

hbl_count	ds.b 1

stund	dc.l $74000
screen1 dc.l $68000
screen2	dc.l $74000

b_palette	dc.l dhelp
f_palette	dc.l hhelp

dhelp	dc.w $000,$300,$500,$700
	dc.w $333,$300,$500,$700
	dc.w $777,$777,$777,$777
	dc.w $777,$777,$777,$777

hhelp	dc.w $000,$300,$500,$700
	dc.w $333,$300,$500,$700
	dc.w $000,$300,$500,$700
	dc.w $333,$300,$500,$700

num_undraw1	ds.w 1
num_undraw2	ds.w 1
undraw1	dc.l bufr+udofs
undraw2	dc.l bufr+udofs2

bcols	dc.w $020,$040,$070,0
	dc.w $001,$223,$445,0
	dc.w $023,$045,$567,0
	dc.w $310,$530,$754,0
	dc.w $311,$533,$755,0
	dc.w $212,$434,$656,0
	dc.w $222,$334,$566,0
	dc.w $121,$243,$465,0
	dc.w $001,$003,$005,0
	dc.w $300,$500,$700,0

palette_fade_delay	dc.b 5

opal	ds.l 8
o44e	ds.l 1

xoff	ds.w 1
yoff	ds.w 1
zoff	ds.w 1

xm	ds.w 1
ym	ds.w 1
zoom	ds.w 1

xng	dc.w 0
yng	dc.w 0
zng	dc.w 0

xang	dc.w 0
yang	dc.w 0
zang	dc.w 0

svbl	ds.l 1

stack	ds.l 1

; Predefined shapes
; 100 x X Coordinate
; 100 x Y Coordinate
; 100 x Z Coordinate
; 100 x size

object1:	; ST Format
	dc.w -10,-25,-37,-45
	dc.w -30,-15,0,0,-13
	dc.w -30,-45,15,30,45
	dc.w 60,38,38,38,38
	
	dc.w -150,-142,-130,-115
	dc.w -138,-123,-150,-150
	dc.w -60,-55,-55,-60
	dc.w -71,-85,-95,-100,-95,-86,-73
	dc.w -40,-40,-40,-40,-40
	dc.w -25,-15,-12,-25,-15,-10
	dc.w 5,5,5,5,10,20,30,40,50,55
	dc.w 55,55,55
	dc.w 70,70,70,75,90,105,110,110,110
	dc.w 90
	dc.w 115,128,141,154,135,135,135,135
	ds.w 20
	
	dc.w 65,65,55,40
	dc.w 40,40,40,25
	dc.w 15,10,10,65,65
	dc.w 65,65,55,40,25,10

	dc.w -35,-20,-10,-10
	dc.w -45,-45,-55,-70
	dc.w -17,-30,-45,-58,-68
	dc.w -68,-56,-42,-27,-16,-10
	dc.w -70,-55,-40,-25,-10,-10,-20
	dc.w -32,-40,-55,-70
	dc.w -70,-55,-40,-25,-10,-25
	dc.w -35,-25,-10,-25,-40,-55,-70
	
	dc.w -70,-55,-40,-25
	dc.w -10,-25,-40,-55,-70,-40
	dc.w -10,-10,-10,-10,-25,-40,-55,-70
	ds.w 20

	ds.w 100

	ds.w 100
endobj1

object2:	; Cube
	dc.w -50,-25,0,25,50
	dc.w -50,-25,0,25,50
	dc.w -50,-25,0,25,50
	dc.w -50,-25,0,25,50

	dc.w 50,50,50
	dc.w -50,-50,-50
	dc.w 50,50,50
	dc.w -50,-50,-50

	dc.w 50,50,50
	dc.w 50,50,50
	dc.w -50,-50,-50
	dc.w -50,-50,-50
	ds.w 100-44
	
	dc.w 50,50,50,50,50
	dc.w -50,-50,-50,-50,-50
	dc.w 50,50,50,50,50
	dc.w -50,-50,-50,-50,-50
	
	dc.w -25,0,25
	dc.w -25,0,25
	dc.w -25,0,25
	dc.w -25,0,25

	dc.w 50,50,50
	dc.w -50,-50,-50
	dc.w 50,50,50
	dc.w -50,-50,-50

	ds.w 100-44

	dc.w 50,50,50,50,50
	dc.w 50,50,50,50,50
	dc.w -50,-50,-50,-50,-50
	dc.w -50,-50,-50,-50,-50
	
	dc.w 50,50,50
	dc.w 50,50,50
	dc.w -50,-50,-50
	dc.w -50,-50,-50

	dc.w -25,0,25
	dc.w -25,0,25
	dc.w -25,0,25
	dc.w -25,0,25

	ds.w 100-44
	
	dc.w 0,256*1,256*2,256*1,0
	dc.w 0,256*1,256*2,256*1,0
	dc.w 0,256*1,256*2,256*1,0
	dc.w 0,256*1,256*2,256*1,0

	dc.w 256*1,256*2,256*1
	dc.w 256*1,256*2,256*1
	dc.w 256*1,256*2,256*1
	dc.w 256*1,256*2,256*1
	
	dc.w 256*1,256*2,256*1
	dc.w 256*1,256*2,256*1
	dc.w 256*1,256*2,256*1
	dc.w 256*1,256*2,256*1

	ds.w 100-44
endobj2

object3:	; Grid square
	dc.w -90,-70,-50,-30,-10,10,30,50,70,90
	dc.w -90,-70,-50,-30,-10,10,30,50,70,90
	dc.w -90,-70,-50,-30,-10,10,30,50,70,90
	dc.w -90,-70,-50,-30,-10,10,30,50,70,90
	dc.w -90,-70,-50,-30,30,50,70,90
	dc.w -90,-70,-50,-30,30,50,70,90
	dc.w -90,-70,-50,-30,-10,10,30,50,70,90
	dc.w -90,-70,-50,-30,-10,10,30,50,70,90
	dc.w -90,-70,-50,-30,-10,10,30,50,70,90
	dc.w -90,-70,-50,-30,-10,10,30,50,70,90
	ds.w 100-96

	dcb.w 10,90
	dcb.w 10,70
	dcb.w 10,50
	dcb.w 10,30
	dcb.w 8,10
	dcb.w 8,-10
	dcb.w 10,-30
	dcb.w 10,-50
	dcb.w 10,-70
	dcb.w 10,-90
	ds.w 100-96
	
	ds.w 100
	ds.w 100
endobj3

object4:	; Pyramid
	dc.w 0											; 1
	dc.w -10,10,-10,10									; 4
	dc.w -20,0,20,-20,0,20,-20,0,20								; 9	
	dc.w -30,-10,10,30,-30,-10,10,30,-30,-10,10,30,-30,-10,10,30				; 16
	dc.w -40,-20,0,20,40,-40,-20,0,20,40,-40,-20,0,20,40,-40,-20,0,20,40,-40,-20,0,20,40	; 25
	ds.w 100-55
	
	dc.w 40
	dcb.w 4,20
	dcb.w 9,0
	dcb.w 16,-20
	dcb.w 25,-40	
	ds.w 100-55
	
	dc.w 1
	dc.w 10,10,-10,-10
	dc.w 20,20,20,0,0,0,-20,-20,-20
	dc.w 30,30,30,30,10,10,10,10,-10,-10,-10,-10,-30,-30,-30,-30
	dc.w 40,40,40,40,40,20,20,20,20,20,0,0,0,0,0,-20,-20,-20,-20,-20,-40,-40,-40,-40,-40
	ds.w 100-55
	
	dc.w 4*256
	dcb.w 4,3*256
	dcb.w 9,2*256
	dcb.w 16,1*256
	dcb.w 25,0
	ds.w 100-55
endobj4
	
object5:
	dc.w 0,10,15,10,0,-10,-15,-10
	dc.w 0,18,27,18,0,-18,-27,-18
	dc.w 0,24,36,24,0,-24,-36,-24
	dc.w 0,26,39,26,0,-26,-39,-26
	dc.w 0,26,39,26,0,-26,-39,-26
	dc.w 0,24,36,24,0,-24,-36,-24
	dc.w 0,18,27,18,0,-18,-27,-18
	dc.w 0,10,15,10,0,-10,-15,-10
	ds.w 100-64
	
	dcb.w 8,36
	dcb.w 8,28
	dcb.w 8,18
	dcb.w 8,6
	dcb.w 8,-6
	dcb.w 8,-18
	dcb.w 8,-28
	dcb.w 8,-36
	
	ds.w 100-64
	
	dc.w 15,10,0,-10,-15,-10,0,10
	dc.w 27,18,0,-18,-27,-18,0,18
	dc.w 36,24,0,-24,-36,-24,0,24
	dc.w 39,26,0,-26,-39,-26,0,26
	dc.w 39,26,0,-26,-39,-26,0,26
	dc.w 36,24,0,-24,-36,-24,0,24
	dc.w 27,18,0,-18,-27,-18,0,18
	dc.w 15,10,0,-10,-15,-10,0,10
	ds.w 100-64
	
	dcb.w 8,256*3
	dcb.w 8,256*2
	dcb.w 8,256*1
	dcb.w 8,0
	dcb.w 8,0
	dcb.w 8,256*1
	dcb.w 8,256*2
	dcb.w 8,256*3
	ds.w 100-64
endobj5

object6	incbin "spiral.obj"
endobj6

object7:
	dc.w 0,12,18,12,0,-12,-18,-12
	dc.w 0,12,18,12,0,-12,-18,-12
	dc.w 0,12,18,12,0,-12,-18,-12
	dc.w 0,12,18,12,0,-12,-18,-12
	dc.w 0,12,18,12,0,-12,-18,-12
	dc.w 0,12,18,12,0,-12,-18,-12
	dc.w 0,12,18,12,0,-12,-18,-12
	dc.w 0,12,18,12,0,-12,-18,-12
	ds.w 100-64
	
	dcb.w 8,-56
	dcb.w 8,-40
	dcb.w 8,-24
	dcb.w 8,-8
	dcb.w 8,8
	dcb.w 8,24
	dcb.w 8,40
	dcb.w 8,56
	
	ds.w 100-64

	dc.w 18,12,0,-12,-18,-12,0,12
	dc.w 18,12,0,-12,-18,-12,0,12
	dc.w 18,12,0,-12,-18,-12,0,12
	dc.w 18,12,0,-12,-18,-12,0,12
	dc.w 18,12,0,-12,-18,-12,0,12
	dc.w 18,12,0,-12,-18,-12,0,12
	dc.w 18,12,0,-12,-18,-12,0,12
	dc.w 18,12,0,-12,-18,-12,0,12
	ds.w 100-64
	
	
	ds.w 100
endobj7

object8	incbin "smiley.obj"
endobj8

object9	; Atari Logo (58 points)
	dcb.w 14,-7
	dcb.w 14,7
	dc.w 20,20,20,20+1,20+2,20+4,20+7,20+11,20+16,20+23,20+30,20+39,20+50,20+64,20+79
	dc.w -20,-20,-20,-(20+1),-(20+2),-(20+4),-(20+7),-(20+11),-(20+16),-(20+23),-(20+30),-(20+39),-(20+50),-(20+64),-(20+79)
	ds.w 100-58

	dc.w 12*7,12*6,12*5,12*4,12*3,12*2,12,0,-12,-12*2,-12*3,-12*4,-12*5,-12*6
	dc.w 12*7,12*6,12*5,12*4,12*3,12*2,12,0,-12,-12*2,-12*3,-12*4,-12*5,-12*6
	dc.w 12*7,12*6,12*5,12*4,12*3,12*2,12,0,-12,-12*2,-12*3,-12*4,(-12*5)+1,(-12*6)+4,(-12*6)
	dc.w 12*7,12*6,12*5,12*4,12*3,12*2,12,0,-12,-12*2,-12*3,-12*4,(-12*5)+1,(-12*6)+4,(-12*6)
	ds.w 100-58

	ds.w 100

	dcb.w 28,2*256
	dc.w 3*256,3*256,3*256,3*256,3*256,3*256,2*256,2*256,2*256,2*256,256,256,0,0,0
	dc.w 3*256,3*256,3*256,3*256,3*256,3*256,2*256,2*256,2*256,2*256,256,256,0,0,0

	ds.w 100-58
endobj9

stpth	incbin "newstz2.pth"
estr	ds.w 1

	EVEN
;music	incbin "scintro.msx"		; Music data - download an unpacked music file from the SNDH archive if you want music
music	dcb.l 3,$4e750000		; Dummy music data (3 x NOP)

bufr	EVEN

	RSRESET
	
x	rs.w max_points
y	rs.w max_points
z	rs.w max_points
sizes	rs.w max_points*4
x2	rs.w max_points
y2	rs.w max_points
z2	rs.w max_points
sz2	rs.w max_points
sizn	rs.w 128

codelist	rs.l 16*8*16
balls	rs.w 64
masp	rs.w 64
emsp	rs.w 10
udofs	rs.l 110
udofs2	rs.l 110
xn	rs.w max_points
yn	rs.w max_points
zn	rs.w max_points
xp	rs.w 100
yp	rs.w 100

stark	rs.w ((estr-stpth)+(90*star_spacing))/2
estark	rs.w 1

stackbuf	rs.w 500
stacktop	rs.w 1

zsizes	rs.w z_range

code	rs.w 30000/2
code2	rs.w 30000/2
code3	rs.w 30000/2

