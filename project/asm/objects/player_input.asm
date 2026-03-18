HandlePlayerInput:
	; If grab animation is active, skip all input
	LDA grabTimer
	BEQ @noGrabFreeze
	DEC grabTimer
	BNE @grabStillActive
	; grabTimer just hit 0 — end pickup pose
	LDA #$00
	STA playerFrame
@grabStillActive:
	LDA #$00
	STA playerMoving
	RTS
@noGrabFreeze:
	; clear movement flag each frame
	LDA #$00
	STA playerMoving

	; store B-held as $40 or $00
	LDA joy1_curr
	AND #$40
	STA playerBheld
@B_AfterHeld:

	; If A is held and grounded, freeze movement (pickup pose)
	LDA joy1_curr
	AND #$80
	BEQ @noPickupFreeze
	LDA playerGrounded
	BEQ @noPickupFreeze
	RTS
@noPickupFreeze:

	; Left/Right handling and sprite shifts
	LDA joy1_curr
	AND #$02
	BNE @TryLeft
	JMP @CheckRight
@TryLeft:
	; left: block if wall on left
	LDA leftCollision
	BEQ @doLeftOk
	JMP @AfterLR
@doLeftOk:
	LDA #$01
	STA playerFacing
	LDA #$01
	STA playerMoving
	; subtract, wrap left if underflowed
	LDA player_world_x_low
	SEC
	SBC #$02
	CMP #$F0
	BCS @wrapLeft
	STA player_world_x_low
	JMP @AfterLR
@wrapLeft:
	LDA #$E8
	STA player_world_x_low
	JMP @AfterLR
@CheckRight:
	LDA joy1_curr
	AND #$01
	BEQ @AfterLR
	; right: block if wall on right
	LDA rightCollision
	BNE @AfterLR
	LDA #$00
	STA playerFacing
	LDA #$01
	STA playerMoving
	; add, wrap right if overflowed
	LDA player_world_x_low
	CLC
	ADC #$02
	CMP #$F0
	BCS @wrapRight
	STA player_world_x_low
	JMP @AfterLR
@wrapRight:
	LDA #$00
	STA player_world_x_low
@AfterLR:
	; Walk SFX: retrigger when grounded and moving
	LDA playerMoving
	BEQ @sfx_not_walking
	LDA playerGrounded
	BEQ @sfx_not_walking
	; grounded and moving: count down timer
	LDA sfx_walk_timer
	BEQ @sfx_walk_fire
	DEC sfx_walk_timer
	JMP @sfx_walk_done
@sfx_walk_fire:
	LDA #$00              ; SFX index 0 = walk
	LDX #FAMISTUDIO_SFX_CH0
	JSR famistudio_sfx_play
	LDA #18               ; ~18 frames matches walk SFX length
	STA sfx_walk_timer
	JMP @sfx_walk_done
@sfx_not_walking:
	LDA #$00              ; reset timer so next step fires immediately
	STA sfx_walk_timer
@sfx_walk_done:
	; Jump button logic
	JMP HandlePlayerJump