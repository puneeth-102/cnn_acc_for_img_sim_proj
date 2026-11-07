#ifndef SOC_REGS_H
#define SOC_REGS_H

#include <stdint.h>

// =============================================================================
// Memory Map Base Addresses (Per SoC Architecture Specification)
// =============================================================================
#define IMEM_BASE           0x00000000UL // M00: 64 KB Instruction Memory
#define DMEM_BASE           0x10000000UL // M01: 64 KB Data Memory
#define UART_BASE           0x20000000UL // M02: 4 KB UART Peripheral
#define TIMER_BASE          0x20001000UL // M03: 4 KB 64-bit RV Timer
#define GPIO_BASE           0x20002000UL // M04: 4 KB GPIO Controller
#define CNN_BASE            0x20003000UL // M05: 4 KB CNN Accelerator
#define DIST_BASE           0x20004000UL // M06: 4 KB Distance / Anomaly Checker
#define DMA_BASE            0x20005000UL // M07: 4 KB DMA Controller
#define MAILBOX_ADDR        0x1000FF00UL // Dedicated Verification Mailbox in DMEM

// =============================================================================
// UART Registers (0x2000_0000)
// =============================================================================
#define UART_RBR            (*(volatile uint32_t*)(UART_BASE + 0x00))
#define UART_THR            (*(volatile uint32_t*)(UART_BASE + 0x00))
#define UART_IER            (*(volatile uint32_t*)(UART_BASE + 0x04))
#define UART_BAUD_DIV       (*(volatile uint32_t*)(UART_BASE + 0x08))
#define UART_LCR            (*(volatile uint32_t*)(UART_BASE + 0x0C))
#define UART_LSR            (*(volatile uint32_t*)(UART_BASE + 0x14))
#define UART_LSR_DR         (1 << 0) // Data Ready
#define UART_LSR_THRE       (1 << 5) // Transmitter Holding Register Empty
#define UART_LSR_TEMT       (1 << 6) // Transmitter Empty (Shift Register Empty)

// =============================================================================
// GPIO Registers (0x2000_2000)
// =============================================================================
#define GPIO_INFO           (*(volatile uint32_t*)(GPIO_BASE + 0x000))
#define GPIO_CFG            (*(volatile uint32_t*)(GPIO_BASE + 0x004))
#define GPIO_EN             (*(volatile uint32_t*)(GPIO_BASE + 0x080))
#define GPIO_IN             (*(volatile uint32_t*)(GPIO_BASE + 0x100))
#define GPIO_OUT            (*(volatile uint32_t*)(GPIO_BASE + 0x180))
#define GPIO_SET            (*(volatile uint32_t*)(GPIO_BASE + 0x200))
#define GPIO_CLEAR          (*(volatile uint32_t*)(GPIO_BASE + 0x280))
#define GPIO_TOGGLE         (*(volatile uint32_t*)(GPIO_BASE + 0x300))
#define GPIO_RISE_EN        (*(volatile uint32_t*)(GPIO_BASE + 0x380))
#define GPIO_FALL_EN        (*(volatile uint32_t*)(GPIO_BASE + 0x400))
#define GPIO_HIGH_EN        (*(volatile uint32_t*)(GPIO_BASE + 0x480))
#define GPIO_LOW_EN         (*(volatile uint32_t*)(GPIO_BASE + 0x500))
#define GPIO_STATUS         (*(volatile uint32_t*)(GPIO_BASE + 0x580))

// =============================================================================
// DMA Registers (0x2000_5000)
// =============================================================================
#define DMA_CTRL            (*(volatile uint32_t*)(DMA_BASE + 0x00))
#define DMA_STATUS          (*(volatile uint32_t*)(DMA_BASE + 0x04))
#define DMA_SRC_ADDR        (*(volatile uint32_t*)(DMA_BASE + 0x08))
#define DMA_DST_ADDR        (*(volatile uint32_t*)(DMA_BASE + 0x0C))
#define DMA_LENGTH          (*(volatile uint32_t*)(DMA_BASE + 0x10))
#define DMA_ERROR_CODE      (*(volatile uint32_t*)(DMA_BASE + 0x14))

#define DMA_CTRL_START      (1 << 0)
#define DMA_CTRL_RESET      (1 << 1)
#define DMA_CTRL_IRQ_EN     (1 << 2)

#define DMA_STATUS_BUSY     (1 << 0)
#define DMA_STATUS_DONE     (1 << 1)
#define DMA_STATUS_ERROR    (1 << 2)

// =============================================================================
// Timer Registers (0x2000_1000)
// =============================================================================
#define TIMER_CTRL          (*(volatile uint32_t*)(TIMER_BASE + 0x00))
#define TIMER_STATUS        (*(volatile uint32_t*)(TIMER_BASE + 0x04))
#define TIMER_INTR_EN       (*(volatile uint32_t*)(TIMER_BASE + 0x08))
#define TIMER_INTR_STATE    (*(volatile uint32_t*)(TIMER_BASE + 0x0C))
#define TIMER_CFG           (*(volatile uint32_t*)(TIMER_BASE + 0x10))
#define TIMER_MTIME_LO      (*(volatile uint32_t*)(TIMER_BASE + 0x14))
#define TIMER_MTIME_HI      (*(volatile uint32_t*)(TIMER_BASE + 0x18))
#define TIMER_MTIMECMP_LO   (*(volatile uint32_t*)(TIMER_BASE + 0x1C))
#define TIMER_MTIMECMP_HI   (*(volatile uint32_t*)(TIMER_BASE + 0x20))
#define TIMER_ERROR_CODE    (*(volatile uint32_t*)(TIMER_BASE + 0x24))

// =============================================================================
// CNN Accelerator Registers (0x2000_3000)
// =============================================================================
#define CNN_CTRL            (*(volatile uint32_t*)(CNN_BASE + 0x00))
#define CNN_STATUS          (*(volatile uint32_t*)(CNN_BASE + 0x04))
#define CNN_IMG_ADDR        (*(volatile uint32_t*)(CNN_BASE + 0x08))
#define CNN_WT_ADDR         (*(volatile uint32_t*)(CNN_BASE + 0x0C))
#define CNN_EMB_ADDR        (*(volatile uint32_t*)(CNN_BASE + 0x10))
#define CNN_DIM_CFG         (*(volatile uint32_t*)(CNN_BASE + 0x14))
#define CNN_EMBED_LEN       (*(volatile uint32_t*)(CNN_BASE + 0x18))
#define CNN_ERROR_CODE      (*(volatile uint32_t*)(CNN_BASE + 0x1C))
#define CNN_EMBED_REG(i)    (*(volatile uint32_t*)(CNN_BASE + 0x20 + ((i) * 4)))
#define CNN_BUF_REG(i)      (*(volatile uint32_t*)(CNN_BASE + 0x100 + ((i) * 4)))

#define CNN_CTRL_START      (1 << 0)
#define CNN_CTRL_RESET      (1 << 1)
#define CNN_CTRL_IRQ_EN     (1 << 2)

#define CNN_STATUS_BUSY     (1 << 0)
#define CNN_STATUS_DONE     (1 << 1)
#define CNN_STATUS_ERROR    (1 << 2)

// =============================================================================
// Distance / Anomaly Checker Registers (0x2000_4000)
// =============================================================================
#define DIST_CTRL           (*(volatile uint32_t*)(DIST_BASE + 0x00))
#define DIST_STATUS         (*(volatile uint32_t*)(DIST_BASE + 0x04))
#define DIST_EMB_ADDR       (*(volatile uint32_t*)(DIST_BASE + 0x08))
#define DIST_REF_ADDR       (*(volatile uint32_t*)(DIST_BASE + 0x0C))
#define DIST_REF_CNT        (*(volatile uint32_t*)(DIST_BASE + 0x10))
#define DIST_METRIC         (*(volatile uint32_t*)(DIST_BASE + 0x14))
#define DIST_THRESHOLD      (*(volatile uint32_t*)(DIST_BASE + 0x18))
#define DIST_RESULT         (*(volatile uint32_t*)(DIST_BASE + 0x1C))
#define DIST_MIN_DISTANCE   (*(volatile uint32_t*)(DIST_BASE + 0x20))
#define DIST_ERROR_CODE     (*(volatile uint32_t*)(DIST_BASE + 0x24))
#define DIST_QUERY_REG(i)   (*(volatile uint32_t*)(DIST_BASE + 0x100 + ((i) * 4)))
#define DIST_REF_REG(i)     (*(volatile uint32_t*)(DIST_BASE + 0x200 + ((i) * 4)))

#define DIST_CTRL_START     (1 << 0)
#define DIST_CTRL_RESET     (1 << 1)
#define DIST_CTRL_IRQ_EN    (1 << 2)

#define DIST_STATUS_BUSY    (1 << 0)
#define DIST_STATUS_DONE    (1 << 1)
#define DIST_STATUS_ERROR   (1 << 2)

// =============================================================================
// Mailbox Register
// =============================================================================
#define MAILBOX_REG         (*(volatile uint32_t*)(MAILBOX_ADDR))

// =============================================================================
// Test Helper Functions
// =============================================================================
static inline void uart_init(uint32_t baud_div) {
    UART_LCR = 0x80;        // Enable DLAB
    UART_BAUD_DIV = baud_div;
    UART_LCR = 0x03;        // 8N1
}

static inline void uart_putc(char c) {
    while ((UART_LSR & UART_LSR_THRE) == 0);
    UART_THR = (uint32_t)(uint8_t)c;
}

static inline void uart_puts(const char *s) {
    while (*s) {
        if (*s == '\n') uart_putc('\r');
        uart_putc(*s++);
    }
}

static inline void uart_print_hex(uint32_t val) {
    const char hex_chars[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uart_putc(hex_chars[(val >> i) & 0xF]);
    }
}

static inline void uart_print_dec(int val) {
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

static inline void delay_cycles(volatile uint32_t count) {
    while (count--) {
        __asm__ volatile("nop");
    }
}

static inline void test_pass(const char *testname) {
    GPIO_EN  = 0x000000FF;
    GPIO_OUT = 0x00000055;
    MAILBOX_REG = 0x00000001;
    uart_puts("\n*** [TEST PASSED]: ");
    uart_puts(testname);
    uart_puts(" ***\n");
}

static inline void test_fail(const char *testname, const char *reason) {
    GPIO_EN  = 0x000000FF;
    GPIO_OUT = 0x0000DEAD;
    MAILBOX_REG = 0xDEADBEEF;
    uart_puts("\n*** [TEST FAILED]: ");
    uart_puts(testname);
    uart_puts(" (");
    uart_puts(reason);
    uart_puts(") ***\n");
}

#endif // SOC_REGS_H
