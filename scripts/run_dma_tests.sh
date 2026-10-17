#!/usr/bin/env bash
# =============================================================================
# scripts/run_dma_tests.sh
# Compiles and executes the AXI4 DMA Controller (dma_axi_wrapper) unit testbench.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export PATH=$VCS_HOME/bin:$PATH
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126

cd "${REPO_DIR}"
mkdir -p build_dma

echo "================================================================="
echo "  Compiling AXI4 DMA Testbench with Synopsys VCS"
echo "================================================================="

vcs -full64 -sverilog -timescale=1ns/1ps \
    rtl/wrappers/dma_axi_wrapper.sv \
    tb/dma/tb_dma_axi_wrapper.sv \
    -top tb_dma_axi_wrapper \
    -o build_dma/simv_dma \
    -l build_dma/compile.log

echo "================================================================="
echo "  Running AXI4 DMA Verification Simulation"
echo "================================================================="
./build_dma/simv_dma -l build_dma/sim.log
