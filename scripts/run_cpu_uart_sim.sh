#!/usr/bin/env bash
# =============================================================================
# scripts/run_cpu_uart_sim.sh
# Compiles the C firmware, compiles tb_cnn_soc_top with VCS,
# and runs the end-to-end CPU -> AXI -> UART simulation.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1
export PATH=$VERDI_HOME/bin:$VCS_HOME/bin:$PATH
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126

cd "${REPO_DIR}"

echo "================================================================="
echo "  Step 1: Building C Firmware for VeeR-EL2 CPU"
echo "================================================================="
./sw/hello_uart/build.sh

mkdir -p build_soc

echo "================================================================="
echo "  Step 2: Compiling Top-Level SoC Testbench with Synopsys VCS"
echo "================================================================="

vcs -full64 -sverilog -kdb -debug_access+all -timescale=1ns/1ps +define+COMMON_CELLS_NO_DEPRECATED_WARNINGS \
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
  rtl/wrappers/dma_axi_wrapper.sv \
  rtl/mem/imem_axi.sv \
  rtl/mem/dmem_axi.sv \
  rtl/top/cnn_soc_top.sv \
  tb/soc/tb_cnn_soc_top.sv \
  -top tb_cnn_soc_top -o build_soc/simv_soc_tb -l build_soc/compile_tb.log

echo "================================================================="
echo "  Step 3: Executing CPU -> AXI UART Simulation (with FSDB dump)"
echo "================================================================="

./build_soc/simv_soc_tb +hex=sw/hello_uart/boot.hex +fsdb "$@" -l build_soc/sim_tb.log


