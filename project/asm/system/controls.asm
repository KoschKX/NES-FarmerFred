; Generic controller reader: fills joy1_* zero-page mirrors
; Sets: joy1_prev, joy1_curr, joy1_pressed, joy1_released
; Bit layout: A=$80 B=$40 Sel=$20 Start=$10 Up=$08 Down=$04 Left=$02 Right=$01

ReadControllers:
  ; save previous
  LDA joy1_curr
  STA joy1_prev

  ; clear current mirror and carry
  LDA #$00
  STA joy1_curr

  ; strobe controller
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016

  ; Read 8 bits via LSR→carry→ROL: branchless, constant-time (~88 cycles)
  ; Controller sends buttons in order: A, B, Select, Start, Up, Down, Left, Right
  ; Each bit 0 from $4016 is shifted into carry via LSR, then rotated into joy1_curr
  LDA $4016
  LSR A
  ROL joy1_curr           ; A      → bit 7
  LDA $4016
  LSR A
  ROL joy1_curr           ; B      → bit 6
  LDA $4016
  LSR A
  ROL joy1_curr           ; Select → bit 5
  LDA $4016
  LSR A
  ROL joy1_curr           ; Start  → bit 4
  LDA $4016
  LSR A
  ROL joy1_curr           ; Up     → bit 3
  LDA $4016
  LSR A
  ROL joy1_curr           ; Down   → bit 2
  LDA $4016
  LSR A
  ROL joy1_curr           ; Left   → bit 1
  LDA $4016
  LSR A
  ROL joy1_curr           ; Right  → bit 0

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