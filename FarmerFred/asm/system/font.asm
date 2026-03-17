; font.asm -- PT0 tile indices for all font characters.
; Included from system.asm so constants are available everywhere.
;
; Layout in graphics_a.chr (PT0):
;   1-9  = $05-$0D
;   :    = $0E
;   A-Z  = $10-$29  (A=$10 ... Z=$29; 0 shares glyph with O at $1E)

; Letters A-Z  (PT0 $10-$29)
font_A = $10
font_B = $11
font_C = $12
font_D = $13
font_E = $14
font_F = $15
font_G = $16
font_H = $17
font_I = $18
font_J = $19
font_K = $1A
font_L = $1B
font_M = $1C
font_N = $1D
font_O = $1E
font_P = $1F
font_Q = $20
font_R = $21
font_S = $22
font_T = $23
font_U = $24
font_V = $25
font_W = $26
font_X = $27
font_Y = $28
font_Z = $29

; Digits 0-9
font_0 = $1E  ; shares glyph with O
font_1 = $05
font_2 = $06
font_3 = $07
font_4 = $08
font_5 = $09
font_6 = $0A
font_7 = $0B
font_8 = $0C
font_9 = $0D

; Punctuation / symbols
font_colon = $0E   ; :
font_arrow_up = $2A   ; :
font_space  = $00  ; blank tile