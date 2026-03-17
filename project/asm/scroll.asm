
; scroll.asm
; camera row-streaming for level.map

Scroll:

  ; rowIndex = (camera_y_high*32) | (camera_y>>3)
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
  STA rowIndex

  LDA rowIndex
  CMP lastRowIndex
  BNE do_stream
  JMP skip_stream

do_stream:
  ; delta = rowIndex - lastRowIndex
  LDA rowIndex
  SEC
  SBC lastRowIndex
  STA tmp_shift

  ; [1..4]=down, [252..255]=up, [5..251]=wrap
  CMP #5
  BCC @stream_normal
  CMP #252
  BCS @stream_normal
  ; large delta = level wrap
  LDA #$00
  STA plant_pending_flag
  LDA rowIndex
  STA lastRowIndex
  JMP skip_stream

@stream_normal:
  LDA tmp_shift
  BMI @entering_top

@entering_bottom:
  ; all rows pre-loaded; PPU scroll handles visual scrolling
  JMP @stream_done

@entering_top:
  ; all rows pre-loaded; no VRAM writes needed here
  JMP @stream_done

; (entering_bottom and entering_top always jump to @stream_done)
@stream_done:
  LDA rowIndex
  STA lastRowIndex

skip_stream:
  RTS

WriteWorldRow:
  STA tmp_shift

  ; VRAM slot = vrow % 60
  CMP #60
  BCC @wwr_slot_lt60
  SEC
  SBC #60
@wwr_slot_lt60:
  CMP #30
  BCC @wwr_slot_lt30
  SEC
  SBC #30
  STA vram_row
  LDA #$01
  STA stream_row
  JMP @wwr_slot_done
@wwr_slot_lt30:
  STA vram_row
  LDA #$00
  STA stream_row
@wwr_slot_done:

  LDA vram_row
  AND #$07
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  STA tmp_low
  LDA vram_row
  LSR A
  LSR A
  LSR A
  STA tmp_high
  LDA stream_row
  ASL A
  ASL A
  ASL A
  CLC
  ADC #$20
  CLC
  ADC tmp_high
  STA pageVar
  LDA tmp_low
  STA pageOffsetVar

  LDA $2002
  LDA pageVar
  STA $2006
  LDA pageOffsetVar
  STA $2006

  LDA tmp_shift
  CMP #60
  BCC @wwr_mod60_ok
  SEC
  SBC #60
@wwr_mod60_ok:
  STA tmp_col
  AND #$07
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  STA tmp_low
  LDA tmp_col
  LSR A
  LSR A
  LSR A
  STA tmp_high
  LDA tmp_low
  CLC
  ADC #<(columnData)
  STA sourceLow
  LDA tmp_high
  ADC #>(columnData)
  STA sourceHigh

  ; per-pair rotation: Y = start offset (0..31)
  LDY tmp_pal
  LDX #$20
@wwr_batch:
  LDA (sourceLow), Y
  STA $2007
  INY
  TYA
  AND #$1F              ; wrap Y within 0..31
  TAY
  DEX
  BNE @wwr_batch

  ; attrs: source=attrs_NT0/1 + (vram_row/4)*8
  LDA vram_row
  LSR A
  LSR A
  ASL A
  ASL A
  ASL A            ; (vram_row/4)*8
  STA tmp_low
  LDA stream_row
  BNE @wwr_src_nt1
  LDA #<(attrs_NT0)
  CLC
  ADC tmp_low
  STA sourceLow
  LDA #>(attrs_NT0)
  ADC #0
  STA sourceHigh
  JMP @wwr_attr_dest
@wwr_src_nt1:
  LDA #<(attrs_NT1)
  CLC
  ADC tmp_low
  STA sourceLow
  LDA #>(attrs_NT1)
  ADC #0
  STA sourceHigh
@wwr_attr_dest:
  LDA tmp_low
  CLC
  ADC #$C0
  STA pageOffsetVar
  LDA stream_row
  ASL A
  ASL A
  ASL A
  CLC
  ADC #$23
  STA pageVar

  LDA $2002
  LDA pageVar
  STA $2006
  LDA pageOffsetVar
  STA $2006
  LDY #$00
@wwr_attr:
  LDA (sourceLow), Y
  STA $2007
  INY
  CPY #$08
  BNE @wwr_attr
  RTS

; PreloadSecondNametable: copy world rows 30-59 to $2800 at startup
PreloadSecondNametable:
  LDA #<(columnData + 960)
  STA sourceLow
  LDA #>(columnData + 960)
  STA sourceHigh
  LDA $2002
  LDA #$28
  STA $2006
  LDA #$00
  STA $2006
  LDX #$03
  LDY #$00
@psn_full:
  LDA (sourceLow), Y
  STA $2007
  INY
  BNE @psn_full
  INC sourceHigh
  DEX
  BNE @psn_full
  LDY #$00
@psn_tail:
  LDA (sourceLow), Y
  STA $2007
  INY
  CPY #$C0
  BNE @psn_tail
  RTS
