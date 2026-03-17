; Vectors must be emitted after all code so forward labels resolve
  .org $FFFA
  .dw NMI
  .dw Reset
  .dw IRQ_STUB
