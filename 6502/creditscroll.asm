
; vertical credits scroller
; somewhat generalised so will scroll all MODE 7 characters up by one pixel at a time
; then adds new row of pixels at the bottom from a fixed array

; separate routine fills the new line buffer with font data from an array of text

.start_fx_creditscroll

\\ Change these to adjust window that is scrolled
CREDITS_shadow_addr = &7C00 + 5*40	; offset by first 4 rows (where logo+header are)
CREDITS_end_addr = CREDITS_shadow_addr + (MODE7_char_width * MODE7_char_height) - 7*40 ; less 2 lines at the bottom which is where test card line is
CREDITS_first_char = 1
CREDITS_last_char = MODE7_char_width

ROW_DELAY = 15	; speed of line updates in vsyncs, set to 0 for no delay

LOOP_CREDITS = FALSE


.line_counter EQUB 0


\ ******************************************************************
\ *	Credit Scroll FX
\ ******************************************************************

\\ Scrolls entire screen up by one pixel adding new pixels from array
FAST_SCROLL = TRUE
.fx_creditscroll_scroll_up
{
	\\ Start by updating the top line
	LDA #LO(CREDITS_shadow_addr)
	STA writeptr
	LDA #HI(CREDITS_shadow_addr)
	STA writeptr+1

	\\ But we'll also be reading from the next line
	LDA #LO(CREDITS_shadow_addr + MODE7_char_width)
	STA readptr
	LDA #HI(CREDITS_shadow_addr + MODE7_char_width)
	STA readptr+1

	\\ For each character row
	.y_loop





IF FAST_SCROLL
	lda writeptr+0
	sta readaddr+1
	sta writeaddr2+1

	lda writeptr+1
	sta readaddr+2
	sta writeaddr2+2

	lda readptr+0
	sta writeaddr1+1

	lda readptr+1
	sta writeaddr1+2
ENDIF



IF FAST_SCROLL
	\\ First char in row
	LDY #CREDITS_first_char
.x_loop

.readaddr
	LDX &ffff, Y			; [4*]
	LDA glyph_shift_table_1-32,X	; [4*]
	STA top_bits+1			; [4]
.writeaddr1
	LDX &ffff, Y			; [4*]
	LDA glyph_shift_table_2-32,X	; [4*]
	.top_bits
	ORA #0					; [2]
	\\ Write the byte back to the screen
.writeaddr2
	STA &ffff, Y		; [4*]
	\\ Full width
	.skip
	INY						; [2]
	CPY #CREDITS_last_char	; [2]
	BCC x_loop				; [2*]

; 32 cycles
ELSE
	\\ First char in row
	LDY #CREDITS_first_char
.x_loop
	\\ Get top pixels from row below
	LDA (readptr), Y		; [5*]
	TAX						; [2]
	AND #&3					; [2]
	STA top_bits + 1		; [4]

	\\ Get bottom pixels from current row
	LDA (writeptr), Y		; [5*]
	AND #&FC				; [2]

	\\ Merge them together
	.top_bits
	ORA #0					; [2]

	\\ Always add 32
	ORA #32					; [2]

	\\ Rotate the pixels to scroll up
	TAX						; [2]
	LDA fx_creditscroll_rotate, X	; [4*]

	\\ Write the byte back to the screen
	STA (writeptr), Y		; [5*]

	\\ Full width
	.skip
	INY						; [2]
	CPY #CREDITS_last_char	; [2]
	BCC x_loop				; [2*]
	; 41 cycles per char

ENDIF


	\\ Move down a row

	LDA readptr
	STA writeptr
	LDA readptr+1
	STA writeptr+1

	CLC
	LDA readptr
	ADC #MODE7_char_width
	STA readptr
	LDA readptr+1
	ADC #0
	STA readptr+1

	\\ Check if we've reached the end?
	LDA readptr
	CMP #LO(CREDITS_end_addr)
	BNE y_loop
	LDA readptr+1
	CMP #HI(CREDITS_end_addr)
	BNE y_loop

	\\ Do last line separately

	LDY #CREDITS_first_char
	.last_loop

	\\ Mask in top pixels from our new line
	LDA fx_creditscroll_new_line, Y
	AND #&3
	STA top_bits_last+1

	\\ Load last line bottom pixels
	LDA (writeptr), Y
	AND #&FC

	\\ Merge them together
	.top_bits_last
	ORA #0

	\\ Always add 32...
	ORA #32

	\\ Rotate them
	TAX
	LDA fx_creditscroll_rotate, X

	\\ Store back to screen
	STA (writeptr), Y

	\\ Entire row
	INY
	CPY #CREDITS_last_char
	BCC last_loop

	.return
	RTS
}

.fx_creditscroll_rotate_new_line
{
	\\ First char in row
	LDY #CREDITS_first_char
	.x_loop

	\\ Get bottom pixels from current row
	LDA fx_creditscroll_new_line, Y
	AND #&FC

	ORA #32

	\\ Rotate the pixels to scroll up
	TAX
	LDA fx_creditscroll_rotate, X

	\\ Write the byte back to the screen
	STA fx_creditscroll_new_line, Y

	\\ Full width
	.skip
	INY
	CPY #CREDITS_last_char
	BCC x_loop

	.return
	RTS
}

\\ Main update function

.fx_creditscroll_update
{
	lda line_counter
	beq new_line
	dec line_counter
	lda fx_credits_finished
	rts

.new_line

	\\ Set graphics white
;	lda #144+7
;	jsr mode7_set_graphics_shadow_fast			; can remove this if other routine handling colours	



	\\ Write new line of text to array
	JSR fx_creditscroll_write_text_line

	\\ Scroll everything up
	JSR fx_creditscroll_scroll_up



	.return
	lda fx_credits_finished
	RTS
}


\ ******************************************************************
\ *	Credit Text FX
\ ******************************************************************

.fx_creditscroll_text_ptr
EQUW fx_creditscroll_text

.fx_creditscroll_text_row
EQUB 0

.fx_creditscroll_text_idx
EQUB 0

.fx_credits_finished
EQUB 0

.fx_creditscroll_init
{
	lda #0
	sta fx_credits_finished
	sta fx_creditscroll_text_idx
	sta fx_creditscroll_text_row
	lda #LO(fx_creditscroll_text)
	sta fx_creditscroll_text_ptr+0
	lda #HI(fx_creditscroll_text)
	sta fx_creditscroll_text_ptr+1	
	rts
}

.fx_creditscroll_write_text_line
{
	\\ Write text into our new line
	LDA fx_creditscroll_text_ptr
	STA readptr
	LDA fx_creditscroll_text_ptr+1
	STA readptr+1

	LDX fx_creditscroll_text_row
	BEQ write_new_text
	CPX #3
	BEQ write_new_text

	\\ Just rotate existing line
	JSR fx_creditscroll_rotate_new_line
	JMP reached_end_of_row

	.write_new_text

	LDX #MODE7_char_width-1
	LDA #0
	.clear_loop
	STA fx_creditscroll_new_line, X
	DEX
	BPL clear_loop

	\\ Get X start
	LDY #0
	LDA (readptr), Y
	TAX

	\\ Set row

	INY
	.char_loop
	STY fx_creditscroll_text_idx

	\\ Get text char
	LDA (readptr), Y
	BNE not_end_of_string

	\\ If EOS assume EOR
	JMP reached_end_of_row

	.not_end_of_string
	;JSR fx_creditscroll_get_char		; preserves X&Y

	\\ A is index into our font data
	TAY

	.font_addr_1
	LDA mode7_font_data, Y
;	EOR #1+2+4+8+16+64
	INY
	STA fx_creditscroll_new_line, X

	\\ Next char cell
	INX
	CPX #MODE7_char_width
	BCS reached_end_of_row

	.font_addr_2
	LDA mode7_font_data, Y
;	EOR #1+2+4+8+16+64	
	INY
	STA fx_creditscroll_new_line, X

	\\ Next char cell
	INX
	CPX #MODE7_char_width
	BCS reached_end_of_row

	.font_addr_3
	LDA mode7_font_data, Y
;	EOR #1+2+4+8+16+64		
	INY
	STA fx_creditscroll_new_line, X

	\\ Next char cell
	INX
	CPX #MODE7_char_width
	BCS reached_end_of_row

	LDY fx_creditscroll_text_idx

	\\ Next text char
	INY
	JMP char_loop

	.reached_end_of_row

	\\ Next time do next row
	LDX fx_creditscroll_text_row
	INX
	CPX #3
	BNE not_three

	\\ At row 3 need to swap to next line of font data
	LDA #LO(mode7_font_data_second_row)
	STA font_addr_1+1
	STA font_addr_2+1
	STA font_addr_3+1
	LDA #HI(mode7_font_data_second_row)
	STA font_addr_1+2
	STA font_addr_2+2
	STA font_addr_3+2

	\\ There are 6 rows in total	
	.not_three
	CPX #6	
	BCC still_same_text



.new_line	

	\\ Next line of text
	LDY fx_creditscroll_text_idx

	\\ Skip to EOS
	{
		.loop
		LDA (readptr), Y
		BEQ done
		INY
		BNE loop
		.done
	}

	\\ Check whether there are any more strings
	INY
	LDA (readptr), Y
	CMP #&FF
	BNE next_line_text

	\\ Reset to start of text
	LDA #LO(fx_creditscroll_text)
	STA fx_creditscroll_text_ptr
	LDA #HI(fx_creditscroll_text)
	STA fx_creditscroll_text_ptr+1

	LDA #255
	STA fx_credits_finished

	\\ Or just flag not to write any more text..
	JMP continue_text

	\\ Update text pointer
	.next_line_text
	TYA
	CLC
	ADC fx_creditscroll_text_ptr
	STA fx_creditscroll_text_ptr
	LDA fx_creditscroll_text_ptr+1
	ADC #0
	STA fx_creditscroll_text_ptr+1

	; insert a delay
	lda #ROW_DELAY
	sta line_counter

	\\ Next line of text
	.continue_text

	\\ Need to reset font data
	LDA #LO(mode7_font_data)
	STA font_addr_1+1
	STA font_addr_2+1
	STA font_addr_3+1
	LDA #HI(mode7_font_data)
	STA font_addr_1+2
	STA font_addr_2+2
	STA font_addr_3+2

	\\ Start from row 0
	LDX #0

	.still_same_text
	STX fx_creditscroll_text_row

	.return
	RTS
}


\ ******************************************************************
\ *	Credit Font FX
\ ******************************************************************


.fx_creditscroll_rotate_table
{
	FOR n, 32, 127, 1	; teletext codes range from 32-127
	a = n AND 1
	b = n AND 2
	c = n AND 4
	d = n AND 8
	e = n AND 16
	f = n AND 64
	
	; Pixel pattern becomes
	;  1  2  ->  a b  ->  c d
	;  4  8  ->  c d  ->  e f 
	; 64 16  ->  e f  ->  a b

	IF (n AND 32)
	PRINT a,b,c,d,e,f
	EQUB 32 + (a * 16) + (b * 32) + (c / 4) + (d / 4) + (e / 4) + (f / 8) + (n AND 128)
	ELSE
	EQUB n
	ENDIF
	NEXT
}

fx_creditscroll_rotate = fx_creditscroll_rotate_table-32



IF FAST_SCROLL
; table to shift 3x2 teletext graphic up by 1 pixel row 
.glyph_shift_table_1
{
	FOR n, 32, 127, 1	; teletext codes range from 32-127
		a = n AND 1
		b = (n AND 2)/2
		c = (n AND 4)/4
		d = (n AND 8)/8
		e = (n AND 16)/16
		f = (n AND 64)/64

		EQUB 32 + (c*1) + (d*2) + (e*4) + (f*8)
		;PRINT n
	NEXT
}
; table to translate top 2 teletext pixels to bottom 2
.glyph_shift_table_2
{
	FOR n, 32, 127, 1	; teletext codes range from 32-127
		a = n AND 1
		b = (n AND 2)/2
		c = (n AND 4)/4
		d = (n AND 8)/8
		e = (n AND 16)/16
		f = (n AND 64)/64

		EQUB (a*16) + (b*64)
	NEXT
}
ENDIF



\\ Spare character row which will get added to bottom of scroll
\\ Update fn so only top two pixels (1+2) get added to bottom of scroll
\\ Can rotate this row itself to shuffle new pixels onto bottom of screen

.fx_creditscroll_new_line
FOR n, 0, MODE7_char_width-1, 1
EQUB 0
NEXT


\\ Map character ASCII values to the byte offset into our MODE 7 font
\\ This is "cunning" but only works because the font has fewer than 256/6 (42) glyphs..

MACRO SET_TELETEXT_FONT_CHAR_MAP

	MAPCHAR 'A', 1
	MAPCHAR 'B', 4
	MAPCHAR 'C', 7
	MAPCHAR 'D', 10
	MAPCHAR 'E', 13
	MAPCHAR 'F', 16
	MAPCHAR 'G', 19
	MAPCHAR 'H', 22
	MAPCHAR 'I', 25
	MAPCHAR 'J', 28
	MAPCHAR 'K', 31
	MAPCHAR 'L', 34
	MAPCHAR 'M', 37

	MAPCHAR 'a', 1
	MAPCHAR 'b', 4
	MAPCHAR 'c', 7
	MAPCHAR 'd', 10
	MAPCHAR 'e', 13
	MAPCHAR 'f', 16
	MAPCHAR 'g', 19
	MAPCHAR 'h', 22
	MAPCHAR 'i', 25
	MAPCHAR 'j', 28
	MAPCHAR 'k', 31
	MAPCHAR 'l', 34
	MAPCHAR 'm', 37

	MAPCHAR 'N', 81
	MAPCHAR 'O', 84
	MAPCHAR 'P', 87
	MAPCHAR 'Q', 90
	MAPCHAR 'R', 93
	MAPCHAR 'S', 96
	MAPCHAR 'T', 99
	MAPCHAR 'U', 102
	MAPCHAR 'V', 105
	MAPCHAR 'W', 108
	MAPCHAR 'X', 111
	MAPCHAR 'Y', 114
	MAPCHAR 'Z', 117

	MAPCHAR 'n', 81
	MAPCHAR 'o', 84
	MAPCHAR 'p', 87
	MAPCHAR 'q', 90
	MAPCHAR 'r', 93
	MAPCHAR 's', 96
	MAPCHAR 't', 99
	MAPCHAR 'u', 102
	MAPCHAR 'v', 105
	MAPCHAR 'w', 108
	MAPCHAR 'x', 111
	MAPCHAR 'y', 114
	MAPCHAR 'z', 117

	MAPCHAR '0', 161
	MAPCHAR '1', 164
	MAPCHAR '2', 167
	MAPCHAR '3', 170
	MAPCHAR '4', 173
	MAPCHAR '5', 176
	MAPCHAR '6', 179
	MAPCHAR '7', 182
	MAPCHAR '8', 185
	MAPCHAR '9', 188
	MAPCHAR '?', 191
	MAPCHAR '!', 194
	MAPCHAR '.', 197

	MAPCHAR ' ', 241

ENDMACRO

SET_TELETEXT_FONT_CHAR_MAP

\\ Credit text strings
\\ First byte is character offset from left side of screen
\\ Then text string terminted by 0
\\ If character offset is &FF this indicates no more strings
\\ Currently strings just loop but could just stop!

\\ New font is 3 chars wide = max 13 letters per line from 1

; centering offsets
; 1=19 2=17 3=16 4=14 5=13 6=11 7=10 8=8 9=7 a=5 b=4 c=2 d=1
.fx_creditscroll_text
;       123456789abcd
EQUS  7,"Bad Apple",0
EQUS  1,"",0
EQUS  8,"Teletext",0
EQUS 10,"Version",0
EQUS  1,"",0
EQUS  1,"",0
EQUS 19,"A",0
EQUS  4,"Bitshifters",0
EQUS  5,"Production",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS 10,"Code By",0
EQUS  1,"",0
EQUS  5,"Kieran and",0
EQUS 10,"simon.m",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  8,"Music by",0
EQUS  1,"",0
EQUS  1,"Inverse Phase",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS 11,"Art by",0
EQUS  1,"",0
EQUS  2,"Horsenburger",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  4,"Released at",0
EQUS  1,"",0
EQUS  4,"Block Party",0
EQUS  7,"Cambridge",0
EQUS  4,"25 Feb 2017",0
EQUS  1," ",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  2,"Thanks to...",0
EQUS  1,"",0
EQUS  7,"Steve3000",0
EQUS  2,"Stardot Crew",0
EQUS 10,"Edit.tf",0
EQUS 11,"jsbeeb",0
EQUS 10,"BeebAsm",0
EQUS  7,"Deflemask",0
;EQUS  8,"Exomizer",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  4,"Greetz from",0
EQUS  2,"Kieran to...",0
EQUS  1,"",0
EQUS  1,"Raquel Meyers",0
EQUS  1,"Steve Horsley",0
EQUS  1,"Dan Farrimond",0
EQUS  2,"Simon Rawles",0
EQUS  1,"Alistair Cree",0
EQUS  4,"Peter Kwan",0
EQUS 10,"Rich TW",0
EQUS  2,"Matt Godbolt",0
;EQUS  3,"Puppeh.CRTC",0
;EQUS  8,"rc55.CRTC",0
;EQUS  2,"Ramon.Desire",0
;EQUS  2,"Paul.Ate Bit",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  4,"Greetz from",0
EQUS  1,"Inverse Phase",0
EQUS 13,"to...",0
EQUS  1,"",0
EQUS 16,"3LN",0
EQUS 14,"4mat",0
EQUS  5,"bitshifter",0
EQUS  4,"bitshifters",0
EQUS 11,"blargg",0
EQUS 13,"cmucc",0
EQUS 14,"crtc",0
EQUS 13,"ctrix",0
EQUS 13,"delek",0
EQUS 11,"gemini",0
EQUS 11,"goto80",0
EQUS 10,"haujobb",0
EQUS 11,"nesdev",0
EQUS 16,"pwp",0
EQUS 13,"siren",0
EQUS 10,"trixter",0
EQUS 11,"ubulab",0
EQUS 14,"virt",0
EQUS 13,"vogue",0
EQUS 14,"mr.h",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  4,"Greetz from",0
EQUS  2,"Henley to...",0
EQUS  1,"",0
EQUS 13,"!FOZ!",0
EQUS 11,"Merlin",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"Thank you for",0
EQUS  7,"Watching!",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS  1,"",0
EQUS &FF
.fx_creditscroll_text_end

PRINT "credits text size ", ~(fx_creditscroll_text_end-fx_creditscroll_text), " bytes"
RESET_MAPCHAR



.end_fx_creditscroll
