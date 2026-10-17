#!/usr/bin/env bash
# =============================================================================
# scripts/view_uvm_verdi.sh
# Launches Synopsys Verdi with the UVM simulation FSDB waveform.
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1
export PATH=$VERDI_HOME/bin:$VCS_HOME/bin:$PATH
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126

cd "${REPO_DIR}"

FSDB_FILE="build_uvm/soc_uvm.fsdb"
if [ ! -f "${FSDB_FILE}" ]; then
    echo "Error: FSDB file ${FSDB_FILE} not found. Please run ./scripts/run_uvm_anomaly_sim.sh first!"
    exit 1
fi

echo "Launching Synopsys Verdi with UVM waveform: ${FSDB_FILE}..."
verdi -ssf "${FSDB_FILE}" -simflow -dbdir build_uvm/simv_uvm.daidir &
