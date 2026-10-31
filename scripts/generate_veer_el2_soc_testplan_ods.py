#!/usr/bin/env python3
# =============================================================================
# generate_veer_el2_soc_testplan_ods.py
# Generates VeeR_EL2_SoC_Testplan.ods and VeeR_EL2_SoC_Testplan.xlsx
# for the CNN Accelerator SoC for Image Anomaly Detection.
# Formatted with the exact 9-column schema, styling, and depth of the reference.
# =============================================================================

import os
import sys
import zipfile
import subprocess
import xml.etree.ElementTree as ET

# -----------------------------------------------------------------------------
# Complete 47 Test Cases for CNN Anomaly Detection RISC-V SoC
# -----------------------------------------------------------------------------
test_cases = [
    # --- Module 1: DMA Controller ---
    {
        "name": "TC_DMA_01",
        "desc": "DMA Register R/W & Reset Verification: Verify reset defaults (0x0000_0000) and read/write accessibility of all DMA configuration registers (CTRL, STATUS, SRC_ADDR, DST_ADDR, LENGTH).",
        "checkpoint": "CTRL and STATUS read 0x0 on reset. Writes to SRC, DST, and LEN retain values under standard AXI-Lite access without bus traps or bit corruption.",
        "c_part": "Write test addresses (0x1000_0100 to SRC, 0x2000_3100 to DST) and 64 to LENGTH; read back each register and assert value equality.",
        "sv_part": "Drive AXI-Lite read/write cycles to CSR address aperture (0x2000_5000); check register flip-flops and OKAY response (bresp === 2'b00).",
        "category": "Internal",
        "interface": "N/A (Internal AXI-Lite CSR)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_DMA_02",
        "desc": "DMA Memory-to-Memory 16-Byte Transfer: Verify basic 16-byte (4-word) autonomous memory-to-memory copy between DMEM source and destination.",
        "checkpoint": "DMA status DONE bit asserts; destination buffer (0x1000_0200) matches source buffer (0x1000_0100) byte-for-byte.",
        "c_part": "Pre-seed source memory array, configure DMA_SRC_ADDR, DMA_DST_ADDR, DMA_LENGTH=16, trigger START=1, poll STATUS.DONE.",
        "sv_part": "Monitor DMA master (S01) read/write bursts on internal crossbar; verify 4-beat burst transfer without bus stalls.",
        "category": "Internal",
        "interface": "N/A (Internal AXI Master & DMEM)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_DMA_03",
        "desc": "DMA Bulk 256-Byte Image Burst to CNN SRAM: Verify high-throughput bulk transfer of 256-byte 16x16 INT8 image from DMEM to CNN internal accelerator SRAM buffer (0x2000_3100).",
        "checkpoint": "All 256 bytes transfer into CNN local SRAM buffer without data corruption; STATUS.DONE asserts; transfer completes in under 100 cycles.",
        "c_part": "Point SRC to &test_image (0x1000_0000), DST to 0x2000_3100, LENGTH=256, set CTRL=START; verify completion.",
        "sv_part": "Monitor continuous AXI burst writes on crossbar; verify sustained throughput and that CNN SRAM buffer contents equal test image array.",
        "category": "Internal",
        "interface": "N/A (Internal Crossbar & CNN SRAM)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_DMA_04",
        "desc": "DMA Partial / Odd Byte Length Transfer with Strobes: Verify transfer of unaligned/odd byte length (13 bytes = 3 full 32-bit words + 1 partial byte) with active byte strobes (wstrb).",
        "checkpoint": "First 3 words write with wstrb=4'hF and 4th word writes with wstrb=4'h1; untouched destination bytes remain uncorrupted.",
        "c_part": "Configure DMA_LENGTH=13, trigger transfer, read back destination buffer words after completion and verify boundary masking.",
        "sv_part": "Assert m01_axi_wstrb matches 4'hF for beats 0-2 and 4'h1 for beat 3; check destination DMEM byte lanes 1..3 remain unmodified.",
        "category": "Internal",
        "interface": "N/A (Internal Byte Strobe Generator)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_DMA_05",
        "desc": "DMA Interrupt Generation upon Completion: Verify assertion of dedicated interrupt pin dma_irq_o upon completion of memory transfer.",
        "checkpoint": "Physical pin dma_irq_o transitions 0 -> 1 simultaneously with STATUS.DONE assertion; CPU catches interrupt or flag.",
        "c_part": "Configure DMA_CTRL with IRQ_EN=1 (0x05); initiate transfer and wait for interrupt service routine or status flag.",
        "sv_part": "Monitor physical dma_irq_o pin on chip boundary; assert dma_irq_o === 1'b1 upon completion handshake (bvalid & bready).",
        "category": "External",
        "interface": "DMA Interrupt Interface",
        "signals": "dma_irq_o"
    },
    {
        "name": "TC_DMA_06",
        "desc": "DMA Write-1-to-Clear Status & IRQ Deassertion: Verify Write-1-to-Clear (W1C) mechanism clears STATUS.DONE and immediately drops dma_irq_o back to 0.",
        "checkpoint": "STATUS.DONE clears to 0; dma_irq_o falls 1 -> 0 within 2 clock cycles of W1C write without interconnect glitch.",
        "c_part": "After transfer completes, write 1 to STATUS.DONE bit (write 0x02 to 0x2000_5004); confirm STATUS register reads 0x0.",
        "sv_part": "Probe dma_irq_o pin and STATUS register; verify pin deasserts immediately upon W1C write response without race conditions.",
        "category": "External",
        "interface": "DMA Interrupt Interface",
        "signals": "dma_irq_o"
    },
    {
        "name": "TC_DMA_07",
        "desc": "DMA Unaligned Address Alignment Fault Rejection: Fault injection: Program unaligned source address (0x1000_0003) and verify error latching.",
        "checkpoint": "DMA rejects start; STATUS.ERROR asserts with ERROR_CODE=1; DMA master issues zero illegal bus requests.",
        "c_part": "Program SRC_ADDR = 0x1000_0003, LENGTH = 16, START = 1; read STATUS register and verify ERROR bit is set.",
        "sv_part": "Check DMA FSM latches ERROR status, suppresses bus master transactions on S01, and leaves crossbar unblocked.",
        "category": "Internal",
        "interface": "N/A (Internal Parameter Validator)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_DMA_08",
        "desc": "DMA Zero-Length Transfer Rejection: Fault injection: Program LENGTH = 0 and verify transfer abort without bus hang.",
        "checkpoint": "Transfer aborted immediately; ERROR=1, ERROR_CODE=1 reported in STATUS; bus remains quiescent.",
        "c_part": "Program LENGTH = 0, START = 1; verify transfer completes immediately with error code.",
        "sv_part": "Scoreboard monitors S01 master port; asserts no read or write addresses are issued (arvalid == 0, awvalid == 0).",
        "category": "Internal",
        "interface": "N/A (Internal FSM Parameter Check)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_DMA_09",
        "desc": "DMA Start Trigger Conflict During Active Transfer: Fault injection: Write START=1 while DMA engine is already actively executing a transfer (BUSY=1).",
        "checkpoint": "Active transfer completes safely without data corruption; second start rejected with STATUS.ERROR=1, ERROR_CODE=4.",
        "c_part": "Initiate 256-byte bulk transfer; immediately write START=1 second time without waiting; verify ongoing transfer integrity.",
        "sv_part": "Verify FSM collision protection logic discards conflicting command, preserves ongoing burst, and reports error flag.",
        "category": "Internal",
        "interface": "N/A (Internal FSM State Protection)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_DMA_10",
        "desc": "DMA Soft Reset Recovery during Active Burst: Verify soft reset aborts active DMA transfer and safely returns DMA engine to IDLE state.",
        "checkpoint": "FSM returns to IDLE; BUSY drops to 0; master cancel gracefully completes current beat without bus protocol violation.",
        "c_part": "Start bulk transfer; assert CTRL.SOFT_RESET=1 mid-transfer; read back STATUS register confirming IDLE.",
        "sv_part": "Monitor S01 master channels; verify soft reset cancels outstanding requests, resets internal FIFO pointers, and restores defaults.",
        "category": "Internal",
        "interface": "N/A (Internal Reset Controller)",
        "signals": "N/A (Internal)"
    },

    # --- Module 2: CNN Feature Extraction Accelerator ---
    {
        "name": "TC_CNN_01",
        "desc": "CNN MAC Unit 8-Bit Signed Arithmetic Datapath: Verify INT8 signed multiplication and 32-bit accumulation datapath with synchronous accumulator clear.",
        "checkpoint": "Product and accumulator output match mathematical reference P = A * B + Acc; clear clears accumulator in 1 cycle.",
        "c_part": "N/A (Dedicated block-level hardware datapath).",
        "sv_part": "Drive exhaustive signed corner cases (-128, +127, 0, -1) to pixel and weight inputs; check signed arithmetic and overflow handling.",
        "category": "Internal",
        "interface": "N/A (Internal MAC ALU)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_CNN_02",
        "desc": "CNN Conv3x3 2D Convolution Layer Execution: Verify 3x3 2D convolution on 16x16 image with 4 parallel filters producing 784 output activations.",
        "checkpoint": "All 784 calculated feature activations match golden Python software model with zero numerical discrepancy.",
        "c_part": "N/A (Accelerator pipeline engine).",
        "sv_part": "Feed test image and trained filter kernels; capture 784 convolution output features and compare against golden model.",
        "category": "Internal",
        "interface": "N/A (Internal Convolution Pipeline)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_CNN_03",
        "desc": "CNN ReLU Activation Function Clamping: Verify element-wise Rectified Linear Unit activation clamping negative numbers to 0 and passing non-negative values.",
        "checkpoint": "Outputs max(0, x) for all 784 convolution values; zero negative activations propagate forward.",
        "c_part": "N/A (Accelerator activation stage).",
        "sv_part": "Feed signed vector containing negative and positive values; assert all negative values clamp to 0 and positive values pass unchanged.",
        "category": "Internal",
        "interface": "N/A (Internal Activation Unit)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_CNN_04",
        "desc": "CNN MaxPool2x2 Spatial Downsampling Layer: Verify 2x2 max pooling with stride 2 reducing 784 activations across 4 channels to 196 downsampled features.",
        "checkpoint": "Non-overlapping 2x2 windows select maximum value; spatial dimensions downsample from 14x14 to 7x7 per channel.",
        "c_part": "N/A (Accelerator pooling stage).",
        "sv_part": "Apply 14x14 feature maps per filter; verify maximum element selection for each quadrant into 196 downsampled outputs.",
        "category": "Internal",
        "interface": "N/A (Internal Spatial Downsampler)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_CNN_05",
        "desc": "CNN FC196_16 Fully Connected Layer & Bias Addition: Verify Fully Connected matrix multiplication (196 inputs x 16 neurons) with bias addition producing 16-element embedding.",
        "checkpoint": "Output 16-element embedding vector matches golden dot products Y = W * X + B.",
        "c_part": "N/A (Accelerator dense layer).",
        "sv_part": "Feed 196 pooled features and 16x196 weight matrix; verify 16-D embedding output registers match Python reference vectors.",
        "category": "Internal",
        "interface": "N/A (Internal Dense Matrix Multiplier)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_CNN_06",
        "desc": "CNN SRAM Image Buffer Direct AXI Accessibility: Verify direct AXI reads and writes to the CNN 256-byte internal SRAM buffer (0x2000_3100 - 0x2000_31FC).",
        "checkpoint": "Written image pixels retain integrity; readback matches written bytes; address decoding properly routes to SRAM buffer.",
        "c_part": "Write test pattern array into buffer address 0x2000_3100; read back and verify byte-for-byte equality.",
        "sv_part": "Monitor AXI writes to buffer range; probe SRAM memory array signals; assert write data matches stored bytes.",
        "category": "Internal",
        "interface": "N/A (Internal SRAM Buffer)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_CNN_07",
        "desc": "CNN Full Inference Pipeline Trigger & Embedding Generation: Verify complete CNN inference trigger, busy polling, and 16-element embedding vector generation over AXI crossbar.",
        "checkpoint": "STATUS.DONE asserts; STATUS.BUSY deasserts; 16 embedding registers (0x2000_3020 - 0x2000_305C) contain valid non-zero embeddings.",
        "c_part": "Program DIM_CFG=16x16, EMBED_LEN=16, trigger START=1, poll STATUS.DONE, read embedding registers.",
        "sv_part": "Monitor crossbar transactions to M05; verify pipeline execution latency (approx 500-1000 cycles); check embedding registers match golden vectors.",
        "category": "Internal",
        "interface": "N/A (Internal Accelerator AXI Slave)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_CNN_08",
        "desc": "CNN Completion Interrupt Generation: Verify assertion of dedicated completion interrupt pin cnn_irq_o when CNN inference finishes.",
        "checkpoint": "Physical pin cnn_irq_o transitions 0 -> 1 simultaneously with STATUS.DONE=1; deasserts upon W1C clear.",
        "c_part": "Configure CNN_CTRL with IRQ_EN=1; trigger inference; wait for interrupt; clear status with W1C.",
        "sv_part": "Probe physical cnn_irq_o output pin; assert pin asserts high when STATUS.DONE=1 and drops to 0 after W1C write.",
        "category": "External",
        "interface": "CNN Interrupt Interface",
        "signals": "cnn_irq_o"
    },
    {
        "name": "TC_CNN_09",
        "desc": "CNN Invalid Dimension Configuration Fault Rejection: Fault injection: Program illegal image dimensions or unsupported embedding length and check error handling.",
        "checkpoint": "CNN rejects start; asserts STATUS.ERROR=1 with ERROR_CODE=3; pipeline remains IDLE.",
        "c_part": "Write unsupported dimensions (e.g. 32x32) to DIM_CFG; attempt start; read STATUS register and verify rejection.",
        "sv_part": "Check configuration validator logic blocks FSM transition to RUNNING and reports error code to AXI bus.",
        "category": "Internal",
        "interface": "N/A (Internal Parameter Validator)",
        "signals": "N/A (Internal)"
    },

    # --- Module 3: Distance & Anomaly Detection IP ---
    {
        "name": "TC_DIST_01",
        "desc": "Distance Manhattan L1 Calculation: Verify hardware calculation of Manhattan (L1) distance: sum(|query[i] - ref[i]|) for 16 elements.",
        "checkpoint": "MIN_DISTANCE register holds exact mathematical sum of absolute differences.",
        "c_part": "Load query embedding into IP registers; load reference embedding into slot 0; trigger calculation; read MIN_DISTANCE.",
        "sv_part": "Compare hardware computed distance in MIN_DISTANCE against reference C model computation; assert exact equality.",
        "category": "Internal",
        "interface": "N/A (Internal Subtractor & Accumulator)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_DIST_02",
        "desc": "Distance Threshold Match Classification (Normal Image): Verify classification when computed distance <= threshold (Expected: RESULT=1 for MATCH / NORMAL).",
        "checkpoint": "MIN_DISTANCE = 0; RESULT = 1 (MATCH) since distance (0) <= threshold (50).",
        "c_part": "Program matching reference vector, threshold=50, start engine, verify RESULT==1 and MIN_DISTANCE==0.",
        "sv_part": "Monitor Distance AXI registers; verify comparator asserts RESULT=1 when distance is below threshold.",
        "category": "Internal",
        "interface": "N/A (Internal Comparator Logic)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_DIST_03",
        "desc": "Distance Threshold Anomaly Classification (Outlier Image): Verify classification when computed distance > threshold (Expected: RESULT=0 for ANOMALY).",
        "checkpoint": "MIN_DISTANCE = 800; RESULT = 0 (ANOMALY) since distance (800) > threshold (50).",
        "c_part": "Program divergent reference vector, threshold=50, start engine, verify RESULT==0 and MIN_DISTANCE==800.",
        "sv_part": "Monitor Distance AXI registers; verify comparator asserts RESULT=0 when distance exceeds threshold.",
        "category": "Internal",
        "interface": "N/A (Internal Comparator Logic)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_DIST_04",
        "desc": "Distance Completion Interrupt Generation: Verify assertion of dedicated completion interrupt pin dist_irq_o when distance calculation finishes.",
        "checkpoint": "Physical pin dist_irq_o transitions 0 -> 1 when calculation completes; deasserts upon W1C clear.",
        "c_part": "Configure DIST_CTRL with IRQ_EN=1; trigger scoring; clear interrupt via W1C write.",
        "sv_part": "Probe physical dist_irq_o output pin; verify pin rises to 1 on completion and drops to 0 on W1C clear.",
        "category": "External",
        "interface": "Distance Interrupt Interface",
        "signals": "dist_irq_o"
    },
    {
        "name": "TC_DIST_05",
        "desc": "Distance Unsupported Metric Code Fault Rejection: Fault injection: Program unsupported metric index into DIST_METRIC register and verify error response.",
        "checkpoint": "IP rejects configuration; asserts STATUS.ERROR=1 with ERROR_CODE=4; refuses execution.",
        "c_part": "Write unsupported metric code (e.g. 5) into DIST_METRIC; read STATUS register and verify rejection.",
        "sv_part": "Verify configuration validator asserts error flag and prevents distance accumulator from triggering.",
        "category": "Internal",
        "interface": "N/A (Internal Metric Validator)",
        "signals": "N/A (Internal)"
    },

    # --- Module 4: UART 16550 Subsystem ---
    {
        "name": "TC_UART_01",
        "desc": "UART Baud Divisor & Line Control Register Configuration: Verify UART Line Control Register (LCR), Baud Divisor (BAUD_DIV), and Interrupt Enable (IER) read/write access.",
        "checkpoint": "Registers retain written configurations (8N1 mode, divisor 16); readback returns programmed values with OKAY response.",
        "c_part": "Write 0x80 to LCR (DLAB=1), divisor 16 to BAUD_DIV, 0x03 to LCR (8N1), and 0x01 to IER; read back and assert equality.",
        "sv_part": "Snoops AXI crossbar slave M02 (0x2000_0000); asserts awready/wready handshakes and verifies bresp === 2'b00.",
        "category": "Internal",
        "interface": "N/A (Internal AXI-Lite CSR)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_UART_02",
        "desc": "UART Serial Bitstream Serialization on uart_tx_o: Transmit byte 'R' (0x52) across physical serial pin uart_tx_o at configured baud rate (divisor 16 = 170.0 ns/bit).",
        "checkpoint": "Physical pin uart_tx_o drives 1 START bit (low), 8 data bits (01010010 LSB-first), and 1 STOP bit (high).",
        "c_part": "Poll UART_LSR until THRE (bit 5) is set, then write 0x52 ('R') to UART_THR (0x2000_0000).",
        "sv_part": "Testbench UART monitor detects falling edge on uart_tx_o, samples 8 bits sequentially mid-cycle (170 ns bit period), and checks parity/stop bit.",
        "category": "External",
        "interface": "UART Serial Interface",
        "signals": "uart_tx_o"
    },
    {
        "name": "TC_UART_03",
        "desc": "UART TX FIFO Status & Empty Flag Progression: Verify TX FIFO empty, full, and occupancy tracking in Line Status Register (LSR THRE and TEMT flags).",
        "checkpoint": "LSR THRE and TEMT assert when FIFO drains to empty; deassert when characters are written to THR.",
        "c_part": "Read LSR, verify THRE=1; write burst of characters; poll LSR until TEMT confirms transmitter shift register is empty.",
        "sv_part": "Monitor internal FIFO pointers (axi_internal_fifo_tx_inst); check empty_o and full_o flags match LSR register bits.",
        "category": "Internal",
        "interface": "N/A (Internal FIFO & Status Register)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_UART_04",
        "desc": "UART Read & Status Interrupt Pin Assertion: Verify assertion of dedicated interrupt pin uart_irq_o when RX data is ready or TX FIFO transitions to empty.",
        "checkpoint": "Physical pin uart_irq_o asserts high on interrupt condition; deasserts upon reading RBR or servicing IER.",
        "c_part": "Enable interrupt in UART_IER; inject or transmit character; verify interrupt line transitions.",
        "sv_part": "Probe physical uart_irq_o output pin on chip boundary; check pin transitions 0 -> 1 upon interrupt event.",
        "category": "External",
        "interface": "UART Serial Interface, Interrupt Interface",
        "signals": "uart_irq_o"
    },

    # --- Module 5: OpenTitan 64-Bit RISC-V Timer ---
    {
        "name": "TC_TMR_01",
        "desc": "Timer Counter Increment Progression: Program prescaler and step rate, enable timer core, and check 64-bit real-time counter progression.",
        "checkpoint": "MTIME counter increments monotonically at configured tick frequency without roll-over glitches.",
        "c_part": "Write prescaler to CFG0 (0x2000_110C), enable timer core via CTRL, sample t0 = MTIME_LO, delay, sample t1, assert t1 > t0.",
        "sv_part": "Snoop AXI slave M03; verify timer CTRL write takes effect and internal counter advances monotonically.",
        "category": "Internal",
        "interface": "N/A (Internal Real-Time Counter)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_TMR_02",
        "desc": "Timer Match Interrupt Generation & Clearing: Validate compare match trigger between MTIME and MTIMECMP registers driving timer_irq_o.",
        "checkpoint": "Physical pin timer_irq_o asserts when MTIME >= MTIMECMP; clears immediately on write to interrupt status.",
        "c_part": "Read MTIME, set MTIMECMP = t0 + 100, enable interrupt, poll INTR_STATE, clear interrupt upon match.",
        "sv_part": "Monitor physical timer_irq_o pin; assert timer_irq_o transitions 0 -> 1 exactly on match and deasserts upon clearing write.",
        "category": "External",
        "interface": "Timer Interrupt Interface",
        "signals": "timer_irq_o"
    },

    # --- Module 6: PULP Platform 32-Bit GPIO ---
    {
        "name": "TC_GPIO_01",
        "desc": "GPIO Pin Direction Configuration: Configure pin direction registers, drive static values, and observe external direction control lines gpio_dir_o.",
        "checkpoint": "Physical pin gpio_dir_o[31:0] reflects programmed direction register exactly (1=output, 0=input).",
        "c_part": "Write GPIO_EN = 0x0000_00FF to enable lower 8 pins as outputs; read back and confirm direction configuration.",
        "sv_part": "Sample top-level pin gpio_dir_o[31:0]; assert gpio_dir_o[7:0] === 8'hFF and gpio_dir_o[31:8] === 24'h0.",
        "category": "External",
        "interface": "GPIO Parallel IO Interface",
        "signals": "gpio_dir_o[31:0]"
    },
    {
        "name": "TC_GPIO_02",
        "desc": "GPIO Output Pattern Driving onto External Pins: Drive test patterns onto gpio_o[31:0] and observe external digital output lines.",
        "checkpoint": "External pins gpio_o[31:0] reflect written values (0xA5, 0x55, 0x25) with zero bit skew.",
        "c_part": "Write GPIO_OUT = 0x0000_00A5; read back and confirm output register reflection.",
        "sv_part": "Sample top-level pins gpio_o[31:0]; assert gpio_o[7:0] === 8'hA5 within 2 clock cycles of write handshake.",
        "category": "External",
        "interface": "GPIO Parallel IO Interface",
        "signals": "gpio_o[31:0]"
    },
    {
        "name": "TC_GPIO_03",
        "desc": "GPIO Atomic SET, CLEAR, and TOGGLE Operations: Verify atomic SET/CLEAR/TOGGLE registers without requiring software read-modify-write cycles.",
        "checkpoint": "Atomic SET sets specific bits; atomic CLEAR clears specific bits; unaffected bits remain unmodified.",
        "c_part": "Write 0x0F to GPIO_SET; write 0x03 to GPIO_CLEAR; verify output state equals 0x0C.",
        "sv_part": "Monitor AXI slave M04; verify atomic registers update internal output flip-flops within 1 cycle.",
        "category": "Internal",
        "interface": "N/A (Internal Atomic Register Logic)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_GPIO_04",
        "desc": "GPIO External Input Sampling via 2-Stage Synchronizer: Drive stimulus into external pins gpio_i[31:0] and verify CPU samples values through 2-stage synchronizers.",
        "checkpoint": "GPIO_IN register returns injected external pattern after 2 clock cycles of synchronization.",
        "c_part": "Read GPIO_IN register (0x2000_2000) and compare read data against injected vector (0x5A5A_A5A5).",
        "sv_part": "Drive gpio_i[31:0] = 32'h5A5A_A5A5; verify signals pass through gpio_input_stage synchronizer and return valid read response.",
        "category": "External",
        "interface": "GPIO Parallel IO Interface",
        "signals": "gpio_i[31:0]"
    },
    {
        "name": "TC_GPIO_05",
        "desc": "GPIO Edge-Triggered Interrupt Generation: Configure rising-edge trigger on pin 0 and verify interrupt generation on low-to-high transition driving gpio_irq_o.",
        "checkpoint": "Physical pin gpio_irq_o asserts on 0 -> 1 pin transition; deasserts after clearing interrupt status register.",
        "c_part": "Program GPIO_RISE_EN = 0x01; wait for hardware event; poll INTRPT_STATUS; clear interrupt via W1C write.",
        "sv_part": "Drive gpio_i[0] from 0 -> 1; assert physical pin gpio_irq_o === 1'b1; verify deassertion after software clears status.",
        "category": "External",
        "interface": "GPIO Parallel IO Interface, Interrupt Interface",
        "signals": "gpio_i[0], gpio_irq_o"
    },

    # --- Module 7: 2-Master x 8-Slave AXI4 Crossbar Interconnect ---
    {
        "name": "TC_AXI_01",
        "desc": "AXI Crossbar 8-Slave Address Decoding Verification: Verify accurate address decoding and transaction routing across all 8 peripheral slave apertures (IMEM, DMEM, UART, Timer, GPIO, CNN, Distance, DMA).",
        "checkpoint": "Each slave port is uniquely selected by its base address aperture; zero address overlap or false aliasing.",
        "c_part": "Execute read/write transactions to base addresses of each slave; verify expected register reflection and memory readback.",
        "sv_part": "Assert slave select decoder activates corresponding m00..m07 channels; verify awready/wready and arready handshakes across all ports.",
        "category": "Internal",
        "interface": "N/A (Internal AXI Interconnect Crossbar)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_AXI_02",
        "desc": "AXI Unmapped Address Access DECERR Response: Verify bus access to unmapped peripheral space (0x3000_0000 or 0xF000_0000) returns decode error (DECERR) without bus deadlock.",
        "checkpoint": "Interconnect default slave returns DECERR (bresp/rresp = 2'b11); CPU receives bus error trap without hanging bus.",
        "c_part": "Perform 32-bit load/store to unmapped address 0x3000_0000; catch expected bus-error trap in mtvec handler.",
        "sv_part": "Monitor crossbar master bus; verify default slave decoder asserts rresp = 2'b11 or bresp = 2'b11 without hanging handshakes.",
        "category": "Internal",
        "interface": "N/A (Internal Interconnect Default Slave)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_AXI_03",
        "desc": "AXI Multi-Master Round-Robin Arbitration Stress: Force concurrent AXI transactions from CPU LSU Master (S00) and DMA Master (S01) targeting distinct slaves.",
        "checkpoint": "Zero deadlock; round-robin arbiter cleanly serves both masters without starving either port; preserves transaction IDs.",
        "c_part": "Execute alternating bursts to Timer and CNN while DMA engine is actively transferring data between DMEM and buffer.",
        "sv_part": "Stress master interfaces simultaneously; check round-robin grant progression; assert zero starvation or ID mix-up.",
        "category": "Internal",
        "interface": "N/A (Internal Multi-Master Arbiter)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_AXI_04",
        "desc": "AXI Slave Backpressure Handshake Integrity: Verify interconnect behavior when slave deasserts ready (awready=0, wready=0, arready=0) introducing backpressure.",
        "checkpoint": "Master holds valid and data stable until ready asserts; zero dropped transactions or corrupted data beats.",
        "c_part": "Issue bursts while peripherals are busy executing multi-cycle operations (e.g. CNN inference or DMA bursts).",
        "sv_part": "Inject artificial delays on slave ready signals; verify master adheres strictly to AXI4 protocol rules (valid stability).",
        "category": "Internal",
        "interface": "N/A (Internal Crossbar Pipeline Stages)",
        "signals": "N/A (Internal)"
    },

    # --- Module 8: Memory Subsystem ---
    {
        "name": "TC_MEM_01",
        "desc": "IMEM True Dual-Port Concurrency Verification: Verify concurrent read/write operations to shared dual-port IMEM (Port A: IFU direct fetch; Port B: LSU/DMA writes).",
        "checkpoint": "CPU fetches instructions from Port A without pipeline stalls while Port B receives firmware updates or writes.",
        "c_part": "Execute program from IMEM while writing data blocks to upper IMEM addresses over LSU Port B.",
        "sv_part": "Drive simultaneous read on Port A and write on Port B to distinct addresses; assert zero contention or data corruption.",
        "category": "Internal",
        "interface": "N/A (Internal Dual-Port SRAM)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_MEM_02",
        "desc": "DMEM Byte-Lane Strobes (wstrb) Verification: Verify byte, half-word, and word reads and writes to Data Memory (0x1000_0000) using 4-bit byte enables (wstrb).",
        "checkpoint": "Byte writes (wstrb=4'h1, 4'h2, 4'h4, 4'h8) update only the addressed byte lanes; neighboring byte lanes remain unchanged.",
        "c_part": "Write 0xAA to byte 0, 0xBB to byte 1, 0xCC to byte 2, 0xDD to byte 3; read back 32-bit word and assert equality to 0xDDCCBBAA.",
        "sv_part": "Monitor m01_axi_wstrb and SRAM byte write enables; verify individual byte storage without side-effects.",
        "category": "Internal",
        "interface": "N/A (Internal Byte-Addressable SRAM)",
        "signals": "N/A (Internal)"
    },

    # --- Module 9: Full SoC Processor-Driven Integration & End-to-End Pipeline ---
    {
        "name": "TC_SOC_01",
        "desc": "SoC Power-on Reset Release & Boot Vector Check: Power-on reset release allows VeeR-EL2 to fetch its first instruction from address 0x0000_0000 into IMEM.",
        "checkpoint": "CPU executes first opcode at 0x0000_0000; reset values asserted across all peripheral registers; GPIO indicates boot stage 0x01.",
        "c_part": "Execute crt0.s startup: set mtvec, configure MRAC (CSR 0x7C0 = 0x5555556A), initialize sp = _stack_top, write 0x01 to GPIO_OUT.",
        "sv_part": "Drive active-low reset rst_l = 0 for 10 cycles, deassert, and monitor trace_rv_i_address_ip === 32'h0000_0000. Verify gpio_o === 32'h01.",
        "category": "External",
        "interface": "Reset & Clock Interface, GPIO Interface",
        "signals": "rst_l, clk, gpio_o[31:0]"
    },
    {
        "name": "TC_SOC_02",
        "desc": "SoC Complete Firmware Console Logging over UART: Verify full processor-driven console print execution over memory-mapped UART 16550 serial wire.",
        "checkpoint": "Serial pin uart_tx_o outputs all boot, progress, and diagnostic banner characters without framing errors.",
        "c_part": "Initialize UART (divisor 16), print banner strings, progress messages, and diagnostic outputs using uart_puts.",
        "sv_part": "Autonomous testbench UART monitor deserializes serial stream from uart_tx_o at 170.0 ns/bit; verifies full banner capture.",
        "category": "External",
        "interface": "UART Serial Interface",
        "signals": "uart_tx_o"
    },
    {
        "name": "TC_SOC_03",
        "desc": "SoC End-to-End Pipeline (Normal Image Classification): Full autonomous pipeline execution: DMA moves image to CNN buffer, CNN extracts embedding, Distance engine classifies normal image (MATCH).",
        "checkpoint": "DMA transfer completes (DONE=1), CNN extracts 16-D embedding, Distance = 0 (<= 50), RESULT = 1 (MATCH / NORMAL).",
        "c_part": "Configure DMA transfer, trigger CNN accelerator, configure Distance with Normal reference, verify classification result equals 1.",
        "sv_part": "Scoreboard tracks multi-IP transaction flow across crossbar; verifies zero error flags and correct decision logging.",
        "category": "Internal",
        "interface": "N/A (On-Chip Hardware Accelerators)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_SOC_04",
        "desc": "SoC End-to-End Pipeline (Anomaly Image Detection): Full autonomous pipeline execution: CNN extracts embedding, Distance engine compares against Divergent reference, flags ANOMALY.",
        "checkpoint": "Computed distance = 800 (> threshold 50); RESULT = 0 (ANOMALY DETECTED); decision logged to UART.",
        "c_part": "Load divergent reference vector, run distance scoring, verify RESULT equals 0 (Anomaly), emit step completion code.",
        "sv_part": "Scoreboard verifies comparator flags anomaly, checks UART logs reflect 'ANOMALY DETECTED!', and asserts zero bus traps.",
        "category": "Internal",
        "interface": "N/A (On-Chip Hardware Accelerators)",
        "signals": "N/A (Internal)"
    },
    {
        "name": "TC_SOC_05",
        "desc": "SoC Final Firmware Pass & C-to-SV Mailbox Handshake: Complete execution of full anomaly suite validating all peripherals sequentially with final GPIO output 0x0000_0055.",
        "checkpoint": "gpio_o reports 0x0000_0055; Mailbox register (0x1000_FF00) reads 0x0000_0001; simulation finishes cleanly with exit code 0.",
        "c_part": "Execute main() through DMA, CNN, Distance, and UART; write 0x0000_0055 to GPIO_OUT; write 0x01 to MAILBOX_REG.",
        "sv_part": "Testbench samples gpio_o and Mailbox; detects 32'h0000_0055, prints '[TESTBENCH SUCCESS] ALL C CODE COMMANDS EXECUTED!', calls $finish(0).",
        "category": "External",
        "interface": "GPIO Parallel IO Interface",
        "signals": "gpio_o[31:0]"
    },
    {
        "name": "TC_SOC_06",
        "desc": "SoC RISC-V CPU Arithmetic to UART Transmission Verification: RISC-V CPU performs arithmetic calculation (10 + 20 - 5 = 25) and transmits the dynamic numerical result over memory-mapped UART.",
        "checkpoint": "Physical pin uart_tx_o outputs 'Result = 25\\r\\n'; gpio_o reports 0x0000_0025; Mailbox reads 25 (0x19); exit code 0.",
        "c_part": "Execute simple_test.c: compute c = 10 + 20 - 5, call uart_puts('Result = '), call uart_print_dec(c), write 0x25 to GPIO_OUT.",
        "sv_part": "UART monitor deserializes serial stream on uart_tx_o; captures string 'Result = 25'; samples gpio_o == 32'h0000_0025; confirms test pass.",
        "category": "External",
        "interface": "UART Serial Interface, GPIO Parallel IO Interface",
        "signals": "uart_tx_o, gpio_o[31:0]"
    }
]

# -----------------------------------------------------------------------------
# XML Helper Functions for ODS Generation
# -----------------------------------------------------------------------------
def escape_xml(s):
    if s is None:
        return ""
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;").replace("'", "&apos;")

def generate_content_xml(test_cases):
    # XML Header and namespaces matching the reference ODS
    xml = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
        'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
        'xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" '
        'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" '
        'xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" '
        'xmlns:presentation="urn:oasis:names:tc:opendocument:xmlns:presentation:1.0" '
        'xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" '
        'xmlns:chart="urn:oasis:names:tc:opendocument:xmlns:chart:1.0" '
        'xmlns:dr3d="urn:oasis:names:tc:opendocument:xmlns:dr3d:1.0" '
        'xmlns:math="http://www.w3.org/1998/Math/MathML" '
        'xmlns:form="urn:oasis:names:tc:opendocument:xmlns:form:1.0" '
        'xmlns:script="urn:oasis:names:tc:opendocument:xmlns:script:1.0" '
        'xmlns:ooo="http://openoffice.org/2004/office" '
        'xmlns:ooow="http://openoffice.org/2004/writer" '
        'xmlns:oooc="http://openoffice.org/2004/calc" '
        'xmlns:dom="http://www.w3.org/2001/xml-events" '
        'xmlns:xforms="http://www.w3.org/2002/xforms" '
        'xmlns:xsd="http://www.w3.org/2001/XMLSchema" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xmlns:rpt="http://openoffice.org/2005/report" '
        'xmlns:of="urn:oasis:names:tc:opendocument:xmlns:of:1.2" '
        'xmlns:xhtml="http://www.w3.org/1999/xhtml" '
        'xmlns:grddl="http://www.w3.org/2003/g/data-view#" '
        'xmlns:tableooo="http://openoffice.org/2009/table" '
        'xmlns:drawooo="http://openoffice.org/2010/draw" '
        'xmlns:calcext="urn:org:documentfoundation:names:experimental:calc:xmlns:calcext:1.0" '
        'xmlns:loext="urn:org:documentfoundation:names:experimental:office:xmlns:loext:1.0" '
        'xmlns:field="urn:openoffice:names:experimental:ooo-ms-interop:xmlns:field:1.0" '
        'xmlns:formx="urn:openoffice:names:experimental:ooxml-odf-interop:xmlns:form:1.0" '
        'xmlns:css3t="http://www.w3.org/TR/css3-text/" office:version="1.2">',
        '<office:scripts/>',
        '<office:font-face-decls>',
        '<style:font-face style:name="Liberation Sans" svg:font-family="&apos;Liberation Sans&apos;" style:font-family-generic="swiss" style:font-pitch="variable"/>',
        '<style:font-face style:name="Calibri" svg:font-family="Calibri" style:font-family-generic="swiss" style:font-pitch="variable"/>',
        '<style:font-face style:name="Consolas" svg:font-family="Consolas" style:font-family-generic="modern" style:font-pitch="fixed"/>',
        '</office:font-face-decls>',
        '<office:automatic-styles>',
        # Column styles with column widths
        '<style:style style:name="co1" style:family="table-column"><style:table-column-properties fo:break-before="auto" style:column-width="1.4cm"/></style:style>',
        '<style:style style:name="co2" style:family="table-column"><style:table-column-properties fo:break-before="auto" style:column-width="2.8cm"/></style:style>',
        '<style:style style:name="co3" style:family="table-column"><style:table-column-properties fo:break-before="auto" style:column-width="26.0cm"/></style:style>',
        '<style:style style:name="co4" style:family="table-column"><style:table-column-properties fo:break-before="auto" style:column-width="18.0cm"/></style:style>',
        '<style:style style:name="co5" style:family="table-column"><style:table-column-properties fo:break-before="auto" style:column-width="28.0cm"/></style:style>',
        '<style:style style:name="co6" style:family="table-column"><style:table-column-properties fo:break-before="auto" style:column-width="26.0cm"/></style:style>',
        '<style:style style:name="co7" style:family="table-column"><style:table-column-properties fo:break-before="auto" style:column-width="3.5cm"/></style:style>',
        '<style:style style:name="co8" style:family="table-column"><style:table-column-properties fo:break-before="auto" style:column-width="10.0cm"/></style:style>',
        '<style:style style:name="co9" style:family="table-column"><style:table-column-properties fo:break-before="auto" style:column-width="8.0cm"/></style:style>',
        # Row styles
        '<style:style style:name="ro_hdr" style:family="table-row"><style:table-row-properties style:row-height="0.9cm" fo:break-before="auto" style:use-optimal-row-height="false"/></style:style>',
        '<style:style style:name="ro_data" style:family="table-row"><style:table-row-properties fo:break-before="auto" style:use-optimal-row-height="true"/></style:style>',
        # Cell styles: Header
        '<style:style style:name="ce_hdr" style:family="table-cell" style:parent-style-name="Default">'
        '<style:table-cell-properties fo:background-color="#1f4e78" fo:wrap-option="wrap" fo:border="0.74pt solid #999999" style:vertical-align="middle"/>'
        '<style:text-properties fo:color="#ffffff" fo:font-weight="bold" style:font-name="Calibri" fo:font-size="11pt"/>'
        '<style:paragraph-properties fo:text-align="center"/>'
        '</style:style>',
        # Cell styles: SNo / Testname (Bold centered or left)
        '<style:style style:name="ce_sno" style:family="table-cell" style:parent-style-name="Default">'
        '<style:table-cell-properties fo:wrap-option="wrap" fo:border="0.74pt solid #d3d3d3" style:vertical-align="top"/>'
        '<style:text-properties fo:color="#000000" fo:font-weight="bold" style:font-name="Calibri" fo:font-size="10pt"/>'
        '<style:paragraph-properties fo:text-align="center"/>'
        '</style:style>',
        '<style:style style:name="ce_name" style:family="table-cell" style:parent-style-name="Default">'
        '<style:table-cell-properties fo:wrap-option="wrap" fo:border="0.74pt solid #d3d3d3" style:vertical-align="top"/>'
        '<style:text-properties fo:color="#0a2540" fo:font-weight="bold" style:font-name="Consolas" fo:font-size="10pt"/>'
        '</style:style>',
        # Cell styles: Text wrap
        '<style:style style:name="ce_text" style:family="table-cell" style:parent-style-name="Default">'
        '<style:table-cell-properties fo:wrap-option="wrap" fo:border="0.74pt solid #d3d3d3" style:vertical-align="top"/>'
        '<style:text-properties fo:color="#000000" style:font-name="Calibri" fo:font-size="10pt"/>'
        '</style:style>',
        # Cell styles: Internal/External
        '<style:style style:name="ce_ext" style:family="table-cell" style:parent-style-name="Default">'
        '<style:table-cell-properties fo:background-color="#e8f4fd" fo:wrap-option="wrap" fo:border="0.74pt solid #d3d3d3" style:vertical-align="top"/>'
        '<style:text-properties fo:color="#004085" fo:font-weight="bold" style:font-name="Calibri" fo:font-size="10pt"/>'
        '<style:paragraph-properties fo:text-align="center"/>'
        '</style:style>',
        '<style:style style:name="ce_int" style:family="table-cell" style:parent-style-name="Default">'
        '<style:table-cell-properties fo:background-color="#f8f9fa" fo:wrap-option="wrap" fo:border="0.74pt solid #d3d3d3" style:vertical-align="top"/>'
        '<style:text-properties fo:color="#383d41" style:font-name="Calibri" fo:font-size="10pt"/>'
        '<style:paragraph-properties fo:text-align="center"/>'
        '</style:style>',
        # Cell styles: Signal name
        '<style:style style:name="ce_sig" style:family="table-cell" style:parent-style-name="Default">'
        '<style:table-cell-properties fo:wrap-option="wrap" fo:border="0.74pt solid #d3d3d3" style:vertical-align="top"/>'
        '<style:text-properties fo:color="#800020" fo:font-weight="bold" style:font-name="Consolas" fo:font-size="9pt"/>'
        '</style:style>',
        '</office:automatic-styles>',
        '<office:body>',
        '<office:spreadsheet>',
        '<table:table table:name="Testplan" table:style-name="ta1">',
        # Columns 1 to 9
        '<table:table-column table:style-name="co1"/>',
        '<table:table-column table:style-name="co2"/>',
        '<table:table-column table:style-name="co3"/>',
        '<table:table-column table:style-name="co4"/>',
        '<table:table-column table:style-name="co5"/>',
        '<table:table-column table:style-name="co6"/>',
        '<table:table-column table:style-name="co7"/>',
        '<table:table-column table:style-name="co8"/>',
        '<table:table-column table:style-name="co9"/>',
        # Header Row
        '<table:table-row table:style-name="ro_hdr">',
        '<table:table-cell table:style-name="ce_hdr" office:value-type="string"><text:p>SNo.</text:p></table:table-cell>',
        '<table:table-cell table:style-name="ce_hdr" office:value-type="string"><text:p>Testname</text:p></table:table-cell>',
        '<table:table-cell table:style-name="ce_hdr" office:value-type="string"><text:p>Description</text:p></table:table-cell>',
        '<table:table-cell table:style-name="ce_hdr" office:value-type="string"><text:p>Checkpoint</text:p></table:table-cell>',
        '<table:table-cell table:style-name="ce_hdr" office:value-type="string"><text:p>C verification part</text:p></table:table-cell>',
        '<table:table-cell table:style-name="ce_hdr" office:value-type="string"><text:p>SV verification part</text:p></table:table-cell>',
        '<table:table-cell table:style-name="ce_hdr" office:value-type="string"><text:p>Internal/ External</text:p></table:table-cell>',
        '<table:table-cell table:style-name="ce_hdr" office:value-type="string"><text:p>Interface (in case of External)</text:p></table:table-cell>',
        '<table:table-cell table:style-name="ce_hdr" office:value-type="string"><text:p>Corresponding signals</text:p></table:table-cell>',
        '</table:table-row>'
    ]

    # Data Rows
    for idx, tc in enumerate(test_cases, 1):
        is_ext = tc["category"] == "External"
        cat_style = "ce_ext" if is_ext else "ce_int"
        xml.append('<table:table-row table:style-name="ro_data">')
        xml.append(f'<table:table-cell table:style-name="ce_sno" office:value-type="float" office:value="{idx}"><text:p>{idx}</text:p></table:table-cell>')
        xml.append(f'<table:table-cell table:style-name="ce_name" office:value-type="string"><text:p>{escape_xml(tc["name"])}</text:p></table:table-cell>')
        xml.append(f'<table:table-cell table:style-name="ce_text" office:value-type="string"><text:p>{escape_xml(tc["desc"])}</text:p></table:table-cell>')
        xml.append(f'<table:table-cell table:style-name="ce_text" office:value-type="string"><text:p>{escape_xml(tc["checkpoint"])}</text:p></table:table-cell>')
        xml.append(f'<table:table-cell table:style-name="ce_text" office:value-type="string"><text:p>{escape_xml(tc["c_part"])}</text:p></table:table-cell>')
        xml.append(f'<table:table-cell table:style-name="ce_text" office:value-type="string"><text:p>{escape_xml(tc["sv_part"])}</text:p></table:table-cell>')
        xml.append(f'<table:table-cell table:style-name="{cat_style}" office:value-type="string"><text:p>{escape_xml(tc["category"])}</text:p></table:table-cell>')
        xml.append(f'<table:table-cell table:style-name="ce_text" office:value-type="string"><text:p>{escape_xml(tc["interface"])}</text:p></table:table-cell>')
        xml.append(f'<table:table-cell table:style-name="ce_sig" office:value-type="string"><text:p>{escape_xml(tc["signals"])}</text:p></table:table-cell>')
        xml.append('</table:table-row>')

    xml.append('</table:table>')
    xml.append('</office:spreadsheet>')
    xml.append('</office:body>')
    xml.append('</office:document-content>')
    return '\n'.join(xml)

def create_ods(output_path, test_cases, template_path='/home/student/Downloads/VeeR_EL2_SoC_Testplan.ods'):
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    new_content_xml = generate_content_xml(test_cases)
    
    # Read template zip and replace content.xml
    with zipfile.ZipFile(template_path, 'r') as zin:
        with zipfile.ZipFile(output_path, 'w', compression=zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                if item.filename == 'mimetype':
                    # mimetype must be stored uncompressed as the first entry
                    zout.writestr('mimetype', b'application/vnd.oasis.opendocument.spreadsheet', compress_type=zipfile.ZIP_STORED)
                elif item.filename == 'content.xml':
                    zout.writestr('content.xml', new_content_xml.encode('utf-8'), compress_type=zipfile.ZIP_DEFLATED)
                else:
                    data = zin.read(item.filename)
                    zout.writestr(item, data)
    print(f"[OK] Generated ODS spreadsheet: {output_path}")

def convert_to_xlsx(ods_path, output_dir):
    cmd = ["libreoffice", "--headless", "--convert-to", "xlsx", ods_path, "--outdir", output_dir]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    if res.returncode == 0:
        base = os.path.splitext(os.path.basename(ods_path))[0]
        xlsx_path = os.path.join(output_dir, f"{base}.xlsx")
        print(f"[OK] Converted to Excel XLSX: {xlsx_path}")
        return xlsx_path
    else:
        print(f"[ERROR] LibreOffice conversion failed: {res.stderr}")
        return None

if __name__ == '__main__':
    target_ods_1 = '/home/student/cnn_acc_for_img_sim_proj/docs/verification/VeeR_EL2_SoC_Testplan.ods'
    target_ods_2 = '/home/student/cnn_acc_for_img_sim_proj/VeeR_EL2_SoC_Testplan.ods'
    target_ods_3 = '/home/student/hon/VeeR_EL2_SoC_Testplan.ods'
    
    create_ods(target_ods_1, test_cases)
    convert_to_xlsx(target_ods_1, '/home/student/cnn_acc_for_img_sim_proj/docs/verification')
    
    # Copy to project root and workspace
    import shutil
    shutil.copy2(target_ods_1, target_ods_2)
    shutil.copy2(target_ods_1.replace('.ods', '.xlsx'), target_ods_2.replace('.ods', '.xlsx'))
    shutil.copy2(target_ods_1, target_ods_3)
    shutil.copy2(target_ods_1.replace('.ods', '.xlsx'), target_ods_3.replace('.ods', '.xlsx'))
    
    print("\nSUCCESS: All VeeR_EL2_SoC_Testplan spreadsheet files generated across all locations!")
