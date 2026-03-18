PlayerCheckCollisions:
	JSR GetBottomCenterTile
	JMP CheckSideAndTopCollisions

GetBottomCenterTile:
	; tile_row from player world Y + 12
	LDA player_world_y_low
	CLC
	ADC #$0C
	STA tmp_qy
	LDA player_world_y_high
	ADC #$00
	ASL A
	ASL A
	ASL A
	ASL A
	ASL A
	STA tile_row
	LDA tmp_qy
	LSR A
	LSR A
	LSR A
	ORA tile_row
	STA tile_row

	; if Down+B held (and not dead), allow drop through one-way platforms
	LDA playerDead
	BNE DoProbes             ; dead → always normal collision
	LDA joy1_curr
	AND #$44
	CMP #$44
	BNE DoProbes         ; buttons not held → normal collision
	LDA tile_row
	CMP #58
	BCS DoProbes         ; tile_row >= 58 → ground floor, always solid
	; Down+B held and not at ground floor → drop-mode probe
	JMP DoProbesDropMode

DoProbes:
	; center-bottom sprite tile probe (+4 to sample centre of 8px sprite)
	LDA $0323
	CLC
	ADC #$04
	LSR A
	LSR A
	LSR A
	STA tile_col
	JSR CFS_GetTileByColRow
	LDA TileID
	STA bottomCenterTile
	TAX
	LDA collision_table, x
	STA tmp_col           ; save full flag byte
	AND #$01
	STA bottomCenterCollision
	LDA tmp_col
	AND #$02
	BEQ @No02Solid
	LDA #$01
	STA bottomCenterCollision
@No02Solid:

	; $02 tiles: treat as solid surface

	; Ground rows 58-59 are always solid — override any non-solid tile result.
	LDA tile_row
	CMP #58
	BCC @NotGroundRow
	LDA #58
	STA tile_row          ; clamp to surface row so snap lands on top
	LDA #$01
	STA bottomCenterCollision
@NotGroundRow:
	LDA TileID
	AND #$0F
	STA bottomCenterCHR

ProbesDone:
	RTS


DoProbesDropMode:
	; Down+B: allow drop-through if tile is one-way (bit 1 clear)
	LDA $0323
	CLC
	ADC #$04
	LSR A
	LSR A
	LSR A
	STA tile_col
	JSR CFS_GetTileByColRow
	LDA TileID
	TAX
	LDA collision_table, x
	AND #$02               ; bit 1 = "full solid" flag
	BNE DoProbes           ; full-solid tile → normal collision
	; Only play SFX if player is on a $01 tile (one-way platform)
	; Fire on the first frame either Down or B is newly pressed while both are held
	LDA collision_table, x
	AND #$01
	BEQ @no_sfx
	LDA joy1_pressed
	AND #$44               ; Down or B newly pressed this frame
	BEQ @no_sfx
	LDA #$06
	LDX #FAMISTUDIO_SFX_CH1
	JSR famistudio_sfx_play
@no_sfx:
	LDA #$00
	STA bottomCenterCollision
	STA bottomCenterTile
	STA bottomCenterCHR
	RTS

; CheckSideAndTopCollisions
; Sets leftCollision, rightCollision, topCollision (0 or 1).
CheckSideAndTopCollisions:
	; save tile_row/tile_col for ApplyGravity restore
	LDA tile_row
	PHA
	LDA tile_col
	PHA
	; remember whether the bottom probe already set bottomCenterCollision;
	; used at the end to decide which tile_row to snap to (bottom vs side probe row)
	LDA bottomCenterCollision
	STA tmp_high

	LDA #$00
	STA leftCollision
	STA rightCollision
	STA topCollision

	; left probe: mid-body Y, left sprite edge
	; Y = player_world_y + $04
	LDA player_world_y_low
	CLC
	ADC #$04
	STA tmp_qy
	LDA player_world_y_high
	ADC #$00
	ASL A
	ASL A
	ASL A
	ASL A
	ASL A
	STA tile_row
	LDA tmp_qy
	LSR A
	LSR A
	LSR A
	ORA tile_row
	STA tile_row
	LDA $0307             ; leftmost sprite X
	LSR A
	LSR A
	LSR A
	STA tile_col
	JSR CFS_GetTileByColRow
	LDA TileID
	TAX
	LDA collision_table, X
	AND #$02
	BEQ @NoLeftHit
	LDA #$01
	STA leftCollision
	; only correct position when falling diagonally into the tile
	LDA playerVelocityY
	BEQ @NoLeftHit
	BMI @NoLeftHit
	; skip snap if tile_col is too close to right edge (col*8+8 would overflow)
	LDA tile_col
	CMP #$1D               ; >= 29: result >= 240 px, skip
	BCS @NoLeftHit
	; snap X: push player right so left sprite edge clears this tile column
	LDA tile_col
	ASL A
	ASL A
	ASL A          ; tile_col * 8
	CLC
	ADC #$08       ; (tile_col+1)*8 — left edge of first clear column
	STA player_world_x_low
	LDA #$01
	STA bottomCenterCollision
@NoLeftHit:

	; right probe: same Y, rightmost sprite + 7
	LDA $030F             ; rightmost sprite X
	CLC
	ADC #$07              ; true right edge (sprite is 8px wide)
	LSR A
	LSR A
	LSR A
	STA tile_col
	JSR CFS_GetTileByColRow
	LDA TileID
	TAX
	LDA collision_table, X
	AND #$02
	BEQ @NoRightHit
	LDA #$01
	STA rightCollision
	; only correct position when falling diagonally into the tile
	LDA playerVelocityY
	BEQ @NoRightHit
	BMI @NoRightHit
	; skip snap if tile_col < 3 (tile_col*8-24 would underflow and teleport right)
	LDA tile_col
	CMP #$03               ; < 3: snap would underflow, skip
	BCC @NoRightHit
	; snap X: push player left so right sprite edge (world_x+23) clears this column
	LDA tile_col
	ASL A
	ASL A
	ASL A          ; tile_col * 8
	SEC
	SBC #$18       ; tile_col*8 - 24 → right edge lands at tile_col*8-1
	STA player_world_x_low
	LDA #$01
	STA bottomCenterCollision
@NoRightHit:

	; top probe: test for full-solid tile directly above the player's head
@NoTopHit:
	LDA player_world_y_high
	BNE @uh_top_calc         ; high != 0: safe to subtract
	LDA player_world_y_low
	BEQ @uh_top_done         ; exactly at world top: skip
@uh_top_calc:
	LDA player_world_y_low
	SEC
	SBC #$01
	STA tmp_qy
	LDA player_world_y_high
	SBC #$00
	ASL A
	ASL A
	ASL A
	ASL A
	ASL A
	STA tile_row
	LDA tmp_qy
	LSR A
	LSR A
	LSR A
	ORA tile_row
	STA tile_row
	CMP #59              ; clamp if out of level range
	BCS @uh_top_done
	LDA $0307            ; leftmost sprite X
	CLC
	ADC #$0C             ; +12 = horizontal midpoint of 24px sprite
	LSR A
	LSR A
	LSR A
	STA tile_col
	JSR CFS_GetTileByColRow
	LDA TileID
	TAX
	LDA collision_table, X
	AND #$02             ; full-solid tiles only (bit 1)
	BEQ @uh_top_done
	LDA #$01
	STA topCollision
@uh_top_done:
	; restore tile_col always
	PLA
	STA tile_col
	; if the side probe forced bottomCenterCollision (bottom probe had not set it),
	; keep tile_row as the side-probe row so the snap lands on the correct tile.
	; otherwise restore the bottom-probe tile_row for normal snapping.
	LDA tmp_high              ; was bottomCenterCollision set before side probes?
	BNE @restore_tile_row     ; yes → use bottom probe's tile_row
	LDA bottomCenterCollision
	BEQ @restore_tile_row     ; neither set → use bottom probe's tile_row
	; side probe forced the snap: tile_row is already the side-probe row —
	; discard the stacked bottom-probe tile_row and return with side row
	PLA
	RTS
@restore_tile_row:
	PLA
	STA tile_row
	RTS