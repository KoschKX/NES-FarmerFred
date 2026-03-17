;RLE decompressor by Shiru (NESASM version)
;uses 4 bytes in zero page
;decompress data from an address in X/Y to PPU_DATA

RLE_LOW		equ $00
RLE_HIGH	equ RLE_LOW+1
RLE_TAG		equ RLE_HIGH+1
RLE_BYTE	equ RLE_TAG+1

unrle
	stx RLE_LOW
	sty RLE_HIGH
	ldy #0
	jsr rle_byte
	sta RLE_TAG
.1
	jsr rle_byte
	cmp RLE_TAG
	beq .2
	sta PPU_DATA
	sta RLE_BYTE
	bne .1
.2
	jsr rle_byte
	cmp #0
	beq .4
	tax
	lda RLE_BYTE

.3
	sta PPU_DATA
	dex
	bne .3
	beq .1
.4
	rts

rle_byte
	lda [RLE_LOW],y
	inc RLE_LOW
	bne .1
	inc RLE_HIGH
.1
	rts

; unrle_attr: same as `unrle` but while streaming output to PPU also
; compute attribute bytes and store them in a 64-byte accumulator
; pointed to by `attr_accum` (zero page pointer). Expects zero page
; variables `attr_accum` (base), `tile_col`, `tile_row`, and `RLE_*`
; Use: LDX #LOW(level_data)
;      LDY #HIGH(level_data)
;      JSR unrle_attr
;
DECODE_LOW	equ $04
DECODE_HIGH	equ DECODE_LOW+1

unrle_attr
	stx RLE_LOW
	sty RLE_HIGH
	ldy #0
;	; initialize tile coords must be set by caller (tile_col/tile_row)
	jsr rle_byte
	sta RLE_TAG
.A1
	jsr rle_byte
	cmp RLE_TAG
	beq .A2
	; output to PPU
	sta PPU_DATA
	; store last tile value for repeats
	sta RLE_BYTE
	; update attribute accumulator for this tile
	jsr .upd_attr
	jmp .A1
.A2
	jsr rle_byte
	cmp #0
	beq .A4
	tax
	lda RLE_BYTE
.A3
	sta PPU_DATA
	jsr .upd_attr
	dex
	bne .A3
	jmp .A1
.A4
	rts

; update attribute accumulator for current tile (A contains tile index)
.upd_attr
	; A contains tile index
	pha
	; pal = (tile >> 4) & 3
	pla
	lsr a
	lsr a
	lsr a
	lsr a
	and #$03
	sta tmp_pal
	; attr_col = tile_col >> 2
	lda tile_col
	lsr a
	lsr a
	sta tmp_col
	; attr_row = tile_row >> 2
	lda tile_row
	lsr a
	lsr a
	sta tmp_row
	; attr_index = tmp_row*8 + tmp_col
	lda tmp_row
	asl a
	asl a
	asl a
	clc
	adc tmp_col
	tax		; X = attr_index
	; quadrant flags: tmp_qx = (tile_col & 2)>>1, tmp_qy = (tile_row & 2)>>1
	lda tile_col
	and #$02
	lsr a
	sta tmp_qx
	lda tile_row
	and #$02
	lsr a
	sta tmp_qy
	; v = tmp_qy*2 + tmp_qx
	lda tmp_qy
	asl a
	clc
	adc tmp_qx
	asl a		; shift amount = v*2
	sta tmp_shift
	; shift palette left by tmp_shift
	ldy tmp_shift
	lda tmp_pal
.Sloop
	cpY #0
	beq .Sdone
	asl a
	dey
	bne .Sloop
.Sdone
	sta tmp_pal
	; now tmp_pal contains shifted palette bits
	lda attr_accum, X
	ora tmp_pal
	sta attr_accum, X
	; advance tile column, wrap at 32
	inc tile_col
	lda tile_col
	cmp #32
	bne .Sret
	lda #0
	sta tile_col
	inc tile_row
.Sret
	pla
	rts