# Master Verification Test Plan & External Interfaces Guide
## RISC-V CNN Anomaly Detection System-on-Chip (SoC)

---

### 📥 Master Spreadsheet Files
* **Multi-Tab Excel Workbook (XML):** [`docs/verification/SoC_Master_Verification_and_Interfaces.xml`](file:///home/student/honours/docs/verification/SoC_Master_Verification_and_Interfaces.xml)  
  *(Contains 2 styled tabs in one file: **Sheet 1 = External Interfaces**, **Sheet 2 = Verification Test Plan**)*
* **Test Plan CSV:** [`docs/verification/SoC_Verification_Test_Plan_Sheet.csv`](file:///home/student/honours/docs/verification/SoC_Verification_Test_Plan_Sheet.csv)
* **External Interfaces CSV:** [`docs/architecture/SoC_External_Interfaces_Sheet.csv`](file:///home/student/honours/docs/architecture/SoC_External_Interfaces_Sheet.csv)

---

## 1. What is an Interface & What Are the External Interfaces?

### What is an Interface?
An **interface** is a shared boundary or contract through which two hardware blocks talk to each other. It consists of:
1. **Physical wires** carrying signals.
2. **Protocol rules** (e.g. valid/ready handshake, or RS-232 serial timing).
3. **Data meaning** (e.g. registers, memory addresses, or ASCII text).

### What Are External Interfaces?
**External interfaces** are the signals that cross the physical package pins of the chip to connect to the outside world (board clock, LEDs, terminal screen, debugger, pushbuttons).

Here are all **28 external signals** used by this SoC (defined in [`rtl/top/cnn_soc_top.sv`](file:///home/student/honours/rtl/top/cnn_soc_top.sv)):

| Interface Group | Signal / Pin Name | Direction | Width | Connected Block | Protocol | What / How We Are Using It |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- |
| **Clock & Reset** | `clk` | Input | 1-bit | Global Clock Tree | 100 MHz CMOS | Primary 100 MHz clock driving CPU, AXI crossbar, DMA, CNN, Distance, and peripherals. |
| **Clock & Reset** | `rst_l` | Input | 1-bit | Reset Controller | Active-Low Reset | Main chip reset. When 0, resets CPU pipeline, bus arbiters, and registers to defaults. |
| **Clock & Reset** | `dbg_rst_l` | Input | 1-bit | Debug Subsystem | Active-Low Reset | Resets on-chip RISC-V debug module and JTAG TAP without resetting the CPU. |
| **UART Serial Console** | `uart_tx_o` | Output | 1-bit | `axi_uart_top` (M02) | RS-232 UART (8N1) | Serial wire sending text to screen (prints 26 boot, inference, and test pass lines). |
| **UART Serial Console** | `uart_rx_i` | Input | 1-bit | `axi_uart_top` (M02) | RS-232 UART (8N1) | Serial wire receiving commands or image data from external PC into UART RX FIFO. |
| **PULP 32-bit GPIO** | `gpio_o[31:0]` | Output | 32-bit | `gpio_axi_wrapper` (M04) | Parallel Digital CMOS | Physical output pins showing progress: 0x01 (boot), 0x02 (DMA done), 0x04 (CNN done), 0x55 (all pass). |
| **PULP 32-bit GPIO** | `gpio_i[31:0]` | Input | 32-bit | `gpio_axi_wrapper` (M04) | Parallel Digital CMOS | Physical inputs for buttons/sensors; passed through on-chip 2-stage synchronizer. |
| **PULP 32-bit GPIO** | `gpio_dir_o[31:0]` | Output | 32-bit | `gpio_axi_wrapper` (M04) | Pad Enable Strobe | Controls external bi-directional chip pad drivers (1=output drive, 0=high-Z input). |
| **Interrupt Output Pins** | `dma_irq_o` | Output | 1-bit | `dma_axi_wrapper` (M07) | Active-High Pulse | External pin pulses high when DMA block transfer (256-byte image) finishes. |
| **Interrupt Output Pins** | `cnn_irq_o` | Output | 1-bit | `cnn_axi_wrapper` (M05) | Active-High Pulse | External pin pulses high when CNN feature extraction inference finishes. |
| **Interrupt Output Pins** | `dist_irq_o` | Output | 1-bit | `distance_axi_wrapper` (M06) | Active-High Pulse | External pin pulses high when Manhattan distance scoring and threshold comparison finish. |
| **Interrupt Output Pins** | `uart_irq_o` | Output | 1-bit | `axi_uart_top` (M02) | Active-High Level | External pin asserts high when UART TX FIFO is empty or RX byte arrives. |
| **Interrupt Output Pins** | `timer_irq_o` | Output | 1-bit | `timer_axi_wrapper` (M03) | Active-High Level | External pin asserts high when 64-bit timer reaches compare target (MTIME >= MTIMECMP). |
| **Interrupt Output Pins** | `gpio_irq_o` | Output | 1-bit | `gpio_axi_wrapper` (M04) | Active-High Pulse | External pin pulses high when an enabled GPIO input pin detects edge/level transition. |
| **Core Interrupt Inputs** | `timer_int` | Input | 1-bit | CPU PIC Controller | Active-High Level | External machine timer interrupt input line wired into the VeeR-EL2 CPU. |
| **Core Interrupt Inputs** | `soft_int` | Input | 1-bit | CPU PIC Controller | Active-High Level | External software / inter-processor interrupt line wired into the VeeR-EL2 CPU. |
| **JTAG Hardware Debug** | `jtag_tck` | Input | 1-bit | VeeR Debug TAP | IEEE 1149.1 Clock | JTAG test clock for OpenOCD/GDB on-chip debugger access. |
| **JTAG Hardware Debug** | `jtag_tms` | Input | 1-bit | VeeR Debug TAP | IEEE 1149.1 Control | JTAG test mode select line driving state transitions of the 16-state TAP. |
| **JTAG Hardware Debug** | `jtag_tdi` | Input | 1-bit | VeeR Debug TAP | IEEE 1149.1 Data In | JTAG serial data input carrying CPU debug instructions and register read/write commands. |
| **JTAG Hardware Debug** | `jtag_trst_n` | Input | 1-bit | VeeR Debug TAP | Active-Low Reset | JTAG asynchronous reset pin to force TAP controller into Test-Logic-Reset state. |
| **JTAG Hardware Debug** | `jtag_tdo` | Output | 1-bit | VeeR Debug TAP | IEEE 1149.1 Data Out | JTAG serial data output returning CPU registers, program counter, and memory values. |
| **JTAG Hardware Debug** | `jtag_tdoEn` | Output | 1-bit | VeeR Debug TAP | Pad Driver Enable | Enables the external TDO pad driver buffer only when shifting data out. |
| **CPU Control & Status** | `i_cpu_halt_req` | Input | 1-bit | CPU Power Management | Handshake Control | External hardware signal to request CPU to pause instruction fetch and halt. |
| **CPU Control & Status** | `o_cpu_halt_ack` | Output | 1-bit | CPU Power Management | Handshake Acknowledge | CPU output signal confirming that the core has safely halted. |
| **CPU Control & Status** | `o_cpu_halt_status` | Output | 1-bit | CPU Power Management | Status Flag | Continuous status output flag indicating whether the CPU core is currently halted. |
| **CPU Control & Status** | `i_cpu_run_req` | Input | 1-bit | CPU Power Management | Handshake Control | External hardware signal to resume execution of a halted CPU core. |
| **CPU Control & Status** | `o_cpu_run_ack` | Output | 1-bit | CPU Power Management | Handshake Acknowledge | CPU output signal confirming that the core has resumed active instruction execution. |
| **CPU Control & Status** | `o_debug_mode_status` | Output | 1-bit | CPU Power Management | Status Flag | Status output signal indicating whether the CPU is halted in JTAG hardware debug mode. |

---

## 2. Meaning of "Internal" vs. "External" for Tests

* **Internal:** The test checks logic, buses, registers, SRAM memories, or ALUs that reside **100% inside the silicon**. No external physical chip pins or package pads are driven or checked (e.g. AXI crossbar routing, address decoders, MAC units, SRAM image buffer, comparator logic).
* **External:** The test checks signals that **cross the physical package boundary** through chip pins or external I/O wires (e.g. `uart_tx_o` serial wire, `gpio_o[31:0]` output pins, `gpio_i[31:0]` input pins, and external interrupt pins `dma_irq_o`, `cnn_irq_o`, `dist_irq_o`, `uart_irq_o`, `timer_irq_o`, `gpio_irq_o`).

---

## 3. Complete Verification Test Matrix (Excel Format)

| Test Name | Description | C Part | SV Part | Internal or External |
| :--- | :--- | :--- | :--- | :--- |
| `DMA_REG_RW_RESET` | Check reset defaults (0x0) and read/write access to DMA registers (CTRL, STATUS, SRC_ADDR, DST_ADDR, LENGTH). | Writes base addresses and lengths; reads back registers to verify setup. | Issues AXI-Lite read/write cycles; checks register flip-flops and OKAY responses. | **Internal** (On-chip registers & AXI-Lite bus) |
| `DMA_MEM2MEM_16B` | Check 16-byte (4-word) memory-to-memory copy between DMEM source and destination. | Sets DMA_SRC_ADDR, DMA_DST_ADDR, DMA_LENGTH=16, triggers START, and polls STATUS. | Monitors DMA master read/write bursts on internal bus; checks destination equals source byte-for-byte. | **Internal** (On-chip DMEM & internal AXI master bus) |
| `DMA_IMAGE_BURST_256B` | Check 256-byte bulk transfer of 16x16 INT8 image from DMEM to CNN SRAM buffer (0x2000_3100). | Sets SRC=&test_image, DST=0x20003100, LENGTH=256, START=1; verifies completion status. | Monitors burst writes; verifies all 256 bytes are loaded into CNN SRAM buffer without stall. | **Internal** (On-chip DMEM to on-chip CNN SRAM buffer) |
| `DMA_PARTIAL_ODD_LEN` | Check transfer of 13 bytes (3 full 32-bit words + 1 byte) with byte strobes. | Configures DMA_LENGTH=13; checks destination buffer after completion. | Asserts words 0-2 write with wstrb=4'hF and word 3 with wstrb=4'h1; checks other bytes untouched. | **Internal** (Internal byte strobe generator & masking) |
| `DMA_IRQ_ASSERTION` | Check that dedicated interrupt pin dma_irq_o pulses high when transfer completes. | Enables interrupt bit in CTRL (IRQ_EN=1); services interrupt or waits for completion flag. | Monitors physical dma_irq_o pin on chip boundary; checks pin rises from 0 to 1 upon completion. | **External** (Physical `dma_irq_o` output pin) |
| `DMA_W1C_CLEAR` | Check Write-1-to-Clear (W1C) clears status flags and drops dma_irq_o back to 0. | Writes '1' to STATUS.DONE bit after transfer completes to acknowledge interrupt. | Probes dma_irq_o pin and STATUS register; verifies pin drops from 1 to 0 immediately on W1C write. | **External** (Deasserts physical `dma_irq_o` pin) |
| `DMA_ERR_ALIGN_FAULT` | Fault injection: Program unaligned source address (0x1000_0003) and verify error latching. | Configures unaligned address; checks STATUS register for error code. | Verifies DMA FSM latches STATUS.ERROR=1 with ERROR_CODE=1 and blocks bus master requests. | **Internal** (Internal address check & error register) |
| `DMA_ERR_ZERO_LEN` | Fault injection: Program LENGTH=0 and verify transfer rejection. | Configures LENGTH=0, START=1; reads back error status. | Verifies DMA aborts transfer without issuing bus transactions; asserts ERROR_CODE=1. | **Internal** (Internal parameter validator) |
| `DMA_ERR_BUSY_CONFLICT` | Fault injection: Write START=1 while DMA is already busy running a transfer. | Writes START=1 twice consecutively without waiting for completion. | Verifies ongoing transfer finishes safely; second command is dropped with ERROR_CODE=4. | **Internal** (Internal FSM collision protection logic) |
| `DMA_SOFT_RESET` | Check soft reset recovery during an active bulk transfer. | Sets CTRL.SOFT_RESET=1 while transfer is running. | Verifies FSM immediately halts, cancels master requests, and resets internal counters to IDLE. | **Internal** (Internal reset tree & FSM clear) |
| `CNN_MAC_UNIT` | Check 8-bit signed multiplication and 32-bit accumulation datapath with synchronous clear. | N/A (Submodule hardware testbench). | Drives signed INT8 pixel and weight inputs; checks product accumulation and clear_acc reset. | **Internal** (On-chip multiplier & accumulator ALU) |
| `CNN_CONV3X3_LAYER` | Check 3x3 2D convolution on 16x16 image with 4 parallel filters (produces 784 activations). | N/A (Submodule hardware testbench). | Feeds test image and filter weights; compares all 784 output features against Python golden model. | **Internal** (On-chip sliding window buffers & MAC array) |
| `CNN_RELU_LAYER` | Check element-wise Rectified Linear Unit activation (clamping negative numbers to 0). | N/A (Submodule hardware testbench). | Drives signed positive and negative values; verifies negative values clamp to 0 and positive values pass. | **Internal** (On-chip activation datapath logic) |
| `CNN_MAXPOOL2X2_LAYER` | Check 2x2 max pooling with stride 2 across 784 inputs (reduces to 196 features). | N/A (Submodule hardware testbench). | Applies 14x14 feature maps per filter; verifies non-overlapping 2x2 max selection into 196 outputs. | **Internal** (On-chip spatial comparator tree) |
| `CNN_FC196_16_LAYER` | Check Fully Connected matrix multiplication (196 inputs x 16 neurons) with bias addition. | N/A (Submodule hardware testbench). | Applies 196 features and 16x196 weights; checks that output 16-D embedding matches golden dot products. | **Internal** (On-chip matrix multiplier & accumulator) |
| `CNN_IMAGE_BUFFER_SRAM` | Check direct AXI writes and reads to the CNN 256-byte image SRAM buffer (0x2000_3100 - 0x2000_31FC). | Writes known pixel array into buffer address 0x2000_3100; reads back data to verify SRAM integrity. | Monitors AXI writes to buffer range; checks SRAM memory array contents match written pixels. | **Internal** (On-chip local SRAM image buffer) |
| `CNN_INFERENCE_EXEC` | Check complete CNN inference trigger, busy polling, and 16-element embedding vector generation. | Sets DIM_CFG=16x16, EMBED_LEN=16, triggers START=1, polls STATUS.DONE, and reads embedding registers (0x20-0x5C). | Monitors CNN AXI slave transactions; verifies pipeline execution cycles; checks embedding values are non-zero. | **Internal** (On-chip accelerator pipeline & registers) |
| `CNN_IRQ_ASSERTION` | Check assertion of dedicated completion interrupt pin cnn_irq_o when inference finishes. | Configures CNN_CTRL with IRQ_EN=1; waits for hardware completion. | Probes physical cnn_irq_o output pin; checks pin asserts high when STATUS.DONE=1. | **External** (Physical `cnn_irq_o` output pin) |
| `CNN_INVALID_CFG_FAULT` | Fault injection: Program invalid image dimensions or embedding length and check error handling. | Writes illegal dimension value to DIM_CFG; reads STATUS register. | Verifies CNN detects illegal configuration, asserts STATUS.ERROR=1 with ERROR_CODE=3, and aborts start. | **Internal** (Internal configuration checker) |
| `DIST_MANHATTAN_CALC` | Check hardware calculation of Manhattan (L1) distance: sum(\|query[i] - ref[i]\|) for 16 elements. | Loads query and reference vectors into IP slots; triggers calculation. | Compares hardware computed distance in MIN_DISTANCE register against software reference calculation. | **Internal** (On-chip absolute difference subtractor & adder) |
| `DIST_THRESHOLD_MATCH` | Check classification when distance <= threshold (Expected: RESULT=1 for MATCH / NORMAL). | Sets matching reference vector, sets threshold=50, starts engine, verifies RESULT==1 and MIN_DISTANCE==0. | Monitors Distance AXI registers; checks comparator asserts RESULT=1 when distance <= threshold. | **Internal** (On-chip distance registers & comparator logic) |
| `DIST_THRESHOLD_ANOMALY` | Check classification when distance > threshold (Expected: RESULT=0 for ANOMALY). | Sets divergent reference vector, sets threshold=50, starts engine, verifies RESULT==0 and MIN_DISTANCE==800. | Monitors Distance AXI registers; checks comparator asserts RESULT=0 when distance > threshold. | **Internal** (On-chip distance registers & comparator logic) |
| `DIST_IRQ_ASSERTION` | Check assertion of dedicated completion interrupt pin dist_irq_o when distance scoring finishes. | Configures DIST_CTRL with IRQ_EN=1; triggers scoring; clears interrupt via W1C. | Probes physical dist_irq_o output pin; verifies pin rises to 1 on completion and drops to 0 on W1C. | **External** (Physical `dist_irq_o` output pin) |
| `DIST_INVALID_METRIC_FAULT` | Fault injection: Program unsupported metric index into DIST_METRIC and verify error response. | Writes unsupported metric code (e.g. 5) into DIST_METRIC register. | Verifies IP rejects configuration, asserts STATUS.ERROR=1 with ERROR_CODE=4, and refuses execution. | **Internal** (Internal metric validator logic) |
| `UART_BAUD_DIV_CONFIG` | Check programming of UART baud rate divisor latch (divisor = 16) and line control register (8N1). | Writes LCR=0x80 (DLAB enable), writes BAUD_DIV=16, restores LCR=0x03 (8 data bits, 1 stop bit, no parity). | Monitors internal AXI writes to UART registers 0x2000_0008 and 0x2000_000C; verifies divisor latch value. | **Internal** (On-chip UART registers & clock divider) |
| `UART_SERIAL_TX_BITSTREAM` | Check physical serial transmission of ASCII characters over uart_tx_o pin at exact baud timing. | Calls uart_putc() / uart_puts() to transmit string messages to console. | Probes physical uart_tx_o output wire; deserializes start bit, 8 data bits, and stop bit at 170 ns/bit; validates text. | **External** (Physical `uart_tx_o` serial output pin) |
| `UART_TX_FIFO_STATUS` | Check UART Line Status Register (LSR) transmitter holding register empty (THRE) and transmitter empty (TEMT). | Polls LSR register until THRE bit is 1 before writing next character into THR. | Monitors AXI reads to LSR (0x2000_0014); checks THRE drops to 0 when FIFO is written and returns to 1 when empty. | **Internal** (On-chip UART FIFO status logic) |
| `UART_IRQ_ASSERTION` | Check assertion of uart_irq_o pin when TX FIFO is empty or RX data is received. | Enables UART interrupts via IER register; handles interrupt or polls status. | Probes physical uart_irq_o output pin; checks pin asserts upon configured UART trigger condition. | **External** (Physical `uart_irq_o` output pin) |
| `TIMER_COUNTER_INCREMENT` | Check continuous 64-bit real-time counter (MTIME) incrementation based on system clock. | Reads MTIME counter registers twice and verifies time progression. | Monitors internal 64-bit timer counter registers; verifies increment rate matches prescaler setting. | **Internal** (On-chip 64-bit timer counter flip-flops) |
| `TIMER_MATCH_INTERRUPT` | Check assertion of timer_irq_o pin when MTIME counter reaches comparator value (MTIME >= MTIMECMP). | Programs MTIMECMP = MTIME + 100; enables timer interrupt; waits for interrupt. | Probes physical timer_irq_o output pin; verifies pin rises to 1 exactly when counter matches compare register. | **External** (Physical `timer_irq_o` output pin) |
| `GPIO_DIRECTION_CONTROL` | Check 32-bit pin direction configuration via GPIO_EN register (input vs push-pull output). | Writes direction mask to GPIO_EN (0x2000_2080); verifies output enables. | Probes internal direction control bus gpio_dir_o[31:0]; checks pins configure correctly as inputs or outputs. | **Internal** (On-chip direction registers & pad control) |
| `GPIO_OUTPUT_PATTERN_DRIVE` | Check driving arbitrary test patterns and stage indicators onto physical gpio_o[31:0] pins. | Writes progress status to GPIO_OUT: 0x01 (boot), 0x02 (DMA done), 0x04 (CNN done), 0x55 (all pass). | Probes physical gpio_o[31:0] output pins on chip boundary; asserts pin levels match written values. | **External** (Physical `gpio_o[31:0]` output pin bus) |
| `GPIO_ATOMIC_SET_CLR_TOGGLE` | Check atomic bit manipulation registers: GPIO_SET (0x200), GPIO_CLEAR (0x280), and GPIO_TOGGLE (0x300). | Writes single bitmasks to SET, CLEAR, and TOGGLE registers without read-modify-write software overhead. | Monitors AXI writes to atomic offsets; asserts that target bits on gpio_o update while other bits remain unchanged. | **External** (Directly changes physical `gpio_o` output pins) |
| `GPIO_INPUT_SAMPLING_SYNC` | Check external signal sampling on physical gpio_i[31:0] pins through 2-stage flip-flop synchronizer. | Reads GPIO_IN register (0x2000_2000) to inspect external switch/pin states. | Drives asynchronous digital signals onto physical gpio_i pins; checks 2-stage synchronizer removes metastability. | **External** (Physical `gpio_i[31:0]` input pins) |
| `GPIO_PIN_INTERRUPT_GEN` | Check generation of gpio_irq_o pin on configurable rising-edge, falling-edge, or level triggers on input pins. | Enables GPIO interrupt mask; reads interrupt status; clears interrupt via W1C. | Drives pulse transitions on gpio_i; probes physical gpio_irq_o pin; verifies interrupt asserts and clears cleanly. | **External** (Physical `gpio_i` pin transition -> `gpio_irq_o` pin) |
| `AXI_SLAVE_ADDR_DECODING` | Check address decoding and routing from CPU master (S00) to all 8 slave peripheral targets (M00-M07). | Issues read/write accesses to all 8 base addresses: IMEM, DMEM, UART, Timer, GPIO, CNN, Distance, and DMA. | Monitors select lines and handshakes on all 8 slave interfaces (m00_axi through m07_axi); verifies 1-to-1 routing. | **Internal** (On-chip AXI crossbar decoder & muxes) |
| `AXI_UNMAPPED_DECERR` | Check generation of DECERR (2'b11) response when accessing unmapped address space (e.g. 0x3000_0000). | Attempts read or write access to unmapped memory address. | Captures write response bresp and read response rresp; asserts interconnect returns 2'b11 without bus hang. | **Internal** (On-chip crossbar default error slave logic) |
| `AXI_MASTER_ARBITRATION` | Check round-robin bus arbitration when CPU (S00) and DMA (S01) issue concurrent accesses to shared DMEM (M01). | Initiates DMA background transfer to DMEM while CPU actively reads instructions and data. | Monitors simultaneous request lines; verifies round-robin arbiter grants alternating access without starving either master. | **Internal** (On-chip crossbar arbiter logic & grant handshakes) |
| `AXI_BACKPRESSURE_HANDSHAKE` | Check valid/ready flow control and stall handling across all AXI channels during burst transactions. | Issues continuous back-to-back memory and register transfers. | Randomly asserts/deasserts ready signals; verifies master correctly holds valid and data until ready is high. | **Internal** (On-chip AXI handshake protocol compliance) |
| `IMEM_DUAL_PORT_ACCESS` | Check Instruction Memory dual-port operation: CPU IFU instruction fetches and LSU/DMA data reads/writes. | Executes code from IMEM while testbench preloads hex data. | Verifies simultaneous IFU fetch and AXI slave access to IMEM (0x0000_0000 - 0x0000_FFFF) without conflict. | **Internal** (On-chip dual-ported 64 KB SRAM memory) |
| `DMEM_BYTE_ENABLE_ACCESS` | Check Data Memory byte-level access using 4-bit write strobes (wstrb) for 8-bit, 16-bit, and 32-bit accesses. | Performs uint8_t, uint16_t, and uint32_t stores and loads in DMEM (0x1000_0000 - 0x1000_FFFF). | Checks that only enabled byte lanes in memory are modified; non-targeted bytes remain preserved. | **Internal** (On-chip 64 KB SRAM byte-enable mask logic) |
| `SOC_CPU_RESET_BOOT` | Check VeeR-EL2 CPU boot from hardware reset, instruction fetch from 0x0000_0000, and stack initialization. | `crt0.s` initializes stack pointer sp to 0x1000_FFF0, configures MRAC CSR (0x5555556A), and calls main(). | Deasserts rst_l; tracks CPU program counter (ifu_i0_pc); verifies execution starts at 0x0000_0000. | **Internal** (CPU reset vector logic & pipeline registers) |
| `SOC_CONSOLE_LOGGING` | Check CPU firmware execution logs system progress, embeddings, and results via UART serial output. | Firmware executes print routines outputting 26 structured log lines to the console. | UART monitor captures all characters from physical uart_tx_o pin; verifies 26 complete lines and pass string. | **External** (Physical `uart_tx_o` serial output wire) |
| `SOC_END2END_NORMAL_CLASSIFY` | Check full autonomous pipeline classifying a normal image sample: DMA copy -> CNN inference -> Distance Match. | Orchestrates DMA transfer, CNN start, loads matching reference embedding, validates RESULT==1, logs PASS. | Scoreboard captures DMA transfer, validates CNN embedding vector, and verifies Distance IP outputs Match=1. | **Internal** (On-chip accelerator pipeline & distance scoring) |
| `SOC_END2END_ANOMALY_CLASSIFY` | Check full autonomous pipeline classifying an anomaly image: DMA copy -> CNN inference -> Distance Anomaly. | Loads divergent reference embedding, triggers Distance IP, validates RESULT==0 (ANOMALY), logs PASS. | Scoreboard verifies Distance IP outputs Dist=800, Result=0, and flags anomaly detection. | **Internal** (On-chip accelerator pipeline & anomaly scoring) |
| `SOC_FINAL_MAILBOX_HANDSHAKE` | Check system completion handshake via DMEM mailbox (0x1000_FF00) and final GPIO output pin state (0x00000055). | Writes 0xCAFE0001 to MAILBOX_REG (0x1000_FF00); drives GPIO_OUT = 0x00000055; enters sleep. | Testbench samples physical gpio_o pins for 0x00000055 and checks DMEM mailbox holds 0xCAFE0001 before exiting. | **External** (Drives physical `gpio_o` pins & internal mailbox) |

---

## 4. Complete Execution Flow (In 6 Short Plain-Text Steps)

Here is how the entire system executes in simulation from power-up to final sign-off:

1. **Step 1: Boot & Bring-up**  
   The external `rst_l` pin is released. The VeeR-EL2 CPU boots from `0x0000_0000` in IMEM, sets up the stack in DMEM (`0x1000_FFF0`), initializes the 16550 UART baud divisor (16), prints a startup banner on `uart_tx_o`, and drives `gpio_o = 0x01`.

2. **Step 2: Autonomous DMA Image Copy**  
   The CPU programs the DMA controller (`0x2000_5000`) with source = `&test_image` (DMEM), destination = CNN SRAM buffer (`0x2000_3100`), length = 256 bytes. The DMA moves all 256 bytes autonomously, pulses the external pin `dma_irq_o`, and the CPU updates `gpio_o = 0x02`.

3. **Step 3: Hardware CNN Feature Extraction**  
   The CPU triggers the CNN accelerator (`0x2000_3000`). The hardware runs Conv3x3 $\rightarrow$ ReLU $\rightarrow$ MaxPool2x2 $\rightarrow$ FC196$\rightarrow$16, outputs a 16-number embedding vector, pulses the external pin `cnn_irq_o`, and the CPU logs the embedding via UART and sets `gpio_o = 0x04`.

4. **Step 4: Normal Image Test**  
   The CPU loads an identical reference vector into Distance IP (`0x2000_4200`) with threshold = 50. The hardware computes Manhattan Distance = 0. Since $0 \le 50$, the hardware outputs `RESULT = 1 (MATCH)`. Firmware prints `[PASS] MATCH` to UART.

5. **Step 5: Anomaly Image Test**  
   The CPU loads a divergent reference vector with threshold = 50. The hardware computes Manhattan Distance = 800. Since $800 > 50$, the hardware outputs `RESULT = 0 (ANOMALY)`. Firmware prints `[PASS] ANOMALY` to UART.

6. **Step 6: Completion Handshake & Verification Sign-Off**  
   The CPU writes `0xCAFE0001` to the DMEM mailbox (`0x1000_FF00`), drives physical pins `gpio_o = 0x55`, and prints `"ALL ANOMALY DETECTION TESTS PASSED SUCCESSFULLY!"` over `uart_tx_o`. The UVM scoreboard confirms all domains pass with **0 Errors / 0 Warnings**.
