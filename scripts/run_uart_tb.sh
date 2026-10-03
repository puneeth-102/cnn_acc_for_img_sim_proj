#!/usr/bin/env bash
# =============================================================
# run_uart_tb.sh
# Compile + simulate AXI-Lite UART testbench using VCS.
# Can be run from any directory.
# =============================================================

set -e

# Repository root = one level above this script:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export PATH=$VCS_HOME/bin:$PATH
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126

# Output directories
BUILD_DIR="${REPO_DIR}/run/uart/build"
WAVES_DIR="${BUILD_DIR}/waves"
SIMV_NAME="${BUILD_DIR}/simv_uart_tb"
COMPILE_LOG="${BUILD_DIR}/compile_uart_tb.log"
SIM_LOG="${BUILD_DIR}/sim_uart_tb.log"

mkdir -p "${BUILD_DIR}"
mkdir -p "${WAVES_DIR}"

echo "======================================================"
echo "  UART AXI-Lite Testbench – VCS Flow"
echo "======================================================"
echo "Repository : ${REPO_DIR}"
echo "Build dir  : ${BUILD_DIR}"
echo "Waves dir  : ${WAVES_DIR}"
echo ""

cd "${REPO_DIR}"

# -------------------------------------------------------------
# Step 1: Compile
# -------------------------------------------------------------
echo "[1/2] Compiling..."

vcs -full64 \
    -sverilog \
    -timescale=1ns/1ps \
    +incdir+rtl/uart/include \
    rtl/uart/uart_parity_bit_compute.v \
    rtl/uart/axi_internal_fifo.v \
    rtl/uart/uart_transmitter.v \
    rtl/uart/uart_receiver.v \
    rtl/uart/uart_controller.v \
    rtl/uart/axi_uart_top.v \
    tb/uart/uart_axi_tb.v \
    -P /home/student/snps_tools_target/verdi/U-2023.03-SP1/share/PLI/VCS/LINUX64/novas.tab \
       /home/student/snps_tools_target/verdi/U-2023.03-SP1/share/PLI/VCS/LINUX64/pli.a \
    -o "${SIMV_NAME}" \
    -l "${COMPILE_LOG}"

echo "Compile done -> ${COMPILE_LOG}"
echo 

# -------------------------------------------------------------
# Step 2: Simulate
# -------------------------------------------------------------
echo "[2/2] Simulating..."

"${SIMV_NAME}" \
    +fsdbfile+"${WAVES_DIR}/uart_axi_dump.fsdb" \
    -l "${SIM_LOG}"

echo ""
echo "Simulation done -> ${SIM_LOG}"
echo "FSDB waveform  -> ${WAVES_DIR}/uart_axi_dump.fsdb"
echo ""

# -------------------------------------------------------------
# Result summary
# -------------------------------------------------------------
echo "======================================================"
echo "  Result Summary"
echo "======================================================"
grep -E "(PASS|FAIL|OVERALL|TOTAL)" "${SIM_LOG}" || true
echo "======================================================"
