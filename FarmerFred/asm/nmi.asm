
NMI:
	; title-screen: music only
	LDA nmi_title_mode
	BEQ @nmi_game_path
	PHA
	TXA
	PHA
	TYA
	PHA
	JSR famistudio_update
	LDA #$01
	STA nmi_ready
	INC frameCounter
	PLA
	TAY
	PLA
	TAX
	PLA
	RTI
@nmi_game_path:


	; === Optimized palette upload ===
	; nmi_full_palette_flag: 0 = only upload BG3, 1 = upload all 32 bytes
	; Set nmi_full_palette_flag to 1 in main/init when full palette upload is needed
	; (e.g. after palette change, game start, or reset)

	LDA nmi_full_palette_flag
	BEQ @nmi_palette3_only
	; --- Full palette upload (32 bytes) ---
	LDA $2002
	LDA #$3F
	STA $2006
	LDA #$00
	STA $2006
	LDX #$00
	@nmi_full_pal_loop:
	  LDA palettes, X
	  STA $2007
	  INX
	  CPX #$20
	  BNE @nmi_full_pal_loop
	LDA #$00
	STA nmi_full_palette_flag
	JMP @nmi_palette_done

	@nmi_palette3_only:
	; --- Only upload BG palette 3 (season) ---
	LDA $2002
	LDA #$3F
	STA $2006
	LDA #$0C
	STA $2006
	LDA season_pal3_c0
	STA $2007
	LDA season_pal3_c1
	STA $2007
	LDA season_pal3_c2
	STA $2007
	LDA season_pal3_c3
	STA $2007
	@nmi_palette_done:



; Defer plant/gate row writes if full palette upload happened this frame
LDA nmi_full_palette_flag
BNE @nmi_no_plant_flush
; deferred plant row
LDA plant_pending_flag
BEQ @nmi_no_plant_flush
LDA #$00
STA plant_pending_flag
LDA plant_pending_qx
STA tmp_qx
LDA plant_pending_pal
STA tmp_pal
JSR WritePlantRow
@nmi_no_plant_flush:

	; plant erase
	LDA plant_erase_count
	BEQ @nmi_no_erase
	LDA #$00
	STA plant_erase_count
	LDA plant_erase_buf+0
	STA $2006
	LDA plant_erase_buf+1
	STA $2006
	LDA #$00
	STA $2007
@nmi_no_erase:

	; OAM DMA
	LDA #$00
	STA $2003
	LDA #$03
	STA OAM_DMA

	JSR UpdateBasketAnim
	JSR Scroll
	JSR UpdateHUD

; Defer gate row update if full palette upload happened this frame
LDA nmi_full_palette_flag
BNE @nmi_no_top_row
; gate row update
LDA top_row_gate_flag
BEQ @nmi_no_top_row
CMP #$01
BNE @nmi_restore_row0
; write $D3 * 32 to NT0 row 0
LDA $2002
LDA #$20
STA $2006
LDA #$00
	STA $2006
	LDA #$D3
	LDX #$20
@nmi_d3_nt0:
	STA $2007
	DEX
	BNE @nmi_d3_nt0
	JMP @nmi_gate_row_done
@nmi_restore_row0:
	; restore NT0 row 0 (sky = $00)
	LDA $2002
	LDA #$20
	STA $2006
	LDA #$00
	STA $2006
	LDA #$00              ; blank
	LDX #$20
@nmi_restore_nt0:
	STA $2007
	DEX
	BNE @nmi_restore_nt0
@nmi_gate_row_done:
	LDA #$00
	STA top_row_gate_flag
@nmi_no_top_row:

	; scroll registers
	LDA $2002            ; reset latch
	LDA #$00
	STA PPU_SCROLL       ; X = 0
	LDA scroll_y_ppu
	STA PPU_SCROLL       ; Y scroll
	LDA nametable
	AND #$01
	ASL A
	ORA #%10000000       ; NMI on
	STA PPU_CTRL
	LDA #%00011110
	STA PPU_MASK

	JSR famistudio_update

	LDA #$01
	STA nmi_ready
	INC frameCounter
	RTI

