#!/bin/bash
set -e

# Build the Analogue Pocket PCXT core with Quartus.
# Override QUARTUS_DIR to point at a different Quartus install.

QUARTUS_DIR="${QUARTUS_DIR:-/opt/intelFPGA_lite/18.1/quartus}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$PROJECT_DIR/src/fpga"

# Quartus incremental compile ignores $readmem ROM images (firmware, splash,
# credits text, fonts), so always synthesize from a clean cache.
rm -rf db incremental_db

echo "Building openfpga-x86 (PCXT) with Quartus 18.1..."
"$QUARTUS_DIR/bin/quartus_sh" --flow compile ap_core
