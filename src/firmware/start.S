// PicoRV32 crt0 + interrupt vector for the PCXT disk / OSD softcore.
//
// Reset lands at _start (ROM base); the interrupt vector sits at 0x10 (PROGADDR_IRQ).
// The vector saves the interrupted context to irq_regs, calls the C handler irq(), then
// restores and returns. The built-in timer raises a periodic interrupt so the OSD is
// serviced on a fixed cadence no matter what the disk service is doing; timer_start()
// and irq_mask() wrap the picorv32 custom instructions the C code arms it with.

#include "custom_ops.S"

.text
.globl _start
.p2align 2
.type _start,@function
_start:
    // At most 16 bytes here: irq_vec must land at PROGADDR_IRQ (0x10).
    j start

.balign 16
irq_vec:
    // The CPU has saved the return PC in q0 and the IRQ mask in q1. Stash x1/x2 in the
    // scratch q-regs so they can be reused to save the rest of the context to irq_regs.
    picorv32_setq_insn(q2, x1)
    picorv32_setq_insn(q3, x2)

    lui x1, %hi(irq_regs)
    addi x1, x1, %lo(irq_regs)

    picorv32_getq_insn(x2, q0)
    sw x2, 0*4(x1)
    picorv32_getq_insn(x2, q2)
    sw x2, 1*4(x1)
    picorv32_getq_insn(x2, q3)
    sw x2, 2*4(x1)

    sw x3,   3*4(x1)
    sw x4,   4*4(x1)
    sw x5,   5*4(x1)
    sw x6,   6*4(x1)
    sw x7,   7*4(x1)
    sw x8,   8*4(x1)
    sw x9,   9*4(x1)
    sw x10, 10*4(x1)
    sw x11, 11*4(x1)
    sw x12, 12*4(x1)
    sw x13, 13*4(x1)
    sw x14, 14*4(x1)
    sw x15, 15*4(x1)
    sw x16, 16*4(x1)
    sw x17, 17*4(x1)
    sw x18, 18*4(x1)
    sw x19, 19*4(x1)
    sw x20, 20*4(x1)
    sw x21, 21*4(x1)
    sw x22, 22*4(x1)
    sw x23, 23*4(x1)
    sw x24, 24*4(x1)
    sw x25, 25*4(x1)
    sw x26, 26*4(x1)
    sw x27, 27*4(x1)
    sw x28, 28*4(x1)
    sw x29, 29*4(x1)
    sw x30, 30*4(x1)
    sw x31, 31*4(x1)

    // irq(regs, irq_bits)
    lui a0, %hi(irq_regs)
    addi a0, a0, %lo(irq_regs)
    picorv32_getq_insn(a1, q1)
    jal ra, irq

    // irq() returns the (possibly new) context pointer in a0; restore from it.
    addi x1, a0, 0

    lw x2, 0*4(x1)
    picorv32_setq_insn(q0, x2)
    lw x2, 1*4(x1)
    picorv32_setq_insn(q1, x2)
    lw x2, 2*4(x1)
    picorv32_setq_insn(q2, x2)

    lw x3,   3*4(x1)
    lw x4,   4*4(x1)
    lw x5,   5*4(x1)
    lw x6,   6*4(x1)
    lw x7,   7*4(x1)
    lw x8,   8*4(x1)
    lw x9,   9*4(x1)
    lw x10, 10*4(x1)
    lw x11, 11*4(x1)
    lw x12, 12*4(x1)
    lw x13, 13*4(x1)
    lw x14, 14*4(x1)
    lw x15, 15*4(x1)
    lw x16, 16*4(x1)
    lw x17, 17*4(x1)
    lw x18, 18*4(x1)
    lw x19, 19*4(x1)
    lw x20, 20*4(x1)
    lw x21, 21*4(x1)
    lw x22, 22*4(x1)
    lw x23, 23*4(x1)
    lw x24, 24*4(x1)
    lw x25, 25*4(x1)
    lw x26, 26*4(x1)
    lw x27, 27*4(x1)
    lw x28, 28*4(x1)
    lw x29, 29*4(x1)
    lw x30, 30*4(x1)
    lw x31, 31*4(x1)

    picorv32_getq_insn(x1, q1)
    picorv32_getq_insn(x2, q2)
    picorv32_retirq_insn()

.balign 4
start:
    // Clear .bss
    la   x26, _bss_start
    la   x27, _bss_end
1:  beq  x26, x27, 2f
    sb   x0, 0(x26)
    addi x26, x26, 1
    j    1b
2:
    // Copy .data from ROM to RAM
    la   x26, _idata_start
    la   x27, _data_start
    la   x28, _data_end
3:  beq  x27, x28, 4f
    lb   x10, 0(x26)
    sb   x10, 0(x27)
    addi x26, x26, 1
    addi x27, x27, 1
    j    3b
4:
    // Set the stack and enter main()
    la   sp, __stacktop
    call main
5:  j    5b

.globl timer_start
.p2align 2
.type timer_start,@function
timer_start:
    picorv32_timer_insn(zero, a0)
    ret

.globl irq_mask
.p2align 2
.type irq_mask,@function
irq_mask:
    picorv32_maskirq_insn(zero, a0)
    ret

.bss
.balign 4
irq_regs:
    // The interrupted context is saved here while an interrupt runs; slot 0 is the PC.
    .fill 32, 4
