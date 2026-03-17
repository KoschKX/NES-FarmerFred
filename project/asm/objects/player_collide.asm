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

	; if Down+B held, allow drop through one-way platforms
	LDA joy1_curr
	AND #$22
	CMP #$22
	BNE DoProbes         ; buttons not held → normal collision
	LDA tile_row
	CMP #58
	BCS DoProbes         ; tile_row >= 58 → ground floor, always solid
	; Down+B held and not at ground floor → drop-mode probe
	JMP DoProbesDropMode

DoProbes:
	; center-bottom sprite tile probe
	LDA $0323
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
	LSR A
	LSR A
	LSR A
	STA tile_col
	JSR CFS_GetTileByColRow
	LDA TileID
	TAX
	LDA collision_table, x
	AND #$02               ; bit 1 = "full solid" flag
	BEQ DropThroughSkip    ; not full-solid → allow drop-through
	JMP DoProbes           ; full-solid tile → normal collision

DropThroughSkip
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
@NoRightHit:

	; top: always passable from below (topCollision stays 0)
@NoTopHit:
	; restore tile_row/tile_col for ApplyGravity
	PLA
	STA tile_col
	PLA
	STA tile_row
	RTS