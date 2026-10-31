import csv
import sys
import os

# -----------------------------------------------------------------------------
# Part 1: External Interfaces List
# -----------------------------------------------------------------------------
ext_interfaces = [
    {
        "group": "Clock & Reset",
        "signal": "clk",
        "dir": "Input",
        "width": "1-bit",
        "block": "Global SoC Clock Tree",
        "protocol": "100 MHz CMOS Clock",
        "usage": "Primary 100 MHz clock driving CPU, AXI crossbar, DMA, CNN, Distance, and peripherals."
    },
    {
        "group": "Clock & Reset",
        "signal": "rst_l",
        "dir": "Input",
        "width": "1-bit",
        "block": "Reset Controller",
        "protocol": "Active-Low Reset",
        "usage": "Main chip reset. When 0, resets CPU pipeline, bus arbiters, and registers to defaults."
    },
    {
        "group": "Clock & Reset",
        "signal": "dbg_rst_l",
        "dir": "Input",
        "width": "1-bit",
        "block": "Debug Subsystem",
        "protocol": "Active-Low Reset",
        "usage": "Resets the on-chip RISC-V debug module and JTAG TAP without resetting the CPU."
    },
    {
        "group": "UART Serial Console",
        "signal": "uart_tx_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "axi_uart_top (M02)",
        "protocol": "RS-232 UART (8N1)",
        "usage": "Serial wire sending text to screen (prints 26 boot, inference, and test pass lines)."
    },
    {
        "group": "UART Serial Console",
        "signal": "uart_rx_i",
        "dir": "Input",
        "width": "1-bit",
        "block": "axi_uart_top (M02)",
        "protocol": "RS-232 UART (8N1)",
        "usage": "Serial wire receiving commands or image data from external PC into UART RX FIFO."
    },
    {
        "group": "PULP 32-bit GPIO",
        "signal": "gpio_o[31:0]",
        "dir": "Output",
        "width": "32-bit",
        "block": "gpio_axi_wrapper (M04)",
        "protocol": "Parallel Digital CMOS",
        "usage": "Physical output pins showing progress: 0x01 (boot), 0x02 (DMA done), 0x04 (CNN done), 0x55 (all pass)."
    },
    {
        "group": "PULP 32-bit GPIO",
        "signal": "gpio_i[31:0]",
        "dir": "Input",
        "width": "32-bit",
        "block": "gpio_axi_wrapper (M04)",
        "protocol": "Parallel Digital CMOS",
        "usage": "Physical inputs for buttons/sensors; passed through on-chip 2-stage synchronizer."
    },
    {
        "group": "PULP 32-bit GPIO",
        "signal": "gpio_dir_o[31:0]",
        "dir": "Output",
        "width": "32-bit",
        "block": "gpio_axi_wrapper (M04)",
        "protocol": "Pad Enable Strobe",
        "usage": "Controls external bi-directional chip pad drivers (1=output drive, 0=high-Z input)."
    },
    {
        "group": "Interrupt Output Pins",
        "signal": "dma_irq_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "dma_axi_wrapper (M07)",
        "protocol": "Active-High Pulse",
        "usage": "External pin pulses high when DMA block transfer (256-byte image) finishes."
    },
    {
        "group": "Interrupt Output Pins",
        "signal": "cnn_irq_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "cnn_axi_wrapper (M05)",
        "protocol": "Active-High Pulse",
        "usage": "External pin pulses high when CNN feature extraction inference finishes."
    },
    {
        "group": "Interrupt Output Pins",
        "signal": "dist_irq_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "distance_axi_wrapper (M06)",
        "protocol": "Active-High Pulse",
        "usage": "External pin pulses high when Manhattan distance scoring and threshold comparison finish."
    },
    {
        "group": "Interrupt Output Pins",
        "signal": "uart_irq_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "axi_uart_top (M02)",
        "protocol": "Active-High Level",
        "usage": "External pin asserts high when UART TX FIFO is empty or RX byte arrives."
    },
    {
        "group": "Interrupt Output Pins",
        "signal": "timer_irq_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "timer_axi_wrapper (M03)",
        "protocol": "Active-High Level",
        "usage": "External pin asserts high when 64-bit timer reaches compare target (MTIME >= MTIMECMP)."
    },
    {
        "group": "Interrupt Output Pins",
        "signal": "gpio_irq_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "gpio_axi_wrapper (M04)",
        "protocol": "Active-High Pulse",
        "usage": "External pin pulses high when an enabled GPIO input pin detects edge/level transition."
    },
    {
        "group": "Core Interrupt Inputs",
        "signal": "timer_int",
        "dir": "Input",
        "width": "1-bit",
        "block": "CPU PIC Controller",
        "protocol": "Active-High Level",
        "usage": "External machine timer interrupt input line wired into the VeeR-EL2 CPU."
    },
    {
        "group": "Core Interrupt Inputs",
        "signal": "soft_int",
        "dir": "Input",
        "width": "1-bit",
        "block": "CPU PIC Controller",
        "protocol": "Active-High Level",
        "usage": "External software / inter-processor interrupt line wired into the VeeR-EL2 CPU."
    },
    {
        "group": "JTAG Hardware Debug",
        "signal": "jtag_tck",
        "dir": "Input",
        "width": "1-bit",
        "block": "VeeR Debug TAP",
        "protocol": "IEEE 1149.1 Clock",
        "usage": "JTAG test clock for OpenOCD/GDB on-chip debugger access."
    },
    {
        "group": "JTAG Hardware Debug",
        "signal": "jtag_tms",
        "dir": "Input",
        "width": "1-bit",
        "block": "VeeR Debug TAP",
        "protocol": "IEEE 1149.1 Control",
        "usage": "JTAG test mode select line driving state transitions of the 16-state TAP."
    },
    {
        "group": "JTAG Hardware Debug",
        "signal": "jtag_tdi",
        "dir": "Input",
        "width": "1-bit",
        "block": "VeeR Debug TAP",
        "protocol": "IEEE 1149.1 Data In",
        "usage": "JTAG serial data input carrying CPU debug instructions and register read/write commands."
    },
    {
        "group": "JTAG Hardware Debug",
        "signal": "jtag_trst_n",
        "dir": "Input",
        "width": "1-bit",
        "block": "VeeR Debug TAP",
        "protocol": "Active-Low Reset",
        "usage": "JTAG asynchronous reset pin to force TAP controller into Test-Logic-Reset state."
    },
    {
        "group": "JTAG Hardware Debug",
        "signal": "jtag_tdo",
        "dir": "Output",
        "width": "1-bit",
        "block": "VeeR Debug TAP",
        "protocol": "IEEE 1149.1 Data Out",
        "usage": "JTAG serial data output returning CPU registers, program counter, and memory values."
    },
    {
        "group": "JTAG Hardware Debug",
        "signal": "jtag_tdoEn",
        "dir": "Output",
        "width": "1-bit",
        "block": "VeeR Debug TAP",
        "protocol": "Pad Driver Enable",
        "usage": "Enables the external TDO pad driver buffer only when shifting data out."
    },
    {
        "group": "CPU Control & Status",
        "signal": "i_cpu_halt_req",
        "dir": "Input",
        "width": "1-bit",
        "block": "CPU Power Management",
        "protocol": "Handshake Control",
        "usage": "External hardware signal to request CPU to pause instruction fetch and halt."
    },
    {
        "group": "CPU Control & Status",
        "signal": "o_cpu_halt_ack",
        "dir": "Output",
        "width": "1-bit",
        "block": "CPU Power Management",
        "protocol": "Handshake Acknowledge",
        "usage": "CPU output signal confirming that the core has safely halted."
    },
    {
        "group": "CPU Control & Status",
        "signal": "o_cpu_halt_status",
        "dir": "Output",
        "width": "1-bit",
        "block": "CPU Power Management",
        "protocol": "Status Flag",
        "usage": "Continuous status output flag indicating whether the CPU core is currently halted."
    },
    {
        "group": "CPU Control & Status",
        "signal": "i_cpu_run_req",
        "dir": "Input",
        "width": "1-bit",
        "block": "CPU Power Management",
        "protocol": "Handshake Control",
        "usage": "External hardware signal to resume execution of a halted CPU core."
    },
    {
        "group": "CPU Control & Status",
        "signal": "o_cpu_run_ack",
        "dir": "Output",
        "width": "1-bit",
        "block": "CPU Power Management",
        "protocol": "Handshake Acknowledge",
        "usage": "CPU output signal confirming that the core has resumed active instruction execution."
    },
    {
        "group": "CPU Control & Status",
        "signal": "o_debug_mode_status",
        "dir": "Output",
        "width": "1-bit",
        "block": "CPU Power Management",
        "protocol": "Status Flag",
        "usage": "Status output signal indicating whether the CPU is halted in JTAG hardware debug mode."
    }
]

# -----------------------------------------------------------------------------
# Part 2: Complete Test Plan List (No Tiers, Clean Internal vs External)
# -----------------------------------------------------------------------------
test_cases = [
    # DMA Controller
    {
        "name": "DMA_REG_RW_RESET",
        "desc": "Check reset defaults (0x0) and read/write access to DMA registers (CTRL, STATUS, SRC_ADDR, DST_ADDR, LENGTH).",
        "c_part": "Writes base addresses and lengths; reads back registers to verify setup.",
        "sv_part": "Issues AXI-Lite read/write cycles; checks register flip-flops and OKAY responses.",
        "type": "Internal (On-chip registers & AXI-Lite bus)"
    },
    {
        "name": "DMA_MEM2MEM_16B",
        "desc": "Check 16-byte (4-word) memory-to-memory copy between DMEM source and destination.",
        "c_part": "Sets DMA_SRC_ADDR, DMA_DST_ADDR, DMA_LENGTH=16, triggers START, and polls STATUS.",
        "sv_part": "Monitors DMA master read/write bursts on internal bus; checks destination equals source byte-for-byte.",
        "type": "Internal (On-chip DMEM & internal AXI master bus)"
    },
    {
        "name": "DMA_IMAGE_BURST_256B",
        "desc": "Check 256-byte bulk transfer of 16x16 INT8 image from DMEM to CNN SRAM buffer (0x2000_3100).",
        "c_part": "Sets SRC=&test_image, DST=0x20003100, LENGTH=256, START=1; verifies completion status.",
        "sv_part": "Monitors burst writes; verifies all 256 bytes are loaded into CNN SRAM buffer without stall.",
        "type": "Internal (On-chip DMEM to on-chip CNN SRAM buffer)"
    },
    {
        "name": "DMA_PARTIAL_ODD_LEN",
        "desc": "Check transfer of 13 bytes (3 full 32-bit words + 1 byte) with byte strobes.",
        "c_part": "Configures DMA_LENGTH=13; checks destination buffer after completion.",
        "sv_part": "Asserts words 0-2 write with wstrb=4'hF and word 3 with wstrb=4'h1; checks other bytes untouched.",
        "type": "Internal (Internal byte strobe generator & masking)"
    },
    {
        "name": "DMA_IRQ_ASSERTION",
        "desc": "Check that dedicated interrupt pin dma_irq_o pulses high when transfer completes.",
        "c_part": "Enables interrupt bit in CTRL (IRQ_EN=1); services interrupt or waits for completion flag.",
        "sv_part": "Monitors physical dma_irq_o pin on chip boundary; checks pin rises from 0 to 1 upon completion.",
        "type": "External (Physical dma_irq_o output pin)"
    },
    {
        "name": "DMA_W1C_CLEAR",
        "desc": "Check Write-1-to-Clear (W1C) clears status flags and drops dma_irq_o back to 0.",
        "c_part": "Writes '1' to STATUS.DONE bit after transfer completes to acknowledge interrupt.",
        "sv_part": "Probes dma_irq_o pin and STATUS register; verifies pin drops from 1 to 0 immediately on W1C write.",
        "type": "External (Deasserts physical dma_irq_o pin)"
    },
    {
        "name": "DMA_ERR_ALIGN_FAULT",
        "desc": "Fault injection: Program unaligned source address (0x1000_0003) and verify error latching.",
        "c_part": "Configures unaligned address; checks STATUS register for error code.",
        "sv_part": "Verifies DMA FSM latches STATUS.ERROR=1 with ERROR_CODE=1 and blocks bus master requests.",
        "type": "Internal (Internal address check & error register)"
    },
    {
        "name": "DMA_ERR_ZERO_LEN",
        "desc": "Fault injection: Program LENGTH=0 and verify transfer rejection.",
        "c_part": "Configures LENGTH=0, START=1; reads back error status.",
        "sv_part": "Verifies DMA aborts transfer without issuing bus transactions; asserts ERROR_CODE=1.",
        "type": "Internal (Internal parameter validator)"
    },
    {
        "name": "DMA_ERR_BUSY_CONFLICT",
        "desc": "Fault injection: Write START=1 while DMA is already busy running a transfer.",
        "c_part": "Writes START=1 twice consecutively without waiting for completion.",
        "sv_part": "Verifies ongoing transfer finishes safely; second command is dropped with ERROR_CODE=4.",
        "type": "Internal (Internal FSM collision protection logic)"
    },
    {
        "name": "DMA_SOFT_RESET",
        "desc": "Check soft reset recovery during an active bulk transfer.",
        "c_part": "Sets CTRL.SOFT_RESET=1 while transfer is running.",
        "sv_part": "Verifies FSM immediately halts, cancels master requests, and resets internal counters to IDLE.",
        "type": "Internal (Internal reset tree & FSM clear)"
    },

    # CNN Feature Extractor
    {
        "name": "CNN_MAC_UNIT",
        "desc": "Check 8-bit signed multiplication and 32-bit accumulation datapath with synchronous clear.",
        "c_part": "N/A (Submodule hardware testbench).",
        "sv_part": "Drives signed INT8 pixel and weight inputs; checks product accumulation and clear_acc reset.",
        "type": "Internal (On-chip multiplier & accumulator ALU)"
    },
    {
        "name": "CNN_CONV3X3_LAYER",
        "desc": "Check 3x3 2D convolution on 16x16 image with 4 parallel filters (produces 784 activations).",
        "c_part": "N/A (Submodule hardware testbench).",
        "sv_part": "Feeds test image and filter weights; compares all 784 output features against Python golden model.",
        "type": "Internal (On-chip sliding window buffers & MAC array)"
    },
    {
        "name": "CNN_RELU_LAYER",
        "desc": "Check element-wise Rectified Linear Unit activation (clamping negative numbers to 0).",
        "c_part": "N/A (Submodule hardware testbench).",
        "sv_part": "Drives signed positive and negative values; verifies negative values clamp to 0 and positive values pass.",
        "type": "Internal (On-chip activation datapath logic)"
    },
    {
        "name": "CNN_MAXPOOL2X2_LAYER",
        "desc": "Check 2x2 max pooling with stride 2 across 784 inputs (reduces to 196 features).",
        "c_part": "N/A (Submodule hardware testbench).",
        "sv_part": "Applies 14x14 feature maps per filter; verifies non-overlapping 2x2 max selection into 196 outputs.",
        "type": "Internal (On-chip spatial comparator tree)"
    },
    {
        "name": "CNN_FC196_16_LAYER",
        "desc": "Check Fully Connected matrix multiplication (196 inputs x 16 neurons) with bias addition.",
        "c_part": "N/A (Submodule hardware testbench).",
        "sv_part": "Applies 196 features and 16x196 weights; checks that output 16-D embedding matches golden dot products.",
        "type": "Internal (On-chip matrix multiplier & accumulator)"
    },
    {
        "name": "CNN_IMAGE_BUFFER_SRAM",
        "desc": "Check direct AXI writes and reads to the CNN 256-byte image SRAM buffer (0x2000_3100 - 0x2000_31FC).",
        "c_part": "Writes known pixel array into buffer address 0x2000_3100; reads back data to verify SRAM integrity.",
        "sv_part": "Monitors AXI writes to buffer range; checks SRAM memory array contents match written pixels.",
        "type": "Internal (On-chip local SRAM image buffer)"
    },
    {
        "name": "CNN_INFERENCE_EXEC",
        "desc": "Check complete CNN inference trigger, busy polling, and 16-element embedding vector generation.",
        "c_part": "Sets DIM_CFG=16x16, EMBED_LEN=16, triggers START=1, polls STATUS.DONE, and reads embedding registers (0x20-0x5C).",
        "sv_part": "Monitors CNN AXI slave transactions; verifies pipeline execution cycles; checks embedding values are non-zero.",
        "type": "Internal (On-chip accelerator pipeline & registers)"
    },
    {
        "name": "CNN_IRQ_ASSERTION",
        "desc": "Check assertion of dedicated completion interrupt pin cnn_irq_o when inference finishes.",
        "c_part": "Configures CNN_CTRL with IRQ_EN=1; waits for hardware completion.",
        "sv_part": "Probes physical cnn_irq_o output pin; checks pin asserts high when STATUS.DONE=1.",
        "type": "External (Physical cnn_irq_o output pin)"
    },
    {
        "name": "CNN_INVALID_CFG_FAULT",
        "desc": "Fault injection: Program invalid image dimensions or embedding length and check error handling.",
        "c_part": "Writes illegal dimension value to DIM_CFG; reads STATUS register.",
        "sv_part": "Verifies CNN detects illegal configuration, asserts STATUS.ERROR=1 with ERROR_CODE=3, and aborts start.",
        "type": "Internal (Internal configuration checker)"
    },

    # Distance & Anomaly Engine
    {
        "name": "DIST_MANHATTAN_CALC",
        "desc": "Check hardware calculation of Manhattan (L1) distance: sum(|query[i] - ref[i]|) for 16 elements.",
        "c_part": "Loads query and reference vectors into IP slots; triggers calculation.",
        "sv_part": "Compares hardware computed distance in MIN_DISTANCE register against software reference calculation.",
        "type": "Internal (On-chip absolute difference subtractor & adder)"
    },
    {
        "name": "DIST_THRESHOLD_MATCH",
        "desc": "Check classification when distance <= threshold (Expected: RESULT=1 for MATCH / NORMAL).",
        "c_part": "Sets matching reference vector, sets threshold=50, starts engine, verifies RESULT==1 and MIN_DISTANCE==0.",
        "sv_part": "Monitors Distance AXI registers; checks comparator asserts RESULT=1 when distance <= threshold.",
        "type": "Internal (On-chip distance registers & comparator logic)"
    },
    {
        "name": "DIST_THRESHOLD_ANOMALY",
        "desc": "Check classification when distance > threshold (Expected: RESULT=0 for ANOMALY).",
        "c_part": "Sets divergent reference vector, sets threshold=50, starts engine, verifies RESULT==0 and MIN_DISTANCE==800.",
        "sv_part": "Monitors Distance AXI registers; checks comparator asserts RESULT=0 when distance > threshold.",
        "type": "Internal (On-chip distance registers & comparator logic)"
    },
    {
        "name": "DIST_IRQ_ASSERTION",
        "desc": "Check assertion of dedicated completion interrupt pin dist_irq_o when distance scoring finishes.",
        "c_part": "Configures DIST_CTRL with IRQ_EN=1; triggers scoring; clears interrupt via W1C.",
        "sv_part": "Probes physical dist_irq_o output pin; verifies pin rises to 1 on completion and drops to 0 on W1C.",
        "type": "External (Physical dist_irq_o output pin)"
    },
    {
        "name": "DIST_INVALID_METRIC_FAULT",
        "desc": "Fault injection: Program unsupported metric index into DIST_METRIC and verify error response.",
        "c_part": "Writes unsupported metric code (e.g. 5) into DIST_METRIC register.",
        "sv_part": "Verifies IP rejects configuration, asserts STATUS.ERROR=1 with ERROR_CODE=4, and refuses execution.",
        "type": "Internal (Internal metric validator logic)"
    },

    # UART 16550 Serial Console
    {
        "name": "UART_BAUD_DIV_CONFIG",
        "desc": "Check programming of UART baud rate divisor latch (divisor = 16) and line control register (8N1).",
        "c_part": "Writes LCR=0x80 (DLAB enable), writes BAUD_DIV=16, restores LCR=0x03 (8 data bits, 1 stop bit, no parity).",
        "sv_part": "Monitors internal AXI writes to UART registers 0x2000_0008 and 0x2000_000C; verifies divisor latch value.",
        "type": "Internal (On-chip UART registers & clock divider)"
    },
    {
        "name": "UART_SERIAL_TX_BITSTREAM",
        "desc": "Check physical serial transmission of ASCII characters over uart_tx_o pin at exact baud timing.",
        "c_part": "Calls uart_putc() / uart_puts() to transmit string messages to console.",
        "sv_part": "Probes physical uart_tx_o output wire; deserializes start bit, 8 data bits, and stop bit at 170 ns/bit; validates text.",
        "type": "External (Physical uart_tx_o serial output pin)"
    },
    {
        "name": "UART_TX_FIFO_STATUS",
        "desc": "Check UART Line Status Register (LSR) transmitter holding register empty (THRE) and transmitter empty (TEMT).",
        "c_part": "Polls LSR register until THRE bit is 1 before writing next character into THR.",
        "sv_part": "Monitors AXI reads to LSR (0x2000_0014); checks THRE drops to 0 when FIFO is written and returns to 1 when empty.",
        "type": "Internal (On-chip UART FIFO status logic)"
    },
    {
        "name": "UART_IRQ_ASSERTION",
        "desc": "Check assertion of uart_irq_o pin when TX FIFO is empty or RX data is received.",
        "c_part": "Enables UART interrupts via IER register; handles interrupt or polls status.",
        "sv_part": "Probes physical uart_irq_o output pin; checks pin asserts upon configured UART trigger condition.",
        "type": "External (Physical uart_irq_o output pin)"
    },

    # OpenTitan RV Timer
    {
        "name": "TIMER_COUNTER_INCREMENT",
        "desc": "Check continuous 64-bit real-time counter (MTIME) incrementation based on system clock.",
        "c_part": "Reads MTIME counter registers twice and verifies time progression.",
        "sv_part": "Monitors internal 64-bit timer counter registers; verifies increment rate matches prescaler setting.",
        "type": "Internal (On-chip 64-bit timer counter flip-flops)"
    },
    {
        "name": "TIMER_MATCH_INTERRUPT",
        "desc": "Check assertion of timer_irq_o pin when MTIME counter reaches comparator value (MTIME >= MTIMECMP).",
        "c_part": "Programs MTIMECMP = MTIME + 100; enables timer interrupt; waits for interrupt.",
        "sv_part": "Probes physical timer_irq_o output pin; verifies pin rises to 1 exactly when counter matches compare register.",
        "type": "External (Physical timer_irq_o output pin)"
    },

    # PULP Platform 32-bit GPIO
    {
        "name": "GPIO_DIRECTION_CONTROL",
        "desc": "Check 32-bit pin direction configuration via GPIO_EN register (input vs push-pull output).",
        "c_part": "Writes direction mask to GPIO_EN (0x2000_2080); verifies output enables.",
        "sv_part": "Probes internal direction control bus gpio_dir_o[31:0]; checks pins configure correctly as inputs or outputs.",
        "type": "Internal (On-chip direction registers & pad control)"
    },
    {
        "name": "GPIO_OUTPUT_PATTERN_DRIVE",
        "desc": "Check driving arbitrary test patterns and stage indicators onto physical gpio_o[31:0] pins.",
        "c_part": "Writes progress status to GPIO_OUT: 0x01 (boot), 0x02 (DMA done), 0x04 (CNN done), 0x55 (all pass).",
        "sv_part": "Probes physical gpio_o[31:0] output pins on chip boundary; asserts pin levels match written values.",
        "type": "External (Physical gpio_o[31:0] output pin bus)"
    },
    {
        "name": "GPIO_ATOMIC_SET_CLR_TOGGLE",
        "desc": "Check atomic bit manipulation registers: GPIO_SET (0x200), GPIO_CLEAR (0x280), and GPIO_TOGGLE (0x300).",
        "c_part": "Writes single bitmasks to SET, CLEAR, and TOGGLE registers without read-modify-write software overhead.",
        "sv_part": "Monitors AXI writes to atomic offsets; asserts that target bits on gpio_o update while other bits remain unchanged.",
        "type": "External (Directly changes physical gpio_o output pins)"
    },
    {
        "name": "GPIO_INPUT_SAMPLING_SYNC",
        "desc": "Check external signal sampling on physical gpio_i[31:0] pins through 2-stage flip-flop synchronizer.",
        "c_part": "Reads GPIO_IN register (0x2000_2000) to inspect external switch/pin states.",
        "sv_part": "Drives asynchronous digital signals onto physical gpio_i pins; checks 2-stage synchronizer removes metastability.",
        "type": "External (Physical gpio_i[31:0] input pins)"
    },
    {
        "name": "GPIO_PIN_INTERRUPT_GEN",
        "desc": "Check generation of gpio_irq_o pin on configurable rising-edge, falling-edge, or level triggers on input pins.",
        "c_part": "Enables GPIO interrupt mask; reads interrupt status; clears interrupt via W1C.",
        "sv_part": "Drives pulse transitions on gpio_i; probes physical gpio_irq_o pin; verifies interrupt asserts and clears cleanly.",
        "type": "External (Physical gpio_i pin transition -> gpio_irq_o pin)"
    },

    # AXI4 Interconnect
    {
        "name": "AXI_SLAVE_ADDR_DECODING",
        "desc": "Check address decoding and routing from CPU master (S00) to all 8 slave peripheral targets (M00-M07).",
        "c_part": "Issues read/write accesses to all 8 base addresses: IMEM, DMEM, UART, Timer, GPIO, CNN, Distance, and DMA.",
        "sv_part": "Monitors select lines and handshakes on all 8 slave interfaces (m00_axi through m07_axi); verifies 1-to-1 routing.",
        "type": "Internal (On-chip AXI crossbar decoder & muxes)"
    },
    {
        "name": "AXI_UNMAPPED_DECERR",
        "desc": "Check generation of DECERR (2'b11) response when accessing unmapped address space (e.g. 0x3000_0000).",
        "c_part": "Attempts read or write access to unmapped memory address.",
        "sv_part": "Captures write response bresp and read response rresp; asserts interconnect returns 2'b11 without bus hang.",
        "type": "Internal (On-chip crossbar default error slave logic)"
    },
    {
        "name": "AXI_MASTER_ARBITRATION",
        "desc": "Check round-robin bus arbitration when CPU (S00) and DMA (S01) issue concurrent accesses to shared DMEM (M01).",
        "c_part": "Initiates DMA background transfer to DMEM while CPU actively reads instructions and data.",
        "sv_part": "Monitors simultaneous request lines; verifies round-robin arbiter grants alternating access without starving either master.",
        "type": "Internal (On-chip crossbar arbiter logic & grant handshakes)"
    },
    {
        "name": "AXI_BACKPRESSURE_HANDSHAKE",
        "desc": "Check valid/ready flow control and stall handling across all AXI channels during burst transactions.",
        "c_part": "Issues continuous back-to-back memory and register transfers.",
        "sv_part": "Randomly asserts/deasserts ready signals; verifies master correctly holds valid and data until ready is high.",
        "type": "Internal (On-chip AXI handshake protocol compliance)"
    },

    # Memory Subsystem
    {
        "name": "IMEM_DUAL_PORT_ACCESS",
        "desc": "Check Instruction Memory dual-port operation: CPU IFU instruction fetches and LSU/DMA data reads/writes.",
        "c_part": "Executes code from IMEM while testbench preloads hex data.",
        "sv_part": "Verifies simultaneous IFU fetch and AXI slave access to IMEM (0x0000_0000 - 0x0000_FFFF) without conflict.",
        "type": "Internal (On-chip dual-ported 64 KB SRAM memory)"
    },
    {
        "name": "DMEM_BYTE_ENABLE_ACCESS",
        "desc": "Check Data Memory byte-level access using 4-bit write strobes (wstrb) for 8-bit, 16-bit, and 32-bit accesses.",
        "c_part": "Performs uint8_t, uint16_t, and uint32_t stores and loads in DMEM (0x1000_0000 - 0x1000_FFFF).",
        "sv_part": "Checks that only enabled byte lanes in memory are modified; non-targeted bytes remain preserved.",
        "type": "Internal (On-chip 64 KB SRAM byte-enable mask logic)"
    },

    # Full SoC System Integration
    {
        "name": "SOC_CPU_RESET_BOOT",
        "desc": "Check VeeR-EL2 CPU boot from hardware reset, instruction fetch from 0x0000_0000, and stack initialization.",
        "c_part": "crt0.s initializes stack pointer sp to 0x1000_FFF0, configures MRAC CSR (0x5555556A), and calls main().",
        "sv_part": "Deasserts rst_l; tracks CPU program counter (ifu_i0_pc); verifies execution starts at 0x0000_0000.",
        "type": "Internal (CPU reset vector logic & pipeline registers)"
    },
    {
        "name": "SOC_CONSOLE_LOGGING",
        "desc": "Check CPU firmware execution logs system progress, embeddings, and results via UART serial output.",
        "c_part": "Firmware executes print routines outputting 26 structured log lines to the console.",
        "sv_part": "UART monitor captures all characters from physical uart_tx_o pin; verifies 26 complete lines and pass string.",
        "type": "External (Physical uart_tx_o serial output wire)"
    },
    {
        "name": "SOC_END2END_NORMAL_CLASSIFY",
        "desc": "Check full autonomous pipeline classifying a normal image sample: DMA copy -> CNN inference -> Distance Match.",
        "c_part": "Orchestrates DMA transfer, CNN start, loads matching reference embedding, validates RESULT==1, logs PASS.",
        "sv_part": "Scoreboard captures DMA transfer, validates CNN embedding vector, and verifies Distance IP outputs Match=1.",
        "type": "Internal (On-chip accelerator pipeline & distance scoring)"
    },
    {
        "name": "SOC_END2END_ANOMALY_CLASSIFY",
        "desc": "Check full autonomous pipeline classifying an anomaly image: DMA copy -> CNN inference -> Distance Anomaly.",
        "c_part": "Loads divergent reference embedding, triggers Distance IP, validates RESULT==0 (ANOMALY), logs PASS.",
        "sv_part": "Scoreboard verifies Distance IP outputs Dist=800, Result=0, and flags anomaly detection.",
        "type": "Internal (On-chip accelerator pipeline & anomaly scoring)"
    },
    {
        "name": "SOC_FINAL_MAILBOX_HANDSHAKE",
        "desc": "Check system completion handshake via DMEM mailbox (0x1000_FF00) and final GPIO output pin state (0x00000055).",
        "c_part": "Writes 0xCAFE0001 to MAILBOX_REG (0x1000_FF00); drives GPIO_OUT = 0x00000055; enters sleep.",
        "sv_part": "Testbench samples physical gpio_o pins for 0x00000055 and checks DMEM mailbox holds 0xCAFE0001 before exiting.",
        "type": "External (Drives physical gpio_o pins & internal mailbox)"
    }
]

# Write Master CSV
csv_path = "/home/student/honours/docs/verification/SoC_Verification_Test_Plan_Sheet.csv"
fieldnames = ["Test Name", "Description", "C Part", "SV Part", "Internal or External"]

with open(csv_path, mode="w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    for tc in test_cases:
        writer.writerow({
            "Test Name": tc["name"],
            "Description": tc["desc"],
            "C Part": tc["c_part"],
            "SV Part": tc["sv_part"],
            "Internal or External": tc["type"]
        })

print(f"Master CSV written: {csv_path}")

# Write Multi-Tab Master Excel XML Spreadsheet
xml_path = "/home/student/honours/docs/verification/SoC_Master_Verification_and_Interfaces.xml"

def escape_xml(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

xml_content = """<?xml version="1.0" encoding="UTF-8"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:html="http://www.w3.org/TR/REC-html40">
 <Styles>
  <Style ss:ID="Default" ss:Name="Normal">
   <Alignment ss:Vertical="Top" ss:WrapText="1"/>
   <Font ss:FontName="Calibri" ss:Size="11" ss:Color="#000000"/>
  </Style>
  <Style ss:ID="Header">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="2" ss:Color="#000000"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#000000"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#000000"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="2" ss:Color="#000000"/>
   </Borders>
   <Font ss:FontName="Calibri" ss:Size="11" ss:Color="#FFFFFF" ss:Bold="1"/>
   <Interior ss:Color="#1B365D" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="DataCell">
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
   </Borders>
   <Font ss:FontName="Calibri" ss:Size="10" ss:Color="#000000"/>
  </Style>
  <Style ss:ID="SignalCell">
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
   </Borders>
   <Font ss:FontName="Consolas" ss:Size="10" ss:Color="#0A2540" ss:Bold="1"/>
  </Style>
  <Style ss:ID="InternalCell">
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
   </Borders>
   <Font ss:FontName="Calibri" ss:Size="10" ss:Color="#0F5132" ss:Bold="1"/>
   <Interior ss:Color="#D1E7DD" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="ExternalCell">
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
   </Borders>
   <Font ss:FontName="Calibri" ss:Size="10" ss:Color="#842029" ss:Bold="1"/>
   <Interior ss:Color="#F8D7DA" ss:Pattern="Solid"/>
  </Style>
 </Styles>

 <!-- SHEET 1: EXTERNAL INTERFACES -->
 <Worksheet ss:Name="External Interfaces">
  <Table ss:ExpandedColumnCount="7" x:FullColumns="1" x:FullRows="1" ss:DefaultRowHeight="20">
   <Column ss:Width="130"/>
   <Column ss:Width="140"/>
   <Column ss:Width="70"/>
   <Column ss:Width="60"/>
   <Column ss:Width="160"/>
   <Column ss:Width="160"/>
   <Column ss:Width="360"/>
   <Row ss:Height="28">
    <Cell ss:StyleID="Header"><Data ss:Type="String">Interface Group</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Signal / Pin Name</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Direction</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Width</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Connected Internal Block</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Protocol / Standard</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">What / How We Are Using It</Data></Cell>
   </Row>
"""

for row in ext_interfaces:
    grp  = escape_xml(row["group"])
    sig  = escape_xml(row["signal"])
    d    = escape_xml(row["dir"])
    w    = escape_xml(row["width"])
    blk  = escape_xml(row["block"])
    prt  = escape_xml(row["protocol"])
    usg  = escape_xml(row["usage"])
    dir_style = "InternalCell" if row["dir"] == "Input" else "ExternalCell"

    xml_content += f"""   <Row ss:AutoFitHeight="1">
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{grp}</Data></Cell>
    <Cell ss:StyleID="SignalCell"><Data ss:Type="String">{sig}</Data></Cell>
    <Cell ss:StyleID="{dir_style}"><Data ss:Type="String">{d}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{w}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{blk}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{prt}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{usg}</Data></Cell>
   </Row>
"""

xml_content += """  </Table>
 </Worksheet>

 <!-- SHEET 2: VERIFICATION TEST PLAN -->
 <Worksheet ss:Name="Verification Test Plan">
  <Table ss:ExpandedColumnCount="5" x:FullColumns="1" x:FullRows="1" ss:DefaultRowHeight="20">
   <Column ss:Width="180"/>
   <Column ss:Width="280"/>
   <Column ss:Width="270"/>
   <Column ss:Width="270"/>
   <Column ss:Width="200"/>
   <Row ss:Height="28">
    <Cell ss:StyleID="Header"><Data ss:Type="String">Test Name</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Description</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">C Part</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">SV Part</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Internal or External</Data></Cell>
   </Row>
"""

for tc in test_cases:
    name = escape_xml(tc["name"])
    desc = escape_xml(tc["desc"])
    c_p  = escape_xml(tc["c_part"])
    sv_p = escape_xml(tc["sv_part"])
    t_p  = escape_xml(tc["type"])
    style_id = "InternalCell" if "Internal" in tc["type"] and "External" not in tc["type"] else "ExternalCell"

    xml_content += f"""   <Row ss:AutoFitHeight="1">
    <Cell ss:StyleID="SignalCell"><Data ss:Type="String">{name}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{desc}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{c_p}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{sv_p}</Data></Cell>
    <Cell ss:StyleID="{style_id}"><Data ss:Type="String">{t_p}</Data></Cell>
   </Row>
"""

xml_content += """  </Table>
 </Worksheet>
</Workbook>
"""

with open(xml_path, "w", encoding="utf-8") as f:
    f.write(xml_content)

print(f"Master multi-tab Excel XML written: {xml_path}")
