#!/usr/bin/env bash
# =============================================================================
# Run simple_test CPU -> UART simulation
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

"${REPO_DIR}/scripts/run_cpu_uart_sim.sh" sw/riscv_test/simple_test.hex "$@"
