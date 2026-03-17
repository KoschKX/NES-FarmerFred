; player_grab.asm
; Grab plant tiles when A is pressed; sets bits in plant_removed_bits.

; Bit-mask lookup (indexed by col & 7)
grab_bit_masks:
  .db $01, $02, $04, $08, $10, $20, $40, $80

; Plant rows in tile-row space (one row above each platform top).
; Platform tops: 9, 19, 29, 39, 49 → plant rows: 8, 18, 28, 38, 48
grab_plant_rows:
  .db 8, 18, 28, 38, 48

; ClearPlantRemovedBits
;   Zeroes the 24-byte plant_removed_bits array.  Call once at level init.
ClearPlantRemovedBits:
  LDX #19
  LDA #$00
@cpb_loop:
  STA plant_removed_bits, X
  DEX
  BPL @cpb_loop
  RTS

; PlayerTryGrabPlant
PlayerTryGrabPlant:
  LDA joy1_pressed
  AND #$01              ; A button
  BNE @grab_b_pressed
  RTS                   ; A not pressed — early out
@grab_b_pressed:
  ; Handle based on carry state
  LDA isCarrying
  BEQ @grab_try          ; 0 = not carrying, attempt a grab
  CMP #$01
  BNE @grab_rts          ; 2+ = pumpkin in flight, ignore input
  JSR PlayerThrowPumpkin ; 1 = carrying, throw it
@grab_rts:
  RTS
@grab_try:

  ; Only allow grab when grounded
  LDA playerGrounded
  BEQ @grab_rts

  ; tile_row = (world_y_high<<5) | ((world_y_low+4)>>3)
  LDA player_world_y_low
  CLC
  ADC #$04
  STA tmp_low
  LDA player_world_y_high
  ADC #$00              ; handle carry
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  STA tmp_high
  LDA tmp_low
  LSR A
  LSR A
  LSR A
  ORA tmp_high
  STA tile_row

  ; Check if tile_row matches any plant row (8,16,24,32,40,48)
  LDX #4
@grab_chk_row:
  CMP grab_plant_rows, X
  BEQ @grab_row_found
  DEX
  BPL @grab_chk_row
  RTS                   ; not a plant row — nothing to grab

@grab_row_found:
  ; X = row index (0-4) — save in tmp_high
  STX tmp_high

  ; probe left/center/right bottom sprite columns
  ; OAM X: left=$031F center=$0323 right=$0327
  LDA $031F
  JSR @grab_probe_col
  BEQ @grab_col_found
  LDA $0323
  JSR @grab_probe_col
  BEQ @grab_col_found
  LDA $0327
  JSR @grab_probe_col
  BEQ @grab_col_found
  RTS                   ; no live plant under any column

@grab_col_found:
  ; tmp_low = matched tile_col, tmp_high = row_index
  JSR @grab_set_removal_bit   ; preserves tmp_low
  LDA tmp_low
  STA tmp_mul           ; save tile_col for VRAM erase
@grab_do_anim:

  ; clear stale velocity and jump buffer during grab freeze
  LDA #$00
  STA playerVelocityY
  STA jumpBuffer

  ; Start grab animation — freeze player for 20 frames
  LDA #20
  STA grabTimer
  LDA #$01
  STA isCarrying           ; pumpkin now carried — stays visible after grab anim
  LDA #$06
  STA playerFrame          ; show pickup sprite during grab

  ; PPU base address for tile_row
  ; NT0 (<30): hi=$20+(row>>3)  NT1 (>=30): hi=$28+((row-30)>>3)
  LDA tile_row
  CMP #30
  BCS @grab_nt1
  ; NT0
  LDA tile_row
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$20
  STA tmp_high             ; PPU hi byte
  LDA tile_row
  AND #$07
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  STA tmp_low              ; PPU lo base
  JMP @grab_erase_cols
@grab_nt1:
  ; NT1
  LDA tile_row
  SEC
  SBC #30               ; A = local_row
  PHA                   ; save local_row (keeps tmp_mul free for tile_col)
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$28
  STA tmp_high             ; PPU hi byte
  PLA                   ; restore local_row
  AND #$07
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  STA tmp_low              ; PPU lo base
@grab_erase_cols:
  ; tmp_mul holds the grabbed tile_col (saved at @grab_col_found)
  LDA tmp_mul
  CLC
  ADC tmp_low
  STA plant_erase_buf+1    ; lo0
  LDA tmp_high
  ADC #$00
  STA plant_erase_buf+0    ; hi0
  ; Arm the erase — NMI will blank 1 tile
  LDA #$01
  STA plant_erase_count

@grab_done:
  RTS
; @grab_probe_col: A=OAM X, returns Z=1 if plant present
@grab_probe_col:
  CLC
  ADC #$04
  LSR A
  LSR A
  LSR A
  STA tmp_low
  JMP @grab_check_col

@grab_check_col:
  LDA tmp_high          ; row index
  ASL A
  ASL A                 ; row_index * 4
  STA tmp_mul
  LDA tmp_low
  LSR A
  LSR A
  LSR A                 ; tile_col >> 3 = byte offset within row
  CLC
  ADC tmp_mul
  TAX
  LDA tmp_low
  AND #$07
  TAY
  LDA plant_removed_bits, X
  AND grab_bit_masks, Y ; Z=1 if bit clear (plant present)
  RTS

; @grab_set_removal_bit
;   Sets the plant_removed_bits entry for column tmp_low at row tmp_high.
@grab_set_removal_bit:
  LDA tmp_high          ; row index (0-5)
  ASL A
  ASL A                 ; row_index * 4
  STA tmp_mul
  LDA tmp_low           ; column
  LSR A
  LSR A
  LSR A                 ; column >> 3
  CLC
  ADC tmp_mul
  TAX                   ; byte offset into plant_removed_bits
  LDA tmp_low
  AND #$07
  TAY
  LDA grab_bit_masks, Y ; bit mask for this column
  ORA plant_removed_bits, X
  STA plant_removed_bits, X
  RTS

; PlayerThrowPumpkin
PlayerThrowPumpkin:
  LDA #$02
  STA isCarrying
  LDA $0328             ; held pumpkin OAM Y
  STA pumpkin_world_y_low
  LDA $032B             ; held pumpkin OAM X
  STA pumpkinX
  ; vx: +3 right, $FD left
  LDA playerFacing
  BEQ @thr_right
  LDA #$FD
  STA pumpkinVX
  JMP @thr_done
@thr_right:
  LDA #$03
  STA pumpkinVX
@thr_done:
  LDA #$00
  STA pumpkinVY
  LDA #$06
  LDX #FAMISTUDIO_SFX_CH1
  JSR famistudio_sfx_play
  RTS

; UpdatePumpkinThrow
;   Move pumpkin, apply gravity, score on basket ($05) tile hit.
UpdatePumpkinThrow:
  LDA isCarrying
  CMP #$02
  BEQ @upt_active
  RTS              ; not in thrown state — nothing to do
@upt_active:
  ; Move screen X (signed byte velocity)
  LDA pumpkinX
  CLC
  ADC pumpkinVX
  STA pumpkinX
  ; Move screen Y downward
  LDA pumpkin_world_y_low
  CLC
  ADC pumpkinVY
  STA pumpkin_world_y_low
  ; Apply gravity, capped at 6
  LDA pumpkinVY
  CMP #$06
  BCS @upt_no_grav
  INC pumpkinVY
@upt_no_grav:
  ; Tile collision check: score if ANY bottom tile hits a $05
  ; skip tile check until pumpkinVY >= 3 (avoid foot-level false trigger)
  LDA pumpkinVY
  CMP #$03
  BCS @upt_do_tile_check
  JMP @upt_check_offscreen   ; still launching — skip tile check
@upt_do_tile_check:
  LDA pumpkin_world_y_low
  CLC
  ADC camera_y            ; screen_y + camera_low
  STA tmp_low
  LDA camera_y_high
  ADC #$00                ; propagate carry
  STA tmp_high
  LDA tmp_low
  CLC
  ADC #$10                ; +16 = bottom edge of 2-row sprite
  STA tmp_low
  LDA tmp_high
  ADC #$00
  AND #$07                ; clamp high bits
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A                   ; * 32
  STA tile_row
  LDA tmp_low
  LSR A
  LSR A
  LSR A                   ; >> 3
  ORA tile_row
  STA tile_row
  ; Clamp tile_row to 0-59: pumpkin near screen bottom can overflow with carry
  CMP #60
  BCC @upt_row_ok
  LDA #$3B              ; 59
  STA tile_row
@upt_row_ok:
  ; left tile_col = pumpkinX / 8
  LDA pumpkinX
  LSR A
  LSR A
  LSR A
  STA tile_col
  JSR CFS_GetTileByColRow
  LDX TileID
  LDA collision_table, X
  CMP #$05
  BEQ @upt_score_hit
  ; centre tile_col = (pumpkinX + 8) / 8
  LDA pumpkinX
  CLC
  ADC #$08
  LSR A
  LSR A
  LSR A
  STA tile_col
  JSR CFS_GetTileByColRow
  LDX TileID
  LDA collision_table, X
  CMP #$05
  BEQ @upt_score_hit
  ; right tile_col = (pumpkinX + 16) / 8
  LDA pumpkinX
  CLC
  ADC #$10
  LSR A
  LSR A
  LSR A
  STA tile_col
  JSR CFS_GetTileByColRow
  LDX TileID
  LDA collision_table, X
  CMP #$05
  BNE @upt_check_offscreen
@upt_score_hit:
  ; At least one bottom tile is $05 - increment counters (capped at 99) and despawn
  LDA veggieCount
  CMP #99
  BCS @upt_scored
  INC veggieCount
  INC pageVeggies
  LDA #$03
  LDX #FAMISTUDIO_SFX_CH1
  JSR famistudio_sfx_play
  JSR UpdateSeasons
  ; arm basket sparkle 2 rows above hit tile
  LDA tile_row
  SEC
  SBC #$02
  CMP #30
  BCS @upt_ba_nt1
  STA tmp_low
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$20
  STA basket_anim_ppu_hi
  LDA tmp_low
  AND #$07
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  ORA tile_col
  STA basket_anim_ppu_lo
  JMP @upt_ba_armed
@upt_ba_nt1:
  SEC
  SBC #30
  STA tmp_low
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$28
  STA basket_anim_ppu_hi
  LDA tmp_low
  AND #$07
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  ORA tile_col
  STA basket_anim_ppu_lo
@upt_ba_armed:
  LDA #$1E              ; 30 frames = 0.5 second
  STA basket_anim_timer
@upt_scored:
  LDA #$00
  STA isCarrying
  JMP @upt_done
@upt_check_offscreen:
  ; No scoring tile hit — despawn silently when off the bottom of screen
  LDA pumpkin_world_y_low
  CMP #$F0
  BCC @upt_done
  LDA #$00
  STA isCarrying
@upt_done:
  RTS

; AllPlantsGone -- returns Z=1 if all plants grabbed (plant_removed_bits bytes 0-19 all $FF).
AllPlantsGone:
  LDX #19
@apg_loop:
  LDA plant_removed_bits, X
  CMP #$FF
  BNE @apg_no         ; found a byte with a live plant — not all gone
  DEX
  BPL @apg_loop
  LDA #$00             ; all $FF — Z=1: no plants left
  RTS
@apg_no:
  LDA #$01             ; Z=0: plants remain
  RTS