; setup.asm - FarmerFred ROM layout (asm6)
; Mapper 4 (MMC3), 2x16 KB PRG, 2x8 KB CHR
.base 0
  .db 78,69,83,26   ; NES magic (N,E,S,$1A)
  .db 2             ; 2x16KB PRG banks
  .db 2             ; 2x8KB CHR banks
  .db 64            ; Flags6: mapper 4 lower nibble (64=$40)
  .db 0             ; Flags7: mapper 4 upper nibble
  .dsb 8,0          ; padding -> 16 byte header
  .include "asm/zeropage.asm"
  .include "asm/globals.asm"
  .include "asm/buffers.asm"
  .base $8000

; ---- FamiStudio config + engine (bank 0: $8000-$9FFF, currently all padding) --
FAMISTUDIO_CFG_EXTERNAL       = 1
FAMISTUDIO_CFG_NTSC_SUPPORT   = 1
FAMISTUDIO_CFG_DPCM_SUPPORT   = 0
FAMISTUDIO_CFG_SFX_SUPPORT    = 1
FAMISTUDIO_CFG_SFX_STREAMS    = 2
FAMISTUDIO_USE_VOLUME_TRACK   = 1
FAMISTUDIO_USE_PITCH_TRACK    = 1
FAMISTUDIO_USE_SLIDE_NOTES    = 1
FAMISTUDIO_USE_VIBRATO        = 1
FAMISTUDIO_USE_ARPEGGIO       = 1
FAMISTUDIO_CFG_SMOOTH_VIBRATO = 1
FAMISTUDIO_USE_RELEASE_NOTES  = 1
FAMISTUDIO_ASM6_ZP_ENUM       = $84    ; ZP temps: $82=nmi_title_mode, $83 spare, $84+ FamiStudio
FAMISTUDIO_ASM6_BSS_ENUM      = $0500  ; RAM above plant_removed_bits ($0400)
FAMISTUDIO_ASM6_CODE_BASE     = $8000  ; engine lives at the start of bank 0
LIB:
  .include "asm/-LIB-/famistudio_asm6.asm"
MUSIC:
  .include "bgm/bgm.asm"
SFX:
  .include "sfx/sfx.asm"
TITLE_DATA:

title_map_data:
  .incbin "map/title.map"
  .pad  $A000
title_pal_data:
  .incbin "pal/title.pal"
INIT:
  .include "asm/init.asm"
SYSTEM:
  .include "asm/system.asm"
BACKGROUNDS:
  .include "asm/backgrounds.asm"
SCROLLING:
  .include "asm/scroll.asm"
OBJECTS:
  .include "asm/objects.asm"
MAIN:
  .include "asm/main.asm"
  .include "asm/nmi.asm"
  .pad  $E000
columnData:
  .incbin "map/level_001.map"
ASSETS:
  .include "asm/assets.asm"
SEASONS:
  .include "asm/objects/seasons.asm"
TITLE:
  .include "asm/title.asm"
WEEVILS:
  .include "asm/objects/weevils.asm"
HAT:
  .include "asm/objects/hat.asm"
IRQ_HANDLER:
  .include "asm/system/irq.asm"
VECTORS:
  .include "asm/vectors.asm"
  .base 0
  .include "asm/assets/chr.asm"
  .pad $2000
  .base 0
  .incbin "chr/title.chr"
  .incbin "chr/title.chr"
  .pad $2000
