levels:
  level_001:
    .incbin "map/level_001.map"
level_001_end:
level_001_len_low:  .db <(level_001_end - level_001)
level_001_len_high: .db >(level_001_end - level_001)

