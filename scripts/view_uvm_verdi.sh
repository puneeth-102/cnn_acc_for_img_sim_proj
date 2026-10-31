#!/usr/bin/env bash
# =============================================================================
# scripts/view_uvm_verdi.sh
# Launches Synopsys Verdi with the UVM simulation and restored signals.
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1
export PATH=$VERDI_HOME/bin:$VCS_HOME/bin:$PATH
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126

cd "${REPO_DIR}"

FSDB_FILE="build_soc/uvm_soc_sim.fsdb"
if [ ! -f "${FSDB_FILE}" ]; then
    echo "ERROR: FSDB waveform file not found at ${FSDB_FILE}"
    exit 1
fi

RC_FILE="scripts/uvm_soc_wave.rc"
RC_OPT=""
if [ -f "${RC_FILE}" ]; then
    RC_OPT="-sswr ${RC_FILE}"
fi

echo "Launching Synopsys Verdi with ${FSDB_FILE} ${RC_OPT}..."
exec verdi -ssf "${FSDB_FILE}" ${RC_OPT} "$@"
