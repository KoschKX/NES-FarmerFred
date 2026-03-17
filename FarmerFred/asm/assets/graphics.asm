  attributes:
; Load 64 bytes of attributes from attributes table

LoadAttributes:
  LDA PPU_STATUS
  LDA #$23
  STA PPU_ADDR
  LDA #$C0
  STA PPU_ADDR
  LDX #$00
@ALoopLoad:
    LDA attributes, x
    STA PPU_DATA
    INX
    CPX #$40
    BNE @ALoopLoad
  LDA #$01
  STA attributesLoadedFromLevel
  RTS

; Load 1KB background data from pointerBackgroundLowByte/HighByte into $2000 (nametable 0)
LoadBackground:
  LDA PPU_STATUS
  LDA #$20
  STA PPU_ADDR
  LDA #$00
  STA PPU_ADDR
  LDX #$00
  LDY #$00
@Loop0:
    LDA (pointerBackgroundLowByte), y
    STA PPU_DATA
    INY
    CPY #$00
    BNE @Loop0
    INC pointerBackgroundHighByte
    INX
    CPX #$04
    BNE @Loop0
  RTS

; Process background: set pointers, load palettes/attributes if present, else use defaults
ProcessBackground:
  LDA #<(level_001)
  STA pointerBackgroundLowByte
  LDA #>(level_001)
  STA pointerBackgroundHighByte
  LDA #<(level_001)
  STA levelBaseLow
  LDA #>(level_001)
  STA levelBaseHigh
  LDA level_001_len_high
  CMP #$04
  BCS @UseRawBackground

@clear_attr_main
  LDA #$00
  STA attr_accum, x
  INX
  CPX #$40
  BNE @clear_attr_main

  LDY #$00
  LDA (pointerBackgroundLowByte), y  ; peek first palette byte
  CMP #$40
  BCS @NoPalettesInStream
  JSR LoadPalettesFromPointer
  LDA #$01
  STA paletteLoadedFromLevel
  ; advance pointer by 16 to point at attributes
  LDA pointerBackgroundLowByte
  CLC
  ADC #$10
  STA pointerBackgroundLowByte
  LDA pointerBackgroundHighByte
  ADC #$00
  STA pointerBackgroundHighByte
  JSR LoadAttributesFromPointer
  JMP @AfterLoadDone
@NoPalettesInStream:
  LDA #$00
  STA paletteLoadedFromLevel
@NoAttributesInStream:
  JSR WriteAttributesAll
  JMP @AfterLoadDone
@AfterLoadDone:
  JMP @AfterLoad
@UseRawBackground:
  JSR LoadPointerBackground
@AfterLoad:
  ; Load level-provided background palettes (only first 16 bytes — BG palettes)
    LDA paletteLoadedFromLevel   ; explicit test — avoids depending on stale Z
    BEQ @SkipPalettePointerSet
    LDA #<(level_001 + $0400)
    STA pointerBackgroundLowByte
    LDA #>(level_001 + $0400)
    STA pointerBackgroundHighByte
@SkipPalettePointerSet:
    LDY #$00
    LDA (pointerBackgroundLowByte), y  ; peek first palette byte
    CMP #$40
    BCS @UseDefaultPalettes
    JSR LoadPalettesFromPointer
    LDA #$01
    STA paletteLoadedFromLevel
    JMP @PalDone
  @UseDefaultPalettes:
    JSR LoadPalettes
    LDA #$00
    STA paletteLoadedFromLevel
  @PalDone:
    LDA #<(level_001 + $03C0)
    STA pointerBackgroundLowByte
    LDA #>(level_001 + $03C0)
    STA pointerBackgroundHighByte
    JSR LoadAttributesFromPointer
    JMP @AttrDone

  @UseDefaultAttributes:
    JSR LoadAttributes
  @AttrDone:
    JSR UploadPalettes
    LDA attributesLoadedFromLevel
    CMP #$01
    BEQ @SkipUploadAttributes
    JSR UploadAttributes
@SkipUploadAttributes:
   LDA #$78
   RTS

  ; graphics.asm (refactored)



  ; Load 32-byte palette (BG + sprite)
  LoadPalettes:
    LDA PPU_STATUS
    LDA #$3F
    STA PPU_ADDR
    LDA #$00
    STA PPU_ADDR
    LDX #$00
    LDY #$00
  @PalLoop:
      LDA palettes, y
      STA PPU_DATA
      INY
      CPY #$20
      BNE @PalLoop
    RTS

  ; Load 16 bytes of BG palettes from pointer
  LoadPalettesFromPointer:
    LDA PPU_STATUS
    LDA #$3F
    STA PPU_ADDR
    LDA #$00
    STA PPU_ADDR
    LDY #$00
  @PLoop:
      LDA (pointerBackgroundLowByte), y
      STA PPU_DATA
      INY
      CPY #$10
      BNE @PLoop
    RTS

  ; Load 16 bytes of sprite palettes from palettes table
  LoadSpritePalettes:
    LDA PPU_STATUS
    LDA #$3F
    STA PPU_ADDR
    LDA #$10
    STA PPU_ADDR
    LDX #$10
    LDY #$00
  @SLoop:
      LDA palettes, x
      STA PPU_DATA
      INX
      CPX #$20
      BNE @SLoop
    RTS

  ; Load 64 bytes of attributes from pointer
  LoadAttributesFromPointer:
    LDA PPU_STATUS
    LDA #$23
    STA PPU_ADDR
    LDA #$C0
    STA PPU_ADDR
    LDY #$00
  @ALoopPtr:
      LDA (pointerBackgroundLowByte), y
      STA PPU_DATA
      INY
      CPY #$40
      BNE @ALoopPtr
    LDA #$01
    STA attributesLoadedFromLevel
    RTS

  ; Clear the attribute buffer (64 bytes)
  ClearAttrBuffer:
    LDY #$00
  @ClrLoopA:
      LDA #$00
      STA Attribute_Buffer, y
      INY
      CPY #$40
      BNE @ClrLoopA
    RTS

  ; Upload attributes from Attribute_Buffer to PPU at $23C0
  UploadAttributes:
    LDA PPU_STATUS
    LDA #$23
    STA PPU_ADDR
    LDA #$C0
    STA PPU_ADDR
    LDY #$00
  @UALoopA:
      LDA Attribute_Buffer, y
      STA PPU_DATA
      INY
      CPY #$40
      BNE @UALoopA
    RTS

  ; Write per-nametable attribute blocks from level.map into PPU.
  ; Hardcoded attribute tables for both nametables.
  ; NT0 covers world tile rows 0-29 ($2000 / $23C0).
  ; NT1 covers world tile rows 30-59 ($2800 / $2BC0).
  ; With horizontal mirroring: $23C0=$27C0, $2BC0=$2FC0.
  ; Derived from map/level.map tile data:
  ;   $D0-$DF (surface) -> palette 3
  ;   $E0-$EF (body)    -> palette 2
  ;   $00     (sky)     -> palette 0
  attrs_NT0:
    ; Platforms rotate to any column, so ALL 8 bytes per attr row are uniform.
    ;   $AF = top=pal3 (plant+grass), bottom=pal2 (body)
    ;   $F0 = top=pal0 (sky),         bottom=pal3 (plant+grass)
    ;   $0A = top=pal2 (body),         bottom=pal0 (sky)
    ;   $0F = top=pal3 (plant+grass),  bottom=pal0 (unused NT boundary)
    .db $00,$00,$00,$00,$00,$00,$00,$00  ; attr row 0: tile rows  0- 3 (sky)
    .db $00,$00,$00,$00,$00,$00,$00,$00  ; attr row 1: tile rows  4- 7 (sky)
    .db $AF,$AF,$AF,$AF,$AF,$AF,$AF,$AF  ; attr row 2: tile rows  8-11 (pair1: plant+grass / body)
    .db $00,$00,$00,$00,$00,$00,$00,$00  ; attr row 3: tile rows 12-15 (sky)
    .db $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0  ; attr row 4: tile rows 16-19 (sky / pair2: plant+grass)
    .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ; attr row 5: tile rows 20-23 (pair2: body / sky)
    .db $00,$00,$00,$00,$00,$00,$00,$00  ; attr row 6: tile rows 24-27 (sky)
    .db $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F  ; attr row 7: tile rows 28-29 (pair3: plant+grass / unused)

  attrs_NT1:
    ; Same principle as NT0: uniform palette per attr row for rotated platforms.
    .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ; attr row 0: world rows 30-33 (pair3: body / sky)
    .db $00,$00,$00,$00,$00,$00,$00,$00  ; attr row 1: world rows 34-37 (sky)
    .db $AF,$AF,$AF,$AF,$AF,$AF,$AF,$AF  ; attr row 2: world rows 38-41 (pair4: plant+grass / body)
    .db $00,$00,$00,$00,$00,$00,$00,$00  ; attr row 3: world rows 42-45 (sky)
    .db $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0  ; attr row 4: world rows 46-49 (sky / pair5: plant+grass)
    .db $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A  ; attr row 5: world rows 50-53 (pair5: body / sky)
    .db $00,$00,$00,$00,$00,$00,$00,$00  ; attr row 6: world rows 54-57 (sky)
    .db $00,$00,$00,$00,$00,$00,$00,$00  ; attr row 7: world rows 58-59 (solid floor)

  WriteAttributesDual:
    ; Point sourceLow/sourceHigh at attrs_NT0, write 64 bytes to PPU $23C0
    LDA #<(attrs_NT0)
    STA sourceLow
    LDA #>(attrs_NT0)
    STA sourceHigh
    LDA PPU_STATUS
    LDA #$23
    STA $2006
    LDA #$C0
    STA $2006
    LDY #$00
  @WDLoop1:
      LDA (sourceLow), y
      STA $2007
      INY
      CPY #$40
      BNE @WDLoop1
    ; Point at attrs_NT1, write 64 bytes to PPU $2BC0
    LDA #<(attrs_NT1)
    STA sourceLow
    LDA #>(attrs_NT1)
    STA sourceHigh
    LDA PPU_STATUS
    LDA #$2B
    STA $2006
    LDA #$C0
    STA $2006
    LDY #$00
  @WDLoop2:
      LDA (sourceLow), y
      STA $2007
      INY
      CPY #$40
      BNE @WDLoop2
    RTS

  ; Write 64-byte attr_accum to all four nametable attribute tables
  WriteAttributesAll:
    LDA PPU_STATUS
    LDA #$23
    STA PPU_ADDR
    LDA #$C0
    STA PPU_ADDR
    LDY #$00
  @WLoop1:
      LDA attr_accum, y
      STA PPU_DATA
      INY
      CPY #$40
      BNE @WLoop1
    LDA PPU_STATUS
    LDA #$27
    STA PPU_ADDR
    LDA #$C0
    STA PPU_ADDR
    LDY #$00
  @WLoop2:
      LDA attr_accum, y
      STA PPU_DATA
      INY
      CPY #$40
      BNE @WLoop2
    LDA PPU_STATUS
    LDA #$2B
    STA PPU_ADDR
    LDA #$C0
    STA PPU_ADDR
    LDY #$00
  @WLoop3:
      LDA attr_accum, y
      STA PPU_DATA
      INY
      CPY #$40
      BNE @WLoop3
    LDA PPU_STATUS
    LDA #$2F
    STA PPU_ADDR
    LDA #$C0
    STA PPU_ADDR
    LDY #$00
  @WLoop4:
      LDA attr_accum, y
      STA PPU_DATA
      INY
      CPY #$40
      BNE @WLoop4
    RTS

  ; Load VRAM using pointerBackgroundLowByte/HighByte (256 bytes)
  LoadPointerBackground:
    LDA PPU_STATUS
    LDA #$20
    STA PPU_ADDR
    LDA #$00
    STA PPU_ADDR
    LDX #$00
    LDY #$00
  @PLoop:
      LDA (pointerBackgroundLowByte), y
      STA PPU_DATA
      INY
      CPY #$00
      BNE @PLoop
      INC pointerBackgroundHighByte
      INX
      CPX #$04
      BNE @PLoop
    ; Reset pointer to start of level data for nametable B write
    LDA pointerBackgroundHighByte
    SEC
    SBC #$04
    STA pointerBackgroundHighByte
    ; Write same data to nametable B ($2800) for vertical scroll support
    LDA PPU_STATUS
    LDA #$28
    STA PPU_ADDR
    LDA #$00
    STA PPU_ADDR
    LDX #$00
    LDY #$00
  @PLoopB:
      LDA (pointerBackgroundLowByte), y
      STA PPU_DATA
      INY
      CPY #$00
      BNE @PLoopB
      INC pointerBackgroundHighByte
      INX
      CPX #$04
      BNE @PLoopB
    RTS