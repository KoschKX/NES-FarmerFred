; FRED
gfx_sprites_fred_frame0:
  .db $20,$30,$00,$60
  .db $20,$31,$00,$68
  .db $20,$32,$00,$70
  .db $28,$40,$00,$60
  .db $28,$41,$00,$68
  .db $28,$42,$00,$70
  .db $30,$50,$00,$60
  .db $30,$51,$00,$68
  .db $30,$52,$00,$70

gfx_sprites_fred_frame1:
  .db $20,$33,$00,$60
  .db $20,$34,$00,$68
  .db $20,$35,$00,$70
  .db $28,$43,$00,$60
  .db $28,$44,$00,$68
  .db $28,$45,$00,$70
  .db $30,$53,$00,$60
  .db $30,$54,$00,$68
  .db $30,$55,$00,$70

gfx_sprites_fred_frame2:
  .db $20,$36,$00,$60
  .db $20,$37,$00,$68
  .db $20,$38,$00,$70
  .db $28,$46,$00,$60
  .db $28,$47,$00,$68
  .db $28,$48,$00,$70
  .db $30,$56,$00,$60
  .db $30,$57,$00,$68
  .db $30,$58,$00,$70

gfx_sprites_fred_frame3:
  .db $20,$39,$00,$60
  .db $20,$3A,$00,$68
  .db $20,$3B,$00,$70
  .db $28,$49,$00,$60
  .db $28,$4A,$00,$68
  .db $28,$4B,$00,$70
  .db $30,$59,$00,$60
  .db $30,$5A,$00,$68
  .db $30,$5B,$00,$70

gfx_sprites_fred_frame4:
  .db $20,$3C,$00,$60
  .db $20,$3D,$00,$68
  .db $20,$3E,$00,$70
  .db $28,$4C,$00,$60
  .db $28,$4D,$00,$68
  .db $28,$4E,$00,$70
  .db $30,$5C,$00,$60
  .db $30,$5D,$00,$68
  .db $30,$5E,$00,$70

gfx_sprites_fred_frame5:
  .db $20,$60,$00,$60
  .db $20,$61,$00,$68
  .db $20,$62,$00,$70
  .db $28,$70,$00,$60
  .db $28,$71,$00,$68
  .db $28,$72,$00,$70
  .db $30,$80,$00,$60
  .db $30,$81,$00,$68
  .db $30,$82,$00,$70

gfx_sprites_fred_frame6:
  .db $20,$63,$00,$60
  .db $20,$64,$00,$68
  .db $20,$65,$00,$70
  .db $28,$73,$00,$60
  .db $28,$74,$00,$68
  .db $28,$75,$00,$70
  .db $30,$83,$00,$60
  .db $30,$84,$00,$68
  .db $30,$85,$00,$70

gfx_sprites_fred_frame7:
  .db $20,$00,$00,$60
  .db $20,$00,$00,$68
  .db $20,$00,$00,$70
  .db $28,$7B,$00,$60
  .db $28,$7C,$00,$68
  .db $28,$00,$00,$70
  .db $30,$8B,$00,$60
  .db $30,$8C,$00,$68
  .db $30,$8D,$00,$70

gfx_dead_star_tiles:
  .db $6D, $6E, $6F
gfx_dead_star_mod3:
  .db 0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0


;NO HAT
gfx_sprites_fred_bald_frame0:
  .db $20,$00,$00,$60
  .db $20,$66,$00,$68
  .db $20,$00,$00,$70
  .db $28,$00,$00,$60
  .db $28,$41,$00,$68
  .db $28,$42,$00,$70
  .db $30,$50,$00,$60
  .db $30,$51,$00,$68
  .db $30,$52,$00,$70

gfx_sprites_fred_bald_frame1:
  .db $20,$00,$00,$60
  .db $20,$66,$00,$68
  .db $20,$00,$00,$70
  .db $28,$00,$00,$60
  .db $28,$44,$00,$68
  .db $28,$45,$00,$70
  .db $30,$53,$00,$60
  .db $30,$54,$00,$68
  .db $30,$55,$00,$70

gfx_sprites_fred_bald_frame2:
  .db $20,$00,$00,$60
  .db $20,$67,$00,$68
  .db $20,$00,$00,$70
  .db $28,$00,$00,$60
  .db $28,$47,$00,$68
  .db $28,$48,$00,$70
  .db $30,$56,$00,$60
  .db $30,$57,$00,$68
  .db $30,$58,$00,$70

gfx_sprites_fred_bald_frame3:
  .db $20,$00,$00,$60
  .db $20,$68,$00,$68
  .db $20,$00,$00,$70
  .db $28,$00,$00,$60
  .db $28,$4A,$00,$68
  .db $28,$4B,$00,$70
  .db $30,$59,$00,$60
  .db $30,$5A,$00,$68
  .db $30,$5B,$00,$70

gfx_sprites_fred_bald_frame4:
  .db $20,$76,$00,$60
  .db $20,$77,$00,$68
  .db $20,$3E,$00,$70
  .db $28,$78,$00,$60
  .db $28,$4D,$00,$68
  .db $28,$4E,$00,$70
  .db $30,$5C,$00,$60
  .db $30,$5D,$00,$68
  .db $30,$5E,$00,$70

gfx_sprites_fred_bald_frame5:
  .db $20,$86,$00,$60
  .db $20,$87,$00,$68
  .db $20,$62,$00,$70
  .db $28,$70,$00,$60
  .db $28,$71,$00,$68
  .db $28,$72,$00,$70
  .db $30,$80,$00,$60
  .db $30,$81,$00,$68
  .db $30,$82,$00,$70

gfx_sprites_fred_bald_frame6:
  .db $20,$00,$00,$60
  .db $20,$00,$00,$68
  .db $20,$00,$00,$70
  .db $28,$88,$00,$60
  .db $28,$89,$00,$68
  .db $28,$8A,$00,$70
  .db $30,$83,$00,$60
  .db $30,$84,$00,$68
  .db $30,$85,$00,$70

LoadSprites:
  ; If player is dead show death pose and return immediately
  LDA playerDead
  BEQ @ls_not_dead
  LDY #$01
@ls_dead_loop:
  LDA gfx_sprites_fred_frame7, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @ls_dead_loop
  ; Animate star tile ($6D/$6E/$6F) in top-center slot ($0309)
  ; playerDeadTimer >>4 gives 0-11; mod3 via lookup gives star frame index
  LDA playerDeadTimer
  LSR A
  LSR A            ; divide by 4 -> 0-45
  TAX
  LDA gfx_dead_star_mod3, x
  TAX
  LDA gfx_dead_star_tiles, x
  STA $0309
  RTS
@ls_not_dead:
  ; Flicker player during invincibility window
  LDA playerInvTimer
  BEQ @ls_no_flicker
  AND #$02              ; bit 1 toggles every 2 frames (faster flash)
  BEQ @ls_no_flicker    ; show on this 2-frame window
  LDA #$F0              ; hide all 9 player sprite Y slots
  STA $0304
  STA $0308
  STA $030C
  STA $0310
  STA $0314
  STA $0318
  STA $031C
  STA $0320
  STA $0324
  RTS
@ls_no_flicker:
  ; Use bald frames when the player has been hit by a weevil
  LDA playerHitTimer
  BEQ @ls_not_hit
  JMP LoadBaldSprites
@ls_not_hit:
  ; if A button is held AND player is grounded, show pickup frame
  LDA joy1_curr
  AND #$80
  BEQ @noPickup
  LDA playerGrounded
  BEQ @noPickup
  JMP @use6
@noPickup:

  ; if player is moving vertically, show jump/fall frames
  LDA playerVelocityY
  CMP #$00
  BMI @use4   ; negative -> rising (jump)
  BNE @use5   ; positive -> falling

  ; velocity == 0 but airborne (apex of jump) -> still show jump frame
  LDA playerGrounded
  BEQ @use4

  LDA playerFrame
  CMP #$03
  BEQ @use3
  CMP #$02
  BEQ @use2
  CMP #$01
  BEQ @use1
  ; default -> frame0
  LDY #$01
@loop0:
  LDA gfx_sprites_fred_frame0, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @loop0
  RTS
@use1:
  LDY #$01
@loop1:
  LDA gfx_sprites_fred_frame1, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @loop1
  RTS
@use2:
  LDY #$01
@loop2:
  LDA gfx_sprites_fred_frame2, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @loop2
  RTS

@use3:
  LDY #$01
@loop3:
  LDA gfx_sprites_fred_frame3, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @loop3
  RTS

@use4:
  LDY #$01
@loop4:
  LDA gfx_sprites_fred_frame4, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @loop4
  RTS

@use5:
  LDY #$01
@loop5:
  LDA gfx_sprites_fred_frame5, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @loop5
  RTS

@use6:
  LDY #$01
@loop6:
  LDA gfx_sprites_fred_frame6, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @loop6
  RTS

; LoadBaldSprites - same frame logic as LoadSprites, using NO-HAT tile tables
; Called automatically when playerHitTimer > 0
LoadBaldSprites:
  LDA joy1_curr
  AND #$80
  BEQ @bald_noPickup
  LDA playerGrounded
  BEQ @bald_noPickup
  JMP @bald_use6
@bald_noPickup:
  LDA playerVelocityY
  CMP #$00
  BMI @bald_use4
  BNE @bald_use5
  LDA playerGrounded
  BEQ @bald_use4
  LDA playerFrame
  CMP #$03
  BEQ @bald_use3
  CMP #$02
  BEQ @bald_use2
  CMP #$01
  BEQ @bald_use1
  LDY #$01
@bald_loop0:
  LDA gfx_sprites_fred_bald_frame0, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @bald_loop0
  RTS
@bald_use1:
  LDY #$01
@bald_loop1:
  LDA gfx_sprites_fred_bald_frame1, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @bald_loop1
  RTS
@bald_use2:
  LDY #$01
@bald_loop2:
  LDA gfx_sprites_fred_bald_frame2, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @bald_loop2
  RTS
@bald_use3:
  LDY #$01
@bald_loop3:
  LDA gfx_sprites_fred_bald_frame3, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @bald_loop3
  RTS
@bald_use4:
  LDY #$01
@bald_loop4:
  LDA gfx_sprites_fred_bald_frame4, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @bald_loop4
  RTS
@bald_use5:
  LDY #$01
@bald_loop5:
  LDA gfx_sprites_fred_bald_frame5, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @bald_loop5
  RTS
@bald_use6:
  LDY #$01
@bald_loop6:
  LDA gfx_sprites_fred_bald_frame6, y
  STA $0304, y
  INY
  INY
  INY
  INY
  CPY #$25
  BNE @bald_loop6
  RTS