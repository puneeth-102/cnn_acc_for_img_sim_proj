import csv
import sys
import os

test_cases = [
    # --------------------------------------------------------------------------
    # 1. DMA Controller
    # --------------------------------------------------------------------------
    {
        "module": "DMA Controller",
        "name": "DMA_REG_RW_RESET",
        "desc": "Verify reset defaults (0x0) and read/write accessibility of DMA registers (CTRL, STATUS, SRC_ADDR, DST_ADDR, LENGTH).",
        "c_part": "Writes base addresses and transfer lengths; reads back registers to verify configuration.",
        "sv_part": "Drives AXI-Lite read/write cycles to CSR addresses; checks register flip-flops and OKAY responses.",
        "category": "Internal"
    },
    {
        "module": "DMA Controller",
        "name": "DMA_MEM2MEM_16B",
        "desc": "Verify autonomous 16-byte (4-word) memory copy from DMEM source to DMEM destination.",
        "c_part": "Configures DMA_SRC_ADDR, DMA_DST_ADDR, DMA_LENGTH=16, triggers START, and polls STATUS.",
        "sv_part": "Monitors DMA master read/write bursts on internal bus; checks destination memory matches source memory byte-for-byte.",
        "category": "Internal"
    },
    {
        "module": "DMA Controller",
        "name": "DMA_IMAGE_BURST_256B",
        "desc": "Verify 256-byte bulk transfer of 16x16 INT8 image from DMEM to CNN internal buffer (0x2000_3100).",
        "c_part": "Sets SRC=&test_image, DST=0x20003100, LENGTH=256, START=1; verifies completion status.",
        "sv_part": "Monitors continuous burst writes; verifies all 256 bytes are loaded into CNN SRAM buffer without stall.",
        "category": "Internal"
    },
    {
        "module": "DMA Controller",
        "name": "DMA_PARTIAL_ODD_LEN",
        "desc": "Verify unaligned transfer of 13 bytes (3 full 32-bit words + 1 byte) with byte strobes.",
        "c_part": "Configures DMA_LENGTH=13; checks destination buffer after completion.",
        "sv_part": "Asserts word 0-2 write with wstrb=4'hF and word 3 writes with wstrb=4'h1; verifies non-written bytes remain untouched.",
        "category": "Internal"
    },
    {
        "module": "DMA Controller",
        "name": "DMA_IRQ_ASSERTION",
        "desc": "Verify dedicated interrupt generation upon completion of DMA transfer.",
        "c_part": "Enables interrupt bit in CTRL (IRQ_EN=1); services interrupt or waits for completion flag.",
        "sv_part": "Probes physical dma_irq_o output pin; checks pin transitions from 0 to 1 when transfer completes.",
        "category": "External"
    },
    {
        "module": "DMA Controller",
        "name": "DMA_W1C_CLEAR",
        "desc": "Verify Write-1-to-Clear (W1C) mechanism to clear status flags and deassert interrupt pin.",
        "c_part": "Writes '1' to STATUS.DONE bit after transfer completes to acknowledge interrupt.",
        "sv_part": "Probes dma_irq_o pin and STATUS register; verifies pin drops from 1 to 0 immediately upon W1C write.",
        "category": "External"
    },
    {
        "module": "DMA Controller",
        "name": "DMA_ERR_ALIGN_FAULT",
        "desc": "Fault injection: Program unaligned source address (0x1000_0003) and verify transfer rejection.",
        "c_part": "Configures unaligned address; checks STATUS register for error code.",
        "sv_part": "Verifies DMA FSM latches STATUS.ERROR=1 with ERROR_CODE=1 and blocks bus master requests.",
        "category": "Internal"
    },
    {
        "module": "DMA Controller",
        "name": "DMA_ERR_ZERO_LEN",
        "desc": "Fault injection: Program LENGTH=0 and verify transfer rejection.",
        "c_part": "Configures LENGTH=0, START=1; reads back error status.",
        "sv_part": "Verifies DMA aborts transfer without issuing bus transactions; asserts ERROR_CODE=1.",
        "category": "Internal"
    },
    {
        "module": "DMA Controller",
        "name": "DMA_ERR_BUSY_CONFLICT",
        "desc": "Fault injection: Write START=1 while DMA is already busy performing an active transfer.",
        "c_part": "Writes START=1 twice consecutively without waiting for completion.",
        "sv_part": "Verifies ongoing transfer finishes safely; second command is dropped with ERROR_CODE=4.",
        "category": "Internal"
    },
    {
        "module": "DMA Controller",
        "name": "DMA_SOFT_RESET",
        "desc": "Verify soft reset recovery during an active bulk transfer.",
        "c_part": "Sets CTRL.SOFT_RESET=1 while transfer is running.",
        "sv_part": "Verifies FSM immediately halts, cancels master requests, and resets internal counters to IDLE.",
        "category": "Internal"
    },

    # --------------------------------------------------------------------------
    # 2. CNN Feature Extraction Accelerator
    # --------------------------------------------------------------------------
    {
        "module": "CNN Accelerator",
        "name": "CNN_MAC_UNIT",
        "desc": "Verify 8-bit signed multiplication and 32-bit accumulation datapath with synchronous clear.",
        "c_part": "N/A (Submodule hardware testbench).",
        "sv_part": "Drives signed INT8 pixel and weight inputs; checks product accumulation and clear_acc reset.",
        "category": "Internal"
    },
    {
        "module": "CNN Accelerator",
        "name": "CNN_CONV3X3_LAYER",
        "desc": "Verify 3x3 2D convolution on 16x16 image with 4 parallel filters (produces 784 activations).",
        "c_part": "N/A (Submodule hardware testbench).",
        "sv_part": "Feeds test image and filter weights; compares all 784 output features against Python golden model.",
        "category": "Internal"
    },
    {
        "module": "CNN Accelerator",
        "name": "CNN_RELU_LAYER",
        "desc": "Verify element-wise Rectified Linear Unit activation (clamping negative numbers to 0).",
        "c_part": "N/A (Submodule hardware testbench).",
        "sv_part": "Drives signed positive and negative values; verifies negative values clamp to 0 and positive values pass.",
        "category": "Internal"
    },
    {
        "module": "CNN Accelerator",
        "name": "CNN_MAXPOOL2X2_LAYER",
        "desc": "Verify 2x2 max pooling with stride 2 across 784 inputs (reduces to 196 features).",
        "c_part": "N/A (Submodule hardware testbench).",
        "sv_part": "Applies 14x14 feature maps per filter; verifies non-overlapping 2x2 max selection into 196 outputs.",
        "category": "Internal"
    },
    {
        "module": "CNN Accelerator",
        "name": "CNN_FC196_16_LAYER",
        "desc": "Verify Fully Connected matrix multiplication (196 inputs x 16 neurons) with bias addition.",
        "c_part": "N/A (Submodule hardware testbench).",
        "sv_part": "Applies 196 features and 16x196 weights; checks that output 16-D embedding matches golden dot products.",
        "category": "Internal"
    },
    {
        "module": "CNN Accelerator",
        "name": "CNN_IMAGE_BUFFER_SRAM",
        "desc": "Verify direct AXI writes and reads to the CNN 256-byte image SRAM buffer (0x2000_3100 - 0x2000_31FC).",
        "c_part": "Writes known pixel array into buffer address 0x2000_3100; reads back data to verify SRAM integrity.",
        "sv_part": "Monitors AXI writes to buffer range; checks SRAM memory array contents match written pixels.",
        "category": "Internal"
    },
    {
        "module": "CNN Accelerator",
        "name": "CNN_INFERENCE_EXEC",
        "desc": "Verify complete CNN inference trigger, busy polling, and 16-element embedding vector generation.",
        "c_part": "Sets DIM_CFG=16x16, EMBED_LEN=16, triggers START=1, polls STATUS.DONE, and reads embedding registers (0x20-0x5C).",
        "sv_part": "Monitors CNN AXI slave transactions; verifies pipeline execution cycles; checks embedding values are non-zero.",
        "category": "Internal"
    },
    {
        "module": "CNN Accelerator",
        "name": "CNN_IRQ_ASSERTION",
        "desc": "Verify assertion of dedicated completion interrupt pin cnn_irq_o when inference finishes.",
        "c_part": "Configures CNN_CTRL with IRQ_EN=1; waits for hardware completion.",
        "sv_part": "Probes physical cnn_irq_o output pin; checks pin asserts high when STATUS.DONE=1.",
        "category": "External"
    },
    {
        "module": "CNN Accelerator",
        "name": "CNN_INVALID_CFG_FAULT",
        "desc": "Fault injection: Program invalid image dimensions or embedding length and check error handling.",
        "c_part": "Writes illegal dimension value to DIM_CFG; reads STATUS register.",
        "sv_part": "Verifies CNN detects illegal configuration, asserts STATUS.ERROR=1 with ERROR_CODE=3, and aborts start.",
        "category": "Internal"
    },

    # --------------------------------------------------------------------------
    # 3. Distance & Anomaly Detection Engine
    # --------------------------------------------------------------------------
    {
        "module": "Distance & Anomaly Engine",
        "name": "DIST_MANHATTAN_CALC",
        "desc": "Verify hardware calculation of Manhattan (L1) distance: sum(|query[i] - ref[i]|) for 16 elements.",
        "c_part": "Loads query and reference vectors into IP slots; triggers calculation.",
        "sv_part": "Compares hardware computed distance in MIN_DISTANCE register against software reference calculation.",
        "category": "Internal"
    },
    {
        "module": "Distance & Anomaly Engine",
        "name": "DIST_THRESHOLD_MATCH",
        "desc": "Verify classification when distance <= threshold (Expected: RESULT=1 for MATCH / NORMAL).",
        "c_part": "Sets matching reference vector, sets threshold=50, starts engine, verifies RESULT==1 and MIN_DISTANCE==0.",
        "sv_part": "Monitors Distance AXI registers; checks comparator asserts RESULT=1 when distance <= threshold.",
        "category": "Internal"
    },
    {
        "module": "Distance & Anomaly Engine",
        "name": "DIST_THRESHOLD_ANOMALY",
        "desc": "Verify classification when distance > threshold (Expected: RESULT=0 for ANOMALY).",
        "c_part": "Sets divergent reference vector, sets threshold=50, starts engine, verifies RESULT==0 and MIN_DISTANCE==800.",
        "sv_part": "Monitors Distance AXI registers; checks comparator asserts RESULT=0 when distance > threshold.",
        "category": "Internal"
    },
    {
        "module": "Distance & Anomaly Engine",
        "name": "DIST_IRQ_ASSERTION",
        "desc": "Verify assertion of dedicated completion interrupt pin dist_irq_o when distance scoring finishes.",
        "c_part": "Configures DIST_CTRL with IRQ_EN=1; triggers scoring; clears interrupt via W1C.",
        "sv_part": "Probes physical dist_irq_o output pin; verifies pin rises to 1 on completion and drops to 0 on W1C.",
        "category": "External"
    },
    {
        "module": "Distance & Anomaly Engine",
        "name": "DIST_INVALID_METRIC_FAULT",
        "desc": "Fault injection: Program unsupported metric index into DIST_METRIC and verify error response.",
        "c_part": "Writes unsupported metric code (e.g. 5) into DIST_METRIC register.",
        "sv_part": "Verifies IP rejects configuration, asserts STATUS.ERROR=1 with ERROR_CODE=4, and refuses execution.",
        "category": "Internal"
    },

    # --------------------------------------------------------------------------
    # 4. 16550 UART Serial Peripheral
    # --------------------------------------------------------------------------
    {
        "module": "UART 16550 Peripheral",
        "name": "UART_BAUD_DIV_CONFIG",
        "desc": "Verify programming of UART baud rate divisor latch (divisor = 16) and line control register (8N1).",
        "c_part": "Writes LCR=0x80 (DLAB enable), writes BAUD_DIV=16, restores LCR=0x03 (8 data bits, 1 stop bit, no parity).",
        "sv_part": "Monitors internal AXI writes to UART registers 0x2000_0008 and 0x2000_000C; verifies divisor latch value.",
        "category": "Internal"
    },
    {
        "module": "UART 16550 Peripheral",
        "name": "UART_SERIAL_TX_BITSTREAM",
        "desc": "Verify physical serial transmission of ASCII characters over uart_tx_o pin at exact baud timing.",
        "c_part": "Calls uart_putc() / uart_puts() to transmit string messages to console.",
        "sv_part": "Probes physical uart_tx_o output wire; deserializes start bit, 8 data bits, and stop bit at 170 ns/bit; validates text.",
        "category": "External"
    },
    {
        "module": "UART 16550 Peripheral",
        "name": "UART_TX_FIFO_STATUS",
        "desc": "Verify UART Line Status Register (LSR) transmitter holding register empty (THRE) and transmitter empty (TEMT).",
        "c_part": "Polls LSR register until THRE bit is 1 before writing next character into THR.",
        "sv_part": "Monitors AXI reads to LSR (0x2000_0014); checks THRE drops to 0 when FIFO is written and returns to 1 when empty.",
        "category": "Internal"
    },
    {
        "module": "UART 16550 Peripheral",
        "name": "UART_IRQ_ASSERTION",
        "desc": "Verify assertion of uart_irq_o pin when TX FIFO is empty or RX data is received.",
        "c_part": "Enables UART interrupts via IER register; handles interrupt or polls status.",
        "sv_part": "Probes physical uart_irq_o output pin; checks pin asserts upon configured UART trigger condition.",
        "category": "External"
    },

    # --------------------------------------------------------------------------
    # 5. OpenTitan 64-bit RV Timer
    # --------------------------------------------------------------------------
    {
        "module": "RV Timer Peripheral",
        "name": "TIMER_COUNTER_INCREMENT",
        "desc": "Verify continuous 64-bit real-time counter (MTIME) incrementation based on system clock.",
        "c_part": "Reads MTIME counter registers twice and verifies time progression.",
        "sv_part": "Monitors internal 64-bit timer counter registers; verifies increment rate matches prescaler setting.",
        "category": "Internal"
    },
    {
        "module": "RV Timer Peripheral",
        "name": "TIMER_MATCH_INTERRUPT",
        "desc": "Verify assertion of timer_irq_o pin when MTIME counter reaches comparator value (MTIME >= MTIMECMP).",
        "c_part": "Programs MTIMECMP = MTIME + 100; enables timer interrupt; waits for interrupt.",
        "sv_part": "Probes physical timer_irq_o output pin; verifies pin rises to 1 exactly when counter matches compare register.",
        "category": "External"
    },

    # --------------------------------------------------------------------------
    # 6. PULP Platform 32-bit GPIO
    # --------------------------------------------------------------------------
    {
        "module": "PULP GPIO Peripheral",
        "name": "GPIO_DIRECTION_CONTROL",
        "desc": "Verify 32-bit pin direction configuration via GPIO_EN register (input vs push-pull output).",
        "c_part": "Writes direction mask to GPIO_EN (0x2000_2080); verifies output enables.",
        "sv_part": "Probes internal direction control bus gpio_dir_o[31:0]; checks pins configure correctly as inputs or outputs.",
        "category": "Internal"
    },
    {
        "module": "PULP GPIO Peripheral",
        "name": "GPIO_OUTPUT_PATTERN_DRIVE",
        "desc": "Verify driving arbitrary test patterns and stage indicators onto external physical gpio_o[31:0] pins.",
        "c_part": "Writes progress status to GPIO_OUT: 0x01 (boot), 0x02 (DMA done), 0x04 (CNN done), 0x55 (all pass).",
        "sv_part": "Probes physical gpio_o[31:0] output pins on chip boundary; asserts pin levels match written values.",
        "category": "External"
    },
    {
        "module": "PULP GPIO Peripheral",
        "name": "GPIO_ATOMIC_SET_CLR_TOGGLE",
        "desc": "Verify atomic bit manipulation registers: GPIO_SET (0x200), GPIO_CLEAR (0x280), and GPIO_TOGGLE (0x300).",
        "c_part": "Writes single bitmasks to SET, CLEAR, and TOGGLE registers without read-modify-write software overhead.",
        "sv_part": "Monitors AXI writes to atomic offsets; asserts that target bits on gpio_o update while other bits remain unchanged.",
        "category": "External"
    },
    {
        "module": "PULP GPIO Peripheral",
        "name": "GPIO_INPUT_SAMPLING_SYNC",
        "desc": "Verify external signal sampling on physical gpio_i[31:0] pins through 2-stage flip-flop synchronizer.",
        "c_part": "Reads GPIO_IN register (0x2000_2000) to inspect external switch/pin states.",
        "sv_part": "Drives asynchronous digital signals onto physical gpio_i pins; checks 2-stage synchronizer removes metastability.",
        "category": "External"
    },
    {
        "module": "PULP GPIO Peripheral",
        "name": "GPIO_PIN_INTERRUPT_GEN",
        "desc": "Verify generation of gpio_irq_o pin on configurable rising-edge, falling-edge, or level triggers on input pins.",
        "c_part": "Enables GPIO interrupt mask; reads interrupt status; clears interrupt via W1C.",
        "sv_part": "Drives pulse transitions on gpio_i; probes physical gpio_irq_o pin; verifies interrupt asserts and clears cleanly.",
        "category": "External"
    },

    # --------------------------------------------------------------------------
    # 7. 2-Master × 8-Slave AXI4 Interconnect
    # --------------------------------------------------------------------------
    {
        "module": "AXI4 Interconnect",
        "name": "AXI_SLAVE_ADDR_DECODING",
        "desc": "Verify correct address decoding and routing from CPU master (S00) to all 8 slave peripheral targets (M00-M07).",
        "c_part": "Issues read/write accesses to all 8 base addresses: IMEM, DMEM, UART, Timer, GPIO, CNN, Distance, and DMA.",
        "sv_part": "Monitors select lines and handshakes on all 8 slave interfaces (m00_axi through m07_axi); verifies 1-to-1 routing.",
        "category": "Internal"
    },
    {
        "module": "AXI4 Interconnect",
        "name": "AXI_UNMAPPED_DECERR",
        "desc": "Verify generation of DECERR (2'b11) response when accessing unmapped address space (e.g. 0x3000_0000).",
        "c_part": "Attempts read or write access to unmapped memory address.",
        "sv_part": "Captures write response bresp and read response rresp; asserts interconnect returns 2'b11 without bus hang.",
        "category": "Internal"
    },
    {
        "module": "AXI4 Interconnect",
        "name": "AXI_MASTER_ARBITRATION",
        "desc": "Verify round-robin bus arbitration when CPU (S00) and DMA (S01) issue concurrent accesses to shared DMEM (M01).",
        "c_part": "Initiates DMA background transfer to DMEM while CPU actively reads instructions and data.",
        "sv_part": "Monitors simultaneous request lines; verifies round-robin arbiter grants alternating access without starving either master.",
        "category": "Internal"
    },
    {
        "module": "AXI4 Interconnect",
        "name": "AXI_BACKPRESSURE_HANDSHAKE",
        "desc": "Verify valid/ready flow control and stall handling across all AXI channels during burst transactions.",
        "c_part": "Issues continuous back-to-back memory and register transfers.",
        "sv_part": "Randomly asserts/deasserts ready signals; verifies master correctly holds valid and data until ready is high.",
        "category": "Internal"
    },

    # --------------------------------------------------------------------------
    # 8. Memory Subsystem (IMEM & DMEM)
    # --------------------------------------------------------------------------
    {
        "module": "Memory Subsystem",
        "name": "IMEM_DUAL_PORT_ACCESS",
        "desc": "Verify Instruction Memory dual-port operation: CPU IFU instruction fetches and LSU/DMA data reads/writes.",
        "c_part": "Executes code from IMEM while testbench preloads hex data.",
        "sv_part": "Verifies simultaneous IFU fetch and AXI slave access to IMEM (0x0000_0000 - 0x0000_FFFF) without conflict.",
        "category": "Internal"
    },
    {
        "module": "Memory Subsystem",
        "name": "DMEM_BYTE_ENABLE_ACCESS",
        "desc": "Verify Data Memory byte-level access using 4-bit write strobes (wstrb) for 8-bit, 16-bit, and 32-bit accesses.",
        "c_part": "Performs uint8_t, uint16_t, and uint32_t stores and loads in DMEM (0x1000_0000 - 0x1000_FFFF).",
        "sv_part": "Checks that only enabled byte lanes in memory are modified; non-targeted bytes remain preserved.",
        "category": "Internal"
    },

    # --------------------------------------------------------------------------
    # 9. Full SoC System Integration & Firmware Execution
    # --------------------------------------------------------------------------
    {
        "module": "Full SoC System",
        "name": "SOC_CPU_RESET_BOOT",
        "desc": "Verify VeeR-EL2 CPU boot from hardware reset, instruction fetch from 0x0000_0000, and stack initialization.",
        "c_part": "crt0.s initializes stack pointer sp to 0x1000_FFF0, configures MRAC CSR (0x5555556A), and calls main().",
        "sv_part": "Deasserts rst_l; tracks CPU program counter (ifu_i0_pc); verifies execution starts at 0x0000_0000.",
        "category": "Internal"
    },
    {
        "module": "Full SoC System",
        "name": "SOC_CONSOLE_LOGGING",
        "desc": "Verify CPU firmware execution logs system progress, embeddings, and results via UART serial output.",
        "c_part": "Firmware executes print routines outputting 26 structured log lines to the console.",
        "sv_part": "UART monitor captures all characters from physical uart_tx_o pin; verifies 26 complete lines and pass string.",
        "category": "External"
    },
    {
        "module": "Full SoC System",
        "name": "SOC_END2END_NORMAL_CLASSIFY",
        "desc": "Verify full autonomous pipeline classifying a normal image sample: DMA copy -> CNN inference -> Distance Match.",
        "c_part": "Orchestrates DMA transfer, CNN start, loads matching reference embedding, validates RESULT==1, logs PASS.",
        "sv_part": "Scoreboard captures DMA transfer, validates CNN embedding vector, and verifies Distance IP outputs Match=1.",
        "category": "Internal"
    },
    {
        "module": "Full SoC System",
        "name": "SOC_END2END_ANOMALY_CLASSIFY",
        "desc": "Verify full autonomous pipeline classifying an anomaly image: DMA copy -> CNN inference -> Distance Anomaly.",
        "c_part": "Loads divergent reference embedding, triggers Distance IP, validates RESULT==0 (ANOMALY), logs PASS.",
        "sv_part": "Scoreboard verifies Distance IP outputs Dist=800, Result=0, and flags anomaly detection.",
        "category": "Internal"
    },
    {
        "module": "Full SoC System",
        "name": "SOC_FINAL_MAILBOX_HANDSHAKE",
        "desc": "Verify system completion handshake via DMEM mailbox (0x1000_FF00) and final GPIO output pin state (0x00000055).",
        "c_part": "Writes 0xCAFE0001 to MAILBOX_REG (0x1000_FF00); drives GPIO_OUT = 0x00000055; enters sleep.",
        "sv_part": "Testbench samples physical gpio_o pins for 0x00000055 and checks DMEM mailbox holds 0xCAFE0001 before exiting.",
        "category": "External"
    }
]

# Write CSV
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
            "Internal or External": tc["category"]
        })

print(f"Generated clean CSV: {csv_path} with {len(test_cases)} tests.")

# Write Excel XML
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
  <Style ss:ID="InternalCell">
   <Alignment ss:Horizontal="Center" ss:Vertical="Top"/>
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
   <Alignment ss:Horizontal="Center" ss:Vertical="Top"/>
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
 <Worksheet ss:Name="Verification Test Plan">
  <Table ss:ExpandedColumnCount="5" x:FullColumns="1" x:FullRows="1" ss:DefaultRowHeight="20">
   <Column ss:Width="180"/>
   <Column ss:Width="280"/>
   <Column ss:Width="260"/>
   <Column ss:Width="260"/>
   <Column ss:Width="120"/>
   <Row ss:Height="28">
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
    name = escape_xml(tc["name"])
    desc = escape_xml(tc["desc"])
    c_p  = escape_xml(tc["c_part"])
    sv_p = escape_xml(tc["sv_part"])
    cat  = escape_xml(tc["category"])
    style_id = "InternalCell" if tc["category"] == "Internal" else "ExternalCell"

    xml_content += f"""   <Row ss:AutoFitHeight="1">
    <Cell ss:StyleID="TestNameCell"><Data ss:Type="String">{name}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{desc}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{c_p}</Data></Cell>
    <Cell ss:StyleID="DataCell"><Data ss:Type="String">{sv_p}</Data></Cell>
    <Cell ss:StyleID="{style_id}"><Data ss:Type="String">{cat}</Data></Cell>
   </Row>
"""

xml_content += """  </Table>
 </Worksheet>
</Workbook>
"""

with open(xml_path, "w", encoding="utf-8") as f:
    f.write(xml_content)

print(f"Generated clean Excel XML: {xml_path}")
