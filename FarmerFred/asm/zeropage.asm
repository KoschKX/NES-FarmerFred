.enum 0
nmi_ready	   .dsb 1
nametable      .dsb 1
camera_y		   .dsb 1  ; low byte of 16-bit world scroll Y
; 16-bit player world coordinates
player_world_x_low  .dsb 1
player_world_x_high .dsb 1
player_world_y_low  .dsb 1
player_world_y_high .dsb 1
pageVar    .dsb 1
pageOffsetVar .dsb 1
rowIndex   .dsb 1
stream_row .dsb 1 ; temp for streaming rows in scroll.asm
; 16-bit camera / PPU scroll vars
camera_y_high   .dsb 1  ; high byte of 16-bit world scroll Y
scroll_y_ppu    .dsb 1  ; camera_16bit mod 240 -> written to $2005 Y
vram_row        .dsb 1  ; rowIndex mod 30 (nametable destination row)
veggieCount       .dsb 1  ; cumulative veggies collected (never resets on page change)
pageVeggies       .dsb 1  ; veggies collected this page (resets on page advance / death)
.ende
