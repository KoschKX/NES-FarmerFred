; plants.asm
; Plant tiles ($D0) written above each platform floor row.
;
; WritePlantsForAllPairs -- call once at init, after row_shifts set.
; WritePlantRow          -- call from entering_top after WriteWorldRow.

; Platform top VRAM slot numbers — pairs 1..5 (pair 0 = top platform, no plants; solid floor = skip).
plant_top_slots:
  .db 9, 19, 29, 39, 49

; Bit-mask lookup for removal bitfield (indexed by col & 7)
plant_bit_masks:
  .db $01, $02, $04, $08, $10, $20, $40, $80

; Base byte offset into plant_removed_bits for each plant pair (pair_index * 4)
plant_removal_base:
  .db 0, 4, 8, 12, 16

; WritePlantsForAllPairs
;   Call in forced blank after all row_shifts are populated.
WritePlantsForAllPairs:
  JSR ClearPlantRemovedBits
  LDX #0
@wpfa_loop:
  LDA plant_top_slots, X
  STA tmp_qx
  TXA
  PHA                        ; save loop index — core clobbers X
  LDX tmp_qx
  LDA $02A1, X               ; row_shifts(slot) = rotation for this pair
  STA tmp_pal
  JSR WritePlantRowCore
  PLA
  TAX
  INX
  CPX #5
  BNE @wpfa_loop
  RTS

; WritePlantRow
;   Called from scroll.asm @et_write after WriteWorldRow.
;   In:  tmp_qx = VRAM slot, tmp_pal = rotation.
;   No-op if tmp_qx is not a plant slot.
WritePlantRow:
  LDA tmp_qx
  LDX #4
@wpr_search:
  CMP plant_top_slots, X
  BEQ @wpr_found
  DEX
  BPL @wpr_search
  RTS                        ; not a plant slot — no-op

@wpr_found:
  ; Compute removal base: pair_index * 4
  TXA
  ASL A
  ASL A
  STA tmp_mul
  ; tmp_qx and tmp_pal are already correct — fall into WritePlantRowCore.

; WritePlantRowCore
;   In:  tmp_qx  = VRAM slot (one of 9, 19, 29, 39, 49).
;        tmp_pal = rotation offset (0..31).
WritePlantRowCore:

  ; Source pointer: columnData + tmp_qx * 32
  ;     offset_high = tmp_qx >> 3
  ;     offset_low  = (tmp_qx & 7) << 5
  LDA tmp_qx
  LSR A
  LSR A
  LSR A
  STA tmp_shift              ; high byte of offset
  LDA tmp_qx
  AND #$07
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A                      ; low byte of offset
  CLC
  ADC #<(columnData)
  STA sourceLow
  LDA tmp_shift
  ADC #>(columnData)      ; carry from sourceLow included
  STA sourceHigh

  ; VRAM destination: plant_row = tmp_qx - 1
  LDA tmp_qx
  SEC
  SBC #1
  STA tmp_shift              ; save plant_row for NT calculation

  CMP #30
  BCC @wprc_nt0

@wprc_nt1:
  ; plant_row in 30..58 → NT1.  local_row = plant_row - 30
  SEC
  SBC #30
  STA tmp_low
  AND #$07
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A                      ; (local_row & 7) << 5
  STA tmp_high               ; PPU addr low byte
  LDA tmp_low
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$28                   ; $28 + (local_row >> 3) = PPU addr high byte
  JMP @wprc_open

@wprc_nt0:
  ; plant_row in 0..29 → NT0
  STA tmp_low
  AND #$07
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A                      ; (plant_row & 7) << 5
  STA tmp_high               ; PPU addr low byte
  LDA tmp_low
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$20                   ; $20 + (plant_row >> 3) = PPU addr high byte

@wprc_open:
  ; A = PPU addr high, tmp_high = PPU addr low.  Reset latch and write.
  PHA
  LDA $2002
  PLA
  STA $2006
  LDA tmp_high
  STA $2006

  ; write 32 tiles; Y=rotation, X=col, tmp_shift=LFSR, tmp_qy=gap cooldown
  LDY #$04
@wprc_find_pair:
  LDA tmp_qx
  CMP plant_top_slots, Y
  BEQ @wprc_pair_found
  DEY
  BPL @wprc_find_pair
  LDY #$00               ; fallback (should never happen)
@wprc_pair_found:
  LDA plant_removal_base, Y
  STA tmp_mul            ; base offset into plant_removed_bits

  LDA tmp_pal
  BNE @wprc_seed_ok
  LDA #$AC               ; LFSR must be non-zero
@wprc_seed_ok:
  STA tmp_shift
  LDA #$00
  STA tmp_qy             ; gap counter = 0
  LDY tmp_pal
  LDX #$00

@wprc_col:
  LSR tmp_shift
  BCC @wprc_lfsr_done
  LDA tmp_shift
  EOR #$B8
  STA tmp_shift
@wprc_lfsr_done:
  ; Check floor tile
  LDA (sourceLow), Y
  CMP #$E0
  BCC @wprc_empty
  CMP #$E9               ; one past top of floor tile range
  BCS @wprc_empty
  ; Floor confirmed — check gap cooldown
  LDA tmp_qy
  BNE @wprc_gap_dec      ; gap still active — no plant this column
  ; Gap expired — allow plant if low 2 LFSR bits clear (~1/4)
  LDA tmp_shift
  AND #$03
  BNE @wprc_empty
  ; Skip edge columns — player grab probe can't reach col 0 or col 31
  TXA
  BEQ @wprc_empty        ; col 0 = left pixel edge
  CMP #$1F
  BEQ @wprc_empty        ; col 31 = right pixel edge
  ; Check if plant was removed by player
  STX tmp_ptr            ; save output column X
  TYA
  PHA                    ; save rotation Y
  LDA tmp_ptr            ; column
  LSR A
  LSR A
  LSR A                  ; column >> 3 (0..3)
  CLC
  ADC tmp_mul            ; + row base offset
  TAY                    ; Y = byte index into plant_removed_bits
  LDA tmp_ptr            ; column
  AND #$07
  TAX                    ; X = bit index (0..7)
  LDA plant_bit_masks, X
  AND plant_removed_bits, Y
  STA tmp_ptr+1          ; save result (non-zero = removed)
  PLA
  TAY                    ; restore rotation Y
  LDX tmp_ptr            ; restore output column X
  LDA tmp_ptr+1
  BNE @wprc_empty        ; removed → skip this plant
  ; Plant not removed — emit it
  LDA #$04               ; block next 4 columns
  STA tmp_qy
  ; Use bits 2-3 of LFSR for tile variety ($D0/$D1/$D2)
  LDA tmp_shift
  LSR A
  LSR A
  AND #$03
  CMP #$03
  BNE @plant_tile_ok
  LDA #$02
@plant_tile_ok:
  ORA #$D0
  JMP @wprc_emit
@wprc_gap_dec:
  DEC tmp_qy
@wprc_empty:
  ; Mark this column as having no plant so the grab code doesn't
  ; allow grabs at positions where no plant was ever written.
  ; X = output column, Y = rotation (both preserved after).
  STX tmp_ptr        ; save column
  STY tmp_ptr+1      ; save rotation Y
  TXA
  LSR A
  LSR A
  LSR A              ; column >> 3
  CLC
  ADC tmp_mul        ; + row base offset
  TAY                ; Y = byte index into plant_removed_bits
  LDA tmp_ptr        ; column
  AND #$07
  TAX                ; X = bit index
  LDA plant_bit_masks, X
  ORA plant_removed_bits, Y
  STA plant_removed_bits, Y
  LDX tmp_ptr        ; restore column
  LDY tmp_ptr+1      ; restore rotation
  LDA #$00
@wprc_emit:
  STA $2007
  INY
  TYA
  AND #$1F
  TAY                    ; Y = (Y + 1) & 31  (wrap rotation)
  INX
  CPX #$20
  BEQ @wprc_done
  JMP @wprc_col
@wprc_done:
  RTS

; ReRandomizePlatforms
;   Randomize all 5 platform pairs and rewrite their VRAM rows.
;   Call in forced blank BEFORE WritePlantsForAllPairs.

; Pair bottom rows (top_slot + 1 for each pair)
plant_bottom_slots:
  .db 10, 20, 30, 40, 50

ReRandomizePlatforms:
  LDX #$00
@rrp_loop:
  TXA
  PHA                        ; save pair index

  ; Step LFSR to get a new shift
  LDA $02A0
  BNE @rrp_lfsr_ok
  LDA #$AC                   ; reseed if zero
@rrp_lfsr_ok:
  LSR A
  BCC @rrp_lfsr_done
  EOR #$B8
@rrp_lfsr_done:
  STA $02A0
  AND #$1F                   ; clamp to 0..31
  STA tmp_pal                ; new rotation for this pair

  ; Update row_shifts for top row
  PLA
  PHA                        ; peek pair index
  TAX
  LDA plant_top_slots, X
  TAY
  LDA tmp_pal
  STA $02A1, Y               ; row_shifts(top_slot) = new shift

  ; Update row_shifts for bottom row
  LDA plant_bottom_slots, X
  TAY
  LDA tmp_pal
  STA $02A1, Y               ; row_shifts(bottom_slot) = new shift

  ; Rewrite VRAM: top row
  LDA plant_top_slots, X
  JSR WriteWorldRow           ; A = row, tmp_pal = rotation

  ; Rewrite VRAM: bottom row (tmp_pal still set)
  PLA
  PHA                        ; peek pair index
  TAX
  LDA plant_bottom_slots, X
  JSR WriteWorldRow

  PLA
  TAX
  INX
  CPX #$05
  BNE @rrp_loop
  RTS
