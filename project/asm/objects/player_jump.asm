; player_jump.asm
; jump, gravity, world-wrap

ApplyGravity:
  LDA bottomCenterCollision
  BEQ @CalcGravity
  LDA playerVelocityY
  BMI @CalcGravity        ; rising
  JMP @ClampCheck         ; grounded
@CalcGravity:

@noCoyoteDec:
  LDA coyoteTimer
  BEQ @noCoyoteDec2
  DEC coyoteTimer
@noCoyoteDec2:
  LDA jumpBuffer
  BEQ @noBufferDec
  DEC jumpBuffer
@noBufferDec:
  ; gravity:
  LDA playerVelocityY
  BMI @rising

  ; falling
  CLC
  ADC #$01
  CMP #$05
  BCC @storeVel
  LDA #$04
  JMP @storeVel

@rising:
  LDA playerBheld
  BEQ @risingNotHeld
  LDA playerHoldTimer
  BEQ @risingNotHeld
  DEC playerHoldTimer
  LDA playerVelocityY
  CLC
  ADC #$01
  JMP @storeVel
@risingNotHeld:
  LDA playerVelocityY
  CLC
  ADC #$02
@storeVel:
  STA playerVelocityY

  LDA playerVelocityY
  BEQ @notAirborne
  LDA #$00
  STA playerGrounded
  LDA coyoteTimer
  BNE @notAirborne
  LDA #$06
  STA coyoteTimer
@notAirborne:
  ; apply velocity
  LDA player_world_y_low
  CLC
  ADC playerVelocityY
  STA player_world_y_low
  LDA playerVelocityY
  BMI @vel_neg
  LDA player_world_y_high
  ADC #$00
  STA player_world_y_high
  JMP @wy_bounds
@vel_neg:
  LDA player_world_y_high
  ADC #$FF
  STA player_world_y_high

@wy_bounds:
  ; wrap world_y
  LDA player_world_y_high
  BMI @wy_add_level     ; negative → add one level height
@wy_check_max:
  CMP #$01
  BCS @wy_not_in_range
  JMP @ClampCheck       ; high == 0 → in range
@wy_not_in_range:
  BNE @wy_sub_level     ; high ≥ 2 → over
  LDA player_world_y_low ; high==1: wrap if low ≥ $E0
  CMP #$E0
  BCS @wy_sub_level
  JMP @ClampCheck
@wy_sub_level:
  ; crossed bottom
  LDA #$01
  STA plant_needs_restore
  LDA #$00
  STA plant_restore_idx
  ; world_y -= 480
  LDA player_world_y_low
  SEC
  SBC #$E0
  STA player_world_y_low
  LDA player_world_y_high
  SBC #$01
  STA player_world_y_high
  JMP @wy_bounds          ; re-check in case still out of range
@wy_add_level:
  LDA reached_platform
  BNE @doAddLevel
  ; no platform yet — clamp
@wy_clamp_top:
  LDA #$00
  STA player_world_y_low
  STA player_world_y_high
  STA playerVelocityY
  JMP @ClampCheck
@doAddLevel:
  LDA playerVelocityY
  BPL @wy_clamp_top     ; not rising
  ; gate check
  LDA basketGoal
  BEQ @pj_do_transition     ; 0 = disabled
  LDA pageVeggies
  CMP basketGoal
  BCC @wy_clamp_top         ; pageVeggies < goal - block
@pj_do_transition:
  LDA #$00
  STA pageVeggies
  STA reached_platform
  ; crossed top
  LDA #$01
  STA plant_needs_restore
  LDA #$00
  STA plant_restore_idx
  ; world_y += 480
  LDA player_world_y_low
  CLC
  ADC #$E0
  STA player_world_y_low
  LDA player_world_y_high
  ADC #$01
  STA player_world_y_high
  LDA #$C8
  STA player_world_y_low
  LDA #$01
  STA player_world_y_high
  LDA #$F4              ; -12
  STA playerVelocityY
  LDA #$00
  STA playerGrounded
  STA playerHoldTimer
  JMP @wy_check_max

@ClampCheck
  LDA bottomCenterCollision
  BEQ @done
  LDA playerVelocityY
  BMI @done

  ; snap to platform
  LDA tile_row
  STA tmp_low
  LDA #$00
  STA tmp_high
  ASL tmp_low       ; tile_row * 2
  ROL tmp_high
  ASL tmp_low       ; tile_row * 4
  ROL tmp_high
  ASL tmp_low       ; tile_row * 8
  ROL tmp_high
  LDA tmp_low
  SEC
  SBC #$08
  STA player_world_y_low
  LDA tmp_high
  SBC #$00
  STA player_world_y_high

  LDA #$00
  STA playerVelocityY
  LDA #$01
  STA playerGrounded
  LDA #$00
  STA coyoteTimer

  LDA tile_row
  CMP #58
  BCS @landedOnGround
  LDA #$01
  STA reached_platform
  JMP @checkBuffer
@landedOnGround:
  LDA #$00
  STA reached_platform
@checkBuffer:

  ; buffered jump
  LDA jumpBuffer
  BEQ @noBufferedJump
  LDA #$F2
  STA playerVelocityY
  LDA #$0C
  STA playerHoldTimer
  LDA #$00
  STA jumpBuffer
  LDA #$00
  STA playerGrounded
  LDA #$01
  STA playerMoving
  LDA #$01              ; sfx: jump
  LDX #FAMISTUDIO_SFX_CH1
  JSR famistudio_sfx_play
@noBufferedJump:

@done:
  RTS
HandlePlayerJump:
  LDA joy1_pressed
  AND #$40
  BEQ @SkipJumpEdge
  ; Down+B = drop through one-way platform
  LDA joy1_curr
  AND #$44
  CMP #$44
  BNE @NotDropJump
  JMP @SkipJumpEdge    ; SFX plays in DropThroughSkip if the drop is actually allowed
@NotDropJump:
  LDA playerVelocityY
  BNE @SkipJumpEdge     ; no double-jump
  LDA playerGrounded
  BNE @DoJump
  ; coyote
  LDA coyoteTimer
  BEQ @SetJumpBuffer
  LDA #$00
  STA coyoteTimer
  JMP @DoJump
@SetJumpBuffer:
  LDA #$06
  STA jumpBuffer
  JMP @SkipJumpEdge
@DoJump:
  LDA #$F2
  STA playerVelocityY
  LDA #$00
  STA playerGrounded
  LDA #$01
  STA playerMoving
  LDA #$0C
  STA playerHoldTimer
  LDA #$01              ; sfx: jump
  LDX #FAMISTUDIO_SFX_CH1
  JSR famistudio_sfx_play
@SkipJumpEdge:
  RTS