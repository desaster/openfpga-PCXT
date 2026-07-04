// PicoRV32 crt0 for the PCXT disk softcore.
//
// Reset lands at _start (ROM base). Clear .bss, copy .data from ROM to RAM,
// set the stack, and call main(). Interrupts are unused (the softcore is
// instantiated with ENABLE_IRQ=0), so there is no IRQ vector or custom-op glue.

.text
.globl _start
.p2align 2
.type _start,@function
_start:
    j start

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
