#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$HOME/repos/machineConfig"
CONFIG_DIR="$HOME/linuxcnc/configs/myCoolMachine"

echo "Deploying myCoolMachine to $CONFIG_DIR"

mkdir -p "$CONFIG_DIR"

# Repo-owned files
cp "$REPO_DIR/myCoolMachine.ini" "$CONFIG_DIR/"

read -rp "Deploy tools.tbl? [y/N] " deploy_tools
if [[ "${deploy_tools,,}" == "y" ]]; then
    cp "$REPO_DIR/tools.tbl" "$CONFIG_DIR/"
    echo "Tool table deployed."
else
    echo "Skipping tools.tbl."
fi

# HAL files from repo (flat into config root)
for f in "$REPO_DIR/hal/"*.hal; do
    [[ -f "$f" ]] && cp "$f" "$CONFIG_DIR/"
done

# Subroutines, M-codes, and Python remaps
mkdir -p "$CONFIG_DIR/subroutines"
mkdir -p "$CONFIG_DIR/mcodes"
mkdir -p "$CONFIG_DIR/python"
cp -r "$REPO_DIR/subroutines/." "$CONFIG_DIR/subroutines/"
cp -r "$REPO_DIR/mcodes/."      "$CONFIG_DIR/mcodes/"
cp -r "$REPO_DIR/python/."      "$CONFIG_DIR/python/"

# Standard hallib symlink (system resource, not copied)
ln -sfn /usr/share/linuxcnc/hallib "$CONFIG_DIR/hallib"

# State dir — persists across deploys, not tracked in repo
mkdir -p "$CONFIG_DIR/state"
if [[ ! -f "$CONFIG_DIR/state/tool_restore.ngc" ]]; then
    cat > "$CONFIG_DIR/state/tool_restore.ngc" <<'EOF'
O<tool_restore> sub
  M61 Q0
O<tool_restore> endsub
EOF
fi

echo "Done."
