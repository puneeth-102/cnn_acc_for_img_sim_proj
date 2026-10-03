#!/usr/bin/env bash
# =============================================================================
# scripts/compile_soc_top.sh
# Compiles and elaborates the complete CNN Anomaly Detection SoC Top-Level
# with VeeR-EL2 CPU, AXI Interconnect, UART, CNN, Distance, Timer, GPIO, IMEM, and DMEM.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export PATH=$VCS_HOME/bin:$PATH
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126

cd "${REPO_DIR}"
mkdir -p build_soc

echo "================================================================="
echo "  Compiling Complete SoC Top-Level (cnn_soc_top) with VCS"
echo "================================================================="

vcs -full64 -sverilog -timescale=1ns/1ps +define+COMMON_CELLS_NO_DEPRECATED_WARNINGS \
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
  rtl/mem/imem_axi.sv \
  rtl/mem/dmem_axi.sv \
  rtl/top/cnn_soc_top.sv \
  -top cnn_soc_top -o build_soc/simv_soc_top -l build_soc/compile_soc.log

echo "================================================================="
echo "  SoC Top-Level Compilation and Elaboration SUCCEEDED!"
echo "  Binary: build_soc/simv_soc_top"
echo "================================================================="
