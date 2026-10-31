import csv
import sys
import os

test_cases = [
    # --------------------------------------------------------------------------
    # Tier 1: Unit & Block-Level Verification
    # --------------------------------------------------------------------------
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DMA_REG_RW_RESET",
        "desc": "Verify reset defaults and read/write accessibility of DMA registers (CTRL, STATUS, SRC_ADDR, DST_ADDR, LENGTH).",
        "c_part": "N/A (Standalone testbench stimulus drives AXI-Lite slave interface directly).",
        "sv_part": "Applies reset; issues AXI read to verify defaults (0x0); writes incremental patterns to SRC, DST, LEN; verifies readback data and OKAY response.",
        "internal_external": "Internal (AXI-Lite slave interface, DMA configuration register flip-flops)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DMA_MEM2MEM_16B",
        "desc": "Verify basic 16-byte (4-word) memory-to-memory transfer over AXI4 master interface.",
        "c_part": "N/A (Simulated master transaction via testbench tasks).",
        "sv_part": "Initializes source memory array; configures DMA registers via AXI slave; emulates memory slave responding to DMA master read/write bursts; checks byte-for-byte destination equality.",
        "internal_external": "Internal (DMA master burst FSM, internal byte counter, internal FIFO)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DMA_IMAGE_BURST_256B",
        "desc": "Verify high-throughput bulk transfer of 256-byte (64-word) 16x16 INT8 image into accelerator SRAM buffer.",
        "c_part": "N/A (Simulated master transaction).",
        "sv_part": "Preloads 256-byte image into DMEM model; programs LENGTH=256; monitors sustained AXI burst read and write handshakes; verifies all 256 bytes transfer without stall or data corruption.",
        "internal_external": "Internal (AXI4 master read/write pipelines, burst length counters, address incrementers)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DMA_PARTIAL_ODD_LEN",
        "desc": "Verify transfer of unaligned / odd byte counts (13 bytes = 3 full 32-bit words + 1 partial byte).",
        "c_part": "N/A (Simulated stimulus).",
        "sv_part": "Configures LENGTH=13; asserts that the first 3 words use wstrb=4'hF and the final word uses wstrb=4'h1; verifies non-written byte lanes in destination remain uncorrupted.",
        "internal_external": "Internal (DMA byte strobe generator, byte alignment masking logic)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DMA_IRQ_GEN",
        "desc": "Verify interrupt generation on transfer completion when IRQ_EN bit is enabled.",
        "c_part": "N/A (Hardware pin assertion check).",
        "sv_part": "Programs CTRL=0x05 (START=1, IRQ_EN=1); tracks master write completion (bvalid & bready); asserts that dma_irq_o pin rises to 1 exactly when STATUS.DONE asserts.",
        "external_internal": "External (Dedicated hardware interrupt line dma_irq_o output pin)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DMA_W1C_CLEAR",
        "desc": "Verify Write-1-to-Clear (W1C) handshake for STATUS register and synchronous deassertion of dma_irq_o.",
        "c_part": "N/A (Direct register write test).",
        "sv_part": "Writes 1 to STATUS[1] (DONE) and STATUS[2] (ERROR); checks that STATUS clears to 0 and dma_irq_o immediately deasserts to 0 without bus collision.",
        "internal_external": "Internal & External (W1C register latch and external dma_irq_o pin)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DMA_ERR_ALIGN_FAULT",
        "desc": "Fault injection: Program unaligned source address (e.g., 0x1000_0003) and verify error latching.",
        "c_part": "N/A (Negative fault injection).",
        "sv_part": "Writes unaligned SRC_ADDR; triggers START; verifies DMA rejects transfer, asserts STATUS.ERROR=1 with ERROR_CODE=1, and issues no bus requests.",
        "internal_external": "Internal (DMA address validation check, error status registers)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DMA_ERR_ZERO_LEN",
        "desc": "Fault injection: Program zero length (LENGTH=0) and verify transfer rejection.",
        "c_part": "N/A (Negative fault injection).",
        "sv_part": "Writes LENGTH=0; writes START=1; verifies DMA flags ERROR_CODE=1, asserts STATUS.ERROR=1, and master remains IDLE.",
        "internal_external": "Internal (DMA length validation logic, error encoding)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DMA_ERR_BUSY_CONFLICT",
        "desc": "Fault injection: Write START=1 while DMA is actively processing a transfer (BUSY=1).",
        "c_part": "N/A (Negative fault injection).",
        "sv_part": "Initiates a long burst; writes START=1 while BUSY=1; checks that second command is dropped with ERROR_CODE=4, while ongoing transfer completes successfully.",
        "internal_external": "Internal (DMA FSM state protection logic, arbitration collision lock)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DMA_SOFT_RESET",
        "desc": "Verify soft reset capability during active transfer (CTRL.SOFT_RESET=1).",
        "c_part": "N/A (Direct register stimulus).",
        "sv_part": "Asserts SOFT_RESET while BUSY=1; verifies FSM immediately aborts, master outputs deassert, and all internal counters reset to IDLE.",
        "internal_external": "Internal (Synchronous soft reset tree, FSM state clear)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "CNN_MAC_UNIT_TEST",
        "desc": "Verify 8-bit signed multiplication and 32-bit accumulation with synchronous clear.",
        "c_part": "N/A (Unit test stimulus).",
        "sv_part": "Drives signed INT8 pixel and weight values; verifies single-cycle multiplication and running accumulation; verifies clear_acc resets accumulator.",
        "internal_external": "Internal (Datapath INT8 multiplier and 32-bit signed accumulator)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "CNN_CONV3X3_TEST",
        "desc": "Verify 3x3 2D convolution on 16x16 INT8 image with 4 parallel filters (produces 784 features).",
        "c_part": "N/A (Submodule testbench).",
        "sv_part": "Feeds known 16x16 image and 3x3 filter kernels; steps through sliding window; compares all 784 output activations against Python golden model.",
        "internal_external": "Internal (Convolution sliding window generator, line buffer, 4x MAC array)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "CNN_RELU_TEST",
        "desc": "Verify element-wise Rectified Linear Unit activation (max(0, x)) on 784 convolution outputs.",
        "c_part": "N/A (Submodule testbench).",
        "sv_part": "Drives signed test vector containing positive, zero, and negative values; verifies negative values clamp to 0 and positive values pass through unchanged.",
        "internal_external": "Internal (Activation datapath clamp logic)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "CNN_MAXPOOL2X2_TEST",
        "desc": "Verify 2x2 max pooling with stride 2 across 784 inputs (reduces to 196 features).",
        "c_part": "N/A (Submodule testbench).",
        "sv_part": "Applies 14x14 feature maps per filter; tests non-overlapping 2x2 spatial windows; verifies maximum element selection across all 196 pooled outputs.",
        "internal_external": "Internal (Spatial 2x2 comparator tree, decimation logic)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "CNN_FLATTEN_TEST",
        "desc": "Verify flattening and reordering of pooled feature tensor into 1D 196-element array.",
        "c_part": "N/A (Submodule testbench).",
        "sv_part": "Applies indexed feature stream; verifies correct channel-first/row-first mapping to 196 linear elements.",
        "internal_external": "Internal (Tensor serialization interconnect)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "CNN_FC196_16_TEST",
        "desc": "Verify Fully Connected layer (196 inputs x 16 neurons) with bias addition and INT32 accumulation.",
        "c_part": "N/A (Submodule testbench).",
        "sv_part": "Drives 196 feature inputs and 16x196 weight matrix; compares all 16 output embedding elements against golden matrix dot products.",
        "internal_external": "Internal (FC matrix MAC engine, bias accumulator array)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "CNN_AXI_WRAPPER_TEST",
        "desc": "Verify CNN AXI4-Lite slave wrapper: register access, SRAM image buffer (0x100-0x1FC), start, busy, done, and cnn_irq_o.",
        "c_part": "N/A (Wrapper unit testbench).",
        "sv_part": "Writes 64 words to SRAM buffer; writes START=1; verifies BUSY asserts; waits for DONE; verifies cnn_irq_o pin assertion; reads 16 embedding registers (0x20-0x5C).",
        "internal_external": "Internal & External (AXI-Lite slave interface, internal SRAM, external cnn_irq_o pin)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DIST_MANHATTAN_CALC",
        "desc": "Verify hardware calculation of Manhattan (L1) distance across 16-element signed 32-bit embedding vectors.",
        "c_part": "N/A (Distance unit testbench).",
        "sv_part": "Applies query vector and reference vector; asserts distance = sum(|query[i] - ref[i]|); verifies exact match against software golden sum.",
        "internal_external": "Internal (16-lane absolute difference subtraction & adder tree)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DIST_THRESHOLD_COMP",
        "desc": "Verify threshold comparison logic: distance <= threshold -> similar/MATCH; distance > threshold -> dissimilar/ANOMALY.",
        "c_part": "N/A (Comparator unit testbench).",
        "sv_part": "Sweeps distance below, at, and above threshold; checks that 'similar' output bit asserts high only when distance <= threshold.",
        "internal_external": "Internal (32-bit comparator logic)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "DIST_AXI_WRAPPER_TEST",
        "desc": "Verify Distance AXI4-Lite slave wrapper: register R/W, reference slots (0x200), start, done, dist_irq_o, and result readback.",
        "c_part": "N/A (Wrapper unit testbench).",
        "sv_part": "Programs query and reference vectors; verifies MATCH (dist=0) and ANOMALY (dist=800); validates dist_irq_o pulse and Write-1-to-Clear.",
        "internal_external": "Internal & External (AXI-Lite slave registers, external dist_irq_o pin)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "UART_AXI_WRAPPER_TEST",
        "desc": "Verify 16550 UART AXI4-Lite peripheral: baud divisor latch, line control (LCR), line status (LSR), and TX/RX FIFOs.",
        "c_part": "N/A (UART unit testbench).",
        "sv_part": "Programs baud divisor=16; checks LSR.THRE and LSR.TEMT; transmits bytes through TX FIFO; verifies serial bit timing on uart_tx_o.",
        "internal_external": "Internal & External (UART FIFOs, baud rate generator, external uart_tx_o/uart_rx_i pins)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "TIMER_AXI_WRAPPER_TEST",
        "desc": "Verify OpenTitan 64-bit RV Timer AXI4-Lite wrapper: MTIME counter increment, MTIMECMP match, and timer_irq_o.",
        "c_part": "N/A (Timer unit testbench).",
        "sv_part": "Programs step/prescaler; sets MTIMECMP = MTIME + 50; waits for match; verifies timer_irq_o pin asserts high upon match.",
        "internal_external": "Internal & External (64-bit timer counter, comparator, external timer_irq_o pin)"
    },
    {
        "tier": "Tier 1: Unit / Block-Level",
        "name": "GPIO_AXI_WRAPPER_TEST",
        "desc": "Verify PULP GPIO AXI4-Lite wrapper: direction control, atomic SET/CLEAR/TOGGLE registers, input synchronizer, and interrupts.",
        "c_part": "N/A (GPIO unit testbench).",
        "sv_part": "Configures GPIO_EN; tests GPIO_SET (0x200), GPIO_CLEAR (0x280), GPIO_TOGGLE (0x300); drives gpio_i pins; checks 2-stage sync and gpio_irq_o.",
        "internal_external": "Internal & External (GPIO registers, sync flip-flops, external gpio_o/gpio_i pins, gpio_irq_o)"
    },

    # --------------------------------------------------------------------------
    # Tier 2: Subsystem & 2x8 AXI Interconnect Integration
    # --------------------------------------------------------------------------
    {
        "tier": "Tier 2: Subsystem / AXI Interconnect",
        "name": "AXI_UART_ACCESS (AXI-01)",
        "desc": "Verify CPU master (S00) access to UART (M02 @ 0x2000_0000) through 2x8 AXI interconnect.",
        "c_part": "N/A (Testbench CPU bus emulation tasks cpu_bus_write / cpu_bus_read).",
        "sv_part": "CPU bus write to UART LCR (0x2000_000C) and BAUD_DIV (0x2000_0008); reads LSR (0x2000_0014); asserts LSR.THRE=1, LSR.TEMT=1, resp=OKAY.",
        "internal_external": "Internal (AXI 2x8 crossbar routing to M02, address decoding 0x2000_0000)"
    },
    {
        "tier": "Tier 2: Subsystem / AXI Interconnect",
        "name": "AXI_CNN_ACCEL_ACCESS (AXI-02)",
        "desc": "Verify CPU master access to CNN Accelerator (M05 @ 0x2000_3000) through 2x8 AXI interconnect.",
        "c_part": "N/A (Testbench bus tasks).",
        "sv_part": "CPU bus writes DIM_CFG, EMBED_LEN, and START; polls CNN_STATUS until DONE=1; reads 16-element embedding registers; checks mathematical output.",
        "internal_external": "Internal (AXI 2x8 crossbar routing to M05, address decoding 0x2000_3000)"
    },
    {
        "tier": "Tier 2: Subsystem / AXI Interconnect",
        "name": "AXI_DIST_MATCH_ACCESS (AXI-03)",
        "desc": "Verify CPU master access to Distance IP (M06 @ 0x2000_4000) for MATCH classification over interconnect.",
        "c_part": "N/A (Testbench bus tasks).",
        "sv_part": "CPU writes matching reference vector to 0x2000_4200, sets threshold=50, starts engine; reads MIN_DISTANCE=0 and RESULT=1 (MATCH).",
        "internal_external": "Internal (AXI 2x8 crossbar routing to M06, address decoding 0x2000_4000)"
    },
    {
        "tier": "Tier 2: Subsystem / AXI Interconnect",
        "name": "AXI_DIST_ANOMALY_ACCESS (AXI-04)",
        "desc": "Verify CPU master access to Distance IP (M06 @ 0x2000_4000) for ANOMALY classification over interconnect.",
        "c_part": "N/A (Testbench bus tasks).",
        "sv_part": "CPU writes divergent reference vector to 0x2000_4200, sets threshold=50, starts engine; reads MIN_DISTANCE=800 and RESULT=0 (ANOMALY).",
        "internal_external": "Internal (AXI 2x8 crossbar routing to M06, address decoding 0x2000_4000)"
    },
    {
        "tier": "Tier 2: Subsystem / AXI Interconnect",
        "name": "AXI_TIMER_ACCESS (AXI-05)",
        "desc": "Verify CPU master access to RV Timer (M03 @ 0x2000_1000) and interrupt generation over interconnect.",
        "c_part": "N/A (Testbench bus tasks).",
        "sv_part": "CPU configures MTIME and MTIMECMP; monitors timer_irq_o pin; checks that interrupt asserts upon comparator match.",
        "internal_external": "Internal & External (AXI routing to M03, external timer_irq_o pin)"
    },
    {
        "tier": "Tier 2: Subsystem / AXI Interconnect",
        "name": "AXI_GPIO_ACCESS (AXI-06)",
        "desc": "Verify CPU master access to PULP GPIO (M04 @ 0x2000_2000) and pin driving over interconnect.",
        "c_part": "N/A (Testbench bus tasks).",
        "sv_part": "CPU sets GPIO_EN (0x2000_2080); writes alternating test patterns to GPIO_OUT (0x2000_2180); asserts external gpio_o pins match written patterns.",
        "internal_external": "Internal & External (AXI routing to M04, external gpio_o pins)"
    },
    {
        "tier": "Tier 2: Subsystem / AXI Interconnect",
        "name": "AXI_DECERR_UNMAPPED (AXI-07)",
        "desc": "Verify interconnect address decoding error (DECERR = 2'b11) on unmapped address accesses.",
        "c_part": "N/A (Negative bus test).",
        "sv_part": "CPU issues read and write to unmapped address 0x3000_0000; verifies crossbar returns bresp/rresp = 2'b11 (DECERR) without freezing bus pipeline.",
        "internal_external": "Internal (AXI 2x8 crossbar address decoder default/error slave logic)"
    },
    {
        "tier": "Tier 2: Subsystem / AXI Interconnect",
        "name": "AXI_IMEM_PORT_ACCESS (AXI-08)",
        "desc": "Verify CPU master read/write access to Instruction Memory (M00 @ 0x0000_0000 - 0x0000_FFFF).",
        "c_part": "N/A (Testbench bus tasks).",
        "sv_part": "CPU issues AXI read and write transactions to IMEM base and upper boundary; verifies OKAY response and correct readback.",
        "internal_external": "Internal (AXI 2x8 crossbar routing to M00, dual-port IMEM AXI slave port)"
    },
    {
        "tier": "Tier 2: Subsystem / AXI Interconnect",
        "name": "AXI_DMEM_PORT_ACCESS (AXI-09)",
        "desc": "Verify CPU master read/write access to Data Memory (M01 @ 0x1000_0000 - 0x1000_FFFF) with byte enables.",
        "c_part": "N/A (Testbench bus tasks).",
        "sv_part": "CPU writes 0xCAFEBABE to DMEM; performs partial word writes with wstrb; reads back data; verifies byte enable masking and OKAY response.",
        "internal_external": "Internal (AXI 2x8 crossbar routing to M01, DMEM byte enable write logic)"
    },
    {
        "tier": "Tier 2: Subsystem / AXI Interconnect",
        "name": "AXI_DMA_S01_M07_INTEG (AXI-10)",
        "desc": "Verify full DMA integration: CPU programs DMA via M07 CSRs; DMA Master S01 transfers memory block across crossbar to DMEM destination.",
        "c_part": "N/A (Testbench bus tasks).",
        "sv_part": "Preloads 0xCAFEBABE at DMEM source (0x1000_0100); programs DMA SRC, DST (0x1000_0200), LEN=4 via M07; waits for dma_irq_o; verifies DMEM destination holds 0xCAFEBABE.",
        "internal_external": "Internal & External (AXI 2x8 crossbar arbitration between S00 and S01, external dma_irq_o pin)"
    },

    # --------------------------------------------------------------------------
    # Tier 3: Full SoC Processor-Driven Firmware Verification
    # --------------------------------------------------------------------------
    {
        "tier": "Tier 3: Processor-Driven Firmware",
        "name": "SOC_CPU_BOOT_RESET",
        "desc": "Verify autonomous VeeR-EL2 CPU boot from reset vector 0x0000_0000, crt0.s stack setup, and MRAC CSR configuration.",
        "c_part": "crt0.s initializes stack pointer sp to _stack_top (DMEM 0x1000_FFF0); programs MRAC CSR (0x5555556A) for non-cacheable side-effect regions; branches to main().",
        "sv_part": "Deasserts rst_l; monitors CPU program counter (ifu_i0_pc); verifies instruction fetches begin at 0x0000_0000 and PC advances cleanly into main().",
        "internal_external": "Internal (VeeR-EL2 CPU core fetch, decode, pipeline, and MRAC CSR register)"
    },
    {
        "tier": "Tier 3: Processor-Driven Firmware",
        "name": "SOC_UART_CONSOLE_INIT",
        "desc": "Verify firmware initialization of 16550 UART and serial transmission of startup banner to console.",
        "c_part": "uart_init(16) programs LCR=0x80 (DLAB), BAUD_DIV=16, LCR=0x03 (8N1); uart_puts() sends boot string: '=================================================='.",
        "sv_part": "Monitors uart_tx_o pin; samples serial bitstream at 170 ns per bit; deserializes characters; prints live characters to simulation log.",
        "internal_external": "External (Physical uart_tx_o serial output wire, RS-232 timing)"
    },
    {
        "tier": "Tier 3: Processor-Driven Firmware",
        "name": "SOC_DMA_IMAGE_MOVE",
        "desc": "Verify firmware-driven DMA transfer of 256-byte 16x16 INT8 image from DMEM array to CNN image buffer (0x2000_3100).",
        "c_part": "Firmware sets DMA_SRC_ADDR = (uint32_t)test_image, DMA_DST_ADDR = 0x20003100, DMA_LENGTH = 256; sets DMA_CTRL = 0x05 (START|IRQ_EN); polls DMA_STATUS until DONE=1.",
        "sv_part": "Monitors M07 CSR accesses and S01 master burst traffic; checks dma_irq_o pulse; verifies CNN local buffer contains test_image bytes.",
        "internal_external": "Internal & External (DMA master bus burst, CNN SRAM buffer, external dma_irq_o pin)"
    },
    {
        "tier": "Tier 3: Processor-Driven Firmware",
        "name": "SOC_CNN_FEATURE_EXTRACT",
        "desc": "Verify firmware trigger of CNN accelerator, polling of completion status, and readout of 16-element embedding vector.",
        "c_part": "Firmware configures CNN_DIM_CFG (16x16), CNN_EMBED_LEN (16); sets CNN_CTRL = 0x05 (START|IRQ_EN); polls CNN_STATUS until DONE=1; reads CNN_EMBED_VAL[0..15]; prints via UART.",
        "sv_part": "Monitors M05 AXI slave bus and cnn_irq_o; verifies CNN pipeline execution time; captures embedding vector; verifies non-zero embedding values.",
        "internal_external": "Internal & External (CNN accelerator pipeline, AXI registers, external cnn_irq_o pin)"
    },
    {
        "tier": "Tier 3: Processor-Driven Firmware",
        "name": "SOC_DIST_NORMAL_MATCH",
        "desc": "Verify end-to-end classification of a normal sample against a matching reference vector (expected: Distance=0, Match=1).",
        "c_part": "Firmware writes matching reference vector to DIST_REF_SLOT[0..15]; sets DIST_THRESHOLD = 50; sets DIST_CTRL = START; polls DIST_STATUS; checks DIST_RESULT == 1 and DIST_MIN_DISTANCE == 0.",
        "sv_part": "Monitors M06 AXI slave bus; verifies distance calculation matches 0; validates that result bit 1 is returned over AXI read.",
        "internal_external": "Internal (Distance engine registers, Manhattan ALU, comparator logic)"
    },
    {
        "tier": "Tier 3: Processor-Driven Firmware",
        "name": "SOC_DIST_ANOMALY_DETECT",
        "desc": "Verify end-to-end classification of an anomaly sample against a divergent reference vector (expected: Distance=800, Anomaly=0).",
        "c_part": "Firmware writes divergent reference vector to DIST_REF_SLOT[0..15]; sets DIST_THRESHOLD = 50; sets DIST_CTRL = START; polls DIST_STATUS; checks DIST_RESULT == 0 and DIST_MIN_DISTANCE == 800.",
        "sv_part": "Monitors M06 AXI slave bus; verifies distance calculation matches 800; validates that result bit 0 (ANOMALY) is returned over AXI read.",
        "internal_external": "Internal (Distance engine registers, Manhattan ALU, comparator logic)"
    },
    {
        "tier": "Tier 3: Processor-Driven Firmware",
        "name": "SOC_SYS_MAILBOX_HANDSHAKE",
        "desc": "Verify final C-to-SV synchronization handshake via DMEM Mailbox (0x1000_FF00) and GPIO status pins (0x0000_0055).",
        "c_part": "Firmware writes GPIO_OUT = 0x00000055; writes MAILBOX_REG (0x1000_FF00) = 0xCAFE0001; transmits final UART PASS banner; enters infinite sleep loop.",
        "sv_part": "Testbench samples gpio_o pins; checks gpio_o == 0x00000055; monitors DMEM[0x1000_FF00] == 0xCAFE0001; safely calls $finish(0) indicating success.",
        "internal_external": "External & Internal (External gpio_o pins, internal DMEM mailbox register)"
    },

    # --------------------------------------------------------------------------
    # Tier 4: IEEE 1800.2 UVM 1.2 Multi-Agent Verification
    # --------------------------------------------------------------------------
    {
        "tier": "Tier 4: Multi-Agent UVM 1.2",
        "name": "UVM_UART_STREAM_MONITOR",
        "desc": "Protocol monitor deserializes serial stream on uart_tx_o, reconstructs 26 log lines, and validates PASS banner.",
        "c_part": "Autonomous C firmware prints logs via uart_puts(): system headers, DMA status, embedding vectors, distance scores, and pass banner.",
        "sv_part": "uart_monitor samples uart_tx_o at bit center; packages characters into uart_seq_item; broadcasts via TLM analysis port to soc_scoreboard; validates receipt of PASS banner.",
        "internal_external": "External (Physical uart_tx_o serial pin, 100 MHz bit timing)"
    },
    {
        "tier": "Tier 4: Multi-Agent UVM 1.2",
        "name": "UVM_GPIO_STATE_MONITOR",
        "desc": "Protocol monitor tracks 32-bit GPIO output transitions and verifies hardware stage progression (0x01 -> 0x02 -> 0x04 -> 0x55).",
        "c_part": "C firmware updates GPIO_OUT register at each major milestone: 0x01 (boot), 0x02 (DMA done), 0x04 (CNN done), 0x55 (all tests pass).",
        "sv_part": "gpio_monitor samples gpio_o[31:0] and interrupt pins; emits gpio_seq_item on pin change; soc_scoreboard verifies sequence reaches 0x00000055.",
        "internal_external": "External (Physical gpio_o[31:0] output pin bus, interrupt probe pins)"
    },
    {
        "tier": "Tier 4: Multi-Agent UVM 1.2",
        "name": "UVM_CNN_EMBED_MONITOR",
        "desc": "Protocol monitor taps M05 AXI slave interface, captures image buffer writes, and extracts 16-element embedding vector.",
        "c_part": "C firmware programs CNN registers, initiates inference, and reads embedding registers.",
        "sv_part": "cnn_monitor monitors AXI transactions on M05; detects CNN_EMBEDDING_READY; broadcasts cnn_seq_item; soc_scoreboard verifies non-zero embedding values.",
        "internal_external": "Internal (AXI bus transactions on M05 slave interface, CNN hardware registers)"
    },
    {
        "tier": "Tier 4: Multi-Agent UVM 1.2",
        "name": "UVM_DIST_MATH_MONITOR",
        "desc": "Protocol monitor taps M06 AXI slave interface, captures reference vectors, and checks distance scoring and anomaly classification.",
        "c_part": "C firmware programs Distance IP query and reference slots, triggers scoring, and reads MIN_DISTANCE and RESULT.",
        "sv_part": "dist_monitor captures writes to reference slots and reads of RESULT; soc_scoreboard checks Test 1 (Dist=0 <= Thresh) and Test 2 (Dist=800 > Thresh).",
        "internal_external": "Internal (AXI bus transactions on M06 slave interface, Distance IP registers)"
    },
    {
        "tier": "Tier 4: Multi-Agent UVM 1.2",
        "name": "UVM_DMA_BURST_MONITOR",
        "desc": "Protocol monitor taps M07 CSR interface and dma_irq_o, verifying 256-byte burst transfer to CNN buffer (0x2000_3100).",
        "c_part": "C firmware programs DMA_SRC_ADDR, DMA_DST_ADDR, and DMA_LENGTH; starts transfer.",
        "sv_part": "dma_monitor captures CSR writes and dma_irq_o; packages dma_seq_item; soc_scoreboard verifies 256 bytes transferred to 0x20003100.",
        "internal_external": "Internal & External (M07 CSR slave bus, external dma_irq_o pin)"
    },
    {
        "tier": "Tier 4: Multi-Agent UVM 1.2",
        "name": "UVM_SCOREBOARD_6DOMAINS",
        "desc": "Central multi-domain UVM scoreboard checks all 5 agent streams, enforces synchronization, and asserts zero errors.",
        "c_part": "C firmware provides the stimulus and operational sequencing for all 5 domains.",
        "sv_part": "soc_scoreboard implements 5 uvm_analysis_imp exports; tracks flags across all 6 domains; in report_phase() validates that ALL 6 DOMAINS PASSED with 0 Errors/0 Fatals.",
        "internal_external": "Internal & External (Combines internal bus monitors and external pin monitors)"
    }
]

# Write CSV
csv_path = "/home/student/honours/docs/verification/SoC_Verification_Test_Plan_Sheet.csv"
fieldnames = ["Test Name", "Description", "C Part", "SV Part", "Internal or External", "Tier"]

with open(csv_path, mode="w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    for tc in test_cases:
        writer.writerow({
            "Test Name": tc["name"],
            "Description": tc["desc"],
            "C Part": tc["c_part"],
            "SV Part": tc["sv_part"],
            "Internal or External": tc.get("internal_external", tc.get("external_internal", "Internal")),
            "Tier": tc["tier"]
        })

print(f"Generated CSV: {csv_path} with {len(test_cases)} tests.")

# Generate Excel 2003 XML Spreadsheet (opens natively in Excel with styling)
xml_path = "/home/student/honours/docs/verification/SoC_Verification_Test_Plan_Sheet.xml"

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
  <Style ss:ID="TestNameCell">
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
   </Borders>
   <Font ss:FontName="Consolas" ss:Size="10" ss:Color="#0A2540" ss:Bold="1"/>
  </Style>
  <Style ss:ID="CategoryCell">
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
   </Borders>
   <Font ss:FontName="Calibri" ss:Size="10" ss:Color="#2C3E50" ss:Italic="1"/>
   <Interior ss:Color="#F4F6F9" ss:Pattern="Solid"/>
  </Style>
 </Styles>
 <Worksheet ss:Name="Verification Test Plan">
  <Table ss:ExpandedColumnCount="6" x:FullColumns="1" x:FullRows="1" ss:DefaultRowHeight="20">
   <Column ss:Width="80"/>
   <Column ss:Width="160"/>
   <Column ss:Width="250"/>
   <Column ss:Width="250"/>
   <Column ss:Width="250"/>
   <Column ss:Width="150"/>
   <Row ss:Height="28">
    <Cell ss:StyleID="Header"><Data ss:Type="String">Tier</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Test Name</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Description</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">C Part</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">SV Part</Data></Cell>
    <Cell ss:StyleID="Header"><Data ss:Type="String">Internal or External</Data></Cell>
   </Row>
"""

def escape_xml(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

for tc in test_cases:
    tier = escape_xml(tc["tier"])
    name = escape_xml(tc["name"])
    desc = escape_xml(tc["desc"])
    c_p  = escape_xml(tc["c_part"])
    sv_p = escape_xml(tc["sv_part"])
    ie   = escape_xml(tc.get("internal_external", tc.get("external_internal", "Internal")))

    xml_content += f"""   <Row ss:AutoFitHeight="1">
    <Cell ss:StyleID="CategoryCell"><Data ss:Type="String">{tier}</Data></Cell>
    <Cell ss:StyleID="TestNameCell"><Data ss:Type="String">{name}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{desc}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{c_p}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{sv_p}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{ie}</Data></Cell>
   </Row>
"""

xml_content += """  </Table>
 </Worksheet>
</Workbook>
"""

with open(xml_path, "w", encoding="utf-8") as f:
    f.write(xml_content)

print(f"Generated Excel XML: {xml_path}")
