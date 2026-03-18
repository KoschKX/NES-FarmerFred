.enum $0010
; CAMERA
sourceLow      .dsb 1
sourceHigh     .dsb 1
tmp_low        .dsb 1
tmp_high       .dsb 1

; CONTROLS
joy1_curr	.dsb 1
joy1_prev	.dsb 1
joy1_pressed	.dsb 1
joy1_released	.dsb 1

attr_accum_low            .dsb 1
attr_accum_high           .dsb 1
tile_col                  .dsb 1
tile_row                  .dsb 1
tmp_col                   .dsb 1
tmp_row                   .dsb 1
tmp_qx                    .dsb 1
tmp_qy                    .dsb 1
tmp_shift                 .dsb 1
tmp_pal                   .dsb 1
; Deferred plant row write - queued by scroll.asm entering_top, flushed at NMI start.
; Splitting the write across two NMIs keeps both within the ~1760-cycle vblank budget.
plant_pending_flag        .dsb 1  ; 1 = a plant row write is queued for next NMI
plant_pending_qx          .dsb 1  ; slot number for the queued write (2,9,17...)
plant_pending_pal         .dsb 1  ; rotation offset for the queued write
plant_erase_count         .dsb 1  ; 0 = nothing to erase, 1 = erase 1 tile
plant_erase_buf           .dsb 2  ; hi0,lo0 - PPU address of the tile to blank
; (plant_bitmask bytes removed - plants now appear above every floor tile, no random gating needed)
plant_needs_restore       .dsb 1  ; >0 = queue plant rows one per frame
plant_restore_idx         .dsb 1  ; 0..5 which plant row to queue next
animTimer                 .dsb 1  ; dedicated walk-cycle timer (not shared with NMI)
reached_platform          .dsb 1  ; 1 = player landed on a platform tile

; LEVEL
currentLevel .dsb 1
levelBaseLow .dsb 1
levelBaseHigh .dsb 1
pointerBackgroundLowByte .dsb 1
pointerBackgroundHighByte .dsb 1
paletteLoadedFromLevel  .dsb 1
attributesLoadedFromLevel .dsb 1


; Debug capture vars (used by asm/scroll.asm DebugCapLoop)

; Zero page temp variables for multiplies and pointers (used by plant grab/removal)
tmp_ptr   .dsb 2
tmp_mul   .dsb 1

debug_ptr_low      .dsb 1
debug_ptr_high     .dsb 1
debug_idx_high     .dsb 1
debug_idx_low      .dsb 1
bottomCenterTile   .dsb 1
bottomCenterCHR    .dsb 1
bottomCenterCollision .dsb 1
leftCollision      .dsb 1
rightCollision     .dsb 1
topCollision       .dsb 1
TileID             .dsb 1

frameCounter	   .dsb 1
playerFacing       .dsb 1
playerFrame 	   .dsb 1
playerVelocityY    .dsb 1
playerMoving       .dsb 1
playerBheld        .dsb 1
playerGrounded     .dsb 1
playerHoldTimer    .dsb 1
coyoteTimer        .dsb 1
jumpBuffer         .dsb 1
grabTimer          .dsb 1  ; frames remaining in plant-grab animation (0 = not grabbing)
isCarrying         .dsb 1  ; 1 = player is holding a pumpkin (persists after grab anim)
pumpkinX           .dsb 1  ; thrown pumpkin screen X
pumpkin_world_y_low  .dsb 1  ; thrown pumpkin world Y (low)
pumpkin_world_y_high .dsb 1  ; thrown pumpkin world Y (high)
pumpkinVX          .dsb 1  ; throw X velocity (signed 2's complement)
pumpkinVY          .dsb 1  ; throw Y velocity (positive = down)
lastRowIndex        .dsb 1 ; Last streamed coarse row for scroll.asm
camera_clamp_bottom .dsb 1 ; Non-zero = clamp camera_y at level bottom
platform_col_shift  .dsb 1 ; 0-31: horizontal tile rotation for platform randomization
shift_needs_gen     .dsb 1 ; 1 = generate new platform_col_shift before next NT0 write
randomize_enabled   .dsb 1 ; 0 = platforms at fixed positions, 1 = randomized
; Randomizer RAM - placed at absolute addresses so all included files can see them
; Buffer area ($0200-$029F) is 160 bytes (Attribute_Buffer 64 + attr_accum 64 + debug_buf 32).
; $02A0 onward is free unconditional RAM.
lfsr_state   = $02A0 ; Galois LFSR state (must stay non-zero)
row_shifts   = $02A1 ; 86-byte per-row horizontal tile rotation (0..31), indexed by world_row%86
                     ; occupies $02A1-$02F6
pair_randomized = $02F7 ; 8 bytes (one per platform pair) - non-zero = already randomized
                       ; set at init after all rows written; preserved across level wrap
; $02FF onward is free RAM (plant_masks removed - plants now read source tile data directly)

; Plant removal bitfield: 5 rows (platform pairs 1-5), 4 bytes each = 20 bytes
; Placed at $0400 to avoid OAM shadow at $0300-$03FF
plant_removed_bits = $0400 ; 20 bytes ($0400-$0413)

; -----------------------------------------------------------------------
; Weevil enemy system globals ($0414 onward)
; -----------------------------------------------------------------------
; player_plat_row: saved after PlayerCheckCollisions so weevils can
;   compare their platform row and decide whether to speed up.
player_plat_row   .dsb 1

; Weevil 0
weevil0_x         .dsb 1  ; screen X (byte-wraps across screen edges)
weevil0_yl        .dsb 1  ; world Y low  (feet; weevil stands flush with platform)
weevil0_yh        .dsb 1  ; world Y high
weevil0_state     .dsb 1  ; 0=inactive, 1=walking, 3=stunned (flipped)
weevil0_dir       .dsb 1  ; 0=right, 1=left
weevil0_stun      .dsb 1  ; stun countdown (frames)
weevil0_plat      .dsb 1  ; platform index 0-4

; Weevil 1
weevil1_x         .dsb 1
weevil1_yl        .dsb 1
weevil1_yh        .dsb 1
weevil1_state     .dsb 1
weevil1_dir       .dsb 1
weevil1_stun      .dsb 1
weevil1_plat      .dsb 1

playerHitTimer    .dsb 1  ; permanent bald flag (0=has hat  nonzero=bald)
playerInvTimer    .dsb 1  ; invincibility countdown 90->0 (1.5 sec)
playerDead        .dsb 1  ; 1 = player is dead (showing death animation)
playerDeadTimer   .dsb 1  ; 180->0 countdown (3 sec at 60fps)
basketGoal        .dsb 1  ; veggies required to advance page (0 = no gate)
top_row_gate_flag .dsb 1  ; 0=idle  1=write $D3  2=restore row 0 from level data
gate_open_shadow  .dsb 1  ; 0=gate blocked  1=gate open (previous-frame state)
arrow_sfx_enable  .dsb 1  ; 1=play beep while arrow is visible  0=silent

; Hat physics object
hat_active    .dsb 1  ; 0=hidden  1=in-flight  2=landed
hat_screen_x  .dsb 1  ; screen X of hat center tile
hat_world_y_low  .dsb 1  ; world Y of hat top (low byte)
hat_world_y_high .dsb 1  ; world Y of hat top (high byte)
hat_vx        .dsb 1  ; signed X velocity  ($FD=-3  $03=+3)
hat_vy        .dsb 1  ; signed Y velocity  ($F8=-8 upward -> +6 falling max)
hat_timer     .dsb 1  ; frame counter for flicker / rock animation

; Season system
season            .dsb 1  ; current season 0-3
seasonGoal        .dsb 1  ; veggies per season (0 = disabled)
season_veggie_count .dsb 1  ; basket count toward next season change
season_pal_offset .dsb 1  ; precomputed season*4 (0/4/8/12); indexes season_pal3_colors

; BG palette 3 color cache - 4-byte RAM cache written by UpdateSeasons on each
; season change and seeded from season_pal3_colors at init.
; NMI reads these to upload BG palette 3 each frame. Palettes 0-2 are fixed.
season_pal3_c0  .dsb 1
season_pal3_c1  .dsb 1
season_pal3_c2  .dsb 1
season_pal3_c3  .dsb 1

; Basket sparkle animation - 2 BG tiles above the basket cycle $6D/$6E/$6F
; for 60 frames (1 second) after a successful veggie score.
basket_anim_timer  .dsb 1  ; 60->0 countdown; 0 = idle
basket_anim_ppu_hi .dsb 1  ; PPU address high byte of animated tile
basket_anim_ppu_lo .dsb 1  ; PPU address low byte of the sparkle tile
sfx_walk_timer     .dsb 1  ; frames until next walk SFX retrigger (0 = fire now)
sfx_fly_timer0     .dsb 1  ; frames until next fly SFX retrigger for weevil0
sfx_fly_timer1     .dsb 1  ; frames until next fly SFX retrigger for weevil1
nmi_title_mode     .dsb 1  ; 1 = title-screen NMI (minimal path), 0 = game NMI
; Performance flags
palette_dirty      .dsb 1  ; 1 = BG palette 3 needs uploading next NMI
lastPlayerFacing   .dsb 1  ; cached facing for UpdateSpriteAttrs early-out ($FF = invalid/first frame)
; AllPlantsGone cache
plants_all_gone    .dsb 1  ; cached result: $00 = all gone (Z=1), $01 = plants remain (Z=0)
plants_dirty       .dsb 1  ; $01 = cache invalid, must rescan next call to AllPlantsGone
.ende
