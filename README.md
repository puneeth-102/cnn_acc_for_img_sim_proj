# RISC-V CNN Anomaly Detection SoC

[![Verification](https://img.shields.io/badge/Verification-IEEE%20UVM%201.2%20PASS-brightgreen.svg)]()
[![RTL Simulation](https://img.shields.io/badge/Synopsys%20VCS-2023.03-blue.svg)]()
[![Debug Waveform](https://img.shields.io/badge/Verdi-FSDB%20Enabled-orange.svg)]()
[![Architecture](https://img.shields.io/badge/RISC--V-VeeR--EL2%20RV32IMC-lightgrey.svg)]()
[![Bus Interconnect](https://img.shields.io/badge/Interconnect-2x8%20AXI4%20Crossbar-blueviolet.svg)]()

A synthesizable, production-grade System-on-Chip (SoC) centered around Western Digital's **VeeR-EL2 32-bit RISC-V Core (RV32IMC)**, coupled with an integrated hardware **CNN Feature Extraction Accelerator**, **Manhattan Distance / Anomaly Detection Engine**, **AXI4 DMA Controller**, and standard peripherals connected via a high-performance **2-Master × 8-Slave AXI4 Crossbar Interconnect**.

---

## 📁 Repository Directory Structure

```text
cnn_acc_for_img_sim_proj/
├── docs/                                  # Architectural specs, memory maps, and verification plans
│   ├── architecture/
│   │   └── memory_map.md                  # Comprehensive 32-bit SoC memory map
│   ├── spec/
│   │   ├── CNN_Anomaly_Detection_SoC_Kiro_Specification.docx
│   │   └── extracted_spec.txt             # Hardware registers & sub-system requirements
│   └── verification/
│       └── CNN_SoC_Verification_Test_Plan.md # IEEE UVM 1.2 Verification Test Plan
│
├── rtl/                                   # Synthesizable SystemVerilog RTL source code
│   ├── Cores-VeeR-EL2/                    # Western Digital VeeR-EL2 RISC-V 32-bit Core
│   ├── cnn/                               # Hardware CNN Pipeline (16x16 INT8 Conv3x3 + ReLU + MaxPool + FC16)
│   │   ├── conv3x3.sv
│   │   ├── relu.sv
│   │   ├── maxpool2x2.sv
│   │   ├── flatten.sv
│   │   ├── fc_196_16.sv
│   │   ├── mac_unit.sv
│   │   └── cnn_top.sv
│   ├── distance/                          # Hardware Distance & Anomaly Comparator
│   │   ├── distance.sv                    # Manhattan distance accumulator
│   │   └── threshold.sv                   # Threshold comparator & anomaly classifier
│   ├── dma/                               # High-throughput AXI4 Direct Memory Access engine
│   │   ├── rtl/                           # DMA core, FIFO, FSM, and streamer logic
│   │   └── rggen-verilog-rtl/             # RgGen register adapter components
│   ├── interconnect/                      # 2-Master × 8-Slave Full AXI4 Interconnect
│   │   ├── axi_interconnect_wrap_2x8.v    # 2x8 Top wrapper with round-robin arbitration
│   │   ├── axi_interconnect.v
│   │   ├── arbiter.v
│   │   └── priority_encoder.v
│   ├── mem/                               # Memory subsystem wrappers
│   │   ├── imem_axi.sv                    # Dual-Port Instruction Memory (IFU fetch + LSU/DMA write)
│   │   └── dmem_axi.sv                    # Single-Port Data Memory with 4-bit byte enables
│   ├── uart/                              # 16550-compatible AXI4-Lite UART peripheral
│   │   ├── axi_uart_top.v
│   │   ├── uart_controller.v
│   │   ├── uart_transmitter.v
│   │   ├── uart_receiver.v
│   │   └── axi_internal_fifo.v
│   ├── wrappers/                          # Protocol adaptation wrappers (AXI4-Lite to Core logic)
│   │   ├── cnn_axi_wrapper.sv             # AXI4-Lite wrapper for CNN Accelerator
│   │   ├── distance_axi_wrapper.sv        # AXI4-Lite wrapper for Distance IP
│   │   ├── dma_axi_wrapper.sv             # Dual AXI4 Master/Slave bridge for DMA Engine
│   │   ├── gpio_axi_wrapper.sv            # AXI4-Lite wrapper for PULP GPIO IP
│   │   └── timer_axi_wrapper.sv           # AXI4-Lite wrapper for 64-bit RV Timer
│   └── top/
│       └── cnn_soc_top.sv                 # Top-Level SoC module integrating all masters, slaves & IRQs
│
├── sw/                                    # Embedded C Firmware & Runtime Software Stack
│   ├── anomaly_det/                       # Autonomous anomaly detection firmware application
│   │   └── main.c                         # End-to-end SoC C orchestration firmware
│   ├── hello_uart/                        # Hello UART & basic sanity test application
│   │   └── main.c
│   ├── drivers/                           # Modular peripheral HAL drivers
│   │   ├── uart.h / uart.c                # Polled & interrupt UART driver
│   │   ├── cnn.h                          # CNN accelerator trigger & readout HAL
│   │   ├── distance.h                     # Distance threshold & reference embedding HAL
│   │   └── dma.h                          # DMA block-transfer configuration HAL
│   ├── include/                           # SoC system definitions & register header files
│   │   ├── soc_regs.h                     # Base addresses & peripheral register offsets
│   │   ├── csr_dma.h                      # DMA CSR definitions
│   │   └── gpio_hal.h                     # Low-level GPIO configuration macros
│   └── boot/                              # Bootloader and startup hex images
│       ├── boot_test.hex                  # Assembled firmware image loaded into IMEM
│       └── link.ld                        # RISC-V GCC Linker script
│
├── tb/                                    # Testbenches & Verification Suites
│   ├── uvm/                               # IEEE 1800.2 UVM 1.2 Multi-Agent Verification Environment
│   │   ├── if/                            # SystemVerilog interfaces (soc_if.sv)
│   │   ├── agents/                        # Modular UVM Verification Components (UVCs)
│   │   │   ├── uart_agent/                # UART Protocol Monitor & Driver
│   │   │   ├── gpio_agent/                # GPIO Pin Activity Monitor
│   │   │   ├── cnn_agent/                 # CNN Accelerator AXI Protocol Monitor
│   │   │   ├── dist_agent/                # Distance / Similarity Protocol Monitor
│   │   │   └── dma_agent/                 # DMA Engine Transaction Monitor
│   │   ├── env/
│   │   │   ├── soc_env.sv                 # Top UVM Environment instantiating all agents
│   │   │   └── soc_scoreboard.sv          # 6-Domain Self-Checking Scoreboard with reference models
│   │   ├── tests/
│   │   │   └── soc_anomaly_test.sv        # End-to-end anomaly detection UVM test
│   │   ├── soc_uvm_pkg.sv                 # UVM Package containing all UVCs and sequences
│   │   └── tb_top_uvm.sv                  # Top UVM Verification Testbench harness
│   └── soc/                               # SystemVerilog direct SoC integration testbenches
│       └── tb_cnn_soc_axi_integration.sv  # 63-test SoC regression testbench
│
├── scripts/                               # Automation, Compilation, and Regression Scripts
│   ├── compile_soc_top.sh                 # VCS elaboration & compilation script for cnn_soc_top
│   ├── run_cpu_uart_sim.sh                # End-to-end firmware execution simulation
│   ├── run_uvm_anomaly_sim.sh             # VCS compile & execution of IEEE UVM 1.2 multi-agent testbench
│   ├── run_soc_regression.sh              # 63-test AXI SoC interconnect & peripheral regression
│   ├── run_dma_tests.sh                   # Standalone DMA controller unit testbench
│   ├── run_mem_tests.sh                   # Standalone IMEM/DMEM SRAM testbench
│   ├── run_uart_tb.sh                     # Standalone UART peripheral testbench
│   ├── view_verdi.sh                      # Launch Synopsys Verdi on SoC simulation FSDB waveform
│   ├── view_uvm_verdi.sh                  # Launch Synopsys Verdi on UVM simulation FSDB waveform
│   └── veer_files.f                       # VeeR-EL2 CPU filelist
│
└── .gitignore                             # Git ignore rules for VCS, Verdi, and EDA artifacts
```

---

## 🏛️ SoC Architecture & Block Diagram

```text
                               +-----------------------------+
                               |     VeeR-EL2 RISC-V Core    |
                               |  (RV32IMC, 4-stage Pipeline)|
                               +--------------+--------------+
                                              | S00 (LSU)
                                              v
+------------------+           +-----------------------------+
|  AXI DMA Master  +---------->|   2x8 AXI4 Crossbar Matrix  |
|  (Descriptor/Blk)| S01       |  (axi_interconnect_wrap_2x8)|
+------------------+           +--------------+--------------+
                                              |
        +-------------+---------------+-------+-------+---------------+-------------+
        |             |               |               |               |             |
        v             v               v               v               v             v
   +---------+   +---------+     +---------+     +---------+     +---------+   +---------+
   |   m00   |   |   m01   |     |   m02   |     |   m03   |     |   m04   |   |   m05   |
   |  IMEM   |   |  DMEM   |     |  UART   |     | RV Timer|     |  GPIO   |   | CNN Acc |
   | (64 KB) |   | (64 KB) |     | (16550) |     | (64-bit)|     | (32-bit)|   | (16x16) |
   +---------+   +---------+     +----+----+     +----+----+     +----+----+   +----+----+
                                      |               |               |             |
                                      |   +-----------+---------------+             |
                                      |   |                                         |
                                      v   v                                         v
                               +--------------+                                +---------+
                               |   Interrupt  |<-------------------------------+   m06   |
                               |  Controller  |<-------------------------------+ Distance|
                               +--------------+                                | Engine  |
                                                                               +----+----+
                                                                                    |
                                                                               +----+----+
                                                                               |   m07   |
                                                                               | DMA Reg |
                                                                               +---------+
```

---

## 🗺️ SoC Memory Address Map

All transactions are 32-bit byte-addressed, arbitrated across a 2-Master × 8-Slave AXI4 crossbar:

| Port | Base Address | End Address | Size | Subsystem / Peripheral | Functionality |
| :---: | :---: | :---: | :---: | :--- | :--- |
| **m00** | `0x0000_0000` | `0x0000_FFFF` | 64 KB | **Instruction SRAM (IMEM)** | Dual-Port. CPU IFU execution vector (`0x0000_0000`), LSU/DMA writable. |
| **m01** | `0x1000_0000` | `0x1000_FFFF` | 64 KB | **Data SRAM (DMEM)** | Single-Port SRAM with 4-bit byte enables. Stores input images and weights. |
| **m02** | `0x2000_0000` | `0x2000_0FFF` | 4 KB | **AXI UART (16550)** | Serial communication interface (Baud divisor, FIFO, live console logs). |
| **m03** | `0x2000_1000` | `0x2000_1FFF` | 4 KB | **64-bit RISC-V Timer** | OpenTitan `timer_core` (`mtime`, `mtimecmp`, prescaler, timer interrupt). |
| **m04** | `0x2000_2000` | `0x2000_2FFF` | 4 KB | **PULP 32-bit GPIO** | General purpose I/O, bitwise set/clear, input synchronization. |
| **m05** | `0x2000_3000` | `0x2000_3FFF` | 4 KB | **CNN Accelerator** | 16×16 INT8 Conv3x3 + ReLU + MaxPool + FC16 hardware pipeline. |
| **m06** | `0x2000_4000` | `0x2000_4FFF` | 4 KB | **Distance / Similarity** | Reference embedding bank + Manhattan distance + threshold classifier. |
| **m07** | `0x2000_5000` | `0x2000_5FFF` | 4 KB | **AXI DMA Registers** | CSR configuration space for DMA engine (descriptors, transfer triggers). |
| **—** | *All other* | — | — | **Default DECERR Slave** | Returns AXI `DECERR` (`2'b11`) response to prevent bus hang on invalid access. |

---

## ⚡ Autonomous Firmware Flow

The autonomous C application ([`sw/anomaly_det/main.c`](sw/anomaly_det/main.c)) executes without testbench intervention:

1. **CPU Boot & Peripheral Initialization**:
   - Resets from `0x0000_0000`, initializes UART at 115200 baud, and clears GPIO outputs.
2. **DMA Image Transfer**:
   - Programs the AXI DMA engine to transfer a 256-byte INT8 raw image (`16×16`) from Data RAM (`DMEM: 0x1000_0000`) directly to the CNN Accelerator buffer (`0x2000_3100`).
3. **Hardware CNN Feature Extraction**:
   - Triggers the hardware CNN accelerator (`0x2000_3000 = 0x1`).
   - Polls `STATUS` register (`0x2000_3004`) until `DONE=1`.
   - Reads back the 16-element INT8 embedding vector (e.g., `0xFFFFFC20`).
4. **Reference Image Matching & Distance Computation**:
   - Programs reference embedding into Distance IP registers (`0x2000_4000` - `0x2000_400C`).
   - Sets similarity threshold (`0x2000_4010 = 0x64`).
   - Runs **Similarity Test**: Computes Manhattan distance (`Dist = 0 <= 100`) → Flags `Match = 1` (NORMAL).
   - Runs **Anomaly Test**: Injects perturbed embedding (`Dist = 800 > 100`) → Flags `Match = 0` (ANOMALY DETECTED).
5. **Live UART Output & Hardware Handshake**:
   - Streams formatted classification results over UART TX.
   - Asserts GPIO heartbeat pins (`0x55`).
   - Writes pass signature `0xCAFE0001` to mailbox register to complete simulation.

---

## 🧪 Verification Environment (IEEE UVM 1.2)

The SoC is fully verified using an **IEEE 1800.2 UVM 1.2** multi-agent verification environment:

- **5 Dedicated Agents / Monitors**:
  - `uart_agent`: Captures serial TX packets, checks character transmission and framing.
  - `gpio_agent`: Monitors 32-bit GPIO outputs and heartbeat transitions (`0x55`).
  - `cnn_agent`: Monitors AXI4-Lite transactions to the CNN Accelerator (`0x2000_3000`).
  - `dist_agent`: Monitors Distance IP configuration, reference embeddings, and classification results.
  - `dma_agent`: Tracks AXI4 burst transactions generated by the DMA engine.
- **Scoreboard (`soc_scoreboard`)**:
  - Independent software reference models for CNN feature extraction and Manhattan distance calculation.
  - Compares hardware accelerator outputs against golden expectations cycle-by-cycle.
  - Monitors Mailbox register (`0x1000_0FF0`) for CPU software completion signature (`0xCAFE0001`).

---

## 🚀 Quick Start / How to Run

### Prerequisites
- **Simulator**: Synopsys VCS (v2023.03 or compatible)
- **Waveform Viewer**: Synopsys Verdi
- **Toolchain**: RISC-V 32-bit GCC (`riscv32-unknown-elf-gcc`)

### 1. Compile the Complete SoC Top-Level
```bash
./scripts/compile_soc_top.sh
```

### 2. Run End-to-End Autonomous Firmware Simulation
```bash
./scripts/run_cpu_uart_sim.sh
```

### 3. Run Full IEEE UVM 1.2 Multi-Agent Verification
```bash
./scripts/run_uvm_anomaly_sim.sh
```
*Expected Result:*
```text
==================================================================================
  UVM SIMULATION PASSED: ALL 6 SCOREBOARD DOMAINS MATCHED WITH ZERO ERRORS!
==================================================================================
--- UVM Report Summary ---
uvm_test_top.env.sb [SB_SUMMARY] 6 out of 6 domains verified successfully!
** UVM TEST PASSED **
```

### 4. View Waveforms in Synopsys Verdi
- View SoC Firmware Simulation:
  ```bash
  ./scripts/view_verdi.sh
  ```
- View UVM Verification Simulation:
  ```bash
  ./scripts/view_uvm_verdi.sh
  ```

---

## 📜 Author & Maintainer

- **Developer**: Puneeth (`puneeth-102`)
- **Email**: [saipuneeth102@gmail.com](mailto:saipuneeth102@gmail.com)
- **GitHub**: [https://github.com/puneeth-102/cnn_acc_for_img_sim_proj](https://github.com/puneeth-102/cnn_acc_for_img_sim_proj)
