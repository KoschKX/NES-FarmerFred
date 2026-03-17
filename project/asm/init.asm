; init.asm
Reset:
  ; MMC3 mapper init
  LDA #$00
  STA $8000             ; select R0 (2KB CHR at PPU $0000)
  STA $8001             ; R0 = bank 0 (CHR bytes $0000-$07FF)
  LDA #$01
  STA $8000             ; select R1 (2KB CHR at PPU $0800)
  LDA #$02
  STA $8001             ; R1 = bank 2 (CHR bytes $0800-$0FFF)
  LDA #$02
  STA $8000             ; select R2 (1KB CHR at PPU $1000)
  LDA #$04
  STA $8001             ; R2 = bank 4 (CHR bytes $1000-$13FF)
  LDA #$03
  STA $8000             ; select R3 (1KB CHR at PPU $1400)
  LDA #$05
  STA $8001             ; R3 = bank 5 (CHR bytes $1400-$17FF)
  LDA #$04
  STA $8000             ; select R4 (1KB CHR at PPU $1800)
  LDA #$06
  STA $8001             ; R4 = bank 6 (CHR bytes $1800-$1BFF)
  LDA #$05
  STA $8000             ; select R5 (1KB CHR at PPU $1C00)
  LDA #$07
  STA $8001             ; R5 = bank 7 (CHR bytes $1C00-$1FFF)
  LDA #$06
  STA $8000             ; select R6 (PRG 8KB at $8000)
  LDA #$00
  STA $8001             ; R6 = PRG bank 0
  LDA #$07
  STA $8000             ; select R7 (PRG 8KB at $A000)
  LDA #$01
  STA $8001             ; R7 = PRG bank 1
  LDA #$01
  STA $A000             ; horizontal mirroring
  LDA #$40
  STA $4017             ; disable APU frame IRQ
  LDA #$00
  STA $E000             ; disable MMC3 IRQ
  STA nmi_ready         ; PPU off during init
  LDA #$23
  STA camera_y
  LDA #$01
  STA camera_y_high
  LDA #$00
  STA scroll_y_ppu
  STA nametable
  LDA #$01
  STA player_world_y_high
  LDA #$01
  STA camera_clamp_bottom
  LDA #$00
  STA $0044             ; platform_col_shift = $0044
  STA plant_pending_flag
  STA plant_erase_count

  ; zero player state
  STA grabTimer
  STA isCarrying
  STA pumpkinX
  STA pumpkin_world_y_low
  STA pumpkin_world_y_high
  STA pumpkinVX
  STA pumpkinVY
  STA veggieCount
  STA pageVeggies
  STA playerFacing
  STA playerFrame
  STA playerVelocityY
  STA playerMoving
  STA playerBheld
  STA playerHoldTimer
  STA coyoteTimer
  STA jumpBuffer
  STA joy1_curr
  STA joy1_prev
  STA joy1_pressed
  STA joy1_released
  STA reached_platform
  STA plant_needs_restore
  STA plant_restore_idx
  STA hat_active
  STA playerHitTimer
  STA playerInvTimer
  STA playerDead
  STA playerDeadTimer
  STA top_row_gate_flag
  STA gate_open_shadow   ; blocked
  LDA #$00
  STA arrow_sfx_enable   ; arrow beep on by default
  LDA #5
  STA basketGoal         ; 0 = disabled
  ; season init (spring)
  LDA #$00
  STA season_veggie_count
  LDA #$03
  STA season
  LDA #$0C               ; 3*4
  STA season_pal_offset
  ; seed pal3 cache
  LDA season_pal3_colors+12
  STA season_pal3_c0
  LDA season_pal3_colors+13
  STA season_pal3_c1
  LDA season_pal3_colors+14
  STA season_pal3_c2
  LDA season_pal3_colors+15
  STA season_pal3_c3
  LDA #$00
  STA basket_anim_timer
  LDA #25
  STA seasonGoal
  ; zero collision state
  STA bottomCenterCollision
  STA leftCollision
  STA rightCollision
  STA topCollision
  STA tile_row
  LDA #$01
  STA playerGrounded

  LDA #$01
  STA randomize_enabled ; 0 = disabled
  LDA #$00
  LDX #8
@clr_pair_flags:
  STA $02F7-1, X        ; pair_randomized[0..7] = 0
  DEX
  BNE @clr_pair_flags

  ; LFSR seed from VBlank timing
  LDA #$01              ; non-zero required
  STA $02A0             ; lfsr_state
  LDA #$00
  STA frameCounter
init_wait_vblank:
  INC frameCounter
  BNE init_no_carry
  INC $02A0
init_no_carry:
  BIT $2002
  BPL init_wait_vblank
  ; mix counter into seed
  LDA $02A0
  EOR frameCounter
  BNE init_seed_ok
  LDA #$AC
init_seed_ok:
  STA $02A0

  ; player start
  LDA #$60
  STA player_world_x_low
  LDA #$00
  STA player_world_x_high
  ; ground floor (tile_row=57)
  LDA #$C0
  STA player_world_y_low
  LDA #$01
  STA player_world_y_high
  LDA #$39                  ; 57
  STA tile_row
  LDA #$01
  STA bottomCenterCollision
  JSR UpdateCamera          ; sync camera before first NMI
  ; sync lastRowIndex
  LDA camera_y_high
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  STA tmp_low
  LDA camera_y
  LSR A
  LSR A
  LSR A
  ORA tmp_low
  STA lastRowIndex

  JMP TitleScreen

StartGame:
  ; music init
  LDX #<music_data_untitled
  LDY #>music_data_untitled
  LDA #1               ; NTSC
  JSR famistudio_init
  LDA #1               ; creek
  JSR famistudio_music_play
  LDX #<sounds
  LDY #>sounds
  JSR famistudio_sfx_init
  JSR LoadBackground
  JSR ProcessBackground
  JSR WriteAttributesDual

  ; write all 60 rows with per-pair random shifts
  LDA #$00
  STA frameCounter      ; row counter
  STA tmp_pal
init_write_rows:
  ; bottom row of pair: reuse shift from top row
  LDA frameCounter
  CMP #3
  BEQ init_same_shift
  CMP #10
  BEQ init_same_shift
  CMP #20
  BEQ init_same_shift
  CMP #30
  BEQ init_same_shift
  CMP #40
  BEQ init_same_shift
  CMP #50
  BEQ init_same_shift
  CMP #59
  BEQ init_same_shift
  ; new row — check ground
  LDA frameCounter
  CMP #57
  BEQ init_force_ground
  CMP #58
  BNE init_not_ground
init_force_ground:
  LDA #$00
  STA tmp_pal
  JMP init_same_shift
init_not_ground:
  LDA randomize_enabled
  BNE init_do_lfsr
  LDA #$00
  STA tmp_pal
  JMP init_same_shift
init_do_lfsr:
  LDA $02A0
  BNE init_lfsr_ok
  LDA #$AC              ; reseed
  STA $02A0
init_lfsr_ok:
  LSR $02A0             ; Galois LFSR ($B8)
  BCC init_lfsr_done
  LDA $02A0
  EOR #$B8
  STA $02A0
init_lfsr_done:
  LDA $02A0
  AND #$1F
  STA tmp_pal
init_same_shift:
  LDX frameCounter
  LDA tmp_pal
  STA $02A1, X
  LDA frameCounter
  JSR WriteWorldRow
  INC frameCounter
  LDA frameCounter
  CMP #60
  BNE init_write_rows

  ; ground rows: no shift
  LDA #$00
  STA $02A1+57
  STA $02A1+58
  STA $02A1+59
  LDX #25              ; clear tail entries
@clr_rs_tail:
  STA $02A1+60, X
  DEX
  BPL @clr_rs_tail

  LDA #$01
  LDX #8
@set_pair_flags:
  STA $02F7-1, X
  DEX
  BNE @set_pair_flags

  JSR WritePlantsForAllPairs

  ; gate: write $D3 to NT0 row 0 if enabled
  LDA basketGoal
  BEQ @init_skip_gate_d3
  LDA $2002             ; reset PPU address latch
  LDA #$20
  STA $2006
  LDA #$00
  STA $2006
  LDA #$D3
  LDX #$20
@init_gate_d3_nt0:
  STA $2007
  DEX
  BNE @init_gate_d3_nt0
@init_skip_gate_d3:

  LDA #$00
  STA frameCounter      ; reset so NMI increments from 0

  JSR InitSpritePositions
  JSR InitWeevils
  JSR LoadSprites

  ; pre-compute scroll + OAM before first NMI
  JSR UpdateCameraRender
  JSR UpdateSpriteWorldPos
  JSR UpdateSpriteAttrs

  ; wait for vblank
@init_wait_final_vbl:
  BIT $2002
  BPL @init_wait_final_vbl

  LDA #$00
  STA $2003
  LDA #$03
  STA OAM_DMA

  LDA #$00
  STA PPU_SCROLL          ; X
  LDA scroll_y_ppu
  STA PPU_SCROLL          ; Y

  LDA nametable
  AND #$01
  ASL A
  ORA #%10000000          ; NMI on
  STA PPU_CTRL
  LDA #%00011110
  STA PPU_MASK

  JMP MAIN

