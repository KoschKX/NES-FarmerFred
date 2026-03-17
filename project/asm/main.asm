WaitForVBlank:
    LDA nmi_ready
    BEQ WaitForVBlank
    LDA #$00
    STA nmi_ready

    ; Check for player death (bypasses most game logic; gravity still applies)
    LDA playerDead
    BEQ @not_dead
    JSR PlayerCheckCollisions
    JSR ApplyGravity
    JSR DeadTick
    JMP MAIN
@not_dead:

    ; Game logic
      JSR ReadControllers
      JSR HandlePlayerInput
      JSR PlayerTryGrabPlant
      JSR UpdatePumpkinThrow

      JSR PlayerCheckCollisions
      LDA tile_row                 ; save player's platform row for weevil speed-up check
      STA player_plat_row
      JSR ApplyGravity

      JSR UpdateCamera
      JSR UpdateCameraRender

      JSR UpdateSpriteWorldPos
      JSR PlayerAnimation
      JSR LoadSprites
      JSR UpdateSpriteAttrs
      JSR UpdateWeevils
      JSR UpdateHat
      ; inv timer
      LDA playerInvTimer
      BEQ @skip_inv_dec
      DEC playerInvTimer
@skip_inv_dec:

      ; page transition: repopulate plants
      LDA plant_needs_restore
      BEQ @no_plant_restore
      LDA #$00
      STA plant_needs_restore
      STA PPU_CTRL               ; NMI off
      STA PPU_MASK               ; rendering off
@plant_wait_vb:
      BIT $2002
      BPL @plant_wait_vb
      ; vblank
      JSR ClearPlantRemovedBits
      JSR ReRandomizePlatforms
      JSR WritePlantsForAllPairs
      JSR InitWeevils
      LDA #$00
      STA hat_active
      JSR PlaceHatOnBottomPlatform
@plant_wait_vb2:
      BIT $2002
      BPL @plant_wait_vb2
      LDA $2002                  ; reset latch
      LDA #$00
      STA PPU_SCROLL
      LDA scroll_y_ppu
      STA PPU_SCROLL
      LDA nametable
      AND #$01
      ASL A
      ORA #%10000000
      STA PPU_CTRL
      LDA #%00011110
      STA PPU_MASK
      LDA #$01
      STA nmi_ready
@no_plant_restore:
      
    JMP MAIN
