WaitForVBlank:
    LDA nmi_ready
    BEQ WaitForVBlank
    LDA #$00
    STA nmi_ready

    ; Check for player death (bypasses most game logic; gravity still applies)
    LDA playerDead
    BEQ @not_dead
    ; Dead path: kept lean to stay within one NMI period (no lag frames).
    ; Scroll and HUD are skipped; gravity, hat + pumpkin physics still run.
    JSR ReadControllers
    JSR PlayerCheckCollisions
    JSR ApplyGravity
    JSR DeadTick
    JSR UpdateHat
    JSR UpdatePumpkinThrow
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
      JSR Scroll

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
      JSR RestorePlantLayout    ; vblank-gated VRAM restore; clears plant_needs_restore
@no_plant_restore:

      JSR UpdateHUD

    JMP MAIN
