; seasons.asm - Season progression + BG palette cycling
;
;   season              0-3 current season
;   seasonGoal          veggies per season (0 = disabled)
;   season_veggie_count basket count toward next change
;   season_pal3_c0..c3  RAM cache of BG palette 3 for current season

; UpdateSeasons
; Call after a successful basket score.
; Advances season when season_veggie_count reaches seasonGoal.
; No-ops when seasonGoal = 0.
UpdateSeasons:
  LDA seasonGoal
  BNE @us_active          ; 0 = disabled
  RTS
@us_active:

  INC season_veggie_count
  LDA season_veggie_count
  CMP seasonGoal
  BCS @us_advance         ; reached goal
  RTS                     ; not yet at goal
@us_advance:

  ; Reset counter and advance season
  LDA #$00
  STA season_veggie_count
  INC season
  LDA season
  CMP #$04
  BCC @us_set_offset
  LDA #$00                ; wrap 3->0
  STA season

@us_set_offset:
  ; season_pal_offset = season * 4 (index into 16-byte season_pal3_colors table)
  ASL A          ; *2
  ASL A          ; *4
  STA season_pal_offset
  ; Set tmp_ptr to &season_pal3_colors[season_pal_offset] then copy 4 bytes
  CLC
  ADC #<(season_pal3_colors)
  STA tmp_ptr
  LDA #>(season_pal3_colors)
  ADC #$00
  STA tmp_ptr+1
  LDY #$00
  LDA (tmp_ptr), Y
  STA season_pal3_c0
  INY
  LDA (tmp_ptr), Y
  STA season_pal3_c1
  INY
  LDA (tmp_ptr), Y
  STA season_pal3_c2
  INY
  LDA (tmp_ptr), Y
  STA season_pal3_c3
  RTS

; ResetSeasonCounter
; Zeroes season_veggie_count without changing the current season.
ResetSeasonCounter:
  LDA #$00
  STA season_veggie_count
  RTS

; UpdateBasketAnim
; Cycles basket tiles while basket_anim_timer > 0; restores $00 when done.
UpdateBasketAnim:
  LDA basket_anim_timer
  BEQ @uba_done             ; idle
  DEC basket_anim_timer
  LDA basket_anim_timer
  BEQ @uba_restore          ; just hit 0: restore
  ; Fast cycle: 2-3 frames per tile using lower 3 bits
  ; bits 0-2 -> $6F, 3-5 -> $6E, 6-7 -> $6D
  AND #$07
  CMP #$06
  BCS @uba_tile0            ; 6-7 -> $6D
  CMP #$03
  BCS @uba_tile1            ; 3-5 -> $6E
  LDA #$6F                  ; 0-2 -> $6F
  JMP @uba_write
@uba_tile1:
  LDA #$6E
  JMP @uba_write
@uba_tile0:
  LDA #$6D
  JMP @uba_write
@uba_restore:
  LDA #$00                  ; blank/sky tile to clear sparkle
@uba_write:
  STA tmp_high              ; save tile
  LDA $2002                 ; reset PPU latch
  LDA basket_anim_ppu_hi
  STA $2006
  LDA basket_anim_ppu_lo
  STA $2006
  LDA tmp_high
  STA $2007                 ; sparkle tile
@uba_done:
  RTS
