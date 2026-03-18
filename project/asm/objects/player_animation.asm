; player_animation.asm
; Handles player walking animation and frame logic

PlayerAnimation:
    LDA grabTimer
    BEQ @pa_run
    RTS                   ; freeze animation while grab is active
@pa_run:
    INC animTimer
    LDA animTimer
    CMP #$03
    BCC @skipToggle
    LDA #$00
    STA animTimer

    LDA playerMoving
    BEQ @setIdle

    ; advance frame counter within 1..3 while moving
    INC playerFrame
    LDA playerFrame
    CMP #$04
    BNE @skipToggle
    LDA #$01
    STA playerFrame
    BNE @skipToggle
@setIdle:
    LDA #$00
    STA playerFrame
@skipToggle:

    RTS