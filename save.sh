#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/repos/machineConfig"
CONFIG_DIR="$HOME/linuxcnc/configs/myCoolMachine"

echo "Saving from $CONFIG_DIR back to repo..."

cp "$CONFIG_DIR/myCoolMachine.ini" "$REPO_DIR/"
cp "$CONFIG_DIR/tools.tbl"         "$REPO_DIR/"

# Subroutines
mkdir -p "$REPO_DIR/subroutines"
find "$CONFIG_DIR/subroutines" -maxdepth 1 -name "*.ngc" -exec cp {} "$REPO_DIR/subroutines/" \;

# M-codes
mkdir -p "$REPO_DIR/mcodes"
find "$CONFIG_DIR/mcodes" -maxdepth 1 -name "*.ngc" -exec cp {} "$REPO_DIR/mcodes/" \;

# Python remaps
mkdir -p "$REPO_DIR/python"
find "$CONFIG_DIR/python" -maxdepth 1 -name "*.py" -exec cp {} "$REPO_DIR/python/" \;

# Custom HAL files (skip stock and external files)
SKIP_HALS=(core_sim.hal sim_spindle_encoder.hal axis_manualtoolchange.hal simulated_home.hal panic_controller.hal)
for f in "$CONFIG_DIR/"*.hal; do
    [[ -f "$f" ]] || continue
    fname="$(basename "$f")"
    skip=0
    for s in "${SKIP_HALS[@]}"; do [[ "$fname" == "$s" ]] && skip=1 && break; done
    [[ $skip -eq 0 ]] && cp "$f" "$REPO_DIR/hal/"
done

echo "Done. Changes:"
cd "$REPO_DIR"
git diff --stat
