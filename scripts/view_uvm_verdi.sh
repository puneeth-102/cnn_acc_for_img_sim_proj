#!/usr/bin/env bash
# =============================================================================
# scripts/view_uvm_verdi.sh
# Opens Synopsys Verdi with the UVM SoC simulation FSDB database.
# =============================================================================

export VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1
export PATH=$VERDI_HOME/bin:$PATH
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_DIR}"

FSDB_FILE="build_soc/uvm_soc_sim.fsdb"

if [ ! -f "${FSDB_FILE}" ]; then
    echo "ERROR: FSDB waveform file not found at ${FSDB_FILE}"
    exit 1
fi

echo "Launching Synopsys Verdi with ${FSDB_FILE}..."
verdi -ssf "${FSDB_FILE}" &
