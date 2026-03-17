; randomizer.asm
; Galois LFSR random number generator + per-row platform shift table helpers.
;
; row_shifts[row%86] stores the horizontal tile rotation (0-31) for that world row.
; Going up  (entering_top):  GenRandomShiftForRow writes a new value before streaming.
; Going down (entering_bottom / Rebuild*):  streaming code reads the stored value.

; GetRandom -- advance LFSR; return next byte in A.
GetRandom:
  LDA lfsr_state
  BNE @gr_notZero
  LDA #$AC            ; re-seed if state has somehow reached 0
  STA lfsr_state
@gr_notZero:
  ; Galois LFSR tap (poly $B8)
  LSR A
  BCC @gr_nofeed
  EOR #$B8
@gr_nofeed:
  STA lfsr_state
  EOR frameCounter    ; additional entropy from timing
  RTS

; GenRandomShiftForRow -- generate and store a new 0-31 shift for world row A.
GenRandomShiftForRow:
  PHA                 ; save virtual row
  AND #$FE            ; pair rows share same shift
  ; (row & ~1) % 86
  CMP #86
  BCC @grs_mod_ok
  SEC
  SBC #86
  CMP #86
  BCC @grs_mod_ok
  SEC
  SBC #86
@grs_mod_ok:
  TAX                 ; X = even row index in row_shifts[]
  JSR GetRandom
  AND #$1F            ; clamp to 0..31
  STA row_shifts, X   ; even row slot
  INX                 ; X = odd row slot
  CPX #86
  BCC @grs_store_odd
  LDX #0
@grs_store_odd:
  STA row_shifts, X   ; same shift for the odd partner row (platform pair stays aligned)
  PLA                 ; restore virtual row
  RTS
