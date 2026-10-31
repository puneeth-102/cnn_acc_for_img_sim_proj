#!/usr/bin/env bash
# =============================================================================
# Build script for simple_test C program on VeeR-EL2
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

CROSS_COMPILE=/home/student/tools/riscv-gnu/2023.04.29/bin/riscv64-unknown-elf-
CC=${CROSS_COMPILE}gcc
OBJCOPY=${CROSS_COMPILE}objcopy
OBJDUMP=${CROSS_COMPILE}objdump

echo "Compiling crt0.s and simple_test.c for RV32IMC_ZICSR_ZIFENCEI..."
${CC} -march=rv32imc_zicsr_zifencei -mabi=ilp32 -O2 -nostartfiles -T link.ld -Wall \
    crt0.s simple_test.c -o simple_test.elf

echo "Generating disassembly simple_test.dis..."
${OBJDUMP} -d simple_test.elf > simple_test.dis

echo "Generating raw binary simple_test.bin..."
${OBJCOPY} -O binary simple_test.elf simple_test.bin

echo "Converting binary to 32-bit word simple_test.hex for \$readmemh..."
python3 -c '
import struct
with open("simple_test.bin", "rb") as f:
    data = f.read()
if len(data) % 4 != 0:
    data += b"\x00" * (4 - (len(data) % 4))
words = [f"{val:08x}" for (val,) in struct.iter_unpack("<I", data)]
with open("simple_test.hex", "w") as f:
    for w in words:
        f.write(w + "\n")
print(f"Generated simple_test.hex with {len(words)} 32-bit instruction words ({len(data)} bytes).")
'

echo "Build SUCCEEDED!"
