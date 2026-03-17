; Graphics small include: default background map + palettes and attributes

palettes:
  .incbin "pal/palettes.pal"

; BG palette 3 colors per season (4 bytes x 4 seasons = 16 bytes).
; season_pal_offset = season*4 selects which row. UpdateSeasons copies the
; 4 bytes into the season_pal3_c0.@c3 RAM cache on each season change.
; BG palettes 0-2 are always fixed (from palettes.pal bytes 0-11).
season_pal3_colors:
  .incbin "pal/seasons.pal"  ; 16 bytes: 4 seasons x 4 colors (Summer/Autumn/Winter/Spring)

; Upload full 32-byte palette to PPU ($3F00-$3F1F)
; Call from NMI or before enabling rendering
UploadPalettes:
  lda #$3F
  sta $2006
  lda #$00
  sta $2006
  ldx #$00
UploadPalLoop:
  lda palettes,x
  sta PPU_DATA
  inx
  cpx #$20
  bne UploadPalLoop
  RTS



