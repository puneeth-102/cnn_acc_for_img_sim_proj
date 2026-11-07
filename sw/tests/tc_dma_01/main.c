/* =============================================================================
 * File   : sw/tests/tc_dma_01/main.c
 * Test   : TC_DMA_01 - DMA Register R/W & Reset Verification
 * Purpose: Verify reset defaults (0x0) and read/write accessibility of all DMA
 *          configuration registers (CTRL, STATUS, SRC_ADDR, DST_ADDR, LENGTH).
 * Checkpoint:
 *          CTRL and STATUS read 0x0 on reset. Writes to SRC, DST, and LEN retain
 *          values under standard AXI-Lite access without bus traps or corruption.
 * ============================================================================= */

#include "soc_regs.h"

int main(void) {
    // 1. Initialize UART for console reporting
    uart_init(16);
    uart_puts("\n[TC_DMA_01] Start\n");

    // 2. Step 1: Verify Reset Defaults
    if (DMA_CTRL != 0x00000000UL || DMA_STATUS != 0x00000000UL) {
        test_fail("TC_DMA_01", "Reset defaults mismatch");
        while (1);
    }
    uart_puts("[TC_DMA_01] Reset defaults OK\n");

    // 3. Step 2: Write Test Addresses & Length per Test Plan
    DMA_SRC_ADDR = 0x10000100UL;
    DMA_DST_ADDR = 0x20003100UL;
    DMA_LENGTH   = 64UL;

    // 4. Step 3: Read back and assert equality
    if (DMA_SRC_ADDR != 0x10000100UL || DMA_DST_ADDR != 0x20003100UL || DMA_LENGTH != 64UL) {
        test_fail("TC_DMA_01", "Readback mismatch");
        while (1);
    }
    uart_puts("[TC_DMA_01] Reg R/W OK\n");

    // 5. Step 4: Write-pattern stress to verify bit independence
    DMA_SRC_ADDR = 0x100055AAUL;
    DMA_DST_ADDR = 0x2000AA55UL;
    DMA_LENGTH   = 128UL;

    if (DMA_SRC_ADDR != 0x100055AAUL || DMA_DST_ADDR != 0x2000AA55UL || DMA_LENGTH != 128UL) {
        test_fail("TC_DMA_01", "Bit-pattern mismatch");
        while (1);
    }

    // Restore final required values for hardware flip-flop check
    DMA_SRC_ADDR = 0x10000100UL;
    DMA_DST_ADDR = 0x20003100UL;
    DMA_LENGTH   = 64UL;

    // 6. Test Passed
    test_pass("TC_DMA_01");

    while (1);
    return 0;
}
