/* =============================================================================
 * File   : sw/riscv_test/simple_test.c
 * Purpose: End-to-end RISC-V CPU to UART verification test.
 *          Performs arithmetic (10 + 20 - 5 = 25) and transmits the actual
 *          result through the memory-mapped UART.
 * Expected Serial Output: Result = 25
 * ============================================================================= */

#include <stdint.h>

// -----------------------------------------------------------------------------
// Peripheral Base Addresses & Registers (per SoC Memory Map)
// -----------------------------------------------------------------------------
#define UART_BASE           0x20000000UL
#define UART_RBR            (*(volatile uint32_t*)(UART_BASE + 0x00))
#define UART_THR            (*(volatile uint32_t*)(UART_BASE + 0x00))
#define UART_IER            (*(volatile uint32_t*)(UART_BASE + 0x04))
#define UART_BAUD_DIV       (*(volatile uint32_t*)(UART_BASE + 0x08))
#define UART_LCR            (*(volatile uint32_t*)(UART_BASE + 0x0C))
#define UART_LSR            (*(volatile uint32_t*)(UART_BASE + 0x14))
#define UART_LSR_THRE       (1 << 5)

#define GPIO_BASE           0x20002000UL
#define GPIO_EN             (*(volatile uint32_t*)(GPIO_BASE + 0x80))
#define GPIO_OUT            (*(volatile uint32_t*)(GPIO_BASE + 0x180))

#define MAILBOX_REG         (*(volatile uint32_t*)(0x1000FF00UL))

// -----------------------------------------------------------------------------
// UART Driver Functions
// -----------------------------------------------------------------------------
void uart_init(uint32_t baud_div) {
    UART_LCR = 0x80;        // Enable DLAB to configure baud divisor
    UART_BAUD_DIV = baud_div;
    UART_LCR = 0x03;        // 8 data bits, 1 stop bit, no parity (8N1)
}

void uart_putc(char c) {
    // Poll Line Status Register until Transmitter Holding Register is Empty (THRE)
    while ((UART_LSR & UART_LSR_THRE) == 0);
    UART_THR = (uint32_t)(uint8_t)c;
}

void uart_puts(const char *s) {
    while (*s) {
        if (*s == '\n') uart_putc('\r');
        uart_putc(*s++);
    }
}

void uart_print_dec(int val) {
    if (val < 0) {
        uart_putc('-');
        val = -val;
    }
    if (val == 0) {
        uart_putc('0');
        return;
    }
    char buf[12];
    int idx = 0;
    while (val > 0) {
        buf[idx++] = '0' + (val % 10);
        val /= 10;
    }
    for (int i = idx - 1; i >= 0; i--) {
        uart_putc(buf[i]);
    }
}

// -----------------------------------------------------------------------------
// Main Test Program
// -----------------------------------------------------------------------------
int main(void) {
    // 1. Initialize UART (divisor = 16 matches testbench BIT_PERIOD_NS = 170.0 ns)
    uart_init(16);

    // 2. Perform arithmetic calculation: 10 + 20 - 5 = 25
    volatile int a = 10;
    volatile int b = 20;
    volatile int c;

    c = a + b;
    c = c - 5;

    // 3. Transmit the actual result through memory-mapped UART
    // Serial Output: Result = 25
    uart_puts("Result = ");
    uart_print_dec(c);
    uart_puts("\r\n");

    // 4. Update GPIO and Mailbox for verification handshake
    GPIO_EN  = 0x000000FF;  // Configure lower 8 pins as output
    GPIO_OUT = 0x00000025;  // Indicate pass code 0x25 (37 decimal) / result 25 BCD
    MAILBOX_REG = (uint32_t)c; // Store computed 25 in DMEM mailbox

    // 5. Idle loop
    while (1);

    return 0;
}
