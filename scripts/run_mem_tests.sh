#!/usr/bin/env bash
# =============================================================================
# scripts/run_mem_tests.sh
# Compiles and executes IMEM and DMEM AXI4 unit verification testbench.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export PATH=$VCS_HOME/bin:$PATH
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126

cd "${REPO_DIR}"
mkdir -p build_mem

echo "================================================================="
echo "  Compiling IMEM & DMEM Verification Testbench with Synopsys VCS"
echo "================================================================="

vcs -full64 -sverilog -timescale=1ns/1ps \
    rtl/mem/dmem_axi.sv \
    rtl/mem/imem_axi.sv \
    tb/soc/tb_mem_axi.sv \
    -top tb_mem_axi \
    -o build_mem/simv_mem \
    -l build_mem/compile.log

echo "================================================================="
echo "  Running IMEM & DMEM Verification Simulation"
echo "================================================================="
./build_mem/simv_mem -l build_mem/sim.log
