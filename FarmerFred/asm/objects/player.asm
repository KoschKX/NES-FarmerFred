; player.asm
InitSpritePositions:
	; slot 0: unused
	LDA #$FE
	STA $0300
	LDA #$00
	STA $0301
	STA $0302
	STA $0303
	; Player sprites start at slot 1 ($0304).
	LDY #$00
@initloop:
	LDA gfx_sprites_fred_frame0, y
	STA $0304, y
	INY
	CPY #$24
	BNE @initloop
	; pumpkin tiles/attrs
	LDY #$00
@initPumpkinLoop:
	LDA gfx_veggies_pumpkin, y
	STA $0328, y
	INY
	CPY #$24        ; 9 sprites * 4 bytes
	BNE @initPumpkinLoop
	JSR HidePumpkinSprites
	; HUD
	LDY #$00
@initHUDLoop:
	LDA gfx_hud_text, y
	STA $034C, y
	INY
	CPY #$08        ; 2 sprites * 4 bytes
	BNE @initHUDLoop
	; slot 37: units
	LDA #$08
	STA $0394
	LDA #font_0
	STA $0395
	LDA #$00
	STA $0396
	LDA #$18
	STA $0397
	; slot 36: arrow
	LDA #$FF
	STA $0390              ; hidden
	LDA #font_arrow_up
	STA $0391
	LDA #$00
	STA $0392
	LDA #$7C
	STA $0393
	; hide tail slots
	LDA #$FE
	LDX #$00
@initTailLoop:
	STA $0398, X
	INX
	INX
	INX
	INX
	CPX #$68              ; 26 slots * 4 = 104 bytes
	BNE @initTailLoop
	RTS

HidePumpkinSprites:
	LDA #$FE
	STA $0328
	STA $032C
	STA $0330
	STA $0334
	STA $0338
	STA $033C
	STA $0340
	STA $0344
	STA $0348
	RTS

UpdateSpriteWorldPos:
	; clamp_bottom=0: constant 149
	; clamp_bottom=1 + bottom page: compute screen Y dynamically
	; clamp_bottom=1 + top page: constant 149
	LDA camera_clamp_bottom
	BEQ @use_constant
	LDA player_world_y_high
	BMI @use_constant         ; top-wrap zone
	BEQ @use_constant         ; top page (rows 0-29)
	; bottom page — compute dynamically
	SEC
	LDA player_world_y_low
	SBC camera_y
	STA tmp_low
	LDA player_world_y_high
	SBC camera_y_high
	BNE @use_constant         ; wrapped
	LDA tmp_low
	JMP @set_oam
@use_constant:
	LDA #$95
@set_oam:
	STA tmp_low           ; feet screen Y
	; bottom row
	LDA tmp_low
	STA $031C
	STA $0320
	STA $0324
	; Middle row = feet - 8
	LDA tmp_low
	SEC
	SBC #$08
	STA $0310
	STA $0314
	STA $0318
	; top row
	SEC
	SBC #$08
	STA $0304
	STA $0308
	STA $030C
	; X positions
	LDA player_world_x_low
	STA $0307                 ; row0 col0
	STA $0313                 ; row1 col0
	STA $031F                 ; row2 col0
	CLC
	ADC #$08
	STA $030B                 ; row0 col1
	STA $0317                 ; row1 col1
	STA $0323                 ; row2 col1
	CLC
	ADC #$08
	STA $030F                 ; row0 col2
	STA $031B                 ; row1 col2
	STA $0327                 ; row2 col2
	; pumpkin
	LDA isCarrying
	BNE @pumpkin_active
	JMP @hidePumpkin
@pumpkin_active:
	CMP #$02
	BEQ @showThrownPumpkin
	; carried: follow player
	LDA tmp_low
	SEC
	SBC #$18
	STA $0328
	STA $032C
	STA $0330
	LDA tmp_low
	SEC
	SBC #$10
	STA $0334
	STA $0338
	STA $033C
	; row 2: no CHR
	LDA #$FE
	STA $0340
	STA $0344
	STA $0348
	; X
	LDA player_world_x_low
	STA $032B
	STA $0337
	CLC
	ADC #$08
	STA $032F
	STA $033B
	CLC
	ADC #$08
	STA $0333
	STA $033F
	; H-flip pumpkin to match player facing (0=right, 1=left)
	LDA playerFacing
	JSR PumpkinApplyFlip
	RTS
@showThrownPumpkin:
	; thrown: direct screen Y
	LDA pumpkin_world_y_low
	STA $0328
	STA $032C
	STA $0330
	CLC
	ADC #$08
	STA $0334
	STA $0338
	STA $033C
	; row 2: no CHR
	LDA #$FE
	STA $0340
	STA $0344
	STA $0348
	; X
	LDA pumpkinX
	STA $032B
	STA $0337
	CLC
	ADC #$08
	STA $032F
	STA $033B
	CLC
	ADC #$08
	STA $0333
	STA $033F
	LDA pumpkinVX
	AND #$80
	JSR PumpkinApplyFlip
	RTS
@hidePumpkin:
	JMP HidePumpkinSprites

; PumpkinApplyFlip: A=0 right (no flip), A!=0 left (H-flip + col0/col2 swap)
;
; OAM layout used (pumpkin rows 0-1, 3 cols each):
;   col0 tile=$0329  attr=$032A  X=$032B
;   col1 tile=$032D  attr=$032E  X=$032F
;   col2 tile=$0331  attr=$0332  X=$0333
;   col0 tile=$0335  attr=$0336  X=$0337
;   col1 tile=$0339  attr=$033A  X=$033B
;   col2 tile=$033D  attr=$033E  X=$033F
;
; Canonical right-facing tiles: row0 $EB,$EC,$ED  row1 $FB,$FC,$FD
PumpkinApplyFlip:
	BEQ @paf_clear
	; facing left: swap col0<->col2 tiles, set H-flip on all
	; row 0
	LDA #$ED
	STA $0329              ; col0 slot gets right-edge tile (H-flip = correct left)
	LDA #$EB
	STA $0331              ; col2 slot gets left-edge tile
	LDA $032A
	ORA #$40
	STA $032A              ; col0 attr: set H-flip
	LDA $032E
	ORA #$40
	STA $032E              ; col1 attr
	LDA $0332
	ORA #$40
	STA $0332              ; col2 attr
	; row 1
	LDA #$FD
	STA $0335
	LDA #$FB
	STA $033D
	LDA $0336
	ORA #$40
	STA $0336
	LDA $033A
	ORA #$40
	STA $033A
	LDA $033E
	ORA #$40
	STA $033E
	RTS
@paf_clear:
	; facing right: restore canonical tile order, clear H-flip
	; row 0
	LDA #$EB
	STA $0329
	LDA #$ED
	STA $0331
	LDA $032A
	AND #$BF
	STA $032A
	LDA $032E
	AND #$BF
	STA $032E
	LDA $0332
	AND #$BF
	STA $0332
	; row 1
	LDA #$FB
	STA $0335
	LDA #$FD
	STA $033D
	LDA $0336
	AND #$BF
	STA $0336
	LDA $033A
	AND #$BF
	STA $033A
	LDA $033E
	AND #$BF
	STA $033E
	RTS

UpdateSpriteAttrs:
	LDA playerFacing
	BEQ @clearFlip
@setFlip:
	LDY #$02
@setAttrLoop:
	LDA $0304, y
	ORA #$40        ; set bit 6 = H-flip
	STA $0304, y
	INY
	INY
	INY
	INY
	CPY #$26
	BNE @setAttrLoop

	; swap col0 and col2 tile indices so the leading edge faces correctly
	; row0
	LDA $0305
	PHA
	LDA $030D
	STA $0305
	PLA
	STA $030D
	; row1
	LDA $0311
	PHA
	LDA $0319
	STA $0311
	PLA
	STA $0319
	; row2
	LDA $031D
	PHA
	LDA $0325
	STA $031D
	PLA
	STA $0325
	RTS
@clearFlip:
	LDY #$02
@clearLoop:
	LDA $0304, y
	AND #$BF        ; clear bit 6
	STA $0304, y
	INY
	INY
	INY
	INY
	CPY #$26
	BNE @clearLoop
	RTS

  .include "asm/objects/player_input.asm"
  .include "asm/objects/player_walk.asm"
  .include "asm/objects/player_jump.asm"
  .include "asm/objects/player_collide.asm"
  .include "asm/objects/player_animation.asm"
  .include "asm/objects/player_grab.asm"
  .include "asm/objects/veggies.asm"