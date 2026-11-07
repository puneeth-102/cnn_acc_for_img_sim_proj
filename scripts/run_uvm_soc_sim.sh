#!/usr/bin/env bash
# =============================================================================
# scripts/run_uvm_soc_sim.sh
# Compiles and runs the integrated Top-Level UVM Testbench for VeeR-EL2 CNN SoC.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1
export PATH=$VCS_HOME/bin:$VERDI_HOME/bin:$PATH
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126

cd "${REPO_DIR}"
mkdir -p build_uvm

UVM_TEST="${1:-soc_base_test}"
HEX_FILE="${2:-sw/riscv_test/simple_test.hex}"

echo "================================================================="
echo "  COMPILING VEER-EL2 CNN SOC UVM TESTBENCH WITH SYNOPSYS VCS"
echo "  UVM Test : ${UVM_TEST}"
echo "  Firmware : ${HEX_FILE}"
echo "================================================================="

vcs -full64 -sverilog -ntb_opts uvm -timescale=1ns/1ps \
  +define+COMMON_CELLS_NO_DEPRECATED_WARNINGS \
  +define+DUMP_FSDB \
  -P ${VERDI_HOME}/share/PLI/VCS/linux64/novas.tab ${VERDI_HOME}/share/PLI/VCS/linux64/pli.a \
  +incdir+rtl/Cores-VeeR-EL2/snapshots/default \
  +incdir+rtl/Cores-VeeR-EL2/design/include \
  +incdir+rtl/Cores-VeeR-EL2/design/lib \
  +incdir+rtl/uart/include \
  +incdir+rtl/cnn \
  +incdir+rtl/similarity \
  +incdir+rtl/distance \
  +incdir+rtl/wrappers \
  +incdir+ip/timer/rtl \
  +incdir+ip/gpio/deps/common_cells/include \
  +incdir+ip/gpio/deps/register_interface/include \
  +incdir+ip/gpio/deps/tech_cells_generic/src/rtl \
  +incdir+tb/uvm \
  +incdir+tb/uvm/env \
  +incdir+tb/uvm/tests \
  +incdir+tb/uvm/vips/clk_rst_uvm_tb \
  +incdir+tb/uvm/vips/uart_uvm_tb \
  +incdir+tb/uvm/vips/gpio_uvm_tb \
  +incdir+tb/uvm/vips/irq_uvm_tb \
  +incdir+tb/uvm/vips/jtag_uvm_tb \
  rtl/Cores-VeeR-EL2/design/include/el2_def.sv \
  -f scripts/veer_files.f \
  rtl/interconnect/arbiter.v \
  rtl/interconnect/priority_encoder.v \
  rtl/interconnect/axi_interconnect.v \
  rtl/interconnect/axi_interconnect_wrap_2x8.v \
  rtl/uart/uart_parity_bit_compute.v \
  rtl/uart/axi_internal_fifo.v \
  rtl/uart/uart_transmitter.v \
  rtl/uart/uart_receiver.v \
  rtl/uart/uart_controller.v \
  rtl/uart/axi_uart_top.v \
  rtl/cnn/mac_unit.sv \
  rtl/cnn/conv3x3.sv \
  rtl/cnn/relu.sv \
  rtl/cnn/maxpool2x2.sv \
  rtl/cnn/flatten.sv \
  rtl/cnn/fc_196_16.sv \
  rtl/cnn/cnn_top.sv \
  rtl/distance/distance.sv \
  rtl/distance/threshold.sv \
  ip/timer/rtl/timer_core.sv \
  rtl/wrappers/timer_axi_wrapper.sv \
  ip/gpio/deps/register_interface/vendor/lowrisc_opentitan/src/prim_subreg_arb.sv \
  ip/gpio/deps/register_interface/vendor/lowrisc_opentitan/src/prim_subreg.sv \
  ip/gpio/deps/register_interface/vendor/lowrisc_opentitan/src/prim_subreg_ext.sv \
  ip/gpio/deps/register_interface/vendor/lowrisc_opentitan/src/prim_subreg_shadow.sv \
  ip/gpio/deps/register_interface/src/reg_intf.sv \
  ip/gpio/src/gpio_reg_pkg.sv \
  ip/gpio/src/gpio_reg_top.sv \
  ip/gpio/deps/tech_cells_generic/src/rtl/tc_sync.sv \
  ip/gpio/deps/common_cells/src/deprecated/sync.sv \
  ip/gpio/src/gpio_input_stage_no_clk_gates.sv \
  ip/gpio/src/gpio.sv \
  rtl/wrappers/gpio_axi_wrapper.sv \
  rtl/wrappers/cnn_axi_wrapper.sv \
  rtl/wrappers/distance_axi_wrapper.sv \
  rtl/wrappers/dma_axi_wrapper.sv \
  rtl/mem/imem_axi.sv \
  rtl/mem/dmem_axi.sv \
  rtl/top/cnn_soc_top.sv \
  tb/uvm/vips/clk_rst_uvm_tb/clk_rst_if.sv \
  tb/uvm/vips/uart_uvm_tb/uart_if.sv \
  tb/uvm/vips/gpio_uvm_tb/gpio_if.sv \
  tb/uvm/vips/irq_uvm_tb/irq_if.sv \
  tb/uvm/vips/jtag_uvm_tb/jtag_if.sv \
  tb/uvm/vips/clk_rst_uvm_tb/clk_rst_pkg.sv \
  tb/uvm/vips/uart_uvm_tb/uart_pkg.sv \
  tb/uvm/vips/gpio_uvm_tb/gpio_pkg.sv \
  tb/uvm/vips/irq_uvm_tb/irq_pkg.sv \
  tb/uvm/vips/jtag_uvm_tb/jtag_pkg.sv \
  tb/uvm/soc_uvm_pkg.sv \
  tb/uvm/tb_top.sv \
  -top tb_top -o build_uvm/simv_uvm_soc -l build_uvm/compile.log

echo "================================================================="
echo "  COMPILATION SUCCEEDED! RUNNING SIMULATION..."
echo "================================================================="

./build_uvm/simv_uvm_soc +UVM_TESTNAME=${UVM_TEST} +hex=${HEX_FILE} -l build_uvm/sim.log

echo "================================================================="
echo "  UVM SIMULATION COMPLETED! Check build_uvm/sim.log"
echo "================================================================="
