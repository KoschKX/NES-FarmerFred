; title.asm -- Title screen for Farmer Fred
;
; Entry: TitleScreen -- called from init.asm, PPU/NMI off.
; Exits via JMP StartGame on Start press.

TitleScreen:

  ; MMC3: map title.chr into PPU PT0 ($0000-$0FFF)
  LDA #$00
  STA $8000             ; select R0
  LDA #$08
  STA $8001             ; R0 = banks 8-9
  ; R1 = 2KB at PPU $0800: 1KB bank 10 -> covers banks 10-11 (tiles 128-255)
  LDA #$01
  STA $8000             ; select R1
  LDA #$0A
  STA $8001             ; R1 = banks 10-11

  ; Hide all OAM sprites (Y=$FF -> off-screen)
  LDA #$FF
  LDX #$00
@ts_hide_oam:
  STA $0300, X
  INX
  INX
  INX
  INX
  BNE @ts_hide_oam

  ; Wait for VBlank, then upload palette inside it
  BIT $2002
@ts_pre_vb1:
  BIT $2002
  BPL @ts_pre_vb1
  ; IN VBLANK: upload title palette (16 BG colors) to PPU $3F00
  LDA #$3F
  STA $2006
  LDA #$00
  STA $2006
  LDX #$00
@ts_pal_loop:
  LDA title_pal_data, X
  STA $2007
  INX
  CPX #$10
  BNE @ts_pal_loop

  ; Upload nametable (rendering off — OK to run past VBlank)
  LDA $2002             ; reset PPU address latch
  LDA #$20
  STA $2006
  LDA #$00
  STA $2006
  LDX #$00
@ts_nmt0:
  LDA title_map_data+$000, X
  STA $2007
  INX
  BNE @ts_nmt0
@ts_nmt1:
  LDA title_map_data+$100, X
  STA $2007
  INX
  BNE @ts_nmt1
@ts_nmt2:
  LDA title_map_data+$200, X
  STA $2007
  INX
  BNE @ts_nmt2
@ts_nmt3:
  LDA title_map_data+$300, X
  STA $2007
  INX
  BNE @ts_nmt3

  ; Silence APU before init to prevent garbage sound on some emulators
  LDA #$00
  STA $4015             ; disable all channels (incl. DMC)
  STA $4011             ; clear DMC counter
  ; Init FamiStudio now: NMI is still OFF, PPU writes are done
  ; Calling famistudio_init here avoids any PPU timing interference during
  ; palette upload. NMI is still disabled (PPU_CTRL not yet written).
  LDX #<music_data_untitled
  LDY #>music_data_untitled
  LDA #1                ; 1 = NTSC
  JSR famistudio_init
  ; Initialize SFX engine even though we play no SFX on the title screen.
  ; famistudio_sfx_init clears the SFX stream state (sfx_ptr_hi, sfx_repeat,
  ; output buffer). Without this, power-on RAM ($FF on FCEUX/fceumm) makes
  ; famistudio_sfx_update think active SFX are playing from garbage pointers,
  ; producing ~4 seconds of buzzing until the fake "repeat" counters expire.
  LDX #<sounds
  LDY #>sounds
  JSR famistudio_sfx_init
  LDA #0                ; song index 0 = maggie (title)
  JSR famistudio_music_play

  ; arm NMI title mode, set scroll + PPU regs
  LDA #$01
  STA nmi_title_mode    ; NMI handler: skip game logic, only call famistudio_update
  LDA #$00
  STA nmi_ready
  LDA $2002             ; reset write latch
  LDA #$00
  STA PPU_SCROLL        ; X scroll = 0
  STA PPU_SCROLL        ; Y scroll = 0
  LDA #%10000000        ; NMI on, BG at $0000, NT0
  STA PPU_CTRL
  LDA #%00001110        ; show BG, sprites off
  STA PPU_MASK

  ; Title loop: NMI calls famistudio_update at exact 60 Hz
@ts_loop:
@ts_vbl:
  LDA nmi_ready
  BEQ @ts_vbl           ; wait for NMI to fire
  LDA #$00
  STA nmi_ready

  ; Strobe joypad 1, read A B Select Start (discard rest)
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDA $4016             ; A      - discard
  LDA $4016             ; B      - discard
  LDA $4016             ; Select - discard
  LDA $4016             ; Start
  AND #$01
  BEQ @ts_loop          ; not pressed, keep waiting

  ; restore game CHR banks, disable rendering
  LDA #$00
  STA $8000
  STA $8001
  ; restore R1 = bank 2
  LDA #$01
  STA $8000
  LDA #$02
  STA $8001
  LDA #$00
  STA PPU_CTRL
  STA PPU_MASK
  STA nmi_title_mode    ; restore game NMI path
  ; stop music cleanly before entering game
  JSR famistudio_music_stop
  JMP StartGame         ; defined in init.asm