import csv
import sys
import os

interfaces = [
    # --------------------------------------------------------------------------
    # 1. Clock and Reset Interface
    # --------------------------------------------------------------------------
    {
        "group": "Clock & Reset",
        "signal": "clk",
        "dir": "Input",
        "width": "1-bit",
        "block": "Global SoC Clock Tree",
        "protocol": "Single-ended CMOS Clock",
        "usage": "Primary 100 MHz system clock driving the VeeR-EL2 CPU core, 2x8 AXI4 crossbar, DMA engine, CNN accelerator, Distance IP, and peripheral wrappers."
    },
    {
        "group": "Clock & Reset",
        "signal": "rst_l",
        "dir": "Input",
        "width": "1-bit",
        "block": "Global Reset Controller",
        "protocol": "Active-Low Synchronous Reset",
        "usage": "Primary system reset. When held low (0), resets all CPU pipeline registers, AXI bus arbiters, DMA FSM, and memory-mapped control registers to defaults."
    },
    {
        "group": "Clock & Reset",
        "signal": "dbg_rst_l",
        "dir": "Input",
        "width": "1-bit",
        "block": "VeeR Debug Subsystem",
        "protocol": "Active-Low Reset",
        "usage": "Dedicated reset for on-chip RISC-V debug module and JTAG TAP controller; allows CPU reset without destroying active debug sessions."
    },

    # --------------------------------------------------------------------------
    # 2. UART 16550 Serial Console Interface
    # --------------------------------------------------------------------------
    {
        "group": "UART Serial Console",
        "signal": "uart_tx_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "axi_uart_top (M02)",
        "protocol": "RS-232 / UART (8N1 @ Divisor 16)",
        "usage": "Serial transmit wire to host PC/terminal. Transmits 26 structured ASCII log lines during boot, DMA transfer status, CNN embedding vectors, and final PASS banner."
    },
    {
        "group": "UART Serial Console",
        "signal": "uart_rx_i",
        "dir": "Input",
        "width": "1-bit",
        "block": "axi_uart_top (M02)",
        "protocol": "RS-232 / UART (8N1)",
        "usage": "Serial receive wire for external host commands or image data streaming into the SoC UART RX FIFO (held idle-high in simulation)."
    },

    # --------------------------------------------------------------------------
    # 3. PULP Platform 32-bit GPIO Interface
    # --------------------------------------------------------------------------
    {
        "group": "PULP 32-bit GPIO",
        "signal": "gpio_o[31:0]",
        "dir": "Output",
        "width": "32-bit",
        "block": "gpio_axi_wrapper (M04)",
        "protocol": "Parallel Digital CMOS I/O",
        "usage": "Physical status output pins. Driven by firmware to broadcast execution phases: 0x01 (CPU Boot Done), 0x02 (DMA Copy Done), 0x04 (CNN Inference Done), 0x55 (All Tests Passed)."
    },
    {
        "group": "PULP 32-bit GPIO",
        "signal": "gpio_i[31:0]",
        "dir": "Input",
        "width": "32-bit",
        "block": "gpio_axi_wrapper (M04)",
        "protocol": "Parallel Digital CMOS I/O",
        "usage": "External digital inputs connected to board switches, pushbuttons, or external trigger sensors; passed through an on-chip 2-stage synchronizer to prevent metastability."
    },
    {
        "group": "PULP 32-bit GPIO",
        "signal": "gpio_dir_o[31:0]",
        "dir": "Output",
        "width": "32-bit",
        "block": "gpio_axi_wrapper (M04)",
        "protocol": "Direction Control Strobe",
        "usage": "Controls external bi-directional I/O pad buffers (1 = Output drive enabled, 0 = High-impedance / Input mode) based on the GPIO_EN configuration register."
    },

    # --------------------------------------------------------------------------
    # 4. Dedicated Hardware Interrupt Output Pins (IRQ Lines)
    # --------------------------------------------------------------------------
    {
        "group": "Hardware Interrupt Outputs",
        "signal": "dma_irq_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "dma_axi_wrapper (M07)",
        "protocol": "Active-High Pulse / Level IRQ",
        "usage": "Asserts high when DMA controller finishes a block transfer (e.g. 256-byte image copy from DMEM to CNN buffer); cleared synchronously via Write-1-to-Clear (W1C)."
    },
    {
        "group": "Hardware Interrupt Outputs",
        "signal": "cnn_irq_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "cnn_axi_wrapper (M05)",
        "protocol": "Active-High Pulse / Level IRQ",
        "usage": "Asserts high when CNN hardware accelerator completes Conv3x3 -> ReLU -> MaxPool -> FC inference and valid 16-D embedding vector is ready in output registers."
    },
    {
        "group": "Hardware Interrupt Outputs",
        "signal": "dist_irq_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "distance_axi_wrapper (M06)",
        "protocol": "Active-High Pulse / Level IRQ",
        "usage": "Asserts high when Distance/Anomaly engine finishes Manhattan scoring and threshold comparison; signals valid RESULT (Match/Anomaly) and MIN_DISTANCE."
    },
    {
        "group": "Hardware Interrupt Outputs",
        "signal": "uart_irq_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "axi_uart_top (M02)",
        "protocol": "Active-High Level IRQ",
        "usage": "Asserts when UART transmitter FIFO is empty (THRE) or when incoming character bytes are available in the UART receiver FIFO."
    },
    {
        "group": "Hardware Interrupt Outputs",
        "signal": "timer_irq_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "timer_axi_wrapper (M03)",
        "protocol": "Active-High Level IRQ",
        "usage": "Asserts when 64-bit real-time counter MTIME matches or exceeds programmed comparator threshold MTIMECMP; provides periodic RTOS/firmware tick."
    },
    {
        "group": "Hardware Interrupt Outputs",
        "signal": "gpio_irq_o",
        "dir": "Output",
        "width": "1-bit",
        "block": "gpio_axi_wrapper (M04)",
        "protocol": "Active-High Pulse / Level IRQ",
        "usage": "Asserts when any enabled GPIO input pin detects a configured rising-edge, falling-edge, or level-sensitive transition."
    },

    # --------------------------------------------------------------------------
    # 5. External Interrupt Inputs into RISC-V PIC
    # --------------------------------------------------------------------------
    {
        "group": "Core Interrupt Inputs",
        "signal": "timer_int",
        "dir": "Input",
        "width": "1-bit",
        "block": "el2_veer_wrapper (CPU PIC)",
        "protocol": "Active-High Level",
        "usage": "External machine timer interrupt input wired into the VeeR-EL2 Programmable Interrupt Controller (PIC)."
    },
    {
        "group": "Core Interrupt Inputs",
        "signal": "soft_int",
        "dir": "Input",
        "width": "1-bit",
        "block": "el2_veer_wrapper (CPU PIC)",
        "protocol": "Active-High Level",
        "usage": "External inter-processor / software interrupt line routed to VeeR-EL2 PIC for multi-core IPC or OS rescheduling."
    },

    # --------------------------------------------------------------------------
    # 6. IEEE 1149.1 JTAG Hardware Debug Interface
    # --------------------------------------------------------------------------
    {
        "group": "JTAG Hardware Debug",
        "signal": "jtag_tck",
        "dir": "Input",
        "width": "1-bit",
        "block": "VeeR Debug Module (TAP)",
        "protocol": "IEEE 1149.1 Clock",
        "usage": "JTAG Test Clock input; clocks instruction register (IR) and data register (DR) scan chains for OpenOCD/GDB hardware debugging."
    },
    {
        "group": "JTAG Hardware Debug",
        "signal": "jtag_tms",
        "dir": "Input",
        "width": "1-bit",
        "block": "VeeR Debug Module (TAP)",
        "protocol": "IEEE 1149.1 Control",
        "usage": "JTAG Test Mode Select; controls state machine transitions of the standard 16-state TAP controller."
    },
    {
        "group": "JTAG Hardware Debug",
        "signal": "jtag_tdi",
        "dir": "Input",
        "width": "1-bit",
        "block": "VeeR Debug Module (TAP)",
        "protocol": "IEEE 1149.1 Serial In",
        "usage": "JTAG Test Data In; serial data stream containing CPU debug commands, breakpoint registers, and memory access requests."
    },
    {
        "group": "JTAG Hardware Debug",
        "signal": "jtag_trst_n",
        "dir": "Input",
        "width": "1-bit",
        "block": "VeeR Debug Module (TAP)",
        "protocol": "Active-Low Reset",
        "usage": "JTAG Test Reset; asynchronous hardware reset pin that resets TAP controller state to Test-Logic-Reset."
    },
    {
        "group": "JTAG Hardware Debug",
        "signal": "jtag_tdo",
        "dir": "Output",
        "width": "1-bit",
        "block": "VeeR Debug Module (TAP)",
        "protocol": "IEEE 1149.1 Serial Out",
        "usage": "JTAG Test Data Out; serial data stream returning CPU register values, program counter, and debug status to host debugger."
    },
    {
        "group": "JTAG Hardware Debug",
        "signal": "jtag_tdoEn",
        "dir": "Output",
        "width": "1-bit",
        "block": "VeeR Debug Module (TAP)",
        "protocol": "Tri-State Pad Enable",
        "usage": "Output driver enable control for external bi-directional JTAG TDO pad buffer (high only when TAP is in Shift-IR / Shift-DR state)."
    },

    # --------------------------------------------------------------------------
    # 7. CPU Power Management & Multiprocessor Control (MPC) Interface
    # --------------------------------------------------------------------------
    {
        "group": "CPU Control & Status",
        "signal": "i_cpu_halt_req",
        "dir": "Input",
        "width": "1-bit",
        "block": "el2_veer_wrapper (CPU MPC)",
        "protocol": "Handshake Control",
        "usage": "External hardware CPU halt request; forces VeeR-EL2 core to pause instruction fetch and pipeline for power saving or external debug control."
    },
    {
        "group": "CPU Control & Status",
        "signal": "o_cpu_halt_ack",
        "dir": "Output",
        "width": "1-bit",
        "block": "el2_veer_wrapper (CPU MPC)",
        "protocol": "Handshake Acknowledge",
        "usage": "Acknowledge signal asserted by CPU when all outstanding load/store transactions finish and the pipeline has safely entered the halted state."
    },
    {
        "group": "CPU Control & Status",
        "signal": "o_cpu_halt_status",
        "dir": "Output",
        "width": "1-bit",
        "block": "el2_veer_wrapper (CPU MPC)",
        "protocol": "Status Indicator",
        "usage": "Continuous status flag indicating whether the VeeR-EL2 CPU core is currently halted."
    },
    {
        "group": "CPU Control & Status",
        "signal": "i_cpu_run_req",
        "dir": "Input",
        "width": "1-bit",
        "block": "el2_veer_wrapper (CPU MPC)",
        "protocol": "Handshake Control",
        "usage": "External hardware CPU run request; resumes instruction fetching and execution for a previously halted CPU core."
    },
    {
        "group": "CPU Control & Status",
        "signal": "o_cpu_run_ack",
        "dir": "Output",
        "width": "1-bit",
        "block": "el2_veer_wrapper (CPU MPC)",
        "protocol": "Handshake Acknowledge",
        "usage": "Acknowledge signal asserted by CPU confirming that the core has successfully resumed active instruction execution."
    },
    {
        "group": "CPU Control & Status",
        "signal": "o_debug_mode_status",
        "dir": "Output",
        "width": "1-bit",
        "block": "el2_veer_wrapper (CPU MPC)",
        "protocol": "Status Indicator",
        "usage": "Status output signal indicating that the RISC-V core is currently halted in debug mode under JTAG/DMI debugger control."
    }
]

# Ensure directory exists
os.makedirs("/home/student/honours/docs/architecture", exist_ok=True)

# 1. Write CSV
csv_path = "/home/student/honours/docs/architecture/SoC_External_Interfaces_Sheet.csv"
fieldnames = ["Interface Group", "Signal / Pin Name", "Direction", "Width", "Connected Internal Block", "Protocol / Standard", "What / How We Are Using It"]

with open(csv_path, mode="w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    for row in interfaces:
        writer.writerow({
            "Interface Group": row["group"],
            "Signal / Pin Name": row["signal"],
            "Direction": row["dir"],
            "Width": row["width"],
            "Connected Internal Block": row["block"],
            "Protocol / Standard": row["protocol"],
            "What / How We Are Using It": row["usage"]
        })

print(f"Generated CSV: {csv_path} with {len(interfaces)} pins/interfaces.")

# 2. Write Excel XML
xml_path = "/home/student/honours/docs/architecture/SoC_External_Interfaces_Sheet.xml"

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
   <Interior ss:Color="#0D3B66" ss:Pattern="Solid"/>
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
   <Font ss:FontName="Consolas" ss:Size="10" ss:Color="#1D3557" ss:Bold="1"/>
  </Style>
  <Style ss:ID="InputCell">
   <Alignment ss:Horizontal="Center" ss:Vertical="Top"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
   </Borders>
   <Font ss:FontName="Calibri" ss:Size="10" ss:Color="#1E4620" ss:Bold="1"/>
   <Interior ss:Color="#E8F5E9" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="OutputCell">
   <Alignment ss:Horizontal="Center" ss:Vertical="Top"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
   </Borders>
   <Font ss:FontName="Calibri" ss:Size="10" ss:Color="#8B0000" ss:Bold="1"/>
   <Interior ss:Color="#FFEBEE" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="GroupCell">
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D3D3D3"/>
   </Borders>
   <Font ss:FontName="Calibri" ss:Size="10" ss:Color="#2C3E50" ss:Bold="1"/>
   <Interior ss:Color="#F4F6F9" ss:Pattern="Solid"/>
  </Style>
 </Styles>
 <Worksheet ss:Name="External Interfaces">
  <Table ss:ExpandedColumnCount="7" x:FullColumns="1" x:FullRows="1" ss:DefaultRowHeight="20">
   <Column ss:Width="140"/>
   <Column ss:Width="150"/>
   <Column ss:Width="80"/>
   <Column ss:Width="70"/>
   <Column ss:Width="160"/>
   <Column ss:Width="170"/>
   <Column ss:Width="350"/>
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

def escape_xml(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

for row in interfaces:
    grp  = escape_xml(row["group"])
    sig  = escape_xml(row["signal"])
    d    = escape_xml(row["dir"])
    w    = escape_xml(row["width"])
    blk  = escape_xml(row["block"])
    prt  = escape_xml(row["protocol"])
    usg  = escape_xml(row["usage"])
    dir_style = "InputCell" if row["dir"] == "Input" else "OutputCell"

    xml_content += f"""   <Row ss:AutoFitHeight="1">
    <Cell ss:StyleID="GroupCell"><Data ss:Type="String">{grp}</Data></Cell>
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
</Workbook>
"""

with open(xml_path, "w", encoding="utf-8") as f:
    f.write(xml_content)

print(f"Generated Excel XML: {xml_path}")
