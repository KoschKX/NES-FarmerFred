palettes:
  .db $0F,$09,$17,$27
  .db $0F,$01,$21,$31
  .db $0F,$07,$17,$18
  .db $0F,$08,$29,$1B
  .db $0F,$16,$27,$36
  .db $0F,$18,$26,$3B
  .db $0F,$15,$26,$38
  .db $0F,$14,$24,$34

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
  sta $2007
  inx
  cpx #$20
  bne UploadPalLoop
  rts