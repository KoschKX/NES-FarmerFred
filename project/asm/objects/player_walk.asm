; player_walk.asm
; Handles walking, left/right movement, and animation

CFS_GetTileByColRow:
  ; compute index = tile_row << 5 (multiply by 32)
  LDA tile_row
  STA debug_idx_low
  LDA #$00
  STA debug_idx_high
  ; shift left 5 times to multiply by 32
  ASL debug_idx_low
  ROL debug_idx_high
  ASL debug_idx_low
  ROL debug_idx_high
  ASL debug_idx_low
  ROL debug_idx_high
  ASL debug_idx_low
  ROL debug_idx_high
  ASL debug_idx_low
  ROL debug_idx_high

  ; Adjust tile_col by the per-row shift stored during init so collision
  ; matches the rotated tile display written by WriteWorldRow.
  ; row_shifts table starts at $02A1; index by tile_row.
  LDX tile_row
  LDA $02A1, X          ; per-row shift
  CLC
  ADC tile_col
  AND #$1F
  CLC
  ADC debug_idx_low
  STA debug_idx_low
  LDA debug_idx_high
  ADC #$00
  STA debug_idx_high

; compute absolute PRG address = pointerBackground + index
@DoPRGRead:
  LDA levelBaseLow
  CLC
  ADC debug_idx_low
  STA debug_ptr_low
  LDA levelBaseHigh
  ADC debug_idx_high
  STA debug_ptr_high

  LDY #$00
  LDA (debug_ptr_low), y
  STA TileID

  RTS