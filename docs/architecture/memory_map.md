# SoC Memory Address Map

The CNN Anomaly Detection SoC utilizes a unified 32-bit byte-addressed memory space arbitrated via a 2-Master × 8-Slave AXI4 Interconnect (`axi_interconnect_wrap_2x8`).

---

## 1. Master Ports

| Master ID | Interface Name | Master Description | Data Width | Address Width | Bus Protocol |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **S00** | `s00_axi_*` | **VeeR-EL2 CPU LSU** (Load-Store Unit) | 32-bit | 32-bit | AXI4 (via width adapter) |
| **S01** | `s01_axi_*` | **AXI DMA Controller** (Master Interface) | 32-bit | 32-bit | AXI4 Master |

---

## 2. Slave Memory Map

| Slave Port | Base Address | End Address | Size | Target IP / Module | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **m00** | `0x0000_0000` | `0x0000_FFFF` | 64 KB | **Instruction Memory (IMEM)** | Shared Dual-Port SRAM. Port A: IFU direct fetch (`ifu32_*`); Port B: LSU/DMA writes (`m00`). Base of CPU boot vector (`0x0000_0000`). |
| **m01** | `0x1000_0000` | `0x1000_FFFF` | 64 KB | **Data Memory (DMEM)** | Single-Port SRAM with 4-bit byte enables (`wstrb`). Stores INT8 input images, INT8 model weights, and embeddings. |
| **m02** | `0x2000_0000` | `0x2000_0FFF` | 4 KB | **AXI UART** | 16550-compatible serial communications interface (DLAB, IER, LSR, FIFO). |
| **m03** | `0x2000_1000` | `0x2000_1FFF` | 4 KB | **RISC-V 64-bit Timer** | OpenTitan `timer_core` peripheral (`mtime`, `mtimecmp`, prescaler, IRQ). |
| **m04** | `0x2000_2000` | `0x2000_2FFF` | 4 KB | **PULP Platform GPIO** | 32-bit General Purpose I/O controller (atomic SET/CLEAR, direction, input sync, IRQ). |
| **m05** | `0x2000_3000` | `0x2000_3FFF` | 4 KB | **CNN Accelerator** | 16x16 INT8 Conv3x3 + ReLU + MaxPool + FC16 hardware pipeline. Dedicated `cnn_irq_o`. |
| **m06** | `0x2000_4000` | `0x2000_4FFF` | 4 KB | **Similarity / Distance Engine** | Reference embedding bank + Manhattan distance + threshold comparator. Dedicated `dist_irq_o`. |
| **m07** | `0x2000_5000` | `0x2000_5FFF` | 4 KB | **AXI DMA Registers** | CSR configuration space for AXI DMA engine (descriptors, transfer triggers). |
| **Unmapped** | *All other* | — | — | **DECERR Default Slave** | Returns AXI decode error (`2'b11`) to prevent system lockup. |

---

## 3. Dedicated Peripheral Interrupts

| Interrupt Signal | Originating IP | Description |
| :--- | :--- | :--- |
| `uart_irq_o` | UART (`m02`) | Triggered on RX data ready or TX FIFO empty. |
| `cnn_irq_o` | CNN Accelerator (`m05`) | Triggered on CNN inference completion (`DONE=1`). |
| `dist_irq_o` | Distance IP (`m06`) | Triggered on anomaly classification completion (`DONE=1`). |
| `timer_irq_o` | RISC-V Timer (`m03`) | Standard RISC-V timer interrupt (`mtime >= mtimecmp`). |
| `gpio_irq_o` | PULP GPIO (`m04`) | Combined GPIO pin interrupt (edge/level detection). |
