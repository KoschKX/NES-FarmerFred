PLAYER_CAMERA_OFFSET = $9D

UpdateCamera:

  ; camera = player_world_y + 8 - PLAYER_CAMERA_OFFSET  (16-bit)
  LDA player_world_y_low
  CLC
  ADC #$08
  STA tmp_low
  LDA player_world_y_high
  ADC #$00
  STA tmp_high
  LDA tmp_low
  SEC
  SBC #PLAYER_CAMERA_OFFSET
  STA camera_y
  LDA tmp_high
  SBC #$00
  STA camera_y_high

  ; wrap if negative (player crossed level top)
  LDA camera_y_high
  BPL @done
@wrap_large:
  ; add 480px ($01E0) to wrap
  LDA camera_y
  CLC
  ADC #$E0
  STA camera_y
  LDA camera_y_high
  ADC #$01
  STA camera_y_high
  BMI @wrap_large       ; still negative? add another 480

@done:
  ; optional bottom clamp (camera_clamp_bottom flag)
  LDA camera_clamp_bottom
  BEQ @clamp_done           ; flag off → skip
  LDA player_world_y_high
  BMI @clamp_done           ; negative = top-wrap zone → skip
  BEQ @clamp_done           ; $00 = top page (rows 0-29) → skip
  ; player is in bottom page → apply clamp
  LDA camera_y_high
  BNE @do_clamp             ; >= 256 → clamp
  LDA camera_y
  CMP #$F0
  BCC @clamp_done           ; < 240 → fine
@do_clamp:
  LDA #$F0
  STA camera_y
  LDA #$00
  STA camera_y_high
@clamp_done:
  RTS

UpdateCameraRender:

  ; scroll_y_ppu = camera_16bit % 240; toggle nametable each boundary
  LDA camera_y
  STA tmp_low
  LDA camera_y_high
  STA tmp_high
  LDA #$00
  STA nametable
@mod240_loop:
  LDA tmp_high
  BNE @sub240           ; high byte nonzero → definitely >= 240
  LDA tmp_low
  CMP #$F0              ; 240 = $F0
  BCC @mod240_done
@sub240:
  LDA tmp_low
  SEC
  SBC #$F0              ; subtract 240
  STA tmp_low
  LDA tmp_high
  SBC #$00
  STA tmp_high
  LDA nametable
  EOR #$01
  STA nametable
  JMP @mod240_loop
@mod240_done:
  LDA tmp_low
  STA scroll_y_ppu
  RTS

