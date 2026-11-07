#!/usr/bin/env bash
# =============================================================================
# scripts/build_sw_test.sh
# Compiles a C firmware test under sw/tests/<test_name>/main.c into .elf, .bin, .hex
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TEST_NAME="${1}"
if [ -z "${TEST_NAME}" ]; then
    echo "Usage: $0 <test_name>"
    echo "Example: $0 tc_dma_01"
    exit 1
fi

TEST_DIR="${REPO_DIR}/sw/tests/${TEST_NAME}"
if [ ! -d "${TEST_DIR}" ]; then
    echo "Error: Directory ${TEST_DIR} does not exist!"
    exit 1
fi

if [ ! -f "${TEST_DIR}/main.c" ]; then
    echo "Error: ${TEST_DIR}/main.c not found!"
    exit 1
fi

CROSS_COMPILE=/home/student/tools/riscv-gnu/2023.04.29/bin/riscv64-unknown-elf-
CC=${CROSS_COMPILE}gcc
OBJCOPY=${CROSS_COMPILE}objcopy
OBJDUMP=${CROSS_COMPILE}objdump

echo "Compiling ${TEST_NAME} for RV32IMC..."
${CC} -march=rv32imc_zicsr_zifencei -mabi=ilp32 -O2 -nostartfiles \
    -T "${REPO_DIR}/sw/riscv_test/link.ld" \
    -I "${REPO_DIR}/sw/include" \
    -Wall \
    "${REPO_DIR}/sw/riscv_test/crt0.s" \
    "${TEST_DIR}/main.c" \
    -o "${TEST_DIR}/main.elf"

echo "Generating disassembly ${TEST_DIR}/main.dis..."
${OBJDUMP} -d "${TEST_DIR}/main.elf" > "${TEST_DIR}/main.dis"

echo "Generating binary ${TEST_DIR}/main.bin..."
${OBJCOPY} -O binary "${TEST_DIR}/main.elf" "${TEST_DIR}/main.bin"

echo "Generating 32-bit word hex ${TEST_DIR}/main.hex..."
python3 -c '
import struct, sys
bin_file = sys.argv[1]
hex_file = sys.argv[2]
with open(bin_file, "rb") as f:
    data = f.read()
if len(data) % 4 != 0:
    data += b"\x00" * (4 - (len(data) % 4))
words = [f"{val:08x}" for (val,) in struct.iter_unpack("<I", data)]
with open(hex_file, "w") as f:
    for w in words:
        f.write(w + "\n")
print(f"Generated {hex_file}: {len(words)} words ({len(data)} bytes).")
' "${TEST_DIR}/main.bin" "${TEST_DIR}/main.hex"

echo "=== BUILD SUCCESSFUL for ${TEST_NAME} ==="
