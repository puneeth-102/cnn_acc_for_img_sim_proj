/* =============================================================================
 * File   : sw/riscv_test/interactive_echo.c
 * Purpose: Closed-loop interactive UART test for VeeR-EL2 SoC.
 *          1. CPU initializes UART and prints ready prompt.
 *          2. Waits for external UVM Driver to send an ASCII character on uart_rx_i.
 *          3. CPU reads received character, computes an operation (echo + GPIO update),
 *             and transmits response back over uart_tx_o.
 * ============================================================================= */

#include <stdint.h>

#define UART_BASE           0x20000000UL
#define UART_RBR            (*(volatile uint32_t*)(UART_BASE + 0x00))
#define UART_THR            (*(volatile uint32_t*)(UART_BASE + 0x00))
#define UART_IER            (*(volatile uint32_t*)(UART_BASE + 0x04))
#define UART_BAUD_DIV       (*(volatile uint32_t*)(UART_BASE + 0x08))
#define UART_LCR            (*(volatile uint32_t*)(UART_BASE + 0x0C))
#define UART_LSR            (*(volatile uint32_t*)(UART_BASE + 0x14))

#define UART_LSR_DR         (1 << 0) // Data Ready
#define UART_LSR_THRE       (1 << 5) // Transmitter Holding Register Empty

#define GPIO_BASE           0x20002000UL
#define GPIO_EN             (*(volatile uint32_t*)(GPIO_BASE + 0x80))
#define GPIO_OUT            (*(volatile uint32_t*)(GPIO_BASE + 0x180))

#define MAILBOX_REG         (*(volatile uint32_t*)(0x1000FF00UL))

void uart_init(uint32_t baud_div) {
    UART_LCR = 0x80;        // Enable DLAB
    UART_BAUD_DIV = baud_div;
    UART_LCR = 0x03;        // 8N1
    UART_IER = 0x01;        // Enable RX Data Ready flag & interrupt
}

void uart_putc(char c) {
    while ((UART_LSR & UART_LSR_THRE) == 0);
    UART_THR = (uint32_t)(uint8_t)c;
}

void uart_puts(const char *s) {
    while (*s) {
        if (*s == '\n') uart_putc('\r');
        uart_putc(*s++);
    }
}

char uart_getc(void) {
    // Wait until character arrives in RX FIFO (LSR bit 0 = 1)
    while ((UART_LSR & UART_LSR_DR) == 0);
    return (char)(UART_RBR & 0xFF);
}

int main(void) {
    // 1. Initialize UART (Divisor 16 for 170 ns bit period)
    uart_init(16);
    GPIO_EN = 0x000000FF;
    GPIO_OUT = 0x00000001; // Stage 1: Waiting for Driver Input

    // 2. Announce ready state
    uart_puts("READY\r\n");

    // 3. Receive character sent by UVM Driver through uart_rx_i pin
    char rx_char = uart_getc();

    // 4. Echo response back over uart_tx_o
    uart_puts("Echo: ");
    uart_putc(rx_char);
    uart_puts("\r\n");

    // 5. Update GPIO output with received character code
    GPIO_OUT = (uint32_t)(uint8_t)rx_char;
    MAILBOX_REG = (uint32_t)(uint8_t)rx_char;

    // 6. Idle loop
    while (1);

    return 0;
}
