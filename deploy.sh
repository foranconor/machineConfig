#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/repos/machineConfig"
CONFIG_DIR="$HOME/linuxcnc/configs/myCoolMachine"

echo "Deploying myCoolMachine to $CONFIG_DIR"

mkdir -p "$CONFIG_DIR"

# Repo-owned files
cp "$REPO_DIR/myCoolMachine.ini" "$CONFIG_DIR/"

# read -rp "Deploy tools.tbl? [y/N] " deploy_tools
# if [[ "${deploy_tools,,}" == "y" ]]; then
#     cp "$REPO_DIR/tools.tbl" "$CONFIG_DIR/"
#     echo "Tool table deployed."
# else
#     echo "Skipping tools.tbl."
# fi

# HAL files and EtherCAT topology XML from repo (flat into config root)
for f in "$REPO_DIR/hal/"*.hal "$REPO_DIR/hal/"*.xml; do
  [[ -f "$f" ]] && cp "$f" "$CONFIG_DIR/"
done

# EtherCAT ESI file — needed once; requires sudo
ESI_DIR="/usr/share/lcec"
ESI_SRC="$REPO_DIR/LC10E V1.04.xml"
if [[ -f "$ESI_SRC" && ! -f "$ESI_DIR/LC10E V1.04.xml" ]]; then
  echo "Installing ESI file to $ESI_DIR (requires sudo)..."
  sudo mkdir -p "$ESI_DIR"
  sudo cp "$ESI_SRC" "$ESI_DIR/"
  echo "ESI installed."
fi

# Subroutines, M-codes, and Python remaps
mkdir -p "$CONFIG_DIR/subroutines"
mkdir -p "$CONFIG_DIR/mcodes"
mkdir -p "$CONFIG_DIR/python"
cp -r "$REPO_DIR/subroutines/." "$CONFIG_DIR/subroutines/"
cp -r "$REPO_DIR/mcodes/." "$CONFIG_DIR/mcodes/"
cp -r "$REPO_DIR/python/." "$CONFIG_DIR/python/"

# Standard hallib symlink (system resource, not copied)
ln -sfn /usr/share/linuxcnc/hallib "$CONFIG_DIR/hallib"

# State dir — persists across deploys, not tracked in repo
mkdir -p "$CONFIG_DIR/state"
if [[ ! -f "$CONFIG_DIR/state/tool_restore.ngc" ]]; then
  cat >"$CONFIG_DIR/state/tool_restore.ngc" <<'EOF'
O<tool_restore> sub
  M61 Q0
O<tool_restore> endsub
EOF
fi

echo "Done."
