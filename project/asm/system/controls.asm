; Generic controller reader: fills joy1_* zero-page mirrors
; Sets: joy1_prev, joy1_curr, joy1_pressed, joy1_released

ReadControllers:
  ; save previous
  LDA joy1_curr
  STA joy1_prev

  ; clear current mirror
  LDA #$00
  STA joy1_curr

  ; strobe controller
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  ; small timing padding for emulator compatibility (non-controller read)
  LDA $2002
  LDA $2002

  ; Read 8 bits from $4016 into joy1_curr by OR-ing masks
  ; bit0 - A
  LDA $4016
  AND #%00000001
  BEQ RC_SKIP0
  LDA joy1_curr
  ORA #$01
  STA joy1_curr
RC_SKIP0:
  ; bit1 - B
  LDA $4016
  AND #%00000001
  BEQ RC_SKIP1
  LDA joy1_curr
  ORA #$02
  STA joy1_curr
RC_SKIP1:
  ; bit2 - Select
  LDA $4016
  AND #%00000001
  BEQ RC_SKIP2
  LDA joy1_curr
  ORA #$04
  STA joy1_curr
RC_SKIP2:
  ; bit3 - Start
  LDA $4016
  AND #%00000001
  BEQ RC_SKIP3
  LDA joy1_curr
  ORA #$08
  STA joy1_curr
RC_SKIP3:
  ; bit4 - Up
  LDA $4016
  AND #%00000001
  BEQ RC_SKIP4
  LDA joy1_curr
  ORA #$10
  STA joy1_curr
RC_SKIP4:
  ; bit5 - Down
  LDA $4016
  AND #%00000001
  BEQ RC_SKIP5
  LDA joy1_curr
  ORA #$20
  STA joy1_curr
RC_SKIP5:
  ; bit6 - Left
  LDA $4016
  AND #%00000001
  BEQ RC_SKIP6
  LDA joy1_curr
  ORA #$40
  STA joy1_curr
RC_SKIP6:
  ; bit7 - Right
  LDA $4016
  AND #%00000001
  BEQ RC_SKIP7
  LDA joy1_curr
  ORA #$80
  STA joy1_curr
RC_SKIP7:

  ; compute pressed = curr & ~prev
  LDA joy1_prev
  EOR #$FF
  STA tmp_shift
  LDA joy1_curr
  AND tmp_shift
  STA joy1_pressed

  ; compute released = ~curr & prev
  LDA joy1_curr
  EOR #$FF
  STA tmp_shift
  LDA joy1_prev
  AND tmp_shift
  STA joy1_released
  RTS

; Basic controls helpers
ControlsInit:
  LDA #$00
  STA $4016
  RTS