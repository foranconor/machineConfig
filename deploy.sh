#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/repos/machineConfig"
CONFIG_DIR="$HOME/linuxcnc/configs/myCoolMachine"

echo "Deploying myCoolMachine to $CONFIG_DIR"

mkdir -p "$CONFIG_DIR"

# Repo-owned files
cp "$REPO_DIR/myCoolMachine.ini" "$CONFIG_DIR/"
cp "$REPO_DIR/tools.tbl"         "$CONFIG_DIR/"

# HAL files from repo (flat into config root)
for f in "$REPO_DIR/hal/"*.hal; do
    [[ -f "$f" ]] && cp "$f" "$CONFIG_DIR/"
done

# Subroutines and M-codes
mkdir -p "$CONFIG_DIR/subroutines"
mkdir -p "$CONFIG_DIR/mcodes"
cp -r "$REPO_DIR/subroutines/." "$CONFIG_DIR/subroutines/"
cp -r "$REPO_DIR/mcodes/."      "$CONFIG_DIR/mcodes/"

# Standard hallib symlink (system resource, not copied)
ln -sfn /usr/share/linuxcnc/hallib "$CONFIG_DIR/hallib"

# Set as default config so linuxcnc skips the picker on startup
RCFILE="$HOME/.linuxcncrc"
if grep -q '^\[PICKCONFIG\]' "$RCFILE" 2>/dev/null; then
    sed -i "s|^LAST_CONFIG.*|LAST_CONFIG = $CONFIG_DIR/myCoolMachine.ini|" "$RCFILE"
else
    printf '\n[PICKCONFIG]\nLAST_CONFIG = %s/myCoolMachine.ini\n' "$CONFIG_DIR" >> "$RCFILE"
fi

echo "Done."
