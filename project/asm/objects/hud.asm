; hud.asm

UpdateHUD:
        ; hundreds
        LDA veggieCount
        LDX #$00
@hud_hundreds:
        CMP #100
        BCC @hud_after_hundreds
        SBC #100
        INX
        JMP @hud_hundreds
@hud_after_hundreds:
        STX tmp_low        ; save hundreds
        ; tens
        LDX #$00
@hud_tens:
        CMP #10
        BCC @hud_units_done
        SBC #10
        INX
        JMP @hud_tens
@hud_units_done:
        TAY                    ; units
        LDA hud_digit_tiles, X
        STA $0351          ; tens tile (slot 20)
        TYA
        TAX
        LDA hud_digit_tiles, X
        STA $0395          ; units tile (slot 37)
        LDX tmp_low
        LDA hud_digit_tiles, X
        STA $034D          ; hundreds tile (slot 19)
        ; gate
        LDA playerDead
        BNE @hud_no_gate       ; dead: hide arrow + silence beep
        LDA basketGoal
        BEQ @hud_no_gate       ; 0 = disabled
        LDA pageVeggies
        CMP basketGoal
        BCS @hud_gate_open
        ; goal not met — gate blocked
        LDA #$FF
        STA $0390              ; hide arrow
        LDA gate_open_shadow
        BEQ @hud_gate_done     ; already blocked
        LDA #$00
        STA gate_open_shadow
        LDA #$01
        STA top_row_gate_flag  ; NMI: write $D3
        JMP @hud_gate_done
@hud_no_gate:
        LDA #$FF
        STA $0390
        JMP @hud_gate_done
@hud_gate_open:
        LDA gate_open_shadow
        BNE @hud_do_blink      ; already open
        LDA #$01
        STA gate_open_shadow
        LDA arrow_sfx_enable
        BEQ @hud_skip_open_sfx
        LDA #$07              ; sfx: level up
        LDX #FAMISTUDIO_SFX_CH1
        JSR famistudio_sfx_play
@hud_skip_open_sfx:
        LDA #$02
        STA top_row_gate_flag  ; NMI: restore row 0
        LDA #$FF
        STA $0390
        JMP @hud_gate_done
@hud_do_blink:
        LDA frameCounter
        AND #$10               ; blink
        BEQ @hud_arrow_off
        LDA #$08
        STA $0390              ; show arrow (Y=$08)
        LDA frameCounter
        AND #$1F               ; rising edge of on-phase (once per 32 frames)
        CMP #$10
        BNE @hud_gate_done
        LDA arrow_sfx_enable
        BEQ @hud_gate_done     ; sfx disabled
        LDA #$07               ; sfx: level up (repeat while arrow shows)
        LDX #FAMISTUDIO_SFX_CH1
        JSR famistudio_sfx_play
        JMP @hud_gate_done
@hud_arrow_off:
        LDA #$FF
        STA $0390              ; hide during off-phase of blink
@hud_gate_done:
        RTS

hud_digit_tiles:
        .db font_0, font_1, font_2, font_3, font_4
        .db font_5, font_6, font_7, font_8, font_9

gfx_hud_text:
        .db $08, font_0, $00, $08   ; hundreds
        .db $08, font_0, $00, $10   ; tens
