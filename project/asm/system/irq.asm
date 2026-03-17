; irq.asm — MMC3 IRQ handler stub
; The IRQ vector in vectors.asm points to 0 (disabled), so this handler
; is never actually called. It exists to satisfy the .include in setup.asm.
IRQ_STUB:
  RTI
