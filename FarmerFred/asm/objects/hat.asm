; hat.asm - Fred's hat launch + gravity object
;
; OAM slots 33-35 ($0384-$038F)
; hat_world_y_low/high = 16-bit world Y

; Bottom floor hat position constants:
;   Ground floor row = 58
;   hat_world_y = (58-1)*8 = 456 = $01C8
;   hat_screen_x = $80 (center of 256px screen)
HAT_BOTTOM_PLAT_Y_LOW  = $C8
HAT_BOTTOM_PLAT_Y_HIGH = $01
HAT_CENTER_X           = $80

; PlaceHatOnBottomPlatform
;   Call after a page transition (plant_needs_restore handled).
;   If the player is bald (playerHitTimer != 0) and no hat is already
;   active, places the hat as landed at the center of the bottom platform.
PlaceHatOnBottomPlatform:
  LDA playerHitTimer
  BEQ @phbp_done        ; player has hat on -- nothing to do
  LDA hat_active
  BNE @phbp_done        ; hat already flying/landed somewhere
  LDA #HAT_BOTTOM_PLAT_Y_LOW
  STA hat_world_y_low
  LDA #HAT_BOTTOM_PLAT_Y_HIGH
  STA hat_world_y_high
  LDA #HAT_CENTER_X
  STA hat_screen_x
  LDA #$00
  STA hat_vx
  STA hat_vy
  STA hat_timer
  LDA #$02              ; landed state
  STA hat_active
@phbp_done:
  RTS
;   hat_screen_x          = screen X
;   hat_vx / hat_vy       = signed velocity
;   hat_active            = 0 hidden  1 in-flight  2 landed

; SpawnHat
;   Called when a weevil first hits the player.
SpawnHat:
  LDA hat_active
  BNE @sh_done          ; only spawn once

  ; World Y = top of player
  LDA player_world_y_low
  STA hat_world_y_low
  LDA player_world_y_high
  STA hat_world_y_high

  ; Center X: player left sprite X + 12
  LDA $0307
  CLC
  ADC #$0C
  STA hat_screen_x

  ; vx backward from facing: right->left($FD), left->right($03)
  LDA playerFacing
  BEQ @sh_face_right
  LDA #$03
  STA hat_vx
  JMP @sh_set_vy
@sh_face_right:
  LDA #$FD
  STA hat_vx
@sh_set_vy:
  LDA #$F8              ; upward burst
  STA hat_vy
  LDA #$00
  STA hat_timer         ; reset animation counter
  LDA #$01
  STA hat_active
@sh_done:
  RTS

; UpdateHat  - call once per frame
UpdateHat:
  LDA hat_active
  BNE @uh_active
  JMP @uh_hide

@uh_active:
  ; Pickup check: only when falling or landed
  LDA hat_vy
  BMI @uh_skip_pickup   ; still rising: no pickup yet
  ; Y world page must match
  LDA hat_world_y_high
  CMP player_world_y_high
  BNE @uh_skip_pickup
  ; abs(hat_world_y_low - player_world_y_low) < 28
  LDA hat_world_y_low
  SEC
  SBC player_world_y_low
  BCS @phk_ypos
  EOR #$FF
  ADC #$01              ; negate (C=0 here → 256-A)
  JMP @phk_ychk
@phk_ypos:
@phk_ychk:
  CMP #$1C              ; 28 px
  BCS @uh_skip_pickup
  ; X overlap: center tile [hat_screen_x..hat_screen_x+7] vs player [player_world_x_low..+23]
  ; left of player?
  LDA hat_screen_x
  CLC
  ADC #$08              ; hat right edge
  BCS @phk_x_chk_right
  CMP player_world_x_low
  BCC @uh_skip_pickup
  BEQ @uh_skip_pickup
@phk_x_chk_right:
  ; right of player?
  LDA player_world_x_low
  CLC
  ADC #$18              ; player right edge
  BCS @phk_x_overlap
  CMP hat_screen_x
  BCC @uh_skip_pickup
  BEQ @uh_skip_pickup
@phk_x_overlap:
  ; Player touched the hat!
  LDA #$00
  STA hat_active
  STA playerHitTimer    ; restore full-hair sprites
  STA playerInvTimer    ; stop flickering immediately
  JMP @uh_hide

@uh_skip_pickup:
  LDA hat_active
  CMP #$02
  BNE @uh_physics
  JMP @uh_draw          ; landed: skip physics

@uh_physics:
  ; Advance animation timer every in-flight frame
  INC hat_timer

  ; Move X
  LDA hat_screen_x
  CLC
  ADC hat_vx
  STA hat_screen_x

  ; Move world Y (16-bit, signed byte velocity)
  LDA hat_vy
  BMI @uh_up

  ; Falling (vy positive): world Y increases
  LDA hat_world_y_low
  CLC
  ADC hat_vy
  STA hat_world_y_low
  BCC @uh_grav
  INC hat_world_y_high
  JMP @uh_grav

@uh_up:
  ; Rising (vy negative): world Y decreases
  LDA hat_world_y_low
  CLC
  ADC hat_vy            ; adds negative = subtracts
  STA hat_world_y_low
  BCS @uh_grav          ; no borrow
  DEC hat_world_y_high

@uh_grav:
  ; Gravity: apply only every 4 frames (slow float)
  LDA hat_timer
  AND #$03
  BNE @uh_probe
  LDA hat_vy
  BMI @uh_grav_inc
  CMP #$03              ; cap falling speed at +3 (half normal)
  BCS @uh_probe
@uh_grav_inc:
  INC hat_vy

  ; tile probe: world Y + 8 (bottom of sprite)
@uh_probe:
  LDA hat_vy
  BMI @uh_draw          ; still rising - skip collision

  LDA hat_world_y_low
  CLC
  ADC #$08              ; bottom edge
  STA tmp_low
  LDA hat_world_y_high
  ADC #$00              ; carry
  AND #$07
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A                 ; high bits * 32
  STA tile_row
  LDA tmp_low
  LSR A
  LSR A
  LSR A
  ORA tile_row
  STA tile_row

  LDA hat_screen_x
  LSR A
  LSR A
  LSR A
  STA tile_col

  JSR CFS_GetTileByColRow
  LDA TileID
  TAX
  LDA collision_table, X
  BEQ @uh_draw          ; empty tile, keep flying

  ; snap world Y so hat bottom sits on top of tile
  LDA tile_row
  SEC
  SBC #$01              ; tile_row - 1
  STA tmp_low
  AND #$1F
  ASL A
  ASL A
  ASL A                 ; * 8 = low byte
  STA hat_world_y_low
  LDA tmp_low
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A                 ; >> 5 = high byte
  STA hat_world_y_high

  LDA #$02
  STA hat_active

@uh_draw:
  ; screen Y from world Y (16-bit subtract)
  LDA hat_world_y_low
  SEC
  SBC camera_y
  STA tmp_low           ; base OAM Y
  LDA hat_world_y_high
  SBC camera_y_high
  BMI @uh_wrap          ; negative high byte: level may be wrapped
  BNE @uh_bail          ; positive high byte > 0: off bottom of screen
  LDA tmp_low
  CMP #$F0              ; on screen only if screen_y < 240
  BCS @uh_bail
  JMP @uh_on_screen

@uh_wrap:
  ; add level height (480px) to unwrap negative screen Y
  STA tmp_high
  LDA tmp_low
  CLC
  ADC #$E0
  STA tmp_low
  LDA tmp_high
  ADC #$01
  BMI @uh_bail          ; still negative after unwrap: above screen
  BNE @uh_bail          ; high byte > 0 after unwrap: below screen
  LDA tmp_low
  CMP #$F0
  BCS @uh_bail
  JMP @uh_on_screen     ; unwrap succeeded: hat is visible

@uh_bail:
  JMP @uh_hide

@uh_on_screen:
  ; NES sprite Y renders 1 scanline below OAM value, compensate here
  DEC tmp_low
  ; In-flight only: flicker + rock animation
  LDA hat_active
  CMP #$01
  BNE @uh_draw_flat     ; landed: steady, no flicker

  ; flicker while in-flight: hide every other frame
  LDA hat_timer
  AND #$01
  BNE @uh_hide

  ; rock: alternate tilt every 8 frames
  LDA hat_timer
  AND #$08
  BEQ @uh_rock_a

@uh_rock_b:
  ; left up, right down
  LDA tmp_low
  SEC
  SBC #$02
  STA $0384             ; left Y (2 px higher)
  LDA tmp_low
  STA $0388             ; center Y (flat)
  LDA tmp_low
  CLC
  ADC #$02
  STA $038C             ; right Y (2 px lower)
  JMP @uh_draw_tiles

@uh_rock_a:
  ; left down, right up
  LDA tmp_low
  CLC
  ADC #$02
  STA $0384             ; left Y (2 px lower)
  LDA tmp_low
  STA $0388             ; center Y (flat)
  LDA tmp_low
  SEC
  SBC #$02
  STA $038C             ; right Y (2 px higher)
  JMP @uh_draw_tiles

@uh_draw_flat:
  ; Landed: all three tiles at same Y
  LDA tmp_low
  STA $0384
  STA $0388
  STA $038C

@uh_draw_tiles:
  LDA #$6A
  STA $0385
  LDA #$6B
  STA $0389
  LDA #$6C
  STA $038D

  LDA #$00
  STA $0386
  STA $038A
  STA $038E

  LDA hat_screen_x
  SEC
  SBC #$08
  STA $0387             ; left X

  LDA hat_screen_x
  STA $038B             ; center X

  CLC
  ADC #$08
  STA $038F             ; right X
  RTS

@uh_hide:
  LDA #$F0
  STA $0384
  STA $0388
  STA $038C
  RTS

; DeadTick — called every frame while playerDead != 0.
DeadTick:
  JSR UpdateCamera
  JSR UpdateCameraRender
  JSR UpdateSpriteWorldPos
  JSR LoadSprites
  JSR UpdateSpriteAttrs
  JSR UpdateWeevils
  JSR UpdatePumpkinThrow
  ; Decrement the 3-second death timer
  DEC playerDeadTimer
  BNE @dt_done
  ; Timer expired: respawn player
  LDA #$00
  STA playerDead
  STA playerHitTimer     ; hat restored
  STA playerInvTimer     ; no invincibility
  STA hat_active         ; hide hat
  STA isCarrying         ; drop any held/thrown pumpkin on respawn
  STA pumpkinVX          ; clear throw velocity
  STA pumpkinVY
  STA veggieCount        ; reset cumulative score on death
  STA pageVeggies        ; reset per-page counter on death
  JSR ResetSeasonCounter ; reset season progress on death
  STA playerVelocityY    ; no vertical momentum
  LDA #$01
  STA playerGrounded     ; standing on ground
  ; Restore plants for the new life
  LDA #$01
  STA plant_needs_restore
  LDA #$00
  STA plant_restore_idx
  ; Place Fred at bottom platform centre
  LDA #$C8
  STA player_world_y_low
  LDA #$01
  STA player_world_y_high
  LDA #$80
  STA player_world_x_low
  LDA #$00
  STA player_world_x_high
@dt_done:
  RTS

; DropPumpkin - release held pumpkin into a downward fall.
DropPumpkin:
  LDA isCarrying
  CMP #$01                 ; only drop if held (not already thrown)
  BNE @dp_done
  ; screen Y from OAM (UpdateSpriteWorldPos wrote it)
  LDA $0328
  STA pumpkin_world_y_low
  LDA player_world_y_high
  STA pumpkin_world_y_high
  LDA $032B
  STA pumpkinX
  ; Zero horizontal velocity, small downward velocity (gravity takes it)
  LDA #$00
  STA pumpkinVX
  LDA #$02
  STA pumpkinVY
  ; Switch to thrown state so UpdatePumpkinThrow takes over
  LDA #$02
  STA isCarrying
@dp_done:
  RTS