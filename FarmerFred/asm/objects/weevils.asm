; weevils.asm -- Walking weevil enemy system (two weevils)
;
; OAM layout -- 6 sprites per weevil (3 cols x 2 rows):
;   Weevil 0  $0354-$036B  (OAM slots 21-26)
;   Weevil 1  $036C-$0383  (OAM slots 27-32)
;
; CHR frame tiles:
;   Frame 0: top $90 $91 $92  /  bot $A0 $A1 $A2
;   Frame 1: top $93 $94 $95  /  bot $A3 $A4 $A5
;   Frame 2: top $96 $97 $98  /  bot $A6 $A7 $A8
;
; Stun: V-flip + swapped rows (upside-down pose).

WEEVIL_STUN_FRAMES   = 180

WEEVIL_STUN_TOP_BASE = $A0   ; bot walk tiles, drawn at top Y with V-flip
WEEVIL_STUN_BOT_BASE = $90   ; top walk tiles, drawn at bot Y with V-flip

ATTR_NORMAL = $00
ATTR_HFLIP  = $40
ATTR_VFLIP  = $80

; Read-only tables

; Ping-pong anim:  index = (frameCounter >> 3) & 3
weevil_anim_top:
  .db $90, $93, $96, $93
weevil_anim_bot:
  .db $A0, $A3, $A6, $A3

; Fly anim (2-frame toggle): index = (frameCounter >> 2) & 1
;   Frame 0: top $99 $9A $9B  /  bot $A9 $AA $AB
;   Frame 1: top $9C $9D $9E  /  bot $AC $AD $AE
weevil_fly_top:
  .db $99, $9C
weevil_fly_bot:
  .db $A9, $AC

; Platform walking surface tile rows
weevil_plat_rows:
  .db 9, 19, 29, 39, 49

; 16-bit world Y for each platform surface  (tile_row * 8)
weevil_plat_yl:
  .db $48, $98, $E8, $38, $88
weevil_plat_yh:
  .db $00, $00, $00, $01, $01


; InitWeevils
InitWeevils:
  LDA #$FE
  STA $0354
  STA $0358
  STA $035C
  STA $0360
  STA $0364
  STA $0368
  STA $036C
  STA $0370
  STA $0374
  STA $0378
  STA $037C
  STA $0380

  JSR WeevilRandPlat
  STA weevil0_plat
  TAX
  LDA weevil_plat_yl, X
  STA weevil0_yl
  LDA weevil_plat_yh, X
  STA weevil0_yh
  LDA #$60
  STA weevil0_x
  ; Snap to first solid tile on this platform row (shift may have moved tiles)
  LDX weevil0_plat
  LDA weevil_plat_rows, X
  STA tile_row
  LDA #$0C              ; starting tile col = $60 >> 3
  STA tile_col
  LDA #30               ; max 30 tiles to scan
  STA tmp_high
@iw_snap0:
  JSR CFS_GetTileByColRow
  LDA TileID
  TAY
  LDA collision_table, Y
  BNE @iw_snap0_done
  INC tile_col
  LDA tile_col
  CMP #30
  BCC @iw_snap0_next
  LDA #$00
  STA tile_col
@iw_snap0_next:
  DEC tmp_high
  BNE @iw_snap0
@iw_snap0_done:
  LDA tile_col
  ASL A
  ASL A
  ASL A
  STA weevil0_x
  LDA #$00
  STA weevil0_dir
  STA weevil0_stun
  LDA #$01
  STA weevil0_state

@iw_pick1:
  JSR WeevilRandPlat
  CMP weevil0_plat
  BEQ @iw_pick1
  STA weevil1_plat
  TAX
  LDA weevil_plat_yl, X
  STA weevil1_yl
  LDA weevil_plat_yh, X
  STA weevil1_yh
  LDA #$A0
  STA weevil1_x
  ; Snap to first solid tile on this platform row
  LDX weevil1_plat
  LDA weevil_plat_rows, X
  STA tile_row
  LDA #$14              ; starting tile col = $A0 >> 3
  STA tile_col
  LDA #30
  STA tmp_high
@iw_snap1:
  JSR CFS_GetTileByColRow
  LDA TileID
  TAY
  LDA collision_table, Y
  BNE @iw_snap1_done
  INC tile_col
  LDA tile_col
  CMP #30
  BCC @iw_snap1_next
  LDA #$00
  STA tile_col
@iw_snap1_next:
  DEC tmp_high
  BNE @iw_snap1
@iw_snap1_done:
  LDA tile_col
  ASL A
  ASL A
  ASL A
  STA weevil1_x
  LDA #$01
  STA weevil1_dir
  LDA #$00
  STA weevil1_stun
  LDA #$01
  STA weevil1_state
  RTS

WeevilRandPlat:
  LSR lfsr_state
  BCC @wrp_no_tap
  LDA lfsr_state
  EOR #$B8
  STA lfsr_state
@wrp_no_tap:
  LDA lfsr_state
  AND #$07
  CMP #$05
  BCS WeevilRandPlat
  RTS


; UpdateWeevils
UpdateWeevils:
  ; Slow anim (normal): one step every 4 frames  (frameCounter >> 2)
  ; Fast anim (same platform): one step every 2 frames  (frameCounter >> 1)
  LDA frameCounter
  LSR A
  LSR A
  AND #$03
  TAX
  LDA weevil_anim_top, X
  STA tmp_shift
  LDA weevil_anim_bot, X
  STA tmp_pal
  LDA frameCounter
  LSR A
  AND #$03
  TAX
  LDA weevil_anim_top, X
  STA tmp_qx
  LDA weevil_anim_bot, X
  STA tmp_qy

  ; WEEVIL 0
  LDA weevil0_state
  BNE @uw_w0_active
  JMP @uw_do_w1

@uw_w0_active:
  SEC
  LDA weevil0_yl
  SBC camera_y
  STA tmp_low
  LDA weevil0_yh
  SBC camera_y_high       ; high byte of signed 16-bit screen Y
  BMI @uw_w0_wrap         ; negative: may need level-height unwrap
  BNE @uw_w0_hide         ; positive high byte: off bottom of screen
  LDA tmp_low
  CMP #$F0
  BCS @uw_w0_hide
  JMP @uw_w0_update
@uw_w0_wrap:
  ; Add level height (480 = $01E0) to convert wrapped negative screen Y
  STA tmp_high
  LDA tmp_low
  CLC
  ADC #$E0
  STA tmp_low
  LDA tmp_high
  ADC #$01
  BMI @uw_w0_hide         ; still negative after unwrap: above screen
  BNE @uw_w0_hide         ; high byte > 0 after unwrap: below screen
  LDA tmp_low
  CMP #$F0
  BCS @uw_w0_hide
  JMP @uw_w0_update

@uw_w0_hide:
  LDA #$FE
  STA $0354
  STA $0358
  STA $035C
  STA $0360
  STA $0364
  STA $0368
  JMP @uw_do_w1

@uw_w0_update:
  LDA weevil0_state
  CMP #$03
  BNE @uw_w0_walk
  LDA weevil0_stun
  BEQ @uw_w0_unstun
  DEC weevil0_stun
  JMP @uw_w0_draw
@uw_w0_unstun:
  LDA #$01
  STA weevil0_state
  JMP @uw_w0_draw

@uw_w0_walk:
  LDA player_plat_row
  LDX weevil0_plat
  CMP weevil_plat_rows, X
  BEQ @uw_w0_fast
  ; Slow: 1 px every 2 frames
  LDA frameCounter
  AND #$01
  BEQ @uw_w0_slow_move
  LDA #$00
  JMP @uw_w0_move
@uw_w0_slow_move:
  LDA #$01
  JMP @uw_w0_move
@uw_w0_fast:
  ; Fast: switch to fast animation tiles, move 2 px/frame
  LDA tmp_qx
  STA tmp_shift
  LDA tmp_qy
  STA tmp_pal
  LDA #$02
@uw_w0_move:
  STA tmp_high
  LDA weevil0_dir
  BNE @uw_w0_go_left
  JSR WeevilProbeRight0
  LDA weevil0_dir
  BNE @uw_w0_draw
  CLC
  LDA weevil0_x
  ADC tmp_high
  STA weevil0_x
  JMP @uw_w0_draw
@uw_w0_go_left:
  JSR WeevilProbeLeft0
  LDA weevil0_dir
  BEQ @uw_w0_draw
  SEC
  LDA weevil0_x
  SBC tmp_high
  STA weevil0_x

@uw_w0_draw:
  ; Top row OAM Y = feet_y - 16;  bot row OAM Y = feet_y - 8
  SEC
  LDA tmp_low
  SBC #$10
  STA tmp_high
  SEC
  LDA tmp_low
  SBC #$08
  STA tmp_low

  LDA weevil0_state
  CMP #$03
  BNE @uw_w0_not_stun
  JMP @uw_w0_stun_draw
@uw_w0_not_stun:

  ; fly flag: 0 walk, 1 fly
  LDA #$00
  STA tmp_qx
  ; fly only when on same platform as player
  LDA player_plat_row
  LDX weevil0_plat
  CMP weevil_plat_rows, X
  BNE @uw_w0_end_fly    ; different platform: keep walk tiles
  ; Same platform: switch to fly tiles
  LDA frameCounter
  LSR A
  LSR A
  AND #$01
  TAX
  LDA weevil_fly_top, X
  STA tmp_shift
  LDA weevil_fly_bot, X
  STA tmp_pal
  ; Set fly flag and shift up 1 tile (8 px)
  LDA #$01
  STA tmp_qx
  SEC
  LDA tmp_high
  SBC #$08
  STA tmp_high
  SEC
  LDA tmp_low
  SBC #$08
  STA tmp_low
@uw_w0_end_fly:
  ; fly SFX
  LDA tmp_qx
  BEQ @uw_w0_fly_sfx_reset
  LDA sfx_fly_timer0
  BEQ @uw_w0_fly_sfx_fire
  DEC sfx_fly_timer0
  JMP @uw_w0_fly_sfx_done
@uw_w0_fly_sfx_fire:
  LDA #$04
  LDX #FAMISTUDIO_SFX_CH1
  JSR famistudio_sfx_play
  LDA #$14
  STA sfx_fly_timer0
  JMP @uw_w0_fly_sfx_done
@uw_w0_fly_sfx_reset:
  LDA #$00
  STA sfx_fly_timer0
@uw_w0_fly_sfx_done:

  LDA weevil0_dir
  BEQ @uw_w0_not_left
  JMP @uw_w0_left_draw
@uw_w0_not_left:

  ; RIGHT-facing: bottom row always drawn; flicker only top row of back cols
  ; Bot row -- always visible
  LDA tmp_low
  STA $0360
  LDA tmp_pal
  STA $0361
  LDA #ATTR_NORMAL
  STA $0362
  LDA weevil0_x
  STA $0363
  LDA tmp_low
  STA $0364
  LDA tmp_pal
  CLC
  ADC #$01
  STA $0365
  LDA #ATTR_NORMAL
  STA $0366
  LDA weevil0_x
  CLC
  ADC #$08
  STA $0367
  LDA tmp_low
  STA $0368
  LDA tmp_pal
  CLC
  ADC #$02
  STA $0369
  LDA #ATTR_NORMAL
  STA $036A
  LDA weevil0_x
  CLC
  ADC #$10
  STA $036B
  ; Alternate back top tiles when flying: one visible at a time
  LDA tmp_qx
  BEQ @uw_w0r_back_both       ; not flying: show both
  LDA frameCounter
  AND #$01
  BEQ @uw_w0r_show_c0         ; even: show col0, hide col1
  ; Odd: hide col0, show col1
  LDA #$FE
  STA $0354
  LDA tmp_high
  STA $0358
  LDA tmp_shift
  CLC
  ADC #$01
  STA $0359
  LDA #ATTR_NORMAL
  STA $035A
  LDA weevil0_x
  CLC
  ADC #$08
  STA $035B
  JMP @uw_w0r_front
@uw_w0r_show_c0:
  LDA tmp_high
  STA $0354
  LDA tmp_shift
  STA $0355
  LDA #ATTR_NORMAL
  STA $0356
  LDA weevil0_x
  STA $0357
  LDA #$FE
  STA $0358
  JMP @uw_w0r_front
@uw_w0r_back_both:
  ; Not flying: show both back cols
  LDA tmp_high
  STA $0354
  LDA tmp_shift
  STA $0355
  LDA #ATTR_NORMAL
  STA $0356
  LDA weevil0_x
  STA $0357
  LDA tmp_high
  STA $0358
  LDA tmp_shift
  CLC
  ADC #$01
  STA $0359
  LDA #ATTR_NORMAL
  STA $035A
  LDA weevil0_x
  CLC
  ADC #$08
  STA $035B
@uw_w0r_front:
  ; Top col 2 (front, always visible)
  LDA tmp_high
  STA $035C
  LDA tmp_shift
  CLC
  ADC #$02
  STA $035D
  LDA #ATTR_NORMAL
  STA $035E
  LDA weevil0_x
  CLC
  ADC #$10
  STA $035F
  JMP @uw_w0_coll

@uw_w0_left_draw:
  ; LEFT-facing: head at x+0 (tile+2 H-flip). Back cols are x+8 and x+16.
  ; Bottom row -- always visible (all three cols)
  LDA tmp_low
  STA $0360
  LDA tmp_pal
  CLC
  ADC #$02
  STA $0361
  LDA #ATTR_HFLIP
  STA $0362
  LDA weevil0_x
  STA $0363
  LDA tmp_low
  STA $0364
  LDA tmp_pal
  CLC
  ADC #$01
  STA $0365
  LDA #ATTR_HFLIP
  STA $0366
  LDA weevil0_x
  CLC
  ADC #$08
  STA $0367
  LDA tmp_low
  STA $0368
  LDA tmp_pal
  STA $0369
  LDA #ATTR_HFLIP
  STA $036A
  LDA weevil0_x
  CLC
  ADC #$10
  STA $036B
  ; Top row col 0 (front/head) -- always visible
  LDA tmp_high
  STA $0354
  LDA tmp_shift
  CLC
  ADC #$02
  STA $0355
  LDA #ATTR_HFLIP
  STA $0356
  LDA weevil0_x
  STA $0357
  ; Alternate back top tiles when flying: one visible at a time
  LDA tmp_qx
  BEQ @uw_w0l_back_both       ; not flying: show both
  LDA frameCounter
  AND #$01
  BEQ @uw_w0l_show_c1         ; even: show col1, hide col2
  ; Odd: hide col1, show col2
  LDA #$FE
  STA $0358
  LDA tmp_high
  STA $035C
  LDA tmp_shift
  STA $035D
  LDA #ATTR_HFLIP
  STA $035E
  LDA weevil0_x
  CLC
  ADC #$10
  STA $035F
  JMP @uw_w0_coll
@uw_w0l_show_c1:
  LDA tmp_high
  STA $0358
  LDA tmp_shift
  CLC
  ADC #$01
  STA $0359
  LDA #ATTR_HFLIP
  STA $035A
  LDA weevil0_x
  CLC
  ADC #$08
  STA $035B
  LDA #$FE
  STA $035C
  JMP @uw_w0_coll
@uw_w0l_back_both:
  ; Not flying: show both back top cols
  LDA tmp_high
  STA $0358
  LDA tmp_shift
  CLC
  ADC #$01
  STA $0359
  LDA #ATTR_HFLIP
  STA $035A
  LDA weevil0_x
  CLC
  ADC #$08
  STA $035B
  LDA tmp_high
  STA $035C
  LDA tmp_shift
  STA $035D
  LDA #ATTR_HFLIP
  STA $035E
  LDA weevil0_x
  CLC
  ADC #$10
  STA $035F
  JMP @uw_w0_coll

@uw_w0_stun_draw:
  ; Upside-down walk: top row = bot-walk tiles (tmp_pal), bot row = top-walk tiles (tmp_shift)
  ; Both rows use ATTR_VFLIP so the weevil animates while stunned
  LDA tmp_high
  STA $0354
  LDA tmp_pal          ; bot walk tile base (animated)
  STA $0355
  LDA #ATTR_VFLIP
  STA $0356
  LDA weevil0_x
  STA $0357

  LDA tmp_high
  STA $0358
  LDA tmp_pal
  CLC
  ADC #$01
  STA $0359
  LDA #ATTR_VFLIP
  STA $035A
  LDA weevil0_x
  CLC
  ADC #$08
  STA $035B

  LDA tmp_high
  STA $035C
  LDA tmp_pal
  CLC
  ADC #$02
  STA $035D
  LDA #ATTR_VFLIP
  STA $035E
  LDA weevil0_x
  CLC
  ADC #$10
  STA $035F

  LDA tmp_low
  STA $0360
  LDA tmp_shift        ; top walk tile base (animated)
  STA $0361
  LDA #ATTR_VFLIP
  STA $0362
  LDA weevil0_x
  STA $0363

  LDA tmp_low
  STA $0364
  LDA tmp_shift
  CLC
  ADC #$01
  STA $0365
  LDA #ATTR_VFLIP
  STA $0366
  LDA weevil0_x
  CLC
  ADC #$08
  STA $0367

  LDA tmp_low
  STA $0368
  LDA tmp_shift
  CLC
  ADC #$02
  STA $0369
  LDA #ATTR_VFLIP
  STA $036A
  LDA weevil0_x
  CLC
  ADC #$10
  STA $036B

@uw_w0_coll:
  LDA $0360                    ; restore bot Y into tmp_low for collision
  STA tmp_low
  JSR CheckPumpkinWeevil0
  JSR CheckWeevilPlayer0

  ; WEEVIL 1
@uw_do_w1:
  ; Re-load anim bases (tmp_shift/tmp_pal may be clobbered by subroutines)
  LDA frameCounter
  LSR A
  LSR A
  AND #$03
  TAX
  LDA weevil_anim_top, X
  STA tmp_shift
  LDA weevil_anim_bot, X
  STA tmp_pal
  LDA frameCounter
  LSR A
  AND #$03
  TAX
  LDA weevil_anim_top, X
  STA tmp_qx
  LDA weevil_anim_bot, X
  STA tmp_qy

  LDA weevil1_state
  BNE @uw_w1_active
  RTS

@uw_w1_active:
  SEC
  LDA weevil1_yl
  SBC camera_y
  STA tmp_low
  LDA weevil1_yh
  SBC camera_y_high       ; high byte of signed 16-bit screen Y
  BMI @uw_w1_wrap         ; negative: may need level-height unwrap
  BNE @uw_w1_hide         ; positive high byte: off bottom of screen
  LDA tmp_low
  CMP #$F0
  BCS @uw_w1_hide
  JMP @uw_w1_update
@uw_w1_wrap:
  ; Add level height (480 = $01E0) to convert wrapped negative screen Y
  STA tmp_high
  LDA tmp_low
  CLC
  ADC #$E0
  STA tmp_low
  LDA tmp_high
  ADC #$01
  BMI @uw_w1_hide         ; still negative after unwrap: above screen
  BNE @uw_w1_hide         ; high byte > 0 after unwrap: below screen
  LDA tmp_low
  CMP #$F0
  BCS @uw_w1_hide
  JMP @uw_w1_update

@uw_w1_hide:
  LDA #$FE
  STA $036C
  STA $0370
  STA $0374
  STA $0378
  STA $037C
  STA $0380
  RTS

@uw_w1_update:
  LDA weevil1_state
  CMP #$03
  BNE @uw_w1_walk
  LDA weevil1_stun
  BEQ @uw_w1_unstun
  DEC weevil1_stun
  JMP @uw_w1_draw
@uw_w1_unstun:
  LDA #$01
  STA weevil1_state
  JMP @uw_w1_draw

@uw_w1_walk:
  LDA player_plat_row
  LDX weevil1_plat
  CMP weevil_plat_rows, X
  BEQ @uw_w1_fast
  ; Slow: 1 px every 2 frames
  LDA frameCounter
  AND #$01
  BEQ @uw_w1_slow_move
  LDA #$00
  JMP @uw_w1_move
@uw_w1_slow_move:
  LDA #$01
  JMP @uw_w1_move
@uw_w1_fast:
  ; Fast: switch to fast animation tiles, move 2 px/frame
  LDA tmp_qx
  STA tmp_shift
  LDA tmp_qy
  STA tmp_pal
  LDA #$02
@uw_w1_move:
  STA tmp_high
  LDA weevil1_dir
  BNE @uw_w1_go_left
  JSR WeevilProbeRight1
  LDA weevil1_dir
  BNE @uw_w1_draw
  CLC
  LDA weevil1_x
  ADC tmp_high
  STA weevil1_x
  JMP @uw_w1_draw
@uw_w1_go_left:
  JSR WeevilProbeLeft1
  LDA weevil1_dir
  BEQ @uw_w1_draw
  SEC
  LDA weevil1_x
  SBC tmp_high
  STA weevil1_x

@uw_w1_draw:
  SEC
  LDA tmp_low
  SBC #$10
  STA tmp_high
  SEC
  LDA tmp_low
  SBC #$08
  STA tmp_low

  LDA weevil1_state
  CMP #$03
  BNE @uw_w1_not_stun
  JMP @uw_w1_stun_draw
@uw_w1_not_stun:

  ; fly flag: 0 walk, 1 fly
  LDA #$00
  STA tmp_qx
  ; fly only when on same platform as player
  LDA player_plat_row
  LDX weevil1_plat
  CMP weevil_plat_rows, X
  BNE @uw_w1_end_fly
  LDA frameCounter
  LSR A
  LSR A
  AND #$01
  TAX
  LDA weevil_fly_top, X
  STA tmp_shift
  LDA weevil_fly_bot, X
  STA tmp_pal
  ; Set fly flag and shift up 1 tile (8 px)
  LDA #$01
  STA tmp_qx
  SEC
  LDA tmp_high
  SBC #$08
  STA tmp_high
  SEC
  LDA tmp_low
  SBC #$08
  STA tmp_low
@uw_w1_end_fly:
  ; fly SFX
  LDA tmp_qx
  BEQ @uw_w1_fly_sfx_reset
  LDA sfx_fly_timer1
  BEQ @uw_w1_fly_sfx_fire
  DEC sfx_fly_timer1
  JMP @uw_w1_fly_sfx_done
@uw_w1_fly_sfx_fire:
  LDA #$04
  LDX #FAMISTUDIO_SFX_CH1
  JSR famistudio_sfx_play
  LDA #$14
  STA sfx_fly_timer1
  JMP @uw_w1_fly_sfx_done
@uw_w1_fly_sfx_reset:
  LDA #$00
  STA sfx_fly_timer1
@uw_w1_fly_sfx_done:

  LDA weevil1_dir
  BEQ @uw_w1_not_left
  JMP @uw_w1_left_draw
@uw_w1_not_left:

  ; RIGHT-facing: bottom row always drawn; flicker only top row of back cols
  ; Bot row -- always visible
  LDA tmp_low
  STA $0378
  LDA tmp_pal
  STA $0379
  LDA #ATTR_NORMAL
  STA $037A
  LDA weevil1_x
  STA $037B
  LDA tmp_low
  STA $037C
  LDA tmp_pal
  CLC
  ADC #$01
  STA $037D
  LDA #ATTR_NORMAL
  STA $037E
  LDA weevil1_x
  CLC
  ADC #$08
  STA $037F
  LDA tmp_low
  STA $0380
  LDA tmp_pal
  CLC
  ADC #$02
  STA $0381
  LDA #ATTR_NORMAL
  STA $0382
  LDA weevil1_x
  CLC
  ADC #$10
  STA $0383
  ; Alternate back top tiles when flying: one visible at a time
  LDA tmp_qx
  BEQ @uw_w1r_back_both       ; not flying: show both
  LDA frameCounter
  AND #$01
  BEQ @uw_w1r_show_c0         ; even: show col0, hide col1
  ; Odd: hide col0, show col1
  LDA #$FE
  STA $036C
  LDA tmp_high
  STA $0370
  LDA tmp_shift
  CLC
  ADC #$01
  STA $0371
  LDA #ATTR_NORMAL
  STA $0372
  LDA weevil1_x
  CLC
  ADC #$08
  STA $0373
  JMP @uw_w1r_front
@uw_w1r_show_c0:
  LDA tmp_high
  STA $036C
  LDA tmp_shift
  STA $036D
  LDA #ATTR_NORMAL
  STA $036E
  LDA weevil1_x
  STA $036F
  LDA #$FE
  STA $0370
  JMP @uw_w1r_front
@uw_w1r_back_both:
  ; Not flying: show both back cols
  LDA tmp_high
  STA $036C
  LDA tmp_shift
  STA $036D
  LDA #ATTR_NORMAL
  STA $036E
  LDA weevil1_x
  STA $036F
  LDA tmp_high
  STA $0370
  LDA tmp_shift
  CLC
  ADC #$01
  STA $0371
  LDA #ATTR_NORMAL
  STA $0372
  LDA weevil1_x
  CLC
  ADC #$08
  STA $0373
@uw_w1r_front:
  ; Top col 2 (front, always visible)
  LDA tmp_high
  STA $0374
  LDA tmp_shift
  CLC
  ADC #$02
  STA $0375
  LDA #ATTR_NORMAL
  STA $0376
  LDA weevil1_x
  CLC
  ADC #$10
  STA $0377
  JMP @uw_w1_coll

@uw_w1_left_draw:
  ; LEFT-facing: head at x+0 (tile+2 H-flip). Back cols are x+8 and x+16.
  ; Bottom row -- always visible (all three cols)
  LDA tmp_low
  STA $0378
  LDA tmp_pal
  CLC
  ADC #$02
  STA $0379
  LDA #ATTR_HFLIP
  STA $037A
  LDA weevil1_x
  STA $037B
  LDA tmp_low
  STA $037C
  LDA tmp_pal
  CLC
  ADC #$01
  STA $037D
  LDA #ATTR_HFLIP
  STA $037E
  LDA weevil1_x
  CLC
  ADC #$08
  STA $037F
  LDA tmp_low
  STA $0380
  LDA tmp_pal
  STA $0381
  LDA #ATTR_HFLIP
  STA $0382
  LDA weevil1_x
  CLC
  ADC #$10
  STA $0383
  ; Top row col 0 (front/head) -- always visible
  LDA tmp_high
  STA $036C
  LDA tmp_shift
  CLC
  ADC #$02
  STA $036D
  LDA #ATTR_HFLIP
  STA $036E
  LDA weevil1_x
  STA $036F
  ; Alternate back top tiles when flying: one visible at a time
  LDA tmp_qx
  BEQ @uw_w1l_back_both       ; not flying: show both
  LDA frameCounter
  AND #$01
  BEQ @uw_w1l_show_c1         ; even: show col1, hide col2
  ; Odd: hide col1, show col2
  LDA #$FE
  STA $0370
  LDA tmp_high
  STA $0374
  LDA tmp_shift
  STA $0375
  LDA #ATTR_HFLIP
  STA $0376
  LDA weevil1_x
  CLC
  ADC #$10
  STA $0377
  JMP @uw_w1_coll
@uw_w1l_show_c1:
  LDA tmp_high
  STA $0370
  LDA tmp_shift
  CLC
  ADC #$01
  STA $0371
  LDA #ATTR_HFLIP
  STA $0372
  LDA weevil1_x
  CLC
  ADC #$08
  STA $0373
  LDA #$FE
  STA $0374
  JMP @uw_w1_coll
@uw_w1l_back_both:
  ; Not flying: show both back top cols
  LDA tmp_high
  STA $0370
  LDA tmp_shift
  CLC
  ADC #$01
  STA $0371
  LDA #ATTR_HFLIP
  STA $0372
  LDA weevil1_x
  CLC
  ADC #$08
  STA $0373
  LDA tmp_high
  STA $0374
  LDA tmp_shift
  STA $0375
  LDA #ATTR_HFLIP
  STA $0376
  LDA weevil1_x
  CLC
  ADC #$10
  STA $0377
  JMP @uw_w1_coll

@uw_w1_stun_draw:
  ; Upside-down walk: top row = bot-walk tiles (tmp_pal), bot row = top-walk tiles (tmp_shift)
  LDA tmp_high
  STA $036C
  LDA tmp_pal          ; bot walk tile base (animated)
  STA $036D
  LDA #ATTR_VFLIP
  STA $036E
  LDA weevil1_x
  STA $036F

  LDA tmp_high
  STA $0370
  LDA tmp_pal
  CLC
  ADC #$01
  STA $0371
  LDA #ATTR_VFLIP
  STA $0372
  LDA weevil1_x
  CLC
  ADC #$08
  STA $0373

  LDA tmp_high
  STA $0374
  LDA tmp_pal
  CLC
  ADC #$02
  STA $0375
  LDA #ATTR_VFLIP
  STA $0376
  LDA weevil1_x
  CLC
  ADC #$10
  STA $0377

  LDA tmp_low
  STA $0378
  LDA tmp_shift        ; top walk tile base (animated)
  STA $0379
  LDA #ATTR_VFLIP
  STA $037A
  LDA weevil1_x
  STA $037B

  LDA tmp_low
  STA $037C
  LDA tmp_shift
  CLC
  ADC #$01
  STA $037D
  LDA #ATTR_VFLIP
  STA $037E
  LDA weevil1_x
  CLC
  ADC #$08
  STA $037F

  LDA tmp_low
  STA $0380
  LDA tmp_shift
  CLC
  ADC #$02
  STA $0381
  LDA #ATTR_VFLIP
  STA $0382
  LDA weevil1_x
  CLC
  ADC #$10
  STA $0383

@uw_w1_coll:
  LDA $0378                    ; restore bot Y into tmp_low
  STA tmp_low
  JSR CheckPumpkinWeevil1
  JSR CheckWeevilPlayer1
@uw_w1_done:
  RTS


; Edge probes  (3-tile-wide weevil = 24 px wide)
;   Right probe: column one tile past right edge = (weevil_x + 24) >> 3
;   Left probe : column one tile past left edge  = (weevil_x -  8) >> 3

WeevilProbeRight0:
  LDA weevil0_x
  CLC
  ADC #$18
  LSR A
  LSR A
  LSR A
  STA tile_col
  LDX weevil0_plat
  LDA weevil_plat_rows, X
  STA tile_row
  JSR CFS_GetTileByColRow
  LDA TileID
  TAX
  LDA collision_table, X
  BNE @wpr0_ok
  LDA #$01
  STA weevil0_dir
  @wpr0_ok:
  RTS

WeevilProbeLeft0:
  LDA weevil0_x
  SEC
  SBC #$08
  LSR A
  LSR A
  LSR A
  STA tile_col
  LDX weevil0_plat
  LDA weevil_plat_rows, X
  STA tile_row
  JSR CFS_GetTileByColRow
  LDA TileID
  TAX
  LDA collision_table, X
  BNE @wpl0_ok
  LDA #$00
  STA weevil0_dir
  @wpl0_ok:
  RTS

WeevilProbeRight1:
  LDA weevil1_x
  CLC
  ADC #$18
  LSR A
  LSR A
  LSR A
  STA tile_col
  LDX weevil1_plat
  LDA weevil_plat_rows, X
  STA tile_row
  JSR CFS_GetTileByColRow
  LDA TileID
  TAX
  LDA collision_table, X
  BNE @wpr1_ok
  LDA #$01
  STA weevil1_dir
  @wpr1_ok:
  RTS

WeevilProbeLeft1:
  LDA weevil1_x
  SEC
  SBC #$08
  LSR A
  LSR A
  LSR A
  STA tile_col
  LDX weevil1_plat
  LDA weevil_plat_rows, X
  STA tile_row
  JSR CFS_GetTileByColRow
  LDA TileID
  TAX
  LDA collision_table, X
  BNE @wpl1_ok
  LDA #$00
  STA weevil1_dir
  @wpl1_ok:
  RTS


; Player-weevil bounding box collision
;   Called after each weevil's draw routine.
;   Sets playerHitTimer = 120 frames (2 sec) on contact.
;   No-op if: weevil inactive, weevil stunned, timer already running,
;             or player not on same platform.
;   Horizontal threshold: 20 px center-to-center.

CheckWeevilPlayer0:
  ; Skip if weevil inactive or stunned (stunned = player can stomp it)
  LDA weevil0_state
  BEQ @cwp0_done
  CMP #$03
  BEQ @cwp0_done
  ; Skip if player is already dead or still invincible
  LDA playerDead
  BNE @cwp0_done
  LDA playerInvTimer
  BNE @cwp0_done
  ; Vertical overlap: |player_feet_Y - weevil_bot_Y| < 16
  ; tmp_low = weevil0 bottom OAM Y (set just before this call at @uw_w0_coll)
  ; $031C = player bottom row OAM Y (set by UpdateSpriteWorldPos)
  LDA $031C
  SEC
  SBC tmp_low
  BPL @cwp0_dy
  EOR #$FF
  CLC
  ADC #$01
@cwp0_dy:
  CMP #$10                 ; 16 px vertical tolerance
  BCS @cwp0_done
  ; Horizontal overlap: |player_center_X - weevil_center_X| < 24
  ; $030B = player col1 (center) OAM X
  ; weevil center = weevil0_x + 8
  LDA weevil0_x
  CLC
  ADC #$08
  STA tmp_high             ; weevil center X
  LDA $030B                ; player center X
  SEC
  SBC tmp_high
  BPL @cwp0_dx
  EOR #$FF
  CLC
  ADC #$01
@cwp0_dx:
  CMP #$18                 ; 24 px horizontal tolerance
  BCS @cwp0_done
  ; Hit! If already bald → kill player; if has hat → knock hat off
  LDA playerHitTimer
  BEQ @cwp0_hat_hit        ; has hat → normal knock
  ; No hat: kill the player
  LDA #$02
  LDX #FAMISTUDIO_SFX_CH1
  JSR famistudio_sfx_play
  LDA #$01
  STA playerDead
  LDA #$B4                 ; 180 frames = 3 sec
  STA playerDeadTimer
  JSR DropPumpkin          ; drop carried pumpkin if holding one
  JMP @cwp0_done
@cwp0_hat_hit:
  LDA #$02
  LDX #FAMISTUDIO_SFX_CH1
  JSR famistudio_sfx_play
  LDA #$01
  STA playerHitTimer
  LDA #$5A                 ; 90 frames = 1.5 sec
  STA playerInvTimer
  JSR SpawnHat
@cwp0_done:
  RTS

CheckWeevilPlayer1:
  LDA weevil1_state
  BEQ @cwp1_done
  CMP #$03
  BEQ @cwp1_done
  ; Skip if player is already dead or still invincible
  LDA playerDead
  BNE @cwp1_done
  LDA playerInvTimer
  BNE @cwp1_done
  LDA $031C
  SEC
  SBC tmp_low
  BPL @cwp1_dy
  EOR #$FF
  CLC
  ADC #$01
@cwp1_dy:
  CMP #$10
  BCS @cwp1_done
  LDA weevil1_x
  CLC
  ADC #$08
  STA tmp_high
  LDA $030B
  SEC
  SBC tmp_high
  BPL @cwp1_dx
  EOR #$FF
  CLC
  ADC #$01
@cwp1_dx:
  CMP #$18
  BCS @cwp1_done
  ; Hit! If already bald → kill player; if has hat → knock hat off
  LDA playerHitTimer
  BEQ @cwp1_hat_hit        ; has hat → normal knock
  ; No hat: kill the player
  LDA #$02
  LDX #FAMISTUDIO_SFX_CH1
  JSR famistudio_sfx_play
  LDA #$01
  STA playerDead
  LDA #$B4                 ; 180 frames = 3 sec
  STA playerDeadTimer
  JSR DropPumpkin          ; drop carried pumpkin if holding one
  JMP @cwp1_done
@cwp1_hat_hit:
  LDA #$02
  LDX #FAMISTUDIO_SFX_CH1
  JSR famistudio_sfx_play
  LDA #$01
  STA playerHitTimer
  LDA #$5A                 ; 90 frames = 1.5 sec
  STA playerInvTimer
  JSR SpawnHat
@cwp1_done:
  RTS

; Pumpkin-weevil bounding box collision
;   Horizontal threshold 20 px (relative to weevil centre at x+12)
;   Vertical threshold   20 px
;   tmp_low = weevil bot-row OAM Y (set before calling)
CheckPumpkinWeevil0:
  LDA weevil0_state
  CMP #$03
  BEQ @cpw0_done          ; already stunned: don't re-trigger
  LDA isCarrying
  CMP #$02
  BNE @cpw0_done
  ; both tmp_low (weevil bot OAM Y) and pumpkin_world_y_low are screen coords
  SEC
  LDA tmp_low
  SBC pumpkin_world_y_low
  BPL @cpw0_dy
  EOR #$FF
  CLC
  ADC #$01
@cpw0_dy:
  CMP #$14
  BCS @cpw0_done
  SEC
  LDA pumpkinX
  SBC weevil0_x
  SBC #$0C
  BPL @cpw0_dx
  EOR #$FF
  CLC
  ADC #$01
@cpw0_dx:
  CMP #$14
  BCS @cpw0_done
  LDA #$03
  STA weevil0_state
  LDA #WEEVIL_STUN_FRAMES
  STA weevil0_stun
  LDA #$05
  LDX #FAMISTUDIO_SFX_CH1
  JSR famistudio_sfx_play
  @cpw0_done:
  RTS

CheckPumpkinWeevil1:
  LDA weevil1_state
  CMP #$03
  BEQ @cpw1_done          ; already stunned: don't re-trigger
  LDA isCarrying
  CMP #$02
  BNE @cpw1_done
  ; Vertical distance in screen space
  SEC
  LDA tmp_low
  SBC pumpkin_world_y_low
  BPL @cpw1_dy
  EOR #$FF
  CLC
  ADC #$01
@cpw1_dy:
  CMP #$14
  BCS @cpw1_done
  SEC
  LDA pumpkinX
  SBC weevil1_x
  SBC #$0C
  BPL @cpw1_dx
  EOR #$FF
  CLC
  ADC #$01
@cpw1_dx:
  CMP #$14
  BCS @cpw1_done
  LDA #$03
  STA weevil1_state
  LDA #WEEVIL_STUN_FRAMES
  STA weevil1_stun
  LDA #$05
  LDX #FAMISTUDIO_SFX_CH1
  JSR famistudio_sfx_play
  @cpw1_done:
  RTS


; Player jump-kill  (only called when weevil is stunned)
;   Player falling, feet above weevil, vertical gap 2-24 px, hgap < 24 px.
