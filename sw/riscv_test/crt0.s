/* =============================================================================
 * Startup code for VeeR-EL2 CPU (RV32IMC)
 * ============================================================================= */

.section .text.init
.align 4
.global _start

_start:
    /* 1. Set trap vector */
    la   t0, _trap
    csrw mtvec, t0

    /* 2. Configure Memory Region Access Control (MRAC, CSR 0x7C0)
     * Region 0 (0x0000_0000, IMEM)             -> side_effect = 1, cacheable = 0 (2'b10)
     * Region 1 (0x1000_0000, DMEM)             -> side_effect = 1, cacheable = 0 (2'b10)
     * Region 2 (0x2000_0000, MMIO peripherals) -> side_effect = 1, cacheable = 0 (2'b10)
     * Regions 3..15                            -> side_effect = 0, cacheable = 1 (2'b01)
     * Full MRAC = 0x5555556A
     */
    li   t0, 0x5555556A
    csrw 0x7c0, t0
    fence
    fence.i

    /* 3. Initialize Stack Pointer to top of DMEM stack */
    la   sp, _stack_top

    /* 4. Copy .data section from IMEM to DMEM */
    la   a0, _sidata
    la   a1, _sdata
    la   a2, _edata
1:  bge  a1, a2, 2f
    lw   t0, 0(a0)
    sw   t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j    1b
2:

    /* 5. Zero out .bss section in DMEM */
    la   a0, _sbss
    la   a1, _ebss
3:  bge  a0, a1, 4f
    sw   zero, 0(a0)
    addi a0, a0, 4
    j    3b
4:

    /* 6. Jump to main() */
    call main

    /* 7. Trap/halt loop on exit */
_exit_loop:
    wfi
    j    _exit_loop

.align 4
_trap:
    /* Trap handler: loop indefinitely */
    j    _trap
